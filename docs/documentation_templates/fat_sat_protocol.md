# Factory Acceptance Test (FAT) & Site Acceptance Test (SAT) Protocol
## Material Handling Micro Cell (MHMC-01)
**Project Ref:** PX-MHMC-01  
**Author:** Lead Automation Engineer (MIT Graduate)  

---

### 1. Protocol Purpose and Scope
This document defines the validation protocols for the **Factory Acceptance Test (FAT)** and **Site Acceptance Test (SAT)** of the MHMC-01 sorting system.
*   **FAT Objective:** Conducted at the machine builder's facility using the simulated Digital Twin and physical cell to verify that the control logic, state machine, and data integration comply with the Functional Design Specification (FDS).
*   **SAT Objective:** Conducted at the customer installation site using physical hardware to verify electrical installation integrity, safety loop validation, actual throughput performance, and final SCADA connectivity.

---

### 2. Functional Test Cases

#### Test Case 1: PackML State Machine Transitions
*   **Objective:** Verify that commands from the HMI/OPC UA correctly drive PLC state transitions.
*   **Initial Setup:** E-Stop healthy, control power active. PLC is in the `STOPPED` state.

| Step | Action | Expected System Response | Status (Pass/Fail) | Notes |
| :--- | :--- | :--- | :---: | :--- |
| **1.1** | Send `Reset` command from HMI. | PLC transitions through `RESETTING` and stops in `IDLE`. Stack light is solid green. | | |
| **1.2** | Send `Start` command from `IDLE`. | PLC transitions through `STARTING` (vibrating/sounding alarm beacon) and enters `EXECUTE`. VFD starts. | | |
| **1.3** | Press E-Stop button. | PLC immediately transitions to `ABORTING` then `ABORTED`. Conveyor stops instantly. | | |
| **1.4** | Reset E-Stop button. | PLC remains in `ABORTED` until a `Clear` command is received. | | |
| **1.5** | Send `Clear` followed by `Reset`. | PLC returns to `IDLE` state. Ready for restart. | | |

#### Test Case 2: Line Start Permissives
*   **Objective:** Confirm that the system cannot run if any safety or process permissives are violated.
*   **Initial Setup:** PLC is in `IDLE`.

| Step | Action / Condition | Expected System Response | Status (Pass/Fail) | Notes |
| :--- | :--- | :--- | :---: | :--- |
| **2.1** | Disconnect communications from Scanner 1 (unplug ethernet). Send `Start`. | System rejects transition to `STARTING`. Alarm "Scanner Offline" triggers. PLC remains in `IDLE`. | | |
| **2.2** | Bleed pneumatic pressure below $5.0 \text{ bar}$. Send `Start`. | System rejects transition. Alarm "Low Air Pressure" triggers. PLC remains in `IDLE`. | | |
| **2.3** | Force Diverter 1 manually away from Home position switch. Send `Start`. | System rejects transition. Alarm "Diverter Not Home" triggers. PLC remains in `IDLE`. | | |

#### Test Case 3: Automatic Routing & Diverting Sequence
*   **Objective:** Verify correct routing target calculation and physical divert execution.
*   **Initial Setup:** PLC in `EXECUTE`. Conveyor speed set to $0.5 \text{ m/s}$.

| Step | Test Package Barcode | Expected Routing Path | Verification Sensor | Status (P/F) | Notes |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **3.1** | `*BOX-LANE-A-01*` | Divert into Lane A | `PE4` triggers within 1.5s. `ThroughputLaneA` increments by 1. | | |
| **3.2** | `*ENV-LANE-B-02*` | Divert into Lane B | `PE5` triggers within 1.5s. `ThroughputLaneB` increments by 1. | | |
| **3.3** | `*BAD-SCAN-99*` (or unreadable) | Bypasses Lane A & B; goes to Reject. | `PE6` triggers. `ThroughputReject` increments by 1. | | |

#### Test Case 4: Conveyor Jam Watchdogs & Fault Recovery
*   **Objective:** Verify that package blocks trigger jam alarms and execute recovery sequences.
*   **Initial Setup:** PLC in `EXECUTE`. Conveyor speed set to $0.5 \text{ m/s}$.

| Step | Action | Expected System Response | Status (Pass/Fail) | Notes |
| :--- | :--- | :--- | :---: | :--- |
| **4.1** | Block `PE2` manually with a test block for $\ge 3.0\text{ seconds}$. | Conveyor stops. State machine transitions to `HOLDING` then `HELD`. Red alarm tower light flashes. Jam Alarm sent to OPC UA. | | |
| **4.2** | Send HMI `Reset` command *before* removing the physical block. | Reset rejected. State remains in `HELD`. Alarm stays active. | | |
| **4.3** | Remove physical block from `PE2`. Send `Reset` / `ResetJam` method. | State transitions to `UNHOLDING`. Conveyor restarts. System returns to `EXECUTE`. | | |

---

### 3. FAT/SAT Deviation Log
Document any deviations, corrective actions, and re-test outcomes here.

| Dev ID | Test Case | Deviation Details | Corrective Action Planned | Re-Test Status (P/F) | Signature | Date |
| :--- | :---: | :--- | :--- | :---: | :--- | :--- |
| **D-01** | | | | | | |
| **D-02** | | | | | | |

---

### 4. Validation Sign-Off
By signing below, the parties confirm that all tests listed in this protocol have been executed, and any logged deviations have been resolved and re-verified.

**Commissioning / Test Engineer:**  
*Name:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Signature:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Date:* \_\_\_\_\_\_\_\_\_\_\_\_

**Customer Representative:**  
*Name:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Signature:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Date:* \_\_\_\_\_\_\_\_\_\_\_\_
