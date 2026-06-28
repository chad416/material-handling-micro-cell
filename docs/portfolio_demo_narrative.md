# MHMC-01 Portfolio Demo Narrative

## Purpose

This document turns the completed MHMC-01 software package into a clean
portfolio story. It is intended for interviews, portfolio videos, and technical
walkthroughs where the physical cell is not yet commissioned.

## Software Demo Stack

Start the full local software stack:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\start-software-demo.ps1 -UseLocalDevDefaults -OpenBrowser
```

Stop it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\stop-software-demo.ps1
```

The stack presents:

| Asset | URL / Evidence |
| --- | --- |
| HMI prototype | `http://127.0.0.1:8092/` |
| Visual digital twin | `http://127.0.0.1:8093/` |
| Historian preview | `http://127.0.0.1:8091/preview` |
| Grafana dashboard | `http://localhost:3000/d/mhmc-kpi-events/mhmc-01-kpi-and-event-dashboard` |
| PLC validation | `validation/results/validation-report.md` |
| TestHarness matrix | `validation/results/test-harness-report.md` |
| Software polish validation | `validation/results/software-polish-report.md` |

## 90-second executive demo

1. Show the architecture in one sentence:
   MHMC-01 is a software-complete conveyor sorting cell with PLC logic,
   semantic OPC UA, historian/KPI service, HMI/SCADA, Grafana, and a visual
   digital twin.
2. Open the visual digital twin and start the cell.
   Show package flow, scanner event, diverter movement, lane counts, reject
   handling, and event timeline updates.
3. Switch to the HMI prototype.
   Show overview controls, alarm visibility, station/diverter control, and
   maintenance/recipe concepts.
4. Switch to Grafana.
   Show throughput, jams, uptime/OEE, and event timeline panels.
5. End with evidence:
   TwinCAT compile is 0 errors / 0 warnings, TestHarness scenarios are 10 pass
   / 0 fail, and deterministic PLC validation is 168 pass / 0 fail.

## 6-minute engineering walkthrough

1. PLC architecture:
   Explain `FB_LineSupervisor`, `FB_StationController`, `FB_RoutingLogic`,
   `FB_DiverterController`, `FB_JamDetector`, `FB_AlarmManager`,
   `FB_KPIService`, `FB_HistorianConnector`, and `FB_TestHarness`.
2. Sequence behavior:
   Show automatic mode start permissives, conveyor speed request, package
   registration, barcode route target, diverter request, verification sensors,
   KPI increment, and event logging.
3. Fault behavior:
   Run the visual twin `Jam at PE3` scenario and explain how the PLC
   TestHarness validates jam latch, station hold, alarm code, reset readiness,
   and unhold recovery.
4. OPC UA namespace:
   Show semantic objects such as `ControlState`, `DeviceSet`, `KPIs`, `Alarms`,
   `Recipes`, `Maintenance`, and `EventTimeline`. Emphasize that this is not a
   raw tag dump.
5. Historian and dashboard:
   Show the query preview and Grafana dashboard. Explain timestamped telemetry,
   efficient buffering, computed throughput, jam count, uptime/OEE, and alert
   rules.
6. Validation evidence:
   Open the validation and TestHarness reports. Point out normal routing,
   jam recovery, stuck sensor, barcode misread, network dropout, manual abuse,
   recipe change mid-cycle, and throughput degradation scenarios.
7. Close with production boundary:
   The software package is ready for controlled hardware integration. Only
   physical commissioning remains.

## Screenshot capture checklist

Use `tools/new-portfolio-evidence-pack.ps1` to create a timestamped evidence
folder, then capture these screenshots into its `screenshots/` folder:

| File | Capture |
| --- | --- |
| `01-twincat-rebuild-success.png` | TwinCAT XAE Shell showing 0 errors / 0 warnings. |
| `02-opcua-semantic-namespace.png` | OPC UA browser showing `MHMC_Cell` semantic nodes. |
| `03-hmi-overview.png` | HMI prototype overview screen. |
| `04-visual-digital-twin.png` | Visual twin running a scenario. |
| `05-grafana-kpi-dashboard.png` | Grafana KPI and event dashboard. |
| `06-historian-preview.png` | Query API historian preview page. |
| `07-test-harness-report.png` | TestHarness PASS summary. |

## Only hardware remains

After this software package, the remaining work is strictly hardware-related:

- Physical I/O mapping to EtherCAT or another device-level fieldbus.
- Point-to-point sensor, solenoid, VFD, scanner, and air-pressure checkout.
- Qualified E-stop and safety-loop validation.
- VFD direction, scaling, ramp, quick-stop, and fault verification.
- Pneumatic diverter timing, pressure, and home/work switch tuning.
- Barcode scanner trigger timing and read-quality commissioning.
- Real package/SKU recipe matrix testing.
- Production OPC UA certificate trust and user/role hardening.
- Signed FAT/SAT execution and as-built release.

Do not claim a commissioned physical machine until those items are completed.
