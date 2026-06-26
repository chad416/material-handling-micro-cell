"""Async OPC UA server for the MHMC semantic namespace.

Runtime dependency: ``asyncua``.  The pure model and data provider modules are
kept importable without asyncua so mapping and unit tests remain lightweight.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
from pathlib import Path
from typing import Any

from .data_provider import CellDataProvider, InMemoryCellDataProvider
from .model import APPLICATION_URI, NAMESPACE_URI, NODE_SPECS, OBJECT_PATHS, NodeSpec

try:  # pragma: no cover - exercised only when asyncua is installed.
    from asyncua import Server, ua, uamethod
except ModuleNotFoundError:  # pragma: no cover
    Server = None  # type: ignore[assignment]
    ua = None  # type: ignore[assignment]
    uamethod = None  # type: ignore[assignment]


LOGGER = logging.getLogger("mhmc.opcua")


class MHMCOpcUaServer:
    """Builds and runs the MHMC OPC UA address space."""

    def __init__(
        self,
        provider: CellDataProvider | None = None,
        endpoint: str = "opc.tcp://0.0.0.0:4840/mhmc/server/",
        sample_period_s: float = 0.1,
        certificate: Path | None = None,
        private_key: Path | None = None,
        allow_insecure: bool = False,
    ) -> None:
        if Server is None or ua is None:
            raise RuntimeError("asyncua is not installed. Run: pip install -r opcua_server/requirements.txt")

        self.provider = provider or InMemoryCellDataProvider()
        self.endpoint = endpoint
        self.sample_period_s = sample_period_s
        self.certificate = certificate
        self.private_key = private_key
        self.allow_insecure = allow_insecure
        self.server = Server()
        self.namespace_index = 0
        self.objects_by_path: dict[tuple[str, ...], Any] = {}
        self.nodes_by_id: dict[str, Any] = {}
        self.last_values: dict[str, Any] = {}
        self.last_alarm_sequence = 0
        self._stop_event = asyncio.Event()

    async def init(self) -> None:
        await self.server.init()
        self.server.set_endpoint(self.endpoint)
        self.server.set_server_name("MHMC-01 Semantic OPC UA Server")
        await self.server.set_application_uri(APPLICATION_URI)

        await self._configure_security()
        self.namespace_index = await self.server.register_namespace(NAMESPACE_URI)
        await self._build_namespace()

    async def start(self) -> None:
        await self.init()
        await self.server.start()
        LOGGER.info("MHMC OPC UA server running at %s", self.endpoint)
        LOGGER.info("Namespace URI %s registered as ns=%s", NAMESPACE_URI, self.namespace_index)
        try:
            await self._run_update_loop()
        finally:
            await self.server.stop()
            LOGGER.info("MHMC OPC UA server stopped")

    async def stop(self) -> None:
        self._stop_event.set()

    async def _configure_security(self) -> None:
        if self.certificate and self.private_key:
            await self.server.load_certificate(str(self.certificate))
            await self.server.load_private_key(str(self.private_key))
            self.server.set_security_policy([ua.SecurityPolicyType.Basic256Sha256_SignAndEncrypt])
            LOGGER.info("Secure endpoint enabled: Basic256Sha256 SignAndEncrypt")
            return

        if not self.allow_insecure:
            raise RuntimeError(
                "Refusing to start without a server certificate/private key. "
                "Generate them with opcua_server/generate_cert.py or pass --allow-insecure for local SIL only."
            )

        LOGGER.warning("Starting OPC UA server with NoSecurity. Use only for local simulation.")

    async def _build_namespace(self) -> None:
        root_objects = self.server.nodes.objects
        for path in OBJECT_PATHS:
            parent = root_objects if len(path) == 1 else self.objects_by_path[path[:-1]]
            nodeid = ua.NodeId(".".join(path), self.namespace_index)
            browse_name = path[-1]
            if len(path) == 1 or browse_name in {"DeviceSet", "ControlState", "KPIs", "Alarms", "Maintenance", "Recipes", "EventTimeline", "PLCIntegration", "Methods"}:
                obj = await parent.add_folder(nodeid, browse_name)
            else:
                obj = await parent.add_object(nodeid, browse_name)
            self.objects_by_path[path] = obj

        for spec in NODE_SPECS:
            await self._add_variable(spec)

        await self._add_methods()

    async def _add_variable(self, spec: NodeSpec) -> None:
        parent = self.objects_by_path[spec.path]
        nodeid = ua.NodeId(spec.node_id, self.namespace_index)
        variant_type = getattr(ua.VariantType, spec.variant_type)
        node = await parent.add_variable(nodeid, spec.browse_name, spec.default, variant_type)
        await self._write_localized_attribute(node, ua.AttributeIds.Description, spec.description)
        await self._write_localized_attribute(node, ua.AttributeIds.DisplayName, spec.browse_name)
        if spec.is_writable:
            await node.set_writable()
        self.nodes_by_id[spec.node_id] = node
        self.last_values[spec.node_id] = spec.default

    @staticmethod
    async def _write_localized_attribute(node: Any, attribute_id: Any, text: str) -> None:
        value = ua.DataValue(ua.Variant(ua.LocalizedText(text), ua.VariantType.LocalizedText))
        await node.write_attribute(attribute_id, value)

    async def _add_methods(self) -> None:
        methods = self.objects_by_path[("MHMC_Cell", "Methods")]
        idx = self.namespace_index

        @uamethod
        async def start_cell(parent):
            accepted = await self.provider.pulse_command("StartCell")
            return bool(accepted)

        @uamethod
        async def stop_cell(parent):
            accepted = await self.provider.pulse_command("StopCell")
            return bool(accepted)

        @uamethod
        async def reset_jam(parent):
            accepted = await self.provider.pulse_command("ResetJam")
            return bool(accepted)

        @uamethod
        async def load_recipe(parent, recipe_id, target_speed):
            return int(await self.provider.load_recipe(int(recipe_id), float(target_speed)))

        bool_arg = ua.Argument(Name="Success", DataType=ua.NodeId(ua.ObjectIds.Boolean), ValueRank=-1)
        status_arg = ua.Argument(Name="Status", DataType=ua.NodeId(ua.ObjectIds.Int16), ValueRank=-1)
        recipe_id_arg = ua.Argument(Name="RecipeID", DataType=ua.NodeId(ua.ObjectIds.UInt16), ValueRank=-1)
        target_speed_arg = ua.Argument(Name="TargetSpeed", DataType=ua.NodeId(ua.ObjectIds.Double), ValueRank=-1)

        await methods.add_method(ua.NodeId("Methods.StartCell", idx), "StartCell", start_cell, [], [bool_arg])
        await methods.add_method(ua.NodeId("Methods.StopCell", idx), "StopCell", stop_cell, [], [bool_arg])
        await methods.add_method(ua.NodeId("Methods.ResetJam", idx), "ResetJam", reset_jam, [], [bool_arg])
        await methods.add_method(
            ua.NodeId("Methods.LoadRecipe", idx),
            "LoadRecipe",
            load_recipe,
            [recipe_id_arg, target_speed_arg],
            [status_arg],
        )

    async def _run_update_loop(self) -> None:
        while not self._stop_event.is_set():
            await self._harvest_client_writes()
            snapshot = await self.provider.read_snapshot()
            await self._publish_snapshot(snapshot)
            await self._publish_alarm_event_if_needed(snapshot)
            try:
                await asyncio.wait_for(self._stop_event.wait(), timeout=self.sample_period_s)
            except asyncio.TimeoutError:
                pass

    async def _harvest_client_writes(self) -> None:
        for spec in NODE_SPECS:
            if not spec.is_writable:
                continue
            node = self.nodes_by_id[spec.node_id]
            value = await node.read_value()
            if value != self.last_values.get(spec.node_id):
                await self.provider.write_value(spec.node_id, value)
                self.last_values[spec.node_id] = value

    async def _publish_snapshot(self, snapshot: dict[str, Any]) -> None:
        for spec in NODE_SPECS:
            value = snapshot.get(spec.node_id, spec.default)
            if value == self.last_values.get(spec.node_id):
                continue
            variant_type = getattr(ua.VariantType, spec.variant_type)
            await self.nodes_by_id[spec.node_id].write_value(ua.Variant(value, variant_type))
            self.last_values[spec.node_id] = value

    async def _publish_alarm_event_if_needed(self, snapshot: dict[str, Any]) -> None:
        sequence = int(snapshot.get("EventTimeline.LastSequence", 0) or 0)
        if sequence == 0 or sequence == self.last_alarm_sequence:
            return
        severity = int(snapshot.get("EventTimeline.LastSeverity", 0) or 0)
        message = str(snapshot.get("EventTimeline.LastMessage", "MHMC event"))
        self.last_alarm_sequence = sequence

        # asyncua event generation APIs vary by minor version.  Keep this
        # best-effort path isolated; monitored EventTimeline variables remain
        # the deterministic subscription contract for SCADA collectors.
        try:
            emitting_node = self.objects_by_path[("MHMC_Cell", "Alarms")].nodeid
            generator = await self.server.get_event_generator(
                ua.ObjectIds.BaseEventType,
                emitting_node,
            )
            generator.event.Severity = severity
            await generator.trigger(message=message)
        except Exception as exc:  # pragma: no cover - depends on asyncua runtime.
            LOGGER.debug("OPC UA event publish skipped: %s", exc)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the MHMC semantic OPC UA server")
    parser.add_argument("--endpoint", default="opc.tcp://0.0.0.0:4840/mhmc/server/")
    parser.add_argument("--sample-period", type=float, default=0.1)
    parser.add_argument("--certificate", type=Path)
    parser.add_argument("--private-key", type=Path)
    parser.add_argument("--allow-insecure", action="store_true", help="Permit NoSecurity for local SIL only")
    parser.add_argument("--log-level", default="INFO")
    return parser.parse_args()


async def amain() -> None:
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper()), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    server = MHMCOpcUaServer(
        endpoint=args.endpoint,
        sample_period_s=args.sample_period,
        certificate=args.certificate,
        private_key=args.private_key,
        allow_insecure=args.allow_insecure,
    )
    await server.start()


def main() -> None:
    asyncio.run(amain())


if __name__ == "__main__":
    main()
