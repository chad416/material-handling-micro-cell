# OPC UA Information Model & Namespace Design
## Material Handling Micro Cell (MHMC-01)
**Document Ref:** DS-MHMC-OPC-002  
**Version:** 1.0.0  
**Author:** Lead Automation Engineer (MIT Graduate)  
**Date:** June 24, 2026  

---

### 1. Information Model Architecture
The MHMC-01 OPC UA Information Model exposes the structural and behavioral properties of the sorting cell. It is designed to comply with standard object-oriented modeling principles, mapping directly to physical devices, control logic states (PackML), and supervisory interfaces.

*   **Namespace URI:** `http://antigravity.automation.org/MHMC/`
*   **Namespace Index (Recommended):** `ns=2` (dynamically assigned at runtime, but mapped as `ns=2` in examples).

**Implementation binding:** the executable namespace and current PLC symbol map
are implemented in `opcua_server/model.py`.  That file is the authoritative
bridge from semantic node IDs to the current `Main` ST symbols, including the
renamed symbolic PE and diverter lane variables.

```
Root
 └── Objects
      └── MHMC_Cell (FolderType)
           ├── DeviceSet (FolderType)
           │    ├── Conveyor_1 (DeviceType)
           │    ├── Diverter_1 (DiverterType)
           │    ├── Diverter_2 (DiverterType)
           │    └── Scanner_1 (ScannerType)
           ├── ControlState (FolderType)
           │    ├── CurrentMode (Variable)
           │    ├── CurrentState (Variable)
           │    ├── Permissives (Variable)
           │    └── Heartbeat (Variable)
           ├── KPIs (FolderType)
           │    ├── ThroughputTotal (Variable)
           │    ├── ThroughputLaneA (Variable)
           │    ├── ThroughputLaneB (Variable)
           │    ├── ThroughputReject (Variable)
           │    ├── TotalJams (Variable)
           │    └── OEE (Variable)
           └── Methods (FolderType)
                ├── StartCell (Method)
                ├── StopCell (Method)
                ├── ResetJam (Method)
                └── LoadRecipe (Method)
```

---

### 2. DataType Definitions
Custom structures are modeled to maintain logical bindings when reading complex nodes:

#### 2.1 `PackML_State_Enum` (Int32)
*   `0` = STOPPED
*   `1` = STARTING
*   `2` = EXECUTE
*   `3` = SUSPENDED
*   `4` = HOLDING
*   `5` = HELD
*   `6` = UNHOLDING
*   `7` = STOPPING
*   `8` = ABORTED
*   `9` = IDLE
*   `10` = RESETTING

#### 2.2 `PackML_Mode_Enum` (Int32)
*   `0` = MANUAL
*   `1` = AUTO
*   `2` = MAINTENANCE

---

### 3. Node Table & Address Space
The following tables detail the nodes exposed in the address space under `ns=2`.

