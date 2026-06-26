# HMI/SCADA Tag List
## Material Handling Micro Cell MHMC-01

**Document Ref:** DS-MHMC-HMI-TAGS-007  
**Version:** 1.0.0  
**Mapping Authority:** `opcua_server/model.py` and `scada/telegraf.conf`  

## 1. Naming Convention

| Prefix | Meaning |
| --- | --- |
| `HMI_` | Read-only or display-oriented HMI status tag |
| `CMD_` | Operator or maintenance command tag |
| `ALM_` | Alarm state, alarm text, or alarm acknowledgement tag |
| `EVT_` | Event timeline tag |
| `KPI_` | KPI or performance metric |

All physical and control tags use semantic OPC UA node IDs. Command methods are
listed as methods. Derived KPI tags are sourced from the historian query API or
InfluxDB Flux queries and do not have a direct PLC symbol.

## 2. Global Header Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `HMI_Cell_Mode` | Int32 enum | RW | Current PackML mode: 0 MANUAL, 1 AUTO, 2 MAINTENANCE | `ControlState.CurrentMode` | `Main.eSelectedMode` |
| `HMI_Cell_State` | Int32 enum | RO | Current PackML state | `ControlState.CurrentState` | `Main.fbStationController.stOut.ePackMLState` |
| `HMI_Cell_PermissivesOK` | Boolean | RO | Safety, air, VFD, and diverter permissives are healthy | `ControlState.PermissivesOK` | `Main.xPermissivesOK` |
| `HMI_Cell_Heartbeat` | UInt16 | RO | PLC watchdog counter for freshness checks | `ControlState.Heartbeat` | `Main.uiHeartbeat` |
| `ALM_AnyActive` | Boolean | RO | At least one alarm is active | `Alarms.AnyActive` | `Main.fbAlarmManager.stOut.xAnyAlarmActive` |
| `ALM_AnyUnacked` | Boolean | RO | At least one alarm is unacknowledged | `Alarms.AnyUnacked` | `Main.fbAlarmManager.stOut.xAnyUnacked` |
| `HMI_HistorianHealthy` | Boolean | RO | PLC-side collector health | `PLCIntegration.HistorianHealthy` | `Main.fbHistorianConnector.stOut.xHistorianHealthy` |

## 3. Overview Screen Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `CMD_StartCell` | Method | Command | Request PackML start transition | `Methods.StartCell` | OPC UA method mapped to provider command |
| `CMD_StopCell` | Method | Command | Request PackML stop transition | `Methods.StopCell` | OPC UA method mapped to provider command |
| `CMD_AlarmAcknowledge` | Boolean one-shot | RW | Acknowledge current active alarm | `Alarms.Acknowledge` | `Main.xAlarmAcknowledge` |
| `HMI_Conveyor1_Running` | Boolean | RO | Conveyor VFD run command active | `DeviceSet.Conveyor_1.IsRunning` | `Main.xVfdRunCmd` |
| `HMI_Conveyor1_SpeedSetpoint` | Double | RW | Requested conveyor speed in m/s | `DeviceSet.Conveyor_1.SpeedSetpoint` | `Main.rRecipeSpeed_mps` |
| `HMI_Conveyor1_SpeedFeedback` | Double | RO | Actual conveyor speed in m/s | `DeviceSet.Conveyor_1.SpeedFeedback` | `Main.fbConveyor.stStatus.rSpeedFeedback` |
| `HMI_PE1_Blocked` | Boolean | RO | Infeed PE blocked after debounce | `DeviceSet.Conveyor_1.PE1_Blocked` | `Main.xPE1Debounced` |
| `HMI_PE2_Blocked` | Boolean | RO | Scanner trigger PE blocked after debounce | `DeviceSet.Conveyor_1.PE2_Blocked` | `Main.xPE2Debounced` |
| `HMI_PE3_Blocked` | Boolean | RO | Diverter approach PE blocked after debounce | `DeviceSet.Conveyor_1.PE3_Blocked` | `Main.xPE3Debounced` |
| `ALM_ActiveMessage` | String | RO | Current alarm text | `Alarms.ActiveMessage` | `Main.fbAlarmManager.stOut.sActiveMessage` |
| `ALM_Severity` | UInt16 | RO | OPC UA alarm severity 0 to 1000 | `Alarms.Severity` | `Main.fbAlarmManager.stOut.uiSeverity` |
| `KPI_Throughput_Total` | UInt32 | RO | Total verified packages | `KPIs.ThroughputTotal` | `Main.fbKPIService.stOut.udiTotalPackages` |
| `KPI_Throughput_LaneA` | UInt32 | RO | Packages routed to Lane A | `KPIs.ThroughputLaneA` | `Main.fbKPIService.stOut.udiLaneAPackages` |
| `KPI_Throughput_LaneB` | UInt32 | RO | Packages routed to Lane B | `KPIs.ThroughputLaneB` | `Main.fbKPIService.stOut.udiLaneBPackages` |
| `KPI_Throughput_Reject` | UInt32 | RO | Packages routed to reject | `KPIs.ThroughputReject` | `Main.fbKPIService.stOut.udiRejectPackages` |
| `KPI_OEE_Percent` | Double | RO | OEE percent | `KPIs.OEE` | `Main.rOEEPercentage` |

