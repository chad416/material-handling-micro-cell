# OPC UA And Historian Validation Report

- Date: 2026-06-26
- Scope: OPC UA namespace/server tests, historian buffering/KPI calculations, Telegraf config validation, and deterministic InfluxDB line-protocol checks.

## Executed Checks

| Check | Result | Notes |
| --- | --- | --- |
| Python compile check for `historian_service`, `opcua_server`, and `digital_twin` | PASS | All Python files compiled. |
| Historian service unit/integration tests | PASS | 10 tests run, 1 runtime subscription test skipped because `asyncua` is not installed on the default Python path. |
| OPC UA server tests | PASS | 12 tests run, 2 runtime tests skipped for the same default-path dependency reason. |
| Telegraf TOML parse | PASS | `scada/telegraf.conf` parses as valid TOML. |
| Historian Influx line-protocol validation | PASS | Verified timestamps, machine state values, counters, alarm flags, event fields, sensor edge counts, and computed KPI rollup lines using `MemoryLineWriter`. |

## Runtime Coverage Added

`historian_service/tests/test_integration_runtime.py` now contains a concurrent OPC UA client scenario:

- Starts the local semantic OPC UA server.
- Connects two clients representing SCADA/HMI and digital twin.
- Subscribes both clients to `ControlState.CurrentState`, `KPIs.ThroughputTotal`, `Alarms.GeneralJamAlarm`, and `KPIs.OEE`.
- Publishes state, counter, alarm, and KPI changes.
- Asserts both clients receive the updated values.

The same file also verifies historian output records for:

- conveyor speed feedback
- throughput counter
- general jam alarm
- event timeline sequence/message
- PE rising-edge sensor counts
- computed throughput per minute and jam delta

## Not Executed In This Environment

- Live InfluxDB writes were not executed because no InfluxDB service URL/token was provided in this session.
- The concurrent OPC UA runtime subscription test was added but skipped on the default Python path because `asyncua` is not installed there.

To run the full runtime suite on a machine with dependencies installed:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m pip install -r digital_twin\requirements.txt
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -B -m unittest discover -s historian_service\tests
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -B -m unittest discover -s opcua_server\tests
```

To validate against real InfluxDB, set:

```powershell
$env:MHMC_INFLUX_URL = "http://localhost:8086"
$env:MHMC_INFLUX_ORG = "AntigravityAutomation"
$env:MHMC_INFLUX_BUCKET = "mhmc_telemetry"
$env:MHMC_INFLUX_TOKEN = "<secret token>"
```

## Issues

No code-level failures were found in the deterministic tests. The remaining gaps are environment/runtime validation gaps:

- Full OPC UA concurrent subscription runtime test requires `asyncua` installed on the active Python environment.
- Real InfluxDB entry verification requires a running InfluxDB instance and credentials.

## Optimisation Recommendations

- For production scale, prefer OPC UA subscriptions or batched reads in `OpcUaSnapshotCollector` instead of sequential per-node polling at 100 ms.
- Consider writing changed values plus periodic heartbeats rather than every raw node every sample if InfluxDB write volume becomes high.
- Keep `TelemetryBuffer.max_buffer_size` sized for worst-case network outages and alert if `dropped_records` increments.
- Use a dedicated read/write Influx token scoped only to the MHMC bucket, not an admin token.
