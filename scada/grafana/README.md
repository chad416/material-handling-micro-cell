# Grafana Provisioning For MHMC-01

This folder contains Grafana provisioning assets for the Material Handling Micro
Cell historian.

## Files

- `provisioning/datasources/influxdb.yml`: InfluxDB Flux datasource named
  `InfluxDB-Flux`.
- `provisioning/dashboards/mhmc.yml`: Dashboard provider configuration.
- `dashboards/mhmc-kpi-dashboard.json`: KPI, uptime, jam, and event timeline
  dashboard.
- `provisioning/alerting/mhmc-alert-rules.yml`: Alert rules for low throughput
  and jam escalation.

## Environment Variables

Set these in the Grafana service/container environment:

```powershell
$env:MHMC_INFLUX_URL = "http://localhost:8086"
$env:MHMC_INFLUX_ORG = "AntigravityAutomation"
$env:MHMC_INFLUX_BUCKET = "mhmc_telemetry"
$env:MHMC_INFLUX_TOKEN = "<bucket-scoped token>"
```

## Import Option A: Provisioning

Copy this folder into Grafana's provisioning root or mount it into a Grafana
container:

```text
/etc/grafana/provisioning/datasources/influxdb.yml
/etc/grafana/provisioning/dashboards/mhmc.yml
/var/lib/grafana/dashboards/mhmc-kpi-dashboard.json
/etc/grafana/provisioning/alerting/mhmc-alert-rules.yml
```

Then restart Grafana.

## Import Option B: Manual Dashboard Import

1. In Grafana, create an InfluxDB datasource named `InfluxDB-Flux`.
2. Set Query Language to `Flux`.
3. Set bucket to `mhmc_telemetry` and org to `AntigravityAutomation`.
4. Import `dashboards/mhmc-kpi-dashboard.json`.

## Import Option C: Local API Import Script

When Grafana is running locally, import the datasource and dashboard through the
Grafana HTTP API:

```powershell
$env:MHMC_INFLUX_URL = "http://localhost:8086"
$env:MHMC_INFLUX_ORG = "AntigravityAutomation"
$env:MHMC_INFLUX_BUCKET = "mhmc_telemetry"
$env:MHMC_INFLUX_TOKEN = "<bucket-scoped token>"

.\tools\import-grafana-dashboard.ps1 `
  -GrafanaUrl "http://localhost:3000" `
  -GrafanaUser "admin" `
  -GrafanaPassword "<grafana admin password>"
```

The script creates or updates the `InfluxDB-Flux` datasource and imports
`mhmc-kpi-dashboard.json` with overwrite enabled.

## Alert Notes

The alert rules assume that `computed_kpis.throughput_per_min` and
`cell_kpis.total_jams` are being written by `historian_service`. Tune threshold
values during FAT after observing the real cell cycle time and sort pattern.
