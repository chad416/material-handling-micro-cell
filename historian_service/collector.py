"""Runtime historian connector for OPC UA to InfluxDB."""

from __future__ import annotations

import argparse
import asyncio
import logging
from collections import deque
from datetime import UTC, datetime
from typing import Any

from opcua_server.model import NODE_SPECS

from .config import HistorianConfig
from .kpi import compute_kpis
from .telemetry import InfluxDBLineWriter, SensorEdgeCounter, TelemetryBuffer, TelemetrySample, kpi_summary_to_line_protocol, sample_to_line_protocol


LOGGER = logging.getLogger("mhmc.historian")


class OpcUaSnapshotCollector:
    """Collect semantic OPC UA variables into timestamped snapshots."""

    def __init__(self, config: HistorianConfig) -> None:
        self.config = config
        self._client: Any | None = None
        self._nodes: dict[str, Any] = {}

    async def __aenter__(self) -> "OpcUaSnapshotCollector":
        try:
            from asyncua import Client, ua
            from asyncua.crypto.security_policies import SecurityPolicyBasic256Sha256
        except ModuleNotFoundError as exc:  # pragma: no cover - runtime dependency.
            raise RuntimeError("asyncua is not installed. Install digital_twin/requirements.txt") from exc

        self._client = Client(url=self.config.opcua_endpoint)
        if self.config.opcua_security_policy != "None":
            if self.config.opcua_client_certificate is None or self.config.opcua_client_private_key is None:
                raise RuntimeError(
                    "Secure OPC UA collection requires MHMC_OPCUA_CLIENT_CERT and MHMC_OPCUA_CLIENT_KEY"
                )
            if self.config.opcua_security_policy != "Basic256Sha256":
                raise RuntimeError(f"Unsupported OPC UA security policy: {self.config.opcua_security_policy}")
            mode = getattr(ua.MessageSecurityMode, self.config.opcua_security_mode)
            await self._client.set_security(
                SecurityPolicyBasic256Sha256,
                certificate=self.config.opcua_client_certificate,
                private_key=self.config.opcua_client_private_key,
                mode=mode,
            )
        await self._client.connect()
        self._nodes = {
            spec.node_id: self._client.get_node(f"ns={self.config.opcua_namespace_index};s={spec.node_id}")
            for spec in NODE_SPECS
        }
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._client is not None:
            await self._client.disconnect()

    async def read_sample(self) -> TelemetrySample:
        values: dict[str, Any] = {}
        for node_id, node in self._nodes.items():
            values[node_id] = await node.read_value()
        return TelemetrySample(timestamp=datetime.now(UTC), values=values, cell_id=self.config.cell_id)


class HistorianService:
    """Buffered telemetry writer with periodic KPI rollups."""

    def __init__(self, config: HistorianConfig, writer: InfluxDBLineWriter | None = None) -> None:
        self.config = config
        self.writer = writer or InfluxDBLineWriter(
            url=config.influx_url,
            token=config.influx_token,
            org=config.influx_org,
            bucket=config.influx_bucket,
        )
        self.buffer = TelemetryBuffer(max_size=config.max_buffer_size)
        self.window: deque[TelemetrySample] = deque()
        self.sensor_counter = SensorEdgeCounter()
        self._last_flush = datetime.now(UTC)

    def ingest(self, sample: TelemetrySample) -> None:
        self.window.append(sample)
        self._trim_window(sample.timestamp)
        self.buffer.append_many(sample_to_line_protocol(sample))
        sensor_count_line = self.sensor_counter.update(sample)
        if sensor_count_line is not None:
            self.buffer.append_many([sensor_count_line])
        summary = compute_kpis(list(self.window))
        self.buffer.append_many([kpi_summary_to_line_protocol(summary, self.config.cell_id, sample.timestamp)])

    def should_flush(self) -> bool:
        elapsed = (datetime.now(UTC) - self._last_flush).total_seconds()
        return len(self.buffer) >= self.config.max_batch_size or elapsed >= self.config.flush_interval_s

    def flush(self) -> None:
        while len(self.buffer) > 0:
            batch = self.buffer.pop_batch(self.config.max_batch_size)
            self.writer.write_lines(batch)
        self._last_flush = datetime.now(UTC)

    def _trim_window(self, now: datetime) -> None:
        while self.window and (now - self.window[0].timestamp).total_seconds() > self.config.kpi_window_s:
            self.window.popleft()


async def run_historian(config: HistorianConfig) -> None:
    service = HistorianService(config)
    LOGGER.info("Starting historian connector with config: %s", config.redacted())
    async with OpcUaSnapshotCollector(config) as collector:
        while True:
            sample = await collector.read_sample()
            service.ingest(sample)
            if service.should_flush():
                service.flush()
            await asyncio.sleep(config.sample_period_s)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the MHMC OPC UA to InfluxDB historian connector")
    parser.add_argument("--log-level", default="INFO")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper()), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    asyncio.run(run_historian(HistorianConfig.from_env()))


if __name__ == "__main__":
    main()
