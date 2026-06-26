# HMI/SCADA Interface Specification
## Material Handling Micro Cell MHMC-01

**Document Ref:** DS-MHMC-HMI-006  
**Version:** 1.0.0  
**Scope:** Operator HMI, maintenance HMI, SCADA monitoring, and Grafana KPI views  

## 1. Design Principles

The HMI is organized around fast fault recognition, controlled recovery, and
low-risk manual intervention. The first screen always answers four questions:

- Is the cell safe and permissive?
- What mode/state is PackML in?
- Is material flowing as expected?
- Is an alarm or jam blocking production?

Command surfaces are intentionally separated from diagnostic views. Operators
can start, stop, acknowledge alarms, and follow guided jam recovery. Maintenance
users can jog devices, force diagnostic triggers, reset counters, and edit
recipes after the PLC confirms maintenance mode and key/role permission.

## 2. User Roles

| Role | Allowed Actions | Blocked Actions | Typical Screens |
| --- | --- | --- | --- |
| Operator | Start/stop cell, view status, acknowledge alarms, follow jam recovery, view KPIs, select approved recipes | Manual jog, diverter force, scanner trigger, counter reset, recipe parameter edit | Overview, Jam Recovery, Alarms, KPI Dashboard, read-only Recipe view |
| Maintenance | Operator actions plus manual jog, diverter hold-to-run, scanner trigger, maintenance key, counter reset, recipe speed edit | Bypassing PLC permissives, bypassing E-stop/safety, persistent forcing without hold-to-run | Station Control, Diverter Control, Maintenance, Recipe Editor |
| Engineering/Admin | Configure HMI users, Grafana datasource, alert thresholds, OPC UA certificate trust | Production operation without commissioning approval | SCADA configuration, Grafana provisioning |

Role enforcement is layered. The HMI hides or disables controls by role, and the
PLC remains the final authority through PackML mode, maintenance key, and
permissive gates.

## 3. Navigation Flow

```
Overview
  |-- Station Control
  |     |-- Conveyor Station
  |     |-- Scanner Station
  |     |-- Diverter Control
  |-- Jam Recovery
  |-- KPI Dashboard
  |-- Alarm/Event Panel
  |-- Maintenance
  |-- Recipe Editor
```

Global navigation remains visible on every screen. Active alarms and PackML
state are displayed in the header on every screen. Alarm banner selection opens
the Alarm/Event Panel. A jam alarm opens Jam Recovery directly.

## 4. Global Header

**Purpose:** Persistent situational awareness.

**Wireframe:**

```
+--------------------------------------------------------------------------------+
| MHMC-01 | Mode AUTO | State EXECUTE | Permissives OK | Historian OK | Alarm: 0 |
+--------------------------------------------------------------------------------+
```

**Variables and KPIs:**

| Display | Tag | OPC UA Node |
| --- | --- | --- |
| PackML mode | `HMI_Cell_Mode` | `ControlState.CurrentMode` |
| PackML state | `HMI_Cell_State` | `ControlState.CurrentState` |
| Permissives | `HMI_Cell_PermissivesOK` | `ControlState.PermissivesOK` |
| Heartbeat | `HMI_Cell_Heartbeat` | `ControlState.Heartbeat` |
| Any alarm active | `ALM_AnyActive` | `Alarms.AnyActive` |
| Historian healthy | `HMI_HistorianHealthy` | `PLCIntegration.HistorianHealthy` |

## 5. Screen Definitions

### 5.1 Overview

**Purpose:** Normal production operating screen with cell start/stop and high
level material flow status.

**Wireframe:**

```
+--------------------------------------------------------------------------------+
| Header                                                                         |
+----------------------+----------------------+----------------------+-----------+
| Cell State           | Conveyor             | Active Alarm         | Commands  |
| Mode/State           | Run/Speed/PEs        | Message/Severity     | Start     |
| Permissives          | Sensor strip         | Acknowledge          | Stop      |
+----------------------+----------------------+----------------------+-----------+
| Lane A Count         | Lane B Count         | Reject Count         | OEE       |
+----------------------+----------------------+----------------------+-----------+
| Material flow: PE1 -> Scanner -> PE3 -> Diverter A/B -> Verify -> Reject       |
+--------------------------------------------------------------------------------+
```