## 4. Station Control Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `HMI_Conveyor1_VFDCurrent` | Double | RO | Conveyor VFD motor current | `DeviceSet.Conveyor_1.VFD_Current` | `Main.fbConveyor.stStatus.rCurrent` |
| `HMI_Conveyor1_Faulted` | Boolean | RO | Conveyor VFD or conveyor-local fault | `DeviceSet.Conveyor_1.Faulted` | `Main.fbConveyor.stStatus.xFaulted` |
| `CMD_ManualJogForward` | Boolean hold-to-run | RW | Maintenance conveyor jog forward | `Maintenance.ManualJogForward` | `Main.xManualJogForward` |
| `CMD_ManualJogSpeed` | Double | RW | Maintenance jog speed request in m/s | `Maintenance.ManualJogSpeed` | `Main.rManualJogSpeed_mps` |
| `HMI_Scanner1_LastBarcode` | String | RO | Most recent decoded scanner payload | `DeviceSet.Scanner_1.LastReadBarcode` | `Main.sScannerData` |
| `HMI_Scanner1_ReadSuccess` | Boolean | RO | Last scan was valid for routing | `DeviceSet.Scanner_1.ReadSuccess` | `Main.xScannerDataValid` |
| `CMD_Scanner1_Trigger` | Boolean one-shot/diagnostic | RW | Manual scanner trigger override | `DeviceSet.Scanner_1.Trigger` | `Main.xManualScannerTrigger` |

## 5. Diverter Control Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `HMI_Diverter1_Home` | Boolean | RO | Lane A diverter home switch | `DeviceSet.Diverter_1.Home` | `Main.stDiverter1Status.xHomeSensor` |
| `HMI_Diverter1_Work` | Boolean | RO | Lane A diverter work switch | `DeviceSet.Diverter_1.Work` | `Main.stDiverter1Status.xWorkSensor` |
| `CMD_Diverter1_Extend` | Boolean hold-to-run | RW | Maintenance extend command for Lane A diverter | `DeviceSet.Diverter_1.CommandExtend` | `Main.xManualDiverter1Extend` |
| `HMI_Diverter1_Verify` | Boolean | RO | Lane A verification PE | `DeviceSet.Diverter_1.PE_Verify` | `Main.xPE4Debounced` |
| `HMI_Diverter1_Faulted` | Boolean | RO | Lane A pneumatic/interlock fault | `DeviceSet.Diverter_1.Faulted` | `Main.stDiverter1Status.xFaulted` |
| `HMI_Diverter2_Home` | Boolean | RO | Lane B diverter home switch | `DeviceSet.Diverter_2.Home` | `Main.stDiverter2Status.xHomeSensor` |
| `HMI_Diverter2_Work` | Boolean | RO | Lane B diverter work switch | `DeviceSet.Diverter_2.Work` | `Main.stDiverter2Status.xWorkSensor` |
| `CMD_Diverter2_Extend` | Boolean hold-to-run | RW | Maintenance extend command for Lane B diverter | `DeviceSet.Diverter_2.CommandExtend` | `Main.xManualDiverter2Extend` |
| `HMI_Diverter2_Verify` | Boolean | RO | Lane B verification PE | `DeviceSet.Diverter_2.PE_Verify` | `Main.xPE5Debounced` |
| `HMI_Diverter2_Faulted` | Boolean | RO | Lane B pneumatic/interlock fault | `DeviceSet.Diverter_2.Faulted` | `Main.stDiverter2Status.xFaulted` |

