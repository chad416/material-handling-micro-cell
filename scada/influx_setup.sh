#!/bin/bash
# ==============================================================================
# INFLUXDB INITIALIZATION & SETUP SCRIPT
# Project: Material Handling Micro Cell (MHMC-01)
# Author: Lead Automation Engineer (MIT Graduate)
# ==============================================================================

set -e

# Configurable Variables
INFLUX_HOST="http://localhost:8086"
ORG="AntigravityAutomation"
BUCKET_TELEMETRY="mhmc_telemetry"
BUCKET_EVENTS="mhmc_events"
RETENTION_TELEMETRY="30d"  # Keep raw sensor/VFD logs for 30 days
RETENTION_EVENTS="365d"    # Keep alarm history and KPIs for 1 year
ADMIN_USER="admin"
ADMIN_PASSWORD="SuperSecureAutomationPassword2026!"
API_TOKEN="AntigravityOpcUaToInfluxdbTelemetryToken2026=="

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
echo "API Token for Telegraf: $API_TOKEN"
echo "Org Name: $ORG"
echo "=============================================================================="