**Variables and KPIs:**

| Display or Control | Tag | OPC UA Node or Method |
| --- | --- | --- |
| Start cell | `CMD_StartCell` | `Methods.StartCell` |
| Stop cell | `CMD_StopCell` | `Methods.StopCell` |
| Conveyor running | `HMI_Conveyor1_Running` | `DeviceSet.Conveyor_1.IsRunning` |
| Conveyor speed feedback | `HMI_Conveyor1_SpeedFeedback` | `DeviceSet.Conveyor_1.SpeedFeedback` |
| Conveyor speed setpoint | `HMI_Conveyor1_SpeedSetpoint` | `DeviceSet.Conveyor_1.SpeedSetpoint` |
| PE1/PE2/PE3 status | `HMI_PE1_Blocked`, `HMI_PE2_Blocked`, `HMI_PE3_Blocked` | Conveyor PE nodes |
| Total throughput | `KPI_Throughput_Total` | `KPIs.ThroughputTotal` |
| Lane counts | `KPI_Throughput_LaneA`, `KPI_Throughput_LaneB`, `KPI_Throughput_Reject` | KPI nodes |
| OEE | `KPI_OEE_Percent` | `KPIs.OEE` |
| Active alarm text | `ALM_ActiveMessage` | `Alarms.ActiveMessage` |

### 5.2 Station Control Pages

**Purpose:** Device-level supervision for the conveyor and scanner station.
Operator view is read-only except start/stop inherited from the header.
Maintenance view enables hold-to-run diagnostics.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Station: Conveyor and Scanner                                               |
+----------------------------+-----------------------------------------------+
| Conveyor                   | Scanner                                       |
| Speed setpoint/feedback    | Last barcode                                  |
| VFD current                | Read success                                  |
| PE1 PE2 PE3 indicators     | Manual trigger (maintenance only)             |
| Jog forward (maintenance)  |                                               |
+----------------------------+-----------------------------------------------+
```

**Variables and KPIs:**

| Display or Control | Tag | OPC UA Node |
| --- | --- | --- |
| VFD current | `HMI_Conveyor1_VFDCurrent` | `DeviceSet.Conveyor_1.VFD_Current` |
| Conveyor fault | `HMI_Conveyor1_Faulted` | `DeviceSet.Conveyor_1.Faulted` |
| Manual jog forward | `CMD_ManualJogForward` | `Maintenance.ManualJogForward` |
| Manual jog speed | `CMD_ManualJogSpeed` | `Maintenance.ManualJogSpeed` |
| Last barcode | `HMI_Scanner1_LastBarcode` | `DeviceSet.Scanner_1.LastReadBarcode` |
| Scanner read success | `HMI_Scanner1_ReadSuccess` | `DeviceSet.Scanner_1.ReadSuccess` |
| Manual scanner trigger | `CMD_Scanner1_Trigger` | `DeviceSet.Scanner_1.Trigger` |

### 5.3 Diverter Control Page

**Purpose:** Monitor and troubleshoot Lane A and Lane B diverters.
Maintenance controls are hold-to-run and interlocked by PLC permissives.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Diverter Control                                                            |
+------------------------------+------------------------------+--------------+
| Diverter 1 Lane A            | Diverter 2 Lane B            | Interlocks   |
| Home / Work / Verify / Fault | Home / Work / Verify / Fault | Permissives  |
| Extend command               | Extend command               | Jam inhibit  |
+------------------------------+------------------------------+--------------+
```

**Variables:**