## 6. Jam Recovery Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `ALM_GeneralJamAlarm` | Boolean | RO | Package jam detected | `Alarms.GeneralJamAlarm` | `Main.fbAlarmManager.stOut.xGeneralJamAlarm` |
| `ALM_Diverter1Fault` | Boolean | RO | Lane A diverter fault | `Alarms.Diverter1Fault` | `Main.fbAlarmManager.stOut.xDiverter1Alarm` |
| `ALM_Diverter2Fault` | Boolean | RO | Lane B diverter fault | `Alarms.Diverter2Fault` | `Main.fbAlarmManager.stOut.xDiverter2Alarm` |
| `ALM_EStopTripped` | Boolean | RO | E-stop or safety loop open | `Alarms.EStopTripped` | `Main.fbAlarmManager.stOut.xEStopAlarm` |
| `KPI_TotalJams` | UInt16 | RO | Cumulative jam count | `KPIs.TotalJams` | `Main.uiJamEventCounter` |
| `CMD_ResetJam` | Method | Command | Request PLC jam recovery/reset | `Methods.ResetJam` | OPC UA method mapped to provider command |
| `EVT_LastSequence` | UInt32 | RO | Last event sequence number | `EventTimeline.LastSequence` | `Main.stEventTimeline.stLastEvent.udiSequence` |
| `EVT_LastClass` | Int32 enum | RO | Last event class | `EventTimeline.LastClass` | `Main.stEventTimeline.stLastEvent.eClass` |
| `EVT_LastMessage` | String | RO | Last event message | `EventTimeline.LastMessage` | `Main.stEventTimeline.stLastEvent.sMessage` |
| `EVT_LastSeverity` | UInt16 | RO | Last event severity | `EventTimeline.LastSeverity` | `Main.stEventTimeline.stLastEvent.uiSeverity` |
| `EVT_NewEvent` | Boolean pulse | RO | Event appended pulse | `EventTimeline.NewEvent` | `Main.stEventTimeline.xNewEvent` |

## 7. KPI Dashboard Tags

| Tag Name | Type | Direction | Description | OPC UA Node / API | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `KPI_Throughput_PerMinute` | Double | RO | Rolling throughput per minute | `/kpis` query API, `throughput_per_min` | Derived from `KPIs.ThroughputTotal` time window |
| `KPI_Throughput_Total` | UInt32 | RO | Total verified packages | `KPIs.ThroughputTotal` | `Main.fbKPIService.stOut.udiTotalPackages` |
| `KPI_Throughput_LaneA` | UInt32 | RO | Lane A count | `KPIs.ThroughputLaneA` | `Main.fbKPIService.stOut.udiLaneAPackages` |
| `KPI_Throughput_LaneB` | UInt32 | RO | Lane B count | `KPIs.ThroughputLaneB` | `Main.fbKPIService.stOut.udiLaneBPackages` |
| `KPI_Throughput_Reject` | UInt32 | RO | Reject count | `KPIs.ThroughputReject` | `Main.fbKPIService.stOut.udiRejectPackages` |
| `KPI_TotalJams` | UInt16 | RO | Cumulative jam events | `KPIs.TotalJams` | `Main.uiJamEventCounter` |
| `KPI_Availability` | Double | RO | OEE availability factor | `KPIs.Availability` | `Main.rAvailability` |
| `KPI_Performance` | Double | RO | OEE performance factor | `KPIs.Performance` | `Main.rPerformance` |
| `KPI_Quality` | Double | RO | OEE quality factor | `KPIs.Quality` | `Main.rQuality` |
| `KPI_OEE_Percent` | Double | RO | OEE percent | `KPIs.OEE` | `Main.rOEEPercentage` |
| `KPI_AverageCycleTime_s` | Double nullable | RO | Average package cycle time | `/kpis` query API, `average_cycle_time_s` | Derived historian KPI |
| `KPI_MeanTimeBetweenJams_s` | Double nullable | RO | Mean time between jams | `/kpis` query API, `mean_time_between_jams_s` | Derived historian KPI |
| `KPI_Window_s` | Double | RO | Effective KPI query window | `/kpis` query API, `window_s` | Derived historian KPI |

