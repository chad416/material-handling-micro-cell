# Simulation Plan & Digital Twin Strategy
## Material Handling Micro Cell (MHMC-01)
**Document Ref:** SP-MHMC-DT-003  
**Version:** 1.0.0  
**Author:** Lead Automation Engineer (MIT Graduate)  
**Date:** June 24, 2026  

---

### 1. Digital Twin Architecture & Concept
The Digital Twin for the **MHMC-01** cell is designed as a **Software-in-the-Loop (SIL)** simulation. It serves as a real-time virtual replica of the physical cell's mechanical and electrical behaviors, executing in parallel with the PLC code.

#### Key Functions of the Digital Twin:
- **Virtual commissioning:** Validate PLC code sequences and edge-case error recovery routines before deploying to physical hardware.
- **Real-time State Mirroring:** Replicate the system state machine (PackML) and individual sensor/actuator positions.
- **Anomaly Injection:** Provide an interface to inject mechanical and electrical faults (e.g., jammed packages, stuck cylinders) to test PLC diagnostics.
- **SCADA Data Source:** Drive time-series telemetry (via OPC UA) to verify InfluxDB and Grafana integrations.

```
+---------------------------+              +---------------------------+
|    Digital Twin Engine    |              |       PLC logic (ST)      |
|     (Python Simulator)    |              |   (CODESYS / TwinCAT)     |
|                           |              |                           |
| Simulates physical laws:  |   OPC UA     | Runs control loops,       |
| - Conveyor dynamics       | <==========> | checks permissives,       |
| - Package positions       |  (Read/Write | executes diverter pushers |
| - Sensor beam breaks      |   Registers) | and tracks barcode logic  |
| - Pneumatic travel times  |              |                           |
+---------------------------+              +---------------------------+
              |                                          |
              | OPC UA                                   | OPC UA
              v                                          v
+----------------------------------------------------------------------+
|                           OPC UA Namespace                           |
+----------------------------------------------------------------------+
                                  |
                                  | Telegraf (Collector)
                                  v
                        +-------------------+
                        |     InfluxDB      |
                        +-------------------+
                                  |
                                  v
                        +-------------------+
                        |      Grafana      |
                        +-------------------+
```

---

### 2. Mathematical Modeling of Package Kinematics
To simulate realistic package flow and sensor interactions, the simulation uses a one-dimensional coordinate space representing the conveyor surface.

#### 2.1 Coordinate Mapping
Let the conveyor start at coordinate $x = 0.0 \text{ meters}$ (Infeed) and terminate at $x = L_{\text{conv}} = 4.0 \text{ meters}$ (Reject exit). The physical components are located at fixed coordinates:
*   $x_{\text{PE1}}$ (Infeed Sensor) $= 0.2 \text{ m}$
*   $x_{\text{PE2}}$ (Trigger Sensor) $= 1.2 \text{ m}$
*   $x_{\text{Scanner1}}$ (Vision Scan Area) $= 1.3 \text{ m}$
*   $x_{\text{PE3}}$ (Diverter 1 In-range) $= 2.2 \text{ m}$
*   $x_{\text{Diverter1}}$ (Pneumatic Pusher 1) $= 2.2 \text{ m}$
*   $x_{\text{Diverter2}}$ (Pneumatic Pusher 2) $= 3.2 \text{ m}$

#### 2.2 Kinematic Equations
Each active package $i$ is modeled as an object with position $x_i(t)$ and length $W_{\text{pkg}} = 0.25 \text{ m}$. At each simulation timestep $\Delta t$, the package position is integrated:

$$x_i(t + \Delta t) = x_i(t) + v_{\text{conv}}(t) \cdot \Delta t$$

Where:
-   $v_{\text{conv}}(t)$ is the current velocity of Conveyor 1, which lags the speed setpoint ($v_{\text{set}}$) due to simulated motor inertia:
    $$v_{\text{conv}}(t + \Delta t) = v_{\text{conv}}(t) + \left(\frac{v_{\text{set}}(t) - v_{\text{conv}}(t)}{\tau}\right) \Delta t$$
    (where motor time constant $\tau = 0.4 \text{ seconds}$).

