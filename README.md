# Material Handling Micro Cell Software

## Overview

This repository contains the software and automation engineering package for
the MHMC-01 material handling micro cell. The cell sorts packages from an
infeed conveyor to Lane A, Lane B, or reject using barcode data, symbolic PLC
logic, OPC UA telemetry, historian/KPI services, and HMI/SCADA assets.

The project goal is to provide a production-quality software baseline that can
be compiled in TwinCAT 3, exercised in simulation, connected to OPC UA and
InfluxDB/Grafana, and then commissioned against real hardware with controlled
FAT/SAT evidence.

## Project Structure

| Path | Purpose |
| --- | --- |
| `plc/` | IEC 61131-3 Structured Text modules for line supervision, PackML station control, routing, diverters, jam detection, alarm management, KPI calculation, historian handshake, and TestHarness. |
| `twincat/` | Generated TwinCAT 3 solution and PLC project wrapper built from `plc/*.st`. |
| `digital_twin/` | Python simulation assets for the material handling cell. |
| `digital_twin/visual_demo/` | Dependency-free browser visual twin for portfolio walkthroughs. |
| `opcua_server/` | Semantic OPC UA server exposing machine states, counters, alarms, maintenance variables, recipes, and KPI nodes. |
| `historian_service/` | Buffered historian connector, InfluxDB line protocol writer, KPI calculations, and query API. |
| `scada/` | InfluxDB, Telegraf, and Grafana configuration/provisioning. |
| `scada-prototype/` | Dependency-free HTML/JS HMI prototype with mock tag bindings. |
| `portfolio_evidence/` | Repeatable software evidence-pack workflow for interview/demo material. |
| `docs/` | Functional design, HMI/SCADA design, tag list, network topology, final report, and documentation templates. |
| `validation/` | PLC validation runner, TestHarness scenario runner, and generated evidence reports. |
| `tools/` | TwinCAT project generation, build, validation, and Grafana import helpers. |

## PLC Modules

The PLC logic is modular and testable through typed inputs, outputs, configs,
enumerated states, and explicit initialization/cyclic execution patterns.

| Module | Responsibility |
| --- | --- |
| `FB_LineSupervisor` | Command handling, mode selection, recipe loading, target speed dispatch. |
| `FB_StationController` | PackML state control, permissives, conveyor command intent, manual/maintenance safeguards. |
| `FB_RoutingLogic` | Package FIFO tracking, barcode route assignment, diverter requests, verification counters. |
| `FB_DiverterController` | Pneumatic diverter extend, verify, retract, timeout, and manual hold limits. |
| `FB_JamDetector` | Dynamic PE watchdogs, jam warning/alarm, recovery readiness, jam counts. |
| `FB_AlarmManager` | Alarm priority, acknowledgement, stack lights, sounder, event timeline. |
| `FB_KPIService` | Throughput counters, scan quality, availability, performance, quality, OEE. |
| `FB_HistorianConnector` | OPC UA/historian sample strobes, heartbeat health, event publish intent. |
| `FB_TestHarness` | Software-in-the-loop cell simulation and fault scenario execution. |

## Running Validation and TestHarness

Use PowerShell from the repository root.

Run the deterministic TestHarness scenario matrix:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -B validation\run_test_harness.py
```

Run full PLC validation using the recorded manual TwinCAT build evidence:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1 -UseExistingTwinCATBuildEvidence
```

