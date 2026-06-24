# Simulation Strategy Recommendation
## Material Handling Micro Cell (MHMC-01)
**Document Ref:** SSR-MHMC-004  
**Version:** 1.0.0  
**Author:** Lead Automation Engineer (MIT Graduate)  
**Date:** June 24, 2026  

---

### 1. Executive Summary & Recommended Strategy

For the Material Handling Micro Cell (MHMC-01), the recommended simulation strategy is a **Hybrid Software-in-the-Loop (SIL)** approach. This involves using the PLC's native virtual motion capabilities (virtual axes) to simulate the core kinematics of the conveyor, paired with an external high-fidelity Digital Twin (like our Python-based `sim_engine.py`) connected via OPC UA. 

This hybrid approach ensures that the PLC's high-speed motion control loops are tested with microsecond accuracy natively, while complex IT-level interactions, physics (package spacing), and anomaly generation are handled by a flexible external engine.

---

### 2. Platform Comparison: TwinCAT 3 vs. CODESYS SoftMotion

When simulating conveyors, diverters, and sensors entirely within the PLC ecosystem, the two industry standards are Beckhoff TwinCAT 3 and CODESYS SoftMotion.

| Feature / Capability | Beckhoff TwinCAT 3 | CODESYS SoftMotion |
| :--- | :--- | :--- |
| **Virtual Axes & Kinematics** | Excellent. `TcMC2` library allows seamless switching between physical and virtual NC axes without changing PLC code. | Excellent. Virtual drives are easily added to the device tree. CODESYS SoftMotion CNC handles complex gearing. |
| **Simulation Fidelity** | Deep integration with MATLAB/Simulink via `TcCOM` objects. Best for complex mathematical modeling and hardware-in-the-loop (HIL). | `CODESYS Depictor` allows for integrated 3D visualization directly within the IDE based on variable states. |
| **Hardware Dependency** | Tied to Beckhoff IPCs or Windows-based PCs running the TwinCAT runtime. | Hardware agnostic. Runs on Raspberry Pi, Wago, Festo, Schneider, etc. |
| **IT/OT Integration** | Superior native integration. TwinCAT ADS and built-in OPC UA server make external co-simulation extremely fast. | Good OPC UA support, but lacks the low-level, high-speed backbone of TwinCAT ADS. |
| **Verdict for MHMC-01** | **Recommended** if ultimate precision, cycle times (<1ms), and external Python/C++ co-simulation are prioritized. | **Recommended** if platform independence and quick, built-in 3D visualization (Depictor) are prioritized. |

---

### 3. Simulation of Anomalies and Faults

To validate the PackML state machine, faults must be rigorously simulated. 

#### 3.1 Jam Conditions
*   **Mechanism:** Conveyor jams occur when a package fails to move, blocking a sensor longer than the allowable timeframe.
*   **Simulation Strategy:** 
    *   Create a virtual boolean variable `xInjectJam_PE2`.
    *   In the simulation logic, override the physical sensor state: `xPE2_Simulated := (PackageInZone AND NOT xInjectJam_PE2) OR xInjectJam_PE2;`
    *   When the jam is injected, `xPE2_Simulated` remains TRUE indefinitely, causing the PLC watchdog timer to trip and the PackML state to enter `HELD`.

#### 3.2 Sensor Faults (Diverter Limit Switches)
*   **Mechanism:** A diverter cylinder extends, but the `LS_Work` (extended) or `LS_Home` (retracted) proximity sensor fails to trigger.
*   **Simulation Strategy:**
    *   Normally, the simulation sets `LS_Work = TRUE` 0.35s after `CommandExtend = TRUE`.
    *   Inject fault `xFault_Diverter1_Stuck`.
    *   When active, intercept the logic so that `LS_Work` remains `FALSE` despite the command. The PLC's 0.8s travel watchdog will catch this and trigger an `ABORTED` or `HELD` state.

#### 3.3 Barcode Misreads
*   **Mechanism:** The vision scanner fails to decode a barcode due to a damaged label or dirty lens.
*   **Simulation Strategy:**
    *   The scanner is simulated via a virtual Modbus TCP server (or OPC UA string node).
    *   When a package passes the trigger sensor (`PE2`), the simulator normally writes a valid string like `PKG-LANE-A`.
    *   Inject fault `xInject_BadScan`. The simulator instead writes `NO_READ` or `ERROR_701`.
    *   The PLC routing logic must catch this exception and default the package routing to the Reject Lane without stopping the conveyor.

---

### 4. Step-by-Step: Setting Up Virtual Devices & Variable Mapping

The following instructions outline how to set up the simulation entirely within the PLC (applicable to TwinCAT/CODESYS):

#### Step 1: Create Virtual Motion Axes (Conveyor)
1.  Navigate to the **Motion / NC Configuration** tree in your IDE.
2.  Add a new Axis and set its type to **Simulation / Virtual Axis**.
3.  Link the axis to your PLC motion function blocks (e.g., `MC_Power`, `MC_MoveVelocity`).
4.  *Result:* You can command the conveyor to move, and the virtual axis will generate realistic position/velocity feedback (`rSpeedFeedback`) without physical hardware.

#### Step 2: Create a Simulation Task
1.  Create a separate Program Organization Unit (POU), e.g., `PRG_Simulation`.
2.  Assign this POU to a dedicated cyclic task (e.g., `SimTask` running at 10ms). *Do not mix simulation logic with production control logic.*

#### Step 3: Map Actuator Commands to Virtual Physics
1.  In `PRG_Simulation`, read the PLC's actuator outputs.
2.  Write timer-based logic to simulate physical movement. 
    *Example (ST):*
    ```pascal
    // Simulate Diverter 1 Extension Delay
    TON_SimDiv1(IN:= Main.fbDiverter_1.xCommandExtend, PT:= T#350MS);
    Main.fbDiverter_1.xWorkSensor := TON_SimDiv1.Q;
    Main.fbDiverter_1.xHomeSensor := NOT Main.fbDiverter_1.xCommandExtend;
    ```

#### Step 4: Map I/O via GVL (Global Variable List)
1.  Create a `GVL_IO`. Instead of mapping these variables directly to hardware terminals (e.g., EtherCAT terminals), leave them unmapped in the hardware tree.
2.  The `PRG_Simulation` writes to these `GVL_IO` inputs (sensors), and the main PLC logic reads from `GVL_IO` inputs and writes to `GVL_IO` outputs (actuators).
3.  *Production Swap:* When physical hardware arrives, simply map the `GVL_IO` addresses to the physical PROFINET/EtherCAT I/O tree. The PLC code remains completely untouched.

---

### 5. Open Source Tools for Digital Twin Modeling

If scaling beyond native PLC simulation to a full Digital Twin, consider these open-source tools:

1.  **Python (Asyncua / PyModbus):** As implemented in our current `sim_engine.py`. Highly flexible for writing kinematic equations and OPC UA servers. Easily runs in Docker.
2.  **Gazebo / Ignition Robotics:** The gold standard for open-source 3D physics simulation. Excellent for simulating conveyor friction, gravity, and complex 3D collisions. Integrates heavily with ROS/ROS2, which can bridge to OPC UA.
3.  **Blender (with Python API):** While primarily a 3D animation tool, Blender's physics engine and Python scripting allow for stunningly realistic visual digital twins. Variables from the PLC can drive 3D animations in real-time.
4.  **Node-RED:** Excellent for lightweight flow-based simulation and orchestrating IT/OT data bridging. Can easily mock Modbus/OPC UA servers and inject faults via a web dashboard.
