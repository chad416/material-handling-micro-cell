"""Environment-driven configuration for historian services.

Secrets are never hard-coded.  Runtime credentials come from environment
variables or the process supervisor secret store that populates them.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _get_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return default if value is None or value == "" else float(value)


def _get_int(name: str, default: int) -> int:
    value = os.getenv(name)
    return default if value is None or value == "" else int(value)


@dataclass(frozen=True)
class HistorianConfig:
    opcua_endpoint: str
    opcua_namespace_index: int
    opcua_security_policy: str
    opcua_security_mode: str
    opcua_client_certificate: Path | None
    opcua_client_private_key: Path | None
    influx_url: str
    influx_org: str
    influx_bucket: str
    influx_token: str
    cell_id: str
    sample_period_s: float
    flush_interval_s: float
    max_batch_size: int
    max_buffer_size: int
    kpi_window_s: float

    @classmethod
    def from_env(cls) -> "HistorianConfig":
        return cls(
            opcua_endpoint=os.getenv("MHMC_OPCUA_ENDPOINT", "opc.tcp://localhost:4840/mhmc/server/"),
            opcua_namespace_index=_get_int("MHMC_OPCUA_NAMESPACE_INDEX", 2),
            opcua_security_policy=os.getenv("MHMC_OPCUA_SECURITY_POLICY", "Basic256Sha256"),
            opcua_security_mode=os.getenv("MHMC_OPCUA_SECURITY_MODE", "SignAndEncrypt"),
            opcua_client_certificate=_optional_path("MHMC_OPCUA_CLIENT_CERT"),
            opcua_client_private_key=_optional_path("MHMC_OPCUA_CLIENT_KEY"),
            influx_url=os.getenv("MHMC_INFLUX_URL", "http://localhost:8086"),
            influx_org=os.getenv("MHMC_INFLUX_ORG", "AntigravityAutomation"),
            influx_bucket=os.getenv("MHMC_INFLUX_BUCKET", "mhmc_telemetry"),
            influx_token=_required_secret("MHMC_INFLUX_TOKEN"),
            cell_id=os.getenv("MHMC_CELL_ID", "mhmc_01"),
            sample_period_s=_get_float("MHMC_HISTORIAN_SAMPLE_PERIOD_S", 0.1),
            flush_interval_s=_get_float("MHMC_HISTORIAN_FLUSH_INTERVAL_S", 0.5),
            max_batch_size=_get_int("MHMC_HISTORIAN_MAX_BATCH_SIZE", 1000),
            max_buffer_size=_get_int("MHMC_HISTORIAN_MAX_BUFFER_SIZE", 10000),
            kpi_window_s=_get_float("MHMC_KPI_WINDOW_S", 300.0),
        )

    def redacted(self) -> dict[str, object]:
        data = self.__dict__.copy()
        data["influx_token"] = "***" if self.influx_token else ""
        return data


@dataclass(frozen=True)
class QueryApiConfig:
    influx_url: str
    influx_org: str
    influx_bucket: str
    influx_token: str
    host: str
    port: int
    bearer_token: str

    @classmethod
    def from_env(cls) -> "QueryApiConfig":
        return cls(
            influx_url=os.getenv("MHMC_INFLUX_URL", "http://localhost:8086"),
            influx_org=os.getenv("MHMC_INFLUX_ORG", "AntigravityAutomation"),
            influx_bucket=os.getenv("MHMC_INFLUX_BUCKET", "mhmc_telemetry"),
            influx_token=_required_secret("MHMC_INFLUX_TOKEN"),
            host=os.getenv("MHMC_QUERY_API_HOST", "127.0.0.1"),
            port=_get_int("MHMC_QUERY_API_PORT", 8091),
            bearer_token=_required_secret("MHMC_QUERY_API_TOKEN"),
        )


def _optional_path(name: str) -> Path | None:
    value = os.getenv(name)
    return None if value is None or value == "" else Path(value)


def _required_secret(name: str) -> str:
    value = os.getenv(name)
    if value is None or value == "":
        raise RuntimeError(f"Required secret environment variable is not set: {name}")
    return value
