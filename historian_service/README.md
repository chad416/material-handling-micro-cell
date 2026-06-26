# MHMC Historian And KPI Service

This service collects semantic OPC UA telemetry from `opcua_server`, buffers it,
writes line protocol records to InfluxDB, and computes dashboard-ready KPI
rollups.

## Credentials

Set credentials through environment variables or your service manager secret
store. Do not commit tokens or passwords.

```powershell
$env:MHMC_INFLUX_URL = "http://localhost:8086"
$env:MHMC_INFLUX_ORG = "AntigravityAutomation"
$env:MHMC_INFLUX_BUCKET = "mhmc_telemetry"
$env:MHMC_INFLUX_TOKEN = "<secret token>"
$env:MHMC_QUERY_API_TOKEN = "<grafana bearer token>"
$env:MHMC_OPCUA_CLIENT_CERT = "C:\ProgramData\MHMC\opcua\historian-client.der"
$env:MHMC_OPCUA_CLIENT_KEY = "C:\ProgramData\MHMC\opcua\historian-client-key.pem"
```

## Run The Historian

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m historian_service.collector
```

The collector samples OPC UA at `MHMC_HISTORIAN_SAMPLE_PERIOD_S` seconds
defaulting to `0.1`, buffers up to `MHMC_HISTORIAN_MAX_BUFFER_SIZE` records, and
flushes every `MHMC_HISTORIAN_FLUSH_INTERVAL_S` seconds or when the batch is
full.

Written measurements include:

- semantic raw telemetry such as `conveyor_telemetry`, `cell_kpis`, `alarms_events`
- derived `sensor_counts` rising-edge counters for PE and lane verification sensors
- derived `computed_kpis` for throughput per minute, MTBJ, and average cycle time

## Run The Query API

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m historian_service.query_api
```

Grafana can call:

- `GET /health`
- `GET /kpis?window=15m`
- `GET /events?window=15m&limit=50`

All endpoints require:

```text
Authorization: Bearer <MHMC_QUERY_API_TOKEN>
```

For script-style Grafana integrations:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m historian_service.query_api --once --window 15m
```
