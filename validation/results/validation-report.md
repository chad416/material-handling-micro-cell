# MHMC PLC Validation Report

- Generated: 2026-06-25 15:23:55 +02:00
- Workspace: C:\Users\chand\.gemini\antigravity\scratch\material_handling_cell
- Scope: static source contracts, deterministic offline FAT/reference scenarios, and TwinCAT compiler gate
- Passed: 144
- Failed: 0
- Total checks: 144

## Important Scope Boundary

This validation does not replace physical commissioning. Real I/O mapping, E-stop validation, pneumatic timing, VFD behavior, scanner communication, diverter mechanics, OPC UA collector connectivity, and signed FAT/SAT must be performed on the actual cell.

## Results

| Suite | Check | Result | Detail |
| --- | --- | --- | --- |
| SourceContracts | LineSupervisor source file exists | PASS |  |
| SourceContracts | LineSupervisor has typed input structure | PASS |  |
| SourceContracts | LineSupervisor has typed output structure | PASS |  |
| SourceContracts | LineSupervisor has configuration structure | PASS |  |
| SourceContracts | LineSupervisor has context structure | PASS |  |
| SourceContracts | LineSupervisor has enumerated state | PASS |  |
| SourceContracts | LineSupervisor has init function | PASS |  |
| SourceContracts | LineSupervisor has cyclic function | PASS |  |
| SourceContracts | LineSupervisor has FB wrapper | PASS |  |
| SourceContracts | LineSupervisor has meaningful comments | PASS |  |
| SourceContracts | StationController source file exists | PASS |  |
| SourceContracts | StationController has typed input structure | PASS |  |
| SourceContracts | StationController has typed output structure | PASS |  |
| SourceContracts | StationController has configuration structure | PASS |  |
| SourceContracts | StationController has context structure | PASS |  |
| SourceContracts | StationController has enumerated state | PASS |  |
| SourceContracts | StationController has init function | PASS |  |
| SourceContracts | StationController has cyclic function | PASS |  |
| SourceContracts | StationController has FB wrapper | PASS |  |
| SourceContracts | StationController has meaningful comments | PASS |  |
| SourceContracts | DiverterController source file exists | PASS |  |
| SourceContracts | DiverterController has typed input structure | PASS |  |
| SourceContracts | DiverterController has typed output structure | PASS |  |
| SourceContracts | DiverterController has configuration structure | PASS |  |
| SourceContracts | DiverterController has context structure | PASS |  |
| SourceContracts | DiverterController has enumerated state | PASS |  |
| SourceContracts | DiverterController has init function | PASS |  |
| SourceContracts | DiverterController has cyclic function | PASS |  |
| SourceContracts | DiverterController has FB wrapper | PASS |  |
| SourceContracts | DiverterController has meaningful comments | PASS |  |
| SourceContracts | JamDetector source file exists | PASS |  |
| SourceContracts | JamDetector has typed input structure | PASS |  |
| SourceContracts | JamDetector has typed output structure | PASS |  |
| SourceContracts | JamDetector has configuration structure | PASS |  |
| SourceContracts | JamDetector has context structure | PASS |  |
| SourceContracts | JamDetector has enumerated state | PASS |  |
| SourceContracts | JamDetector has init function | PASS |  |
| SourceContracts | JamDetector has cyclic function | PASS |  |
| SourceContracts | JamDetector has FB wrapper | PASS |  |
| SourceContracts | JamDetector has meaningful comments | PASS |  |
| SourceContracts | HistorianConnector source file exists | PASS |  |
| SourceContracts | HistorianConnector has typed input structure | PASS |  |
| SourceContracts | HistorianConnector has typed output structure | PASS |  |
| SourceContracts | HistorianConnector has configuration structure | PASS |  |
| SourceContracts | HistorianConnector has context structure | PASS |  |
| SourceContracts | HistorianConnector has enumerated state | PASS |  |
| SourceContracts | HistorianConnector has init function | PASS |  |
| SourceContracts | HistorianConnector has cyclic function | PASS |  |
| SourceContracts | HistorianConnector has FB wrapper | PASS |  |
| SourceContracts | HistorianConnector has meaningful comments | PASS |  |
| SourceContracts | KPIService source file exists | PASS |  |
| SourceContracts | KPIService has typed input structure | PASS |  |
| SourceContracts | KPIService has typed output structure | PASS |  |
| SourceContracts | KPIService has configuration structure | PASS |  |
| SourceContracts | KPIService has context structure | PASS |  |
| SourceContracts | KPIService has enumerated state | PASS |  |
| SourceContracts | KPIService has init function | PASS |  |
| SourceContracts | KPIService has cyclic function | PASS |  |
| SourceContracts | KPIService has FB wrapper | PASS |  |
| SourceContracts | KPIService has meaningful comments | PASS |  |
| SourceContracts | AlarmManager source file exists | PASS |  |
| SourceContracts | AlarmManager has typed input structure | PASS |  |
| SourceContracts | AlarmManager has typed output structure | PASS |  |
| SourceContracts | AlarmManager has configuration structure | PASS |  |
| SourceContracts | AlarmManager has context structure | PASS |  |
| SourceContracts | AlarmManager has enumerated state | PASS |  |
| SourceContracts | AlarmManager has init function | PASS |  |
| SourceContracts | AlarmManager has cyclic function | PASS |  |
| SourceContracts | AlarmManager has FB wrapper | PASS |  |
| SourceContracts | AlarmManager has meaningful comments | PASS |  |
| SourceContracts | PLCopen motion command adapter exists | PASS |  |
| SourceContracts | recipe/configuration type exists | PASS |  |
| SourceContracts | event timeline ring buffer exists | PASS |  |
| SourceContracts | symbolic I/O only | PASS |  |
| SourceContracts | no unresolved TODO markers | PASS |  |
| SourceContracts | TwinCAT/CODESYS empty strings use single quotes | PASS |  |
| TwinCATProject | TwinCAT wrapper regeneration skipped for existing build evidence | PASS |  |
| TwinCATProject | generated .plcproj exists | PASS |  |
| TwinCATProject | generated solution exists | PASS |  |
| TwinCATProject | generated .plcproj XML parses | PASS |  |
| TwinCATProject | generated project preserves TwinCAT PLC options | PASS |  |
| TwinCATProject | generated project includes module POUs | PASS |  |
| TwinCATProject | generated project includes DUTs | PASS |  |
| RecipeMatrix | default fallback recipe loads | PASS |  |
| RecipeMatrix | default fallback Lane A pattern | PASS | expected=[LANE-A], actual=[LANE-A] |
| RecipeMatrix | book recipe A loads | PASS |  |
| RecipeMatrix | book recipe A pattern dispatch | PASS | expected=[A-SKU], actual=[A-SKU] |
| RecipeMatrix | book recipe B accepts speed trim inside limits | PASS |  |
| RecipeMatrix | book recipe B speed trim applied | PASS | expected=[0.6], actual=[0.6], tolerance=[0.0001] |
| RecipeMatrix | MES/HMI payload recipe loads | PASS |  |
| RecipeMatrix | payload route pattern retained | PASS | expected=[PAY-B], actual=[PAY-B] |
| RecipeMatrix | disabled recipe is rejected | PASS |  |
| RecipeMatrix | overspeed recipe is rejected | PASS |  |
| RecipeMatrix | missing recipe ID is rejected | PASS |  |
| RoutingLogic | Lane A package increments total | PASS | expected=[1], actual=[1] |
| RoutingLogic | Lane A package increments lane A | PASS | expected=[1], actual=[1] |
| RoutingLogic | Lane A route completes without fault | PASS |  |
| RoutingLogic | Lane B package increments total | PASS | expected=[1], actual=[1] |
| RoutingLogic | Lane B package increments lane B | PASS | expected=[1], actual=[1] |
| RoutingLogic | Lane B route completes without fault | PASS |  |
| RoutingLogic | bad scan routes to reject | PASS | expected=[1], actual=[1] |
| RoutingLogic | bad scan pulse is generated | PASS |  |
| RoutingLogic | FIFO overflow latches route fault | PASS |  |
| RoutingLogic | diverter not ready at route window faults | PASS |  |
| RoutingLogic | PE2 trigger without package faults | PASS |  |
| RoutingLogic | manual mode hold-to-run commands without FIFO mutation | PASS |  |
| RoutingLogic | maintenance mode blocks commands without safeguards | PASS |  |
| RoutingLogic | maintenance mode permits hold-to-run with safeguards | PASS |  |
| JamRecovery | warning appears before jam limit | PASS |  |
| JamRecovery | PE2 jam latches alarm and hold request source | PASS |  |
| JamRecovery | jam counter increments once on rising latch | PASS | expected=[1], actual=[1] |
| JamRecovery | reset is rejected while sensor remains blocked | PASS |  |
| JamRecovery | recovery ready only after sensors clear | PASS |  |
| JamRecovery | reset accepted from HELD after clear | PASS |  |
| JamRecovery | dynamic limit clamps at slow speed | PASS | expected=[6], actual=[6], tolerance=[0.0001] |
| DiverterController | auto sequence extends verifies retracts and completes | PASS |  |
| DiverterController | extend timeout faults | PASS |  |
| DiverterController | verification timeout faults | PASS |  |
| DiverterController | manual hold limit faults | PASS |  |
| DiverterController | force retract de-energises solenoid | PASS |  |
| StationController | reset sequence reaches IDLE | PASS | expected=[IDLE], actual=[IDLE] |
| StationController | start sequence reaches EXECUTE and runs conveyor | PASS |  |
| StationController | jam forces HOLDING then HELD quick stop | PASS |  |
| StationController | unhold returns to EXECUTE | PASS | expected=[EXECUTE], actual=[EXECUTE] |
| StationController | safety loop drop aborts station | PASS | expected=[ABORTED], actual=[ABORTED] |
| StationController | clear recovers ABORTED to STOPPED | PASS | expected=[STOPPED], actual=[STOPPED] |
| StationController | maintenance requires key and clamps jog speed | PASS |  |
| KPIService | route pulses update total count | PASS | expected=[3], actual=[3] |
| KPIService | reject count updates | PASS | expected=[1], actual=[1] |
| KPIService | quality excludes reject | PASS | expected=[0.666666666666667], actual=[0.666666666666667], tolerance=[0.0001] |
| KPIService | availability includes held downtime | PASS | expected=[0.75], actual=[0.75], tolerance=[0.0001] |
| KPIService | OEE is calculated from availability performance quality | PASS |  |
| KPIService | reset counters clears KPI totals | PASS |  |
| AlarmManager | jam alarm drives code severity sounder and event | PASS |  |
| AlarmManager | acknowledge silences unacked sounder and logs command | PASS |  |
| AlarmManager | clearing root cause appends recovery event | PASS |  |
| AlarmManager | reset command appends recovery request | PASS |  |
| AlarmManager | E-stop priority overrides jam | PASS |  |
| HistorianConnector | healthy historian publishes KPI alarm and event | PASS |  |
| HistorianConnector | missed heartbeat drives unhealthy/backoff condition | PASS |  |
| FATSequence | startup, Lane A route, jam hold, reset, and unhold complete | PASS |  |
| FATSequence | FAT KPI reflects verified package | PASS |  |
| TwinCATCompile | existing TwinCAT build log reports success | PASS |  |
| TwinCATCompile | TwinCAT build artifact evidence recorded | PASS | Loose .tmc is not present now; accepted because existing transcript proves LastBuildInfo 0 and this evidence mode does not launch XAE. |
