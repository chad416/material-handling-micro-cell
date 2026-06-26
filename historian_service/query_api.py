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


PREVIEW_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MHMC Historian Preview</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: "Segoe UI", Arial, sans-serif;
      background: #101418;
      color: #edf2f7;
    }
    body {
      margin: 0;
      padding: 24px;
      background: #101418;
    }
    main {
      max-width: 1180px;
      margin: 0 auto;
    }
    h1 {
      margin: 0 0 18px;
      font-size: 28px;
      font-weight: 650;
    }
    .controls {
      display: grid;
      grid-template-columns: minmax(220px, 1fr) 140px auto;
      gap: 12px;
      align-items: end;
      margin-bottom: 18px;
    }
    label {
      display: grid;
      gap: 6px;
      color: #a9b4c2;
      font-size: 13px;
    }
    input, button {
      height: 38px;
      border-radius: 6px;
      border: 1px solid #344253;
      background: #151b22;
      color: #edf2f7;
      font: inherit;
      padding: 0 12px;
    }
    button {
      cursor: pointer;
      background: #1e6fba;
      border-color: #2d8fdd;
      font-weight: 600;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 18px;
    }
    .tile {
      border: 1px solid #273544;
      border-radius: 8px;
      padding: 14px;
      background: #151b22;
      min-height: 76px;
    }
    .tile span {
      color: #9fb0c3;
      display: block;
      font-size: 12px;
      margin-bottom: 8px;
    }
    .tile strong {
      font-size: 24px;
      line-height: 1.1;
      word-break: break-word;
    }
    section {
      border: 1px solid #273544;
      border-radius: 8px;
      background: #151b22;
      margin-bottom: 18px;
      overflow: hidden;
    }
    section h2 {
      margin: 0;
      padding: 12px 14px;
      border-bottom: 1px solid #273544;
      font-size: 16px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      padding: 9px 12px;
      border-bottom: 1px solid #222e3b;
      text-align: left;
      vertical-align: top;
    }
    th {
      color: #a9b4c2;
      font-weight: 600;
    }
    pre {
      margin: 0;
      padding: 14px;
      overflow: auto;
      color: #d8e2ee;
    }
    .status {
      color: #a9b4c2;
      min-height: 20px;
      margin-bottom: 12px;
    }
    @media (max-width: 760px) {
      body { padding: 14px; }
      .controls, .grid { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <main>
    <h1>MHMC Historian Preview</h1>
    <div class="controls">
      <label>Bearer token
        <input id="token" type="password" autocomplete="off" placeholder="Enter query API token">
      </label>
      <label>Window
        <input id="window" value="5m" autocomplete="off">
      </label>
      <button id="load" type="button">Load</button>
    </div>
    <div id="status" class="status"></div>
    <div class="grid">
      <div class="tile"><span>Throughput/min</span><strong id="throughput">-</strong></div>
      <div class="tile"><span>Total package delta</span><strong id="packages">-</strong></div>
      <div class="tile"><span>Jam delta</span><strong id="jams">-</strong></div>
      <div class="tile"><span>Window seconds</span><strong id="windowSeconds">-</strong></div>
    </div>
    <section>
      <h2>Recent Events</h2>
      <table>
        <thead><tr><th>Time</th><th>Measurement</th><th>Field</th><th>Value</th></tr></thead>
        <tbody id="events"><tr><td colspan="4">No data loaded</td></tr></tbody>
      </table>
    </section>
    <section>
      <h2>KPI JSON</h2>
      <pre id="json">{}</pre>
    </section>
  </main>
  <script>
    const tokenInput = document.getElementById("token");
    const windowInput = document.getElementById("window");
    const statusEl = document.getElementById("status");
    const eventsEl = document.getElementById("events");
    const jsonEl = document.getElementById("json");

    tokenInput.value = sessionStorage.getItem("mhmcQueryToken") || "";

    function setText(id, value) {
      document.getElementById(id).textContent = value ?? "-";
    }

    function displayEvents(events) {
      if (!events || events.length === 0) {
        eventsEl.innerHTML = '<tr><td colspan="4">No events returned</td></tr>';
        return;
      }
      eventsEl.innerHTML = events.map((event) => `
        <tr>
          <td>${escapeHtml(event.time)}</td>
          <td>${escapeHtml(event.measurement)}</td>
          <td>${escapeHtml(event.field)}</td>
          <td>${escapeHtml(JSON.stringify(event.value))}</td>
        </tr>
      `).join("");
    }

    function escapeHtml(value) {
      return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;");
    }

    async function loadData() {
      const token = tokenInput.value.trim();
      const windowValue = windowInput.value.trim() || "5m";
      if (!token) {
        statusEl.textContent = "Enter the query API token.";
        return;
      }
      sessionStorage.setItem("mhmcQueryToken", token);
      statusEl.textContent = "Loading...";
      try {
        const headers = { Authorization: `Bearer ${token}` };
        const [kpiResponse, eventResponse] = await Promise.all([
          fetch(`/kpis?window=${encodeURIComponent(windowValue)}`, { headers }),
          fetch(`/events?window=${encodeURIComponent(windowValue)}&limit=20`, { headers }),
        ]);
        if (!kpiResponse.ok) throw new Error(await kpiResponse.text());
        if (!eventResponse.ok) throw new Error(await eventResponse.text());
        const kpis = await kpiResponse.json();
        const events = await eventResponse.json();
        setText("throughput", kpis.throughput_per_min);
        setText("packages", kpis.total_packages_delta);
        setText("jams", kpis.jam_delta);
        setText("windowSeconds", kpis.window_s);
        displayEvents(events.events);
        jsonEl.textContent = JSON.stringify(kpis, null, 2);
        statusEl.textContent = `Updated ${new Date().toLocaleTimeString()}`;
      } catch (error) {
        statusEl.textContent = `Request failed: ${error.message}`;
      }
    }

    document.getElementById("load").addEventListener("click", loadData);
    windowInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") loadData();
    });
    tokenInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") loadData();
    });
  </script>
</body>
</html>
"""


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
        bounded_limit = max(1, min(limit, 500))
        flux = f'''
from(bucket: "{self.config.influx_bucket}")
  |> range(start: -{_sanitize_duration(window)})
  |> filter(fn: (r) => r["_measurement"] == "event_timeline" or r["_measurement"] == "alarms_events")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: {bounded_limit})
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
        rows.sort(key=lambda row: str(row["time"]), reverse=True)
        return {"events": rows[:bounded_limit]}

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
        parsed = urlparse(self.path)
        if parsed.path == "/preview":
            self._html_response(PREVIEW_HTML)
            return

        if not self._authorized():
            self._json_response({"error": "unauthorized"}, HTTPStatus.UNAUTHORIZED)
            return

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

    def _html_response(self, html: str, status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
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