| Display or Control | Tag | OPC UA Node |
| --- | --- | --- |
| Diverter 1 home/work | `HMI_Diverter1_Home`, `HMI_Diverter1_Work` | `DeviceSet.Diverter_1.Home`, `.Work` |
| Diverter 1 verify/fault | `HMI_Diverter1_Verify`, `HMI_Diverter1_Faulted` | `DeviceSet.Diverter_1.PE_Verify`, `.Faulted` |
| Diverter 1 extend | `CMD_Diverter1_Extend` | `DeviceSet.Diverter_1.CommandExtend` |
| Diverter 2 home/work | `HMI_Diverter2_Home`, `HMI_Diverter2_Work` | `DeviceSet.Diverter_2.Home`, `.Work` |
| Diverter 2 verify/fault | `HMI_Diverter2_Verify`, `HMI_Diverter2_Faulted` | `DeviceSet.Diverter_2.PE_Verify`, `.Faulted` |
| Diverter 2 extend | `CMD_Diverter2_Extend` | `DeviceSet.Diverter_2.CommandExtend` |

### 5.4 Jam Recovery

**Purpose:** Guide the operator through a safe jam clear sequence.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Jam Recovery                                                                |
+----------------------------------------------------------------------------+
| Active alarm: Package jam detected                                          |
| Step 1: Stop command confirmed                                              |
| Step 2: Clear package from blocked sensor                                   |
| Step 3: Verify PE clear and diverters home                                  |
| Step 4: Reset jam                                                           |
| Step 5: Restart when permissives OK                                         |
+----------------------------------------------------------------------------+
```

**Variables and Commands:**

| Display or Control | Tag | OPC UA Node or Method |
| --- | --- | --- |
| General jam active | `ALM_GeneralJamAlarm` | `Alarms.GeneralJamAlarm` |
| Jam count | `KPI_TotalJams` | `KPIs.TotalJams` |
| Reset jam | `CMD_ResetJam` | `Methods.ResetJam` |
| PE clear verification | `HMI_PE1_Blocked`, `HMI_PE2_Blocked`, `HMI_PE3_Blocked` | Conveyor PE nodes |
| Diverters home | `HMI_Diverter1_Home`, `HMI_Diverter2_Home` | Diverter home nodes |
| Event sequence | `EVT_LastSequence` | `EventTimeline.LastSequence` |
| Event message | `EVT_LastMessage` | `EventTimeline.LastMessage` |

### 5.5 KPI Dashboard

**Purpose:** Production and downtime performance view for supervisors.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| KPI Dashboard                                                               |
+---------------------+---------------------+---------------------+-----------+
| Throughput/min      | Total Packages      | Jam Count           | OEE       |
+---------------------+---------------------+---------------------+-----------+
| Throughput over time chart                                                  |
| Jam count over time chart                                                   |
| Availability / Performance / Quality / OEE trend                            |
+----------------------------------------------------------------------------+
```

**Variables and KPIs:**

| Display | Tag | Source |
| --- | --- | --- |
| Throughput per minute | `KPI_Throughput_PerMinute` | Historian query API derived KPI |
| Total packages | `KPI_Throughput_Total` | `KPIs.ThroughputTotal` |
| Jam count | `KPI_TotalJams` | `KPIs.TotalJams` |
| Availability | `KPI_Availability` | `KPIs.Availability` |
| Performance | `KPI_Performance` | `KPIs.Performance` |
| Quality | `KPI_Quality` | `KPIs.Quality` |
| OEE | `KPI_OEE_Percent` | `KPIs.OEE` |
| Average cycle time | `KPI_AverageCycleTime_s` | Historian query API derived KPI |
| MTBJ | `KPI_MeanTimeBetweenJams_s` | Historian query API derived KPI |

### 5.6 Alarm/Event Panel

