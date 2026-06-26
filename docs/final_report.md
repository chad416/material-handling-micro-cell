# MHMC-01 Final Software Engineering Report

## 1. Executive Summary

The MHMC-01 material handling micro cell software baseline has been developed
as a modular automation package covering PLC control, simulation/TestHarness,
semantic OPC UA exposure, historian/KPI collection, HMI/SCADA tag design,
Grafana visualization, and commissioning documentation templates.

The PLC project compiles in TwinCAT 3 with zero errors and zero warnings based
on the manual XAE rebuild evidence. The deterministic validation suite reports
168 passed checks and 0 failed checks. The TestHarness scenario matrix reports
10 passed scenarios and 0 failed scenarios.

## 2. Software Deliverables

| Area | Deliverables | Status |
| --- | --- | --- |
| PLC Structured Text | Modular ST source under `plc/` | Complete |
| TwinCAT wrapper | Generated solution under `twincat/` | Complete |
| TestHarness | `FB_TestHarness` and `PROGRAM TestHarness` | Complete |
| Validation runner | `tools/validate-plc.ps1`, `validation/run_test_harness.py` | Complete |
| OPC UA server | Semantic server under `opcua_server/` | Complete |
| Historian/KPI service | Collector, buffer, KPI logic, query API under `historian_service/` | Complete |
| HMI/SCADA design | Screen spec, tag list, prototype | Complete |
| Grafana | Datasource, dashboard, alert provisioning | Complete |
| Documentation templates | FAT, SAT, I/O, alarms, interlocks, logs, as-built templates | Complete |

## 3. PLC Module Summary

| Module | Function |
| --- | --- |
| `FB_LineSupervisor` | Commands, mode selection, recipe validation, target speed dispatch. |
| `FB_StationController` | PackML states, permissives, conveyor commands, manual and maintenance safeguards. |
| `FB_RoutingLogic` | Package tracking, barcode route assignment, diverter requests, verification. |
| `FB_DiverterController` | Pneumatic actuator sequence, home/work verification, timeout faults. |
| `FB_JamDetector` | Dynamic jam watchdogs, warnings, jam latch, recovery readiness. |
| `FB_AlarmManager` | Alarm priority, acknowledgement, stack lights, sounder, event timeline. |
| `FB_KPIService` | Package counts, scan counts, throughput, availability, quality, OEE. |
| `FB_HistorianConnector` | Historian heartbeat, sample strobes, publish class selection. |
| `FB_TestHarness` | Deterministic software-in-the-loop simulation and fault injection. |

## 4. OPC UA, Historian, and SCADA Deliverables

The OPC UA server exposes a semantic namespace rather than raw PLC tags. Key
areas include:

- `ControlState`: PackML state, mode, heartbeat, permissives.
- `DeviceSet`: conveyor, scanner, diverter, and sensor telemetry.
- `KPIs`: throughput, lane counts, jams, OEE, availability, performance, quality.
- `Alarms`: alarm state, code, severity, message, acknowledgement.
- `Maintenance`: manual jog, scanner trigger, diverter commands, maintenance key.
- `Recipes`: recipe selection and active recipe information.
- `EventTimeline`: last event class, sequence, severity, message, and new-event pulse.

The historian service collects timestamped telemetry, buffers line protocol
writes, computes KPI rollups, and exposes a query API for Grafana or other
dashboard clients. Grafana provisioning includes KPI trend panels, alarm/event
timeline panels, and throughput alert rules.

## 5. Simulation and Validation Outcomes

| Validation Area | Result | Evidence |
| --- | --- | --- |
| PLC source and module contracts | PASS | `validation/results/validation-report.md` |
| Recipe/routing/jam/diverter/station/KPI/alarm/historian checks | PASS | `validation/results/validation-report.md` |
| TestHarness scenario matrix | 10 PASS, 0 FAIL | `validation/results/test-harness-report.md` |
| TwinCAT manual build | 0 errors, 0 warnings | `validation/results/twincat-manual-build-evidence.md` |
| OPC UA/historian deterministic checks | PASS | `validation/results/opcua-historian-test-report.md` |
| Grafana dashboard import | Verified locally | `scada/grafana/` and import helper |

## 6. TestHarness Scenario Summary