#### 3.1 DeviceSet: Conveyor_1
| Node ID | Browse Name | Node Class | Data Type | Access Level | Description | PLC Mapping / Source |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ns=2;s=DeviceSet.Conveyor_1.SpeedFeedback` | `SpeedFeedback` | Variable | `Double` | RO | Current motor speed in m/s | `Main.fbConveyor.rSpeedFeedback` |
| `ns=2;s=DeviceSet.Conveyor_1.SpeedSetpoint` | `SpeedSetpoint` | Variable | `Double` | RW | Commanded speed in m/s | `Main.fbConveyor.rSpeedSetpoint` |
| `ns=2;s=DeviceSet.Conveyor_1.IsRunning` | `IsRunning` | Variable | `Boolean` | RO | True when motor runs | `Main.fbConveyor.xIsRunning` |
| `ns=2;s=DeviceSet.Conveyor_1.PE1_Blocked` | `PE1_Blocked` | Variable | `Boolean` | RO | Photoelectric 1 beam broken | `Main.fbConveyor.xPE1` |
| `ns=2;s=DeviceSet.Conveyor_1.PE2_Blocked` | `PE2_Blocked` | Variable | `Boolean` | RO | Photoelectric 2 beam broken | `Main.fbConveyor.xPE2` |
| `ns=2;s=DeviceSet.Conveyor_1.PE3_Blocked` | `PE3_Blocked` | Variable | `Boolean` | RO | Photoelectric 3 beam broken | `Main.fbConveyor.xPE3` |
| `ns=2;s=DeviceSet.Conveyor_1.VFD_Current` | `VFD_Current` | Variable | `Double` | RO | VFD Motor Current (Amps) | `Main.fbConveyor.rCurrent` |
| `ns=2;s=DeviceSet.Conveyor_1.Faulted` | `Faulted` | Variable | `Boolean` | RO | VFD or general conveyor fault | `Main.fbConveyor.xFaulted` |

#### 3.2 DeviceSet: Diverter_1 & Diverter_2 (`x` represents Diverter ID `1` or `2`)
| Node ID | Browse Name | Node Class | Data Type | Access Level | Description | PLC Mapping / Source |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ns=2;s=DeviceSet.Diverter_x.Home` | `Home` | Variable | `Boolean` | RO | Pusher is in retracted position | `Main.fbDiverter_x.xHomeSensor` |
| `ns=2;s=DeviceSet.Diverter_x.Work` | `Work` | Variable | `Boolean` | RO | Pusher is in extended position | `Main.fbDiverter_x.xWorkSensor` |
| `ns=2;s=DeviceSet.Diverter_x.CommandExtend`| `CommandExtend` | Variable | `Boolean` | RW | Manual override extend command | `Main.fbDiverter_x.xCommandExtend`|
| `ns=2;s=DeviceSet.Diverter_x.PEX_Blocked` | `PE_Verify` | Variable | `Boolean` | RO | Verification sensor blocked | `Main.fbDiverter_x.xVerificationSensor` |
| `ns=2;s=DeviceSet.Diverter_x.Faulted` | `Faulted` | Variable | `Boolean` | RO | Fails to reach limit switch | `Main.fbDiverter_x.xFaulted` |

#### 3.3 DeviceSet: Scanner_1
| Node ID | Browse Name | Node Class | Data Type | Access Level | Description | PLC Mapping / Source |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ns=2;s=DeviceSet.Scanner_1.LastReadBarcode`| `LastReadBarcode`| Variable | `String` | RO | String content of last scan | `Main.fbRouting.sLastBarcode` |
| `ns=2;s=DeviceSet.Scanner_1.Trigger` | `Trigger` | Variable | `Boolean` | RW | Diagnostic trigger override | `Main.fbRouting.xManualTrigger` |
| `ns=2;s=DeviceSet.Scanner_1.ReadSuccess` | `ReadSuccess` | Variable | `Boolean` | RO | True if last scan was successful | `Main.fbRouting.xReadSuccess` |

#### 3.4 ControlState
| Node ID | Browse Name | Node Class | Data Type | Access Level | Description | PLC Mapping / Source |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ns=2;s=ControlState.CurrentMode` | `CurrentMode` | Variable | `PackML_Mode_Enum`| RO/RW | Cell operational mode | `Main.fbPackML.eMode` |
| `ns=2;s=ControlState.CurrentState` | `CurrentState` | Variable | `PackML_State_Enum`| RO | Cell operational state | `Main.fbPackML.eState` |
| `ns=2;s=ControlState.PermissivesOK` | `PermissivesOK` | Variable | `Boolean` | RO | Safety and start permissives met | `Main.xPermissivesOK` |
| `ns=2;s=ControlState.Heartbeat` | `Heartbeat` | Variable | `UInt16` | RO | Cyclic watchdog index | `Main.uiHeartbeat` |