## 8. Alarm/Event Panel Tags

| Tag Name | Type | Direction | Description | OPC UA Node / API | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `ALM_AnyActive` | Boolean | RO | Any active alarm | `Alarms.AnyActive` | `Main.fbAlarmManager.stOut.xAnyAlarmActive` |
| `ALM_AnyUnacked` | Boolean | RO | Any unacknowledged alarm | `Alarms.AnyUnacked` | `Main.fbAlarmManager.stOut.xAnyUnacked` |
| `ALM_ActiveCode` | UInt16 | RO | Active alarm code | `Alarms.ActiveCode` | `Main.fbAlarmManager.stOut.uiActiveAlarmCode` |
| `ALM_Severity` | UInt16 | RO | Active alarm severity | `Alarms.Severity` | `Main.fbAlarmManager.stOut.uiSeverity` |
| `ALM_ActiveMessage` | String | RO | Active alarm message | `Alarms.ActiveMessage` | `Main.fbAlarmManager.stOut.sActiveMessage` |
| `ALM_GeneralJamAlarm` | Boolean | RO | Jam alarm state | `Alarms.GeneralJamAlarm` | `Main.fbAlarmManager.stOut.xGeneralJamAlarm` |
| `ALM_Diverter1Fault` | Boolean | RO | Lane A diverter alarm | `Alarms.Diverter1Fault` | `Main.fbAlarmManager.stOut.xDiverter1Alarm` |
| `ALM_Diverter2Fault` | Boolean | RO | Lane B diverter alarm | `Alarms.Diverter2Fault` | `Main.fbAlarmManager.stOut.xDiverter2Alarm` |
| `ALM_EStopTripped` | Boolean | RO | Safety loop alarm | `Alarms.EStopTripped` | `Main.fbAlarmManager.stOut.xEStopAlarm` |
| `CMD_AlarmAcknowledge` | Boolean one-shot | RW | Acknowledge active alarm | `Alarms.Acknowledge` | `Main.xAlarmAcknowledge` |
| `EVT_LastSequence` | UInt32 | RO | Latest event sequence | `EventTimeline.LastSequence` | `Main.stEventTimeline.stLastEvent.udiSequence` |
| `EVT_LastClass` | Int32 enum | RO | Latest event class | `EventTimeline.LastClass` | `Main.stEventTimeline.stLastEvent.eClass` |
| `EVT_LastMessage` | String | RO | Latest event message | `EventTimeline.LastMessage` | `Main.stEventTimeline.stLastEvent.sMessage` |
| `EVT_LastSeverity` | UInt16 | RO | Latest event severity | `EventTimeline.LastSeverity` | `Main.stEventTimeline.stLastEvent.uiSeverity` |
| `EVT_RecentEvents` | JSON array | RO | Recent events for table display | `/events` query API | Derived from Influx `alarms_events` and `event_timeline` |

## 9. Maintenance Mode Tags