| Scenario | Expected Behavior | Actual Result | Verdict |
| --- | --- | --- | --- |
| Normal Lane A | Package verifies on Lane A, no alarm, historian updates. | Lane A count updated and historian samples emitted. | PASS |
| Jam PE3 and recovery | Jam alarm, hold, ResetJam, unhold to execute. | Jam code 100 raised, reset accepted, returned to execute. | PASS |
| PE2 stuck high | Detect sensor jam source 2. | Jam source 2 detected before timeout. | PASS |
| PE2 stuck low | Scanner timeout and route fault. | Route fault and alarm code 250 generated. | PASS |
| Start with product present | No false KPI count; route fault if tracking invalid. | No package count, route fault generated. | PASS |
| Barcode misread | Reject package and increment bad scan. | Reject count and bad scan incremented. | PASS |
| Network dropout | Historian/OPC UA health drops and recovers. | Dropout/recovery event behavior captured. | PASS |
| Manual override abuse | Auto-mode manual commands inhibited. | Manual jog/diverter requests blocked. | PASS |
| Recipe change mid cycle | Active package completes without misroute. | Recipe load event logged and package completed. | PASS |
| Throughput degradation | Throughput KPI falls below threshold. | Degraded KPI sample captured. | PASS |

No scenario deviations were recorded in the deterministic software validation.

## 7. Documentation Produced

| Document | Path |
| --- | --- |
| Functional Design Specification | `docs/functional_design_specification.md` |
| HMI/SCADA Design | `docs/hmi_scada_design.md` |
| HMI/SCADA Interface Specification | `docs/hmi_scada_interface_spec.md` |
| HMI/SCADA Tag List | `docs/hmi_scada_tag_list.md` |
| OPC UA Namespace Design | `docs/opc_ua_namespace_design.md` |
| Network Topology Design | `docs/network_topology_design.md` |
| Simulation Plan | `docs/simulation_plan_digital_twin.md` |
| Simulation Strategy Recommendation | `docs/simulation_strategy_recommendation.md` |
| Documentation Templates | `docs/documentation_templates/` |
| Final Report | `docs/final_report.md` |

## 8. Remaining Hardware Integration Tasks

| Task | Purpose |
| --- | --- |
| Field I/O mapping | Bind symbolic PLC variables to actual EtherCAT/fieldbus devices. |
| Point-to-point I/O checkout | Prove PE sensors, diverter switches, solenoids, VFD, scanner, and air pressure signals. |
| Safety validation | Verify E-stop/safety loop behavior under approved safety procedure. |
| VFD commissioning | Confirm direction, scaling, ramp, stop, fault, and feedback behavior. |
| Pneumatic commissioning | Tune diverter travel timing, dwell, home/work sensors, and verification windows. |
| Scanner commissioning | Confirm trigger timing, barcode quality, no-read behavior, and recipe patterns. |
| Network hardening | Configure production IPs, OPC UA certificates, firewall rules, and secure credentials. |
| Historian/Grafana production setup | Configure retention, backups, tokens, alert routing, and dashboard ownership. |
| FAT/SAT execution | Run formal protocols with evidence and witness sign-off. |
| As-built release | Close punch list, update drawings/templates, tag final software revision. |

## 9. Risks and Open Issues

| Risk / Open Issue | Impact | Mitigation |
| --- | --- | --- |
| Hardware timing differs from simulation | Diverter misses, false jams, or scanner misses may occur. | Tune debounce, diverter windows, VFD ramp, and jam limits during commissioning. |
| Safety validation not yet performed on real hardware | Cannot release for production operation. | Execute site-approved safety validation before SAT sign-off. |
| OPC UA production certificates not yet issued | Insecure or rejected client connections. | Generate and trust production certificates; disable insecure endpoints where required. |
| InfluxDB/Grafana production retention not finalized | Data loss or excessive storage use. | Define retention, backup, token scope, and alert routing before go-live. |
| Real package variation not yet tested | Barcode and routing performance may vary by SKU. | Run representative SKU matrix during FAT/SAT and update recipes as needed. |

## 10. Engineering Conclusion

The software baseline is ready for controlled hardware integration. The code is
modular, symbolically mapped, TwinCAT-compiled, and covered by deterministic
validation including fault injection and KPI/event evidence. The remaining work
is physical commissioning, formal FAT/SAT execution, production network/security
configuration, and as-built closeout.