#### 3.5 KPIs
| Node ID | Browse Name | Node Class | Data Type | Access Level | Description | PLC Mapping / Source |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ns=2;s=KPIs.ThroughputTotal` | `ThroughputTotal` | Variable | `UInt32` | RO | Total package count processed | `Main.fbRouting.udiTotalCount` |
| `ns=2;s=KPIs.ThroughputLaneA` | `ThroughputLaneA` | Variable | `UInt32` | RO | Package count sent to Lane A | `Main.fbRouting.udiLaneACount` |
| `ns=2;s=KPIs.ThroughputLaneB` | `ThroughputLaneB` | Variable | `UInt32` | RO | Package count sent to Lane B | `Main.fbRouting.udiLaneBCount` |
| `ns=2;s=KPIs.ThroughputReject` | `ThroughputReject`| Variable | `UInt32` | RO | Package count sent to Reject | `Main.fbRouting.udiRejectCount` |
| `ns=2;s=KPIs.TotalJams` | `TotalJams` | Variable | `UInt16` | RO | Cumulative cell jam events count | `Main.uiJamEventCounter` |
| `ns=2;s=KPIs.OEE` | `OEE` | Variable | `Double` | RO | Real-time OEE percentage | `Main.rOEEPercentage` |

---

### 4. Method Definitions
The server exposes callable RPC methods to control cell execution or override parameters.

#### 4.1 Method: `StartCell`
*   **Node ID:** `ns=2;s=Methods.StartCell`
*   **Input Arguments:** None
*   **Output Arguments:**
    *   `Success` (Boolean): True if command accepted and state transition initiated.
*   **Action:** Signals PLC state machine to transition from `IDLE` to `STARTING`.

#### 4.2 Method: `StopCell`
*   **Node ID:** `ns=2;s=Methods.StopCell`
*   **Input Arguments:** None
*   **Output Arguments:**
    *   `Success` (Boolean): True if transition initiated.
*   **Action:** Signals PLC state machine to transition from `EXECUTE` to `STOPPING`.

#### 4.3 Method: `ResetJam`
*   **Node ID:** `ns=2;s=Methods.ResetJam`
*   **Input Arguments:** None
*   **Output Arguments:**
    *   `Success` (Boolean): True if state transition to `UNHOLDING` or `RESETTING` is accepted.
*   **Action:** Clears active jam timers, resets alarm variables, and commands the cell to recover from `HELD` or `ABORTED`.

#### 4.4 Method: `LoadRecipe`
*   **Node ID:** `ns=2;s=Methods.LoadRecipe`
*   **Input Arguments:**
    *   `RecipeID` (UInt16): Recipe selector ID.
    *   `TargetSpeed` (Double): Default conveyor speed for this recipe (m/s).
*   **Output Arguments:**
    *   `Status` (Int16): `0` = Loaded successfully, `-1` = Invalid speed, `-2` = Recipe not found.
*   **Action:** Configures target speeds and routing regex maps in the PLC runtime memory.

---

### 5. Alarm and Event Mapping
Alarms are mapped to OPC UA Event Notifications. The server registers custom `AlarmConditionType` sub-types.

```
BaseEventType
 └── TransitionEventType
      └── ConditionType
           └── AcknowledgeableConditionType
                └── AlarmConditionType
                     ├── GeneralJamAlarm (Trigger: PE1/2/3 Blocked)
                     ├── DiverterPneumaticAlarm (Trigger: LS fail)
                     └── EmergencyStopAlarm (Trigger: E-stop broken)
```

| Alarm Name | Trigger Condition | Severity (1-1000) | Message | Active State (PLC Node) |
| :--- | :--- | :--- | :--- | :--- |
| **GeneralJamAlarm** | PE sensor blocked $>$ Jam limit time | 800 | "Package jam detected on Main Conveyor" | `Main.fbConveyor.xJamAlarm` |
| **Diverter1Fault** | Pusher 1 failed to actuate | 900 | "Diverter 1 pneumatic actuator fault" | `Main.fbDiverter_1.xFault` |
| **Diverter2Fault** | Pusher 2 failed to actuate | 900 | "Diverter 2 pneumatic actuator fault" | `Main.fbDiverter_2.xFault` |
| **EStopTripped** | E-stop circuit interrupted | 1000 | "Emergency Stop Circuit Tripped" | `NOT Main.xSafetyLoopOK` |