| Tag Name | Type | Direction | Description | OPC UA Node | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `CMD_MaintenanceKey` | Boolean | RW | Maintenance role/key grant request | `Maintenance.MaintenanceKey` | `Main.xMaintenanceKey` |
| `CMD_ManualJogForward` | Boolean hold-to-run | RW | Manual conveyor jog | `Maintenance.ManualJogForward` | `Main.xManualJogForward` |
| `CMD_ManualJogSpeed` | Double | RW | Manual jog speed in m/s | `Maintenance.ManualJogSpeed` | `Main.rManualJogSpeed_mps` |
| `CMD_ResetCounters` | Boolean one-shot | RW | Maintenance counter reset request | `Maintenance.ResetCounters` | `Main.xManualResetCounters` |
| `HMI_CollectorHeartbeat` | Boolean | RW | Collector heartbeat written by bridge | `PLCIntegration.CollectorHeartbeat` | `Main.xCollectorHeartbeat` |
| `HMI_SubscribeEnable` | Boolean | RO | PLC-side subscribe enable | `PLCIntegration.SubscribeEnable` | `Main.fbHistorianConnector.stOut.xSubscribeEnable` |
| `HMI_HistorianHealthy` | Boolean | RO | Historian health | `PLCIntegration.HistorianHealthy` | `Main.fbHistorianConnector.stOut.xHistorianHealthy` |

## 10. Recipe Editor Tags

| Tag Name | Type | Direction | Description | OPC UA Node / Method | ST Variable / Source |
| --- | --- | --- | --- | --- | --- |
| `HMI_Recipe_ActiveID` | UInt16 | RW | Selected/active recipe ID | `Recipes.ActiveRecipeID` | `Main.uiRecipeSelect` |
| `HMI_Recipe_ActiveName` | String | RO | Operator-facing active recipe name | `Recipes.ActiveRecipeName` | `Main.fbLineSupervisor.stOut.stActiveRecipe.sName` |
| `CMD_Recipe_TargetSpeed` | Double | RW | Recipe target speed trim in m/s | `Recipes.TargetSpeed` | `Main.rRecipeSpeed_mps` |
| `CMD_LoadRecipe` | Method | Command | Load recipe ID and target speed | `Methods.LoadRecipe` | OPC UA method mapped to provider command |

## 11. Historian Measurement Mapping

| Measurement | HMI Tags / Fields | Purpose |
| --- | --- | --- |
| `cell_state` | `HMI_Cell_Mode`, `HMI_Cell_State`, `HMI_Cell_PermissivesOK`, `HMI_Cell_Heartbeat` | Mode/state and runtime freshness |
| `conveyor_telemetry` | Conveyor speed, VFD current, PE state, running, fault | Line movement and sensor diagnostics |
| `diverter_1_telemetry` | Diverter 1 home/work/command/verify/fault | Lane A actuator diagnostics |
| `diverter_2_telemetry` | Diverter 2 home/work/command/verify/fault | Lane B actuator diagnostics |
| `sorting_events` | Scanner barcode, trigger, read success | Scanner and routing diagnostics |
| `cell_kpis` | Throughput, lane counts, total jams, OEE factors | Production KPIs |
| `alarms_events` | Alarm active/unacked/code/severity/message/faults | Alarm display and history |
| `event_timeline` | Last sequence/class/message/severity/new event | Sequenced event trace |
| `maintenance` | Jog, maintenance key, counter reset | Maintenance command audit |
| `recipes` | Active recipe, recipe name, target speed | Recipe traceability |
| `collector_health` | Subscribe enable, collector heartbeat, historian healthy | SCADA/PLC integration health |

## 12. Command Safeguards

| Command Tag | HMI Role Gate | PLC Gate |
| --- | --- | --- |
| `CMD_StartCell` | Operator or higher | PackML start permissives |
| `CMD_StopCell` | Operator or higher | Always accepted into safe stop path |
| `CMD_ResetJam` | Operator or higher | Jam clear and permissives verified by PLC |
| `CMD_Diverter1_Extend` | Maintenance only | Maintenance mode, permissives OK, no jam inhibit |
| `CMD_Diverter2_Extend` | Maintenance only | Maintenance mode, permissives OK, no jam inhibit |
| `CMD_ManualJogForward` | Maintenance only | Maintenance mode, speed clamp, safety OK |
| `CMD_Scanner1_Trigger` | Maintenance only | Maintenance mode or diagnostic trigger allowed |
| `CMD_ResetCounters` | Maintenance only | Reset command edge detected and mode gate |
| `CMD_LoadRecipe` | Operator select or Maintenance edit | Recipe ID and speed validated by PLC |
| `CMD_AlarmAcknowledge` | Operator or higher | Acknowledge does not clear root cause |
