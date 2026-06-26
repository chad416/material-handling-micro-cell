"""Telemetry sample model, buffering, and Influx line protocol conversion."""

from __future__ import annotations

import math
from collections import deque
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Iterable, Protocol

from opcua_server.model import NodeSpec, nodes_by_id


@dataclass(frozen=True)
class TelemetrySample:
    timestamp: datetime
    values: dict[str, Any]
    cell_id: str = "mhmc_01"

    def value(self, node_id: str, default: Any = None) -> Any:
        return self.values.get(node_id, default)


class TelemetryWriter(Protocol):
    def write_lines(self, lines: list[str]) -> None:
        """Write line protocol records to the historian."""


class TelemetryBuffer:
    """Bounded FIFO buffer for efficient historian writes."""

    def __init__(self, max_size: int = 10000) -> None:
        if max_size <= 0:
            raise ValueError("max_size must be positive")
        self._items: deque[str] = deque(maxlen=max_size)
        self.dropped_records = 0

    def append_many(self, lines: Iterable[str]) -> None:
        for line in lines:
            if len(self._items) == self._items.maxlen:
                self.dropped_records += 1
            self._items.append(line)

    def pop_batch(self, max_batch_size: int) -> list[str]:
        batch: list[str] = []
        while self._items and len(batch) < max_batch_size:
            batch.append(self._items.popleft())
        return batch

    def __len__(self) -> int:
        return len(self._items)


def sample_to_line_protocol(sample: TelemetrySample, specs: Iterable[NodeSpec] | None = None) -> list[str]:
    """Convert a semantic sample into deterministic Influx line protocol."""

    spec_list = tuple(specs) if specs is not None else tuple(nodes_by_id().values())
    timestamp_ns = _timestamp_ns(sample.timestamp)
    lines: list[str] = []

    for spec in spec_list:
        if spec.node_id not in sample.values:
            continue
        field_value = _format_field_value(sample.values[spec.node_id])
        if field_value is None:
            continue
        measurement = _escape_measurement(spec.historian_measurement)
        tags = f"cell_id={_escape_tag(sample.cell_id)},node_id={_escape_tag(spec.node_id)}"
        if spec.category:
            tags += f",category={_escape_tag(spec.category)}"
        field = _escape_key(spec.historian_field)
        lines.append(f"{measurement},{tags} {field}={field_value} {timestamp_ns}")

    return lines


def kpi_summary_to_line_protocol(summary: Any, cell_id: str, timestamp: datetime | None = None) -> str:
    ts = _timestamp_ns(timestamp or datetime.now(UTC))
    fields = {
        "throughput_per_min": summary.throughput_per_min,
        "mean_time_between_jams_s": summary.mean_time_between_jams_s,
        "average_cycle_time_s": summary.average_cycle_time_s,
        "window_s": summary.window_s,
        "total_packages_delta": summary.total_packages_delta,
        "jam_delta": summary.jam_delta,
    }
    formatted_fields = []
    for key, value in fields.items():
        formatted_value = _format_field_value(value)
        if formatted_value is not None:
            formatted_fields.append(f"{_escape_key(key)}={formatted_value}")
    formatted = ",".join(formatted_fields)
    return f"computed_kpis,cell_id={_escape_tag(cell_id)} {formatted} {ts}"


class InfluxDBLineWriter:
    """InfluxDB v2 writer using line protocol records."""

    def __init__(self, url: str, token: str, org: str, bucket: str) -> None:
        try:
            from influxdb_client import InfluxDBClient
            from influxdb_client.client.write_api import SYNCHRONOUS
        except ModuleNotFoundError as exc:  # pragma: no cover - runtime dependency.
            raise RuntimeError("influxdb-client is not installed. Install digital_twin/requirements.txt") from exc

        self._bucket = bucket
        self._org = org
        self._client = InfluxDBClient(url=url, token=token, org=org)
        self._write_api = self._client.write_api(write_options=SYNCHRONOUS)

    def write_lines(self, lines: list[str]) -> None:
        if lines:
            self._write_api.write(bucket=self._bucket, org=self._org, record=lines)

    def close(self) -> None:
        self._client.close()


class MemoryLineWriter:
    """Test writer that records line protocol batches in memory."""

    def __init__(self) -> None:
        self.lines: list[str] = []

    def write_lines(self, lines: list[str]) -> None:
        self.lines.extend(lines)


class SensorEdgeCounter:
    """Rising-edge counters for sensor nodes sampled through OPC UA."""

    SENSOR_FIELDS = {
        "DeviceSet.Conveyor_1.PE1_Blocked": "pe1_infeed_count",
        "DeviceSet.Conveyor_1.PE2_Blocked": "pe2_scanner_count",
        "DeviceSet.Conveyor_1.PE3_Blocked": "pe3_diverter_approach_count",
        "DeviceSet.Diverter_1.PE_Verify": "lane_a_verify_count",
        "DeviceSet.Diverter_2.PE_Verify": "lane_b_verify_count",
    }

    def __init__(self) -> None:
        self._last_state = {node_id: False for node_id in self.SENSOR_FIELDS}
        self.counts = {field: 0 for field in self.SENSOR_FIELDS.values()}

    def update(self, sample: TelemetrySample) -> str | None:
        changed = False
        for node_id, field in self.SENSOR_FIELDS.items():
            current = bool(sample.value(node_id, False))
            if current and not self._last_state[node_id]:
                self.counts[field] += 1
                changed = True
            self._last_state[node_id] = current

        if not changed:
            return None

        field_values = ",".join(f"{_escape_key(field)}={value}i" for field, value in self.counts.items())
        return f"sensor_counts,cell_id={_escape_tag(sample.cell_id)} {field_values} {_timestamp_ns(sample.timestamp)}"


def _timestamp_ns(timestamp: datetime) -> int:
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=UTC)
    return int(timestamp.timestamp() * 1_000_000_000)


def _format_field_value(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return f"{value}i"
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return None
        return repr(float(value))
    return f"\"{str(value).replace(chr(92), chr(92) + chr(92)).replace(chr(34), chr(92) + chr(34))}\""


def _escape_measurement(value: str) -> str:
    return value.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,")


def _escape_tag(value: str) -> str:
    return value.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,").replace("=", "\\=")


def _escape_key(value: str) -> str:
    return value.replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,").replace("=", "\\=")
