#!/bin/bash
# ==============================================================================
# INFLUXDB INITIALIZATION & SETUP SCRIPT
# Project: Material Handling Micro Cell (MHMC-01)
# Author: Lead Automation Engineer (MIT Graduate)
# ==============================================================================

set -e

# Configurable Variables. Secrets must be injected through the shell,
# service manager, or CI secret store before this script is run.
INFLUX_HOST="${MHMC_INFLUX_URL:-http://localhost:8086}"
ORG="${MHMC_INFLUX_ORG:-AntigravityAutomation}"
BUCKET_TELEMETRY="${MHMC_INFLUX_BUCKET:-mhmc_telemetry}"
BUCKET_EVENTS="${MHMC_INFLUX_EVENTS_BUCKET:-mhmc_events}"
RETENTION_TELEMETRY="${MHMC_INFLUX_RETENTION_TELEMETRY:-30d}"  # Keep raw sensor/VFD logs for 30 days.
RETENTION_EVENTS="${MHMC_INFLUX_RETENTION_EVENTS:-365d}"       # Keep alarm history and KPIs for 1 year.
ADMIN_USER="${MHMC_INFLUX_ADMIN_USER:-admin}"

: "${MHMC_INFLUX_ADMIN_PASSWORD:?Set MHMC_INFLUX_ADMIN_PASSWORD before running setup}"
: "${MHMC_INFLUX_TOKEN:?Set MHMC_INFLUX_TOKEN before running setup}"

ADMIN_PASSWORD="$MHMC_INFLUX_ADMIN_PASSWORD"
API_TOKEN="$MHMC_INFLUX_TOKEN"

echo "Initializing InfluxDB configuration..."

# 1. Setup primary InfluxDB instance (org, bucket, admin user)
influx setup \
  --host "$INFLUX_HOST" \
  --username "$ADMIN_USER" \
  --password "$ADMIN_PASSWORD" \
  --org "$ORG" \
  --bucket "$BUCKET_TELEMETRY" \
  --retention "$RETENTION_TELEMETRY" \
  --token "$API_TOKEN" \
  --force

echo "Primary telemetry bucket '$BUCKET_TELEMETRY' created with $RETENTION_TELEMETRY retention."

# 2. Create the discrete events and KPI history bucket
influx bucket create \
  --host "$INFLUX_HOST" \
  --org "$ORG" \
  --name "$BUCKET_EVENTS" \
  --retention "$RETENTION_EVENTS" \
  --token "$API_TOKEN"

echo "Discrete events bucket '$BUCKET_EVENTS' created with $RETENTION_EVENTS retention."

# 3. Verify bucket generation
echo "Configured buckets:"
influx bucket list --host "$INFLUX_HOST" --token "$API_TOKEN" --org "$ORG"

echo "=============================================================================="
echo "InfluxDB setup completed successfully!"
echo "API Token for Telegraf: provided through MHMC_INFLUX_TOKEN"
echo "Org Name: $ORG"
echo "=============================================================================="