Regenerate the TwinCAT wrapper from the Structured Text files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\generate-twincat-project.ps1
```

Build in TwinCAT manually when COM automation is blocked:

1. Open `twincat\MHMC_Runtime.sln` in TwinCAT XAE Shell.
2. Select `Build > Rebuild Solution`.
3. Confirm `0 Errors`, `0 Warnings`.
4. Save the solution if TwinCAT prompts.

## Simulation and Test Results

Latest recorded validation:

| Evidence | Result |
| --- | --- |
| PLC validation checks | 168 passed, 0 failed |
| TestHarness scenario matrix | 10 passed, 0 failed |
| Manual TwinCAT rebuild | 0 errors, 0 warnings |
| OPC UA/historian deterministic checks | Passed |
| Grafana dashboard import and preview | Verified during local runtime testing |

TestHarness scenarios:

| Scenario | Result |
| --- | --- |
| Normal Lane A | PASS |
| Jam PE3 and recovery | PASS |
| PE2 stuck high | PASS |
| PE2 stuck low | PASS |
| Start with product present | PASS |
| Barcode misread | PASS |
| Network dropout | PASS |
| Manual override abuse | PASS |
| Recipe change mid cycle | PASS |
| Throughput degradation | PASS |

Evidence files:

- `validation/results/test-harness-report.md`
- `validation/results/validation-report.md`
- `validation/results/twincat-manual-build-evidence.md`
- `validation/results/opcua-historian-test-report.md`
- `validation/results/software-polish-report.md`

## Software Demo Stack

The software-side portfolio demo can be started with one command. It runs the
semantic OPC UA server, historian connector, query API, HMI prototype, and
visual digital twin. OPC UA starts with Basic256Sha256 SignAndEncrypt by
default; use `-InsecureOpcUa` only for local troubleshooting.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\start-software-demo.ps1 -UseLocalDevDefaults -OpenBrowser
```

Stop the demo stack:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\stop-software-demo.ps1
```

Demo assets:

| Asset | URL |
| --- | --- |
| HMI prototype | `http://127.0.0.1:8092/` |
| Visual digital twin | `http://127.0.0.1:8093/` |
| Historian preview | `http://127.0.0.1:8091/preview` |
| Grafana dashboard | `http://localhost:3000/d/mhmc-kpi-events/mhmc-01-kpi-and-event-dashboard` |

Run the software-polish validation gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-software-polish-validation.ps1
```

### Portfolio Evidence Pack

Create a Portfolio evidence pack:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\new-portfolio-evidence-pack.ps1 -IncludeRuntimeLogs
```

The demo narrative and screenshot checklist are documented in
`docs/portfolio_demo_narrative.md`.

## OPC UA, Historian, and Grafana

Generate OPC UA certificates before production use:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.generate_cert --hostname localhost
```

Run the semantic OPC UA server:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.server --certificate opcua_server\certs\mhmc-server.der --private-key opcua_server\certs\mhmc-server-key.pem
```

Historian credentials are supplied through environment variables. Do not store
production tokens in the repository.

```powershell
$env:MHMC_INFLUX_URL = "http://localhost:8086"
$env:MHMC_INFLUX_ORG = "AntigravityAutomation"
$env:MHMC_INFLUX_BUCKET = "mhmc_telemetry"
$env:MHMC_INFLUX_TOKEN = "<secret token>"
$env:MHMC_QUERY_API_TOKEN = "<secret token>"
```

Run the KPI query API:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m historian_service.query_api
```

Import the Grafana dashboard:

```powershell
.\tools\import-grafana-dashboard.ps1 -GrafanaUrl "http://localhost:3000" -GrafanaUser "admin" -GrafanaPassword "<password>"
```

## Deployment Path to Real Hardware

1. Freeze a software commit and archive the TwinCAT project.
2. Map symbolic PLC variables to real EtherCAT/fieldbus I/O.
3. Replace simulation/default inputs with field devices: PE1-PE6, diverter home/work sensors, VFD, scanner, air pressure, safety loop.
4. Configure production OPC UA certificates, users, and secure endpoint policy.
5. Configure Telegraf/InfluxDB/Grafana with production credentials and retention.
6. Perform I/O point-to-point checks.
7. Validate E-stop and safety functions under the site safety procedure.
8. Tune conveyor ramp, diverter timing, scanner trigger window, debounce, and jam thresholds on the machine.
9. Execute FAT, SAT, and production readiness run.
10. Close punch list and issue as-built documentation.

## Remaining Hardware Tasks

- Physical I/O mapping and point-to-point verification.
- Safety relay/E-stop validation by qualified personnel.
- VFD scaling, direction, acceleration, and stop behavior verification.
- Pneumatic pressure, diverter travel timing, and home/work switch verification.
- Scanner communication, trigger timing, and read quality tuning.
- Real package routing tests across SKU/recipe matrix.
- OPC UA certificate trust and production user/role configuration.
- Live InfluxDB retention, backup, and alerting configuration.
- Operator and maintenance training.
- Signed FAT/SAT and as-built release.
