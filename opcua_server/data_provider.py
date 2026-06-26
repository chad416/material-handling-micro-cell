"""Data provider boundary between OPC UA and PLC/shared memory.

The production adapter is expected to bind these semantic node IDs to TwinCAT
ADS symbols, fieldbus gateway registers, or another deterministic shared memory
bridge.  The in-memory provider is intentionally small but complete enough for
unit tests, local SCADA checks, and digital twin bring-up.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import Any, Protocol

from .model import NODE_SPECS, NodeSpec, default_values, nodes_by_id


class CellDataProvider(Protocol):
    async def read_snapshot(self) -> dict[str, Any]:
        """Return a complete semantic snapshot keyed by OPC UA node ID."""

    async def write_value(self, node_id: str, value: Any) -> None:
        """Apply a client write to the backing PLC/shared model."""

    async def pulse_command(self, command: str) -> bool:
        """Apply one-shot remote commands such as StartCell or ResetJam."""

    async def load_recipe(self, recipe_id: int, target_speed_mps: float) -> int:
        """Load a recipe and return the documented status code."""


@dataclass
class CommandRegister:
    """One-cycle command latch mirrored to PLC command bits by an adapter."""

    xRemoteStart: bool = False
    xRemoteStop: bool = False
    xRemoteReset: bool = False
    xManualResetJam: bool = False
    xLoadRecipeCommand: bool = False

    def clear_one_shots(self) -> None:
        self.xRemoteStart = False
        self.xRemoteStop = False
        self.xRemoteReset = False
        self.xManualResetJam = False
        self.xLoadRecipeCommand = False


@dataclass
class InMemoryCellDataProvider:
    """Thread-safe in-process data source used for SIL and unit testing."""

    values: dict[str, Any] = field(default_factory=default_values)
    commands: CommandRegister = field(default_factory=CommandRegister)
    min_speed_mps: float = 0.05
    max_speed_mps: float = 1.2
    valid_recipe_ids: set[int] = field(default_factory=lambda: {1, 2, 3})

    def __post_init__(self) -> None:
        self._lock = asyncio.Lock()
        self._spec_by_id = nodes_by_id()

    async def read_snapshot(self) -> dict[str, Any]:
        async with self._lock:
            return dict(self.values)

    async def write_value(self, node_id: str, value: Any) -> None:
        spec = self._spec_by_id.get(node_id)
        if spec is None:
            raise KeyError(f"Unknown OPC UA node ID: {node_id}")
        if not spec.is_writable:
            raise PermissionError(f"OPC UA node is read-only: {node_id}")

        coerced = self._coerce_for_spec(spec, value)
        async with self._lock:
            self.values[node_id] = coerced

    async def pulse_command(self, command: str) -> bool:
        async with self._lock:
            if command == "StartCell":
                self.commands.xRemoteStart = True
                self.values["ControlState.CurrentState"] = 1
                return True
            if command == "StopCell":
                self.commands.xRemoteStop = True
                self.values["ControlState.CurrentState"] = 7
                return True
            if command == "ResetJam":
                self.commands.xRemoteReset = True
                self.commands.xManualResetJam = True
                self.values["Alarms.GeneralJamAlarm"] = False
                self.values["Alarms.AnyActive"] = False
                self.values["ControlState.CurrentState"] = 6
                return True
            return False

    async def load_recipe(self, recipe_id: int, target_speed_mps: float) -> int:
        if recipe_id not in self.valid_recipe_ids:
            return -2
        if target_speed_mps != 0.0 and not (self.min_speed_mps <= target_speed_mps <= self.max_speed_mps):
            return -1

        async with self._lock:
            self.values["Recipes.ActiveRecipeID"] = int(recipe_id)
            self.values["Recipes.TargetSpeed"] = float(target_speed_mps)
            if target_speed_mps > 0.0:
                self.values["DeviceSet.Conveyor_1.SpeedSetpoint"] = float(target_speed_mps)
            self.commands.xLoadRecipeCommand = True
        return 0

    @staticmethod
    def _coerce_for_spec(spec: NodeSpec, value: Any) -> Any:
        if spec.variant_type == "Boolean":
            return bool(value)
        if spec.variant_type in {"Double", "Float"}:
            return float(value)
        if spec.variant_type in {"UInt16", "UInt32", "Int16", "Int32"}:
            numeric = int(value)
            if spec.variant_type.startswith("UInt") and numeric < 0:
                raise ValueError(f"{spec.node_id} does not accept negative values")
            return numeric
        if spec.variant_type == "String":
            return str(value)
        return value


def build_plc_fieldbus_mapping() -> list[dict[str, str]]:
    """Expose semantic-to-PLC bindings for ADS, fieldbus gateway, or codegen."""

    rows: list[dict[str, str]] = []
    for spec in NODE_SPECS:
        rows.append(
            {
                "opcua_node_id": spec.node_id,
                "plc_symbol": spec.plc_symbol,
                "access": spec.access.value,
                "variant_type": spec.variant_type,
                "historian_measurement": spec.historian_measurement,
                "historian_field": spec.historian_field,
            }
        )
    return rows