**Purpose:** Active alarm triage and event timeline review.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Alarm/Event Panel                                                           |
+--------------------------+-------------------------------------------------+
| Active Alarm             | Event Timeline                                  |
| Code / Severity / Text   | Sequence / Class / Severity / Message          |
| Ack button               | Recent records                                 |
+--------------------------+-------------------------------------------------+
```

**Variables:**

| Display or Control | Tag | OPC UA Node |
| --- | --- | --- |
| Any active | `ALM_AnyActive` | `Alarms.AnyActive` |
| Any unacknowledged | `ALM_AnyUnacked` | `Alarms.AnyUnacked` |
| Active code | `ALM_ActiveCode` | `Alarms.ActiveCode` |
| Severity | `ALM_Severity` | `Alarms.Severity` |
| Active message | `ALM_ActiveMessage` | `Alarms.ActiveMessage` |
| Acknowledge | `CMD_AlarmAcknowledge` | `Alarms.Acknowledge` |
| Event sequence/class/message/severity | `EVT_LastSequence`, `EVT_LastClass`, `EVT_LastMessage`, `EVT_LastSeverity` | EventTimeline nodes |

### 5.7 Maintenance Mode

**Purpose:** Controlled diagnostics and low-speed device movement.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Maintenance                                                                 |
+----------------------------+----------------------+-----------------------+
| Maintenance key            | Manual jog           | Counter reset         |
| Collector heartbeat        | Jog speed            | Historian health      |
| Subscribe enable           | Permissives          | PLC heartbeat         |
+----------------------------+----------------------+-----------------------+
```

**Variables:**

| Display or Control | Tag | OPC UA Node |
| --- | --- | --- |
| Maintenance key | `CMD_MaintenanceKey` | `Maintenance.MaintenanceKey` |
| Manual jog forward | `CMD_ManualJogForward` | `Maintenance.ManualJogForward` |
| Manual jog speed | `CMD_ManualJogSpeed` | `Maintenance.ManualJogSpeed` |
| Reset counters | `CMD_ResetCounters` | `Maintenance.ResetCounters` |
| Collector heartbeat | `HMI_CollectorHeartbeat` | `PLCIntegration.CollectorHeartbeat` |
| Historian healthy | `HMI_HistorianHealthy` | `PLCIntegration.HistorianHealthy` |
| Subscribe enable | `HMI_SubscribeEnable` | `PLCIntegration.SubscribeEnable` |

### 5.8 Recipe Editor

**Purpose:** Select validated sort pattern recipes and adjust target speed
within PLC-bounded limits.

**Wireframe:**

```
+----------------------------------------------------------------------------+
| Recipe Editor                                                               |
+----------------------------+----------------------+-----------------------+
| Active recipe ID/name      | Target speed         | Load Recipe           |
| Approved recipe list       | Validation status    | Current line mode     |
+----------------------------+----------------------+-----------------------+
```

**Variables and Methods:**

| Display or Control | Tag | OPC UA Node or Method |
| --- | --- | --- |
| Active recipe ID | `HMI_Recipe_ActiveID` | `Recipes.ActiveRecipeID` |
| Active recipe name | `HMI_Recipe_ActiveName` | `Recipes.ActiveRecipeName` |
| Target speed | `CMD_Recipe_TargetSpeed` | `Recipes.TargetSpeed` |
| Load recipe | `CMD_LoadRecipe` | `Methods.LoadRecipe` |
| Current mode | `HMI_Cell_Mode` | `ControlState.CurrentMode` |

## 6. Screen Access Rules

| Screen | Operator | Maintenance | Engineering/Admin |
| --- | --- | --- | --- |
| Overview | View and start/stop | View and start/stop | View |
| Station Control | View | Jog and trigger diagnostics | Configure limits outside runtime |
| Diverter Control | View | Hold-to-run extend commands | Configure commissioning tests |
| Jam Recovery | Guided reset | Guided reset plus diagnostics | Review sequence |
| KPI Dashboard | View | View | Configure dashboard/alerts |
| Alarm/Event Panel | View and acknowledge | View and acknowledge | Configure alarm metadata |
| Maintenance Mode | No access to commands | Full command access | Full command access |
| Recipe Editor | Select approved recipe | Edit speed/select recipe | Configure recipe library |

## 7. Quality Notes

- All command controls must be momentary or explicit one-shot actions unless the
  PLC node is documented as a held command.
- Manual diverter commands must be hold-to-run and disabled unless PackML mode
  is MAINTENANCE and permissives are OK.
- HMI tag quality and last update time must be displayed or logged for any
  critical status used in operator decisions.
- Alarm acknowledgement does not clear root cause. The recovery screen must
  still require sensor and diverter verification before restart.
- Recipe speed edits are advisory; the PLC must clamp and validate the value
  before applying it.