#### 2.3 Sensor State Logic
A photoelectric sensor $PE_k$ located at position $x_{\text{PE\_k}}$ is triggered (`TRUE`) if any part of a package overlaps the sensor position:

$$\text{SensorState}(PE_k) = \begin{cases} 
\text{TRUE} & \text{if } \exists i \text{ s.t. } x_i(t) \le x_{\text{PE\_k}} \le (x_i(t) + W_{\text{pkg}}) \\
\text{FALSE} & \text{otherwise}
\end{cases}$$

---

### 3. Actuator Simulation (Pneumatic Diverters)
The diverter pushers are modeled as state-based actuators with transit times and feedback switches.

*   **Transit Speed:** Cylinders take $t_{\text{transit}} = 0.35 \text{ seconds}$ to extend or retract.
*   **PLC Commands:** The simulation reads `CommandExtend` via OPC UA.
*   **Limit Switches:**
    *   If current position is $0.0 \text{ m}$ (fully retracted), `LS_Home` = TRUE, `LS_Work` = FALSE.
    *   If current position is $d_{\text{stroke}} = 0.15 \text{ m}$ (fully extended), `LS_Home` = FALSE, `LS_Work` = TRUE.
    *   During travel, both limits are FALSE.

---

### 4. OPC UA Synchronization Strategy
The Digital Twin acts as the **master OPC UA server** in our test environment (simulating the physical interface of the PLC + Fieldbus). 

1.  **Read Loop (Every 50ms):**
    *   Read conveyor speed setpoint `ns=2;s=DeviceSet.Conveyor_1.SpeedSetpoint`.
    *   Read manual override inputs (e.g. `CommandExtend` values).
    *   Read PackML command signals (e.g., Method calls to `StartCell`, `StopCell`, `ResetJam`).
2.  **Simulation Step:**
    *   Update conveyor speed based on inertia.
    *   Advance all active package coordinates.
    *   Evaluate sensor beam states.
    *   Update pneumatic cylinder strokes.
    *   Route or reject package coordinates if a diverter is commanded and extended when a package is in-range ($x_i \approx x_{\text{PE3}}$ or $x_{\text{PE3\_div2}}$).
3.  **Write Loop (Every 50ms):**
    *   Update VFD speed feedback, motor current, and running status.
    *   Write sensor states: `PE1_Blocked`, `PE2_Blocked`, `PE3_Blocked`, etc.
    *   Write diverter limit switch states: `Home`, `Work`.
    *   Update Scanner data node `LastReadBarcode` upon package passing $x_{\text{PE2}}$.

---

### 5. Anomaly Injection & Verification Plan
The digital twin simulation engine will support the injection of anomalous behavior via command-line arguments, a JSON configuration file, or script flags:

#### 5.1 Jam Simulation (Main Conveyor)
*   **Mechanism:** When package $i$ reaches coordinate $x = 1.2 \text{ m}$ (at `PE2`), set its velocity to $0.0 \text{ m/s}$ (stuck) and ignore VFD conveyor movement.
*   **Expected PLC Behavior:** `PE2` remains blocked. The PLC jam timer expires ($t_{\text{blocked}} \ge 3.0 \text{ s}$). State transitions to `HOLDING` then `HELD`. VFD output is disabled. An alarm event is logged to InfluxDB.

#### 5.2 Diverter Proximity Switch Failure
*   **Mechanism:** When Diverter 1 is commanded to extend, lock the simulated cylinder stroke at $0.05 \text{ m}$ (jammed mid-stroke) or intercept the signal so `LS1_Work` remains FALSE.
*   **Expected PLC Behavior:** PLC commands Diverter 1 to extend. The watchdog timer (0.8s) expires. PLC aborts the line, transitions state machine to `ABORTED` (or `HELD`), and flags a pneumatic fault alarm.

#### 5.3 Scanner Timeout / Bad Read
*   **Mechanism:** Simulate a dirty lens on Scanner 1. When package breaks `PE2`, return "NO READ" string.
*   **Expected PLC Behavior:** The PLC receives the "NO READ" string, bypasses sorting to Lane A or Lane B, sets `RouteTarget` = 9 (Reject), and verifies its routing to the Reject Lane via `PE6`.
