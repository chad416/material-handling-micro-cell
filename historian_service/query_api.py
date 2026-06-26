"""Small Grafana-facing query API for MHMC historian KPIs."""

from __future__ import annotations

import argparse
import json
import logging
from datetime import UTC, datetime, timedelta
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from .config import QueryApiConfig
from .kpi import compute_kpis
from .telemetry import TelemetrySample


LOGGER = logging.getLogger("mhmc.query_api")


class InfluxQueryService:
    def __init__(self, config: QueryApiConfig) -> None:
        try:
            from influxdb_client import InfluxDBClient
        except ModuleNotFoundError as exc:  # pragma: no cover - runtime dependency.
            raise RuntimeError("influxdb-client is not installed. Install digital_twin/requirements.txt") from exc
        self.config = config
        self._client = InfluxDBClient(url=config.influx_url, token=config.influx_token, org=config.influx_org)
        self._query_api = self._client.query_api()

    def get_kpis(self, window: str = "15m") -> dict[str, object]:
        samples = self._read_samples(window)
        summary = compute_kpis(samples)
        return summary.as_dict()

    def get_recent_events(self, window: str = "15m", limit: int = 50) -> dict[str, object]:
        flux = f'''
from(bucket: "{self.config.influx_bucket}")
  |> range(start: -{_sanitize_duration(window)})
  |> filter(fn: (r) => r["_measurement"] == "event_timeline" or r["_measurement"] == "alarms_events")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: {max(1, min(limit, 500))})
'''
        rows = []
        for table in self._query_api.query(flux):
            for record in table.records:
                rows.append(
                    {
                        "time": record.get_time().isoformat(),
                        "measurement": record.get_measurement(),
                        "field": record.get_field(),
                        "value": record.get_value(),
                    }
                )
        return {"events": rows}

    def _read_samples(self, window: str) -> list[TelemetrySample]:
        flux = f'''
from(bucket: "{self.config.influx_bucket}")
  |> range(start: -{_sanitize_duration(window)})
  |> filter(fn: (r) => r["_measurement"] == "cell_kpis" or r["_measurement"] == "conveyor_telemetry" or r["_measurement"] == "event_timeline")
  |> keep(columns: ["_time", "_measurement", "_field", "_value", "node_id"])
'''
        grouped: dict[datetime, dict[str, Any]] = {}
        field_to_node = {
            "throughput_total": "KPIs.ThroughputTotal",
            "total_jams": "KPIs.TotalJams",
            "heartbeat": "ControlState.Heartbeat",
            "speed_feedback": "DeviceSet.Conveyor_1.SpeedFeedback",
            "last_sequence": "EventTimeline.LastSequence",
        }
        for table in self._query_api.query(flux):
            for record in table.records:
                timestamp = record.get_time().astimezone(UTC)
                node_id = record.values.get("node_id") or field_to_node.get(record.get_field())
                if node_id is None:
                    continue
                grouped.setdefault(timestamp, {})[str(node_id)] = record.get_value()
        return [TelemetrySample(timestamp=ts, values=values) for ts, values in sorted(grouped.items())]


class QueryRequestHandler(BaseHTTPRequestHandler):
    query_service: InfluxQueryService
    bearer_token: str

    def do_GET(self) -> None:
        if not self._authorized():
            self._json_response({"error": "unauthorized"}, HTTPStatus.UNAUTHORIZED)
            return

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        try:
            if parsed.path == "/health":
                self._json_response({"status": "ok"})
            elif parsed.path == "/kpis":
                window = params.get("window", ["15m"])[0]
                self._json_response(self.query_service.get_kpis(window=window))
            elif parsed.path == "/events":
                window = params.get("window", ["15m"])[0]
                limit = int(params.get("limit", ["50"])[0])
                self._json_response(self.query_service.get_recent_events(window=window, limit=limit))
            else:
                self._json_response({"error": "not found"}, HTTPStatus.NOT_FOUND)
        except Exception as exc:  # pragma: no cover - defensive runtime path.
            LOGGER.exception("Query request failed")
            self._json_response({"error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)

    def log_message(self, format: str, *args: object) -> None:
        LOGGER.info("%s - %s", self.address_string(), format % args)

    def _authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        return header == f"Bearer {self.bearer_token}"

    def _json_response(self, payload: dict[str, object], status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def run_http_api(config: QueryApiConfig) -> None:
    service = InfluxQueryService(config)
    QueryRequestHandler.query_service = service
    QueryRequestHandler.bearer_token = config.bearer_token
    server = ThreadingHTTPServer((config.host, config.port), QueryRequestHandler)
    LOGGER.info("MHMC query API listening on http://%s:%s", config.host, config.port)
    server.serve_forever()


def print_once(config: QueryApiConfig, window: str) -> None:
    service = InfluxQueryService(config)
    print(json.dumps(service.get_kpis(window=window), indent=2, sort_keys=True))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve or query MHMC historian KPI JSON")
    parser.add_argument("--once", action="store_true", help="Print KPI JSON once instead of serving HTTP")
    parser.add_argument("--window", default="15m")
    parser.add_argument("--log-level", default="INFO")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper()), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    config = QueryApiConfig.from_env()
    if args.once:
        print_once(config, args.window)
    else:
        run_http_api(config)


def _sanitize_duration(value: str) -> str:
    allowed = set("0123456789smhdw")
    if not value or any(char not in allowed for char in value):
        raise ValueError("window must be an Influx duration such as 15m, 1h, or 7d")
    return value


if __name__ == "__main__":
    main()
