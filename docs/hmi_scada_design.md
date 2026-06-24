# HMI/SCADA Design Specification
## Material Handling Micro Cell (MHMC-01)
**Document Ref:** DS-MHMC-SCADA-004  
**Version:** 1.0.0  
**Author:** Lead Automation Engineer (MIT Graduate)  
**Date:** June 24, 2026  

---

### 1. SCADA Architecture & Data Pipeline
The supervisory control system for the MHMC-01 cell utilizes a modern open-architecture telemetry stack. Rather than proprietary SCADA runtime packages, this design implements an industrial time-series logging pipeline optimized for sub-second analysis, OEE tracking, and predictive maintenance.

```
+--------------------+            +-------------------+            +--------------------+
|  OPC UA Server     |  OPC UA    |  Telegraf Agent   |  Line      | InfluxDB           |
| (PLC/Digital Twin) | =========> | (Collector Node)  | =========> | (Time-Series DB)   |
| (Port 4840)        |            | (Polling: 100ms)  | Protocol   | (Port 8086)        |
+--------------------+            +-------------------+            +--------------------+
                                                                             |
                                                                             | Flux Query
                                                                             v
                                                                   +--------------------+
                                                                   | Grafana Dashboards |
                                                                   | (Visual SCADA Client)
                                                                   | (Port 3000)        |
                                                                   +--------------------+
```

-   **Collector (Telegraf):** An open-source collector agent configured with the `inputs.opcua` plugin. It connects to the PLC/Digital Twin OPC UA server, subscribes to variables on change or polls at 100ms intervals, and forwards data to the database.
-   **Database (InfluxDB v2):** A high-performance time-series database. Sensor state changes, throughput ticks, VFD currents, and alarm states are persisted with nanosecond-resolution timestamps.
-   **Visualization (Grafana):** A web-based analytical visualization dashboard. Grafana displays live cell status overlays, OEE gauges, historical line charts, and active/historical alarm tables.

---

### 2. InfluxDB Time-Series Schema Design
To ensure high query speeds and low storage footprints, data is structured into specialized measurements, indexing static dimensions as **tags** and varying telemetry as **fields**.

#### 2.1 Measurement: `conveyor_telemetry`
Logs physical operating conditions of the main line.
*   **Tags:**
    *   `device_id` (e.g., `conveyor_1`)
    *   `vfd_model` (e.g., `sinamics_g120`)
*   **Fields:**
    *   `speed_setpoint` (Double, m/s)
    *   `speed_feedback` (Double, m/s)
    *   `motor_current` (Double, Amperes)
    *   `is_running` (Boolean)
    *   `pe1_blocked` (Boolean)
    *   `pe2_blocked` (Boolean)
    *   `pe3_blocked` (Boolean)

#### 2.2 Measurement: `diverter_telemetry`
Logs cylinder action sequences and feedback verification.
*   **Tags:**
    *   `diverter_id` (e.g., `diverter_1`, `diverter_2`)
*   **Fields:**
    *   `is_home` (Boolean)
    *   `is_work` (Boolean)
    *   `command_extend` (Boolean)
    *   `divert_verified` (Boolean)
    *   `actuation_time_ms` (Integer)

#### 2.3 Measurement: `sorting_events`
Logs discrete event tracking records whenever a package completes inspection.
*   **Tags:**
    *   `scanner_id` (e.g., `scanner_1`)
    *   `assigned_lane` (e.g., `Lane_A`, `Lane_B`, `Reject`)
    *   `read_status` (e.g., `Success`, `No_Read`, `Mismatch`)
*   **Fields:**
    *   `barcode` (String)
    *   `package_uid` (Integer)
    *   `transit_duration_sec` (Double, time between PE1 and exit)

#### 2.4 Measurement: `cell_kpis`
Logs cyclic aggregates for performance metrics.
*   **Tags:**
    *   `cell_id` (e.g., `mhmc_01`)
*   **Fields:**
    *   `throughput_total` (Integer)
    *   `throughput_lane_a` (Integer)
    *   `throughput_lane_b` (Integer)
    *   `throughput_reject` (Integer)
    *   `jam_count` (Integer)
    *   `availability_pct` (Double)
    *   `performance_pct` (Double)
    *   `quality_pct` (Double)
    *   `oee_pct` (Double)

#### 2.5 Measurement: `alarms_events`
Logs discrete state changes for system faults.
*   **Tags:**
    *   `alarm_name` (e.g., `GeneralJamAlarm`, `Diverter1Fault`, `EStopTripped`)
    *   `severity` (e.g., `Low`, `Medium`, `High`, `Critical`)
*   **Fields:**
    *   `message` (String)
    *   `is_active` (Boolean)  // TRUE on activation, FALSE on clear
    *   `acknowledged` (Boolean)

---

### 3. HMI Screen Layout & Wireframes
The visualization screens utilize high-contrast layouts conforming to **ISA-101 (Human-Machine Interfaces for Process Automation Systems)** guidelines to minimize operator fatigue and improve response times.

#### 3.1 Screen 1: Dashboard Overview (Executive/Operator view)
```
+---------------------------------------------------------------------------------+
| MHMC-01 | MODE: AUTO | STATE: EXECUTE | HEARTBEAT: [OK] | 2026-06-24 13:30:00   |
+---------------------------------------------------------------------------------+
|                                                                                 |
|   +-------------------+   +-----------------------+   +---------------------+   |
|   |    OEE FEEDBACK   |   |   PRODUCTION COUNTS   |   |  ACTIVE ALARMS      |   |
|   |      +-----+      |   | Total: 1,420 pkgs     |   | [CRITICAL]          |   |
|   |     /  88%  \     |   | Lane A:  820 pkgs     |   | - E-Stop Tripped    |   |
|   |    +---------+    |   | Lane B:  480 pkgs     |   |   (2026-06-24 13:02)|   |
|   |   OEE Indicator   |   | Reject:  120 pkgs     |   |                     |   |
|   +-------------------+   +-----------------------+   +---------------------+   |
|                                                                                 |
|   +-------------------------------------------------------------------------+   |
|   |                      LIVE PACKML STATE TIMELINE                         |   |
|   | [Stopped]======[Resetting]======[Idle]======[Starting]======[EXECUTE]   |   |
|   +-------------------------------------------------------------------------+   |
+---------------------------------------------------------------------------------+
```

#### 3.2 Screen 2: Live Cell Control (Manual/Maintenance view)
*Provides tools to jog motors, test actuators, and load recipes.*
*   **Conveyor controls:** Slider for `SpeedSetpoint` (0.0 to 1.0 m/s), Start/Stop buttons.
*   **Actuator overrides:** Toggle buttons for `CommandExtend` (Diverter 1 and 2), displaying limit switch indicator lights (Green = Home, Amber = Work, Red = Fault).
*   **Recipe Selector:** Drop-down menu containing pre-loaded configurations (e.g., "Standard Boxes", "Envelopes", "High Speed Sorting") with a "Load Recipe" button triggering the OPC UA RPC method.

#### 3.3 Screen 3: Maintenance & Diagnostics (Engineering view)
*Displays low-level sensor signals, diagnostic timers, and communication statistics.*
*   **Photoelectric Sensor Matrix:** Real-time indicator grids showing `PE1` through `PE6` status (Green = Clear, Red = Blocked).
*   **Jam Timers:** Dynamic bars displaying the current elapsed time of each PE sensor block against its jam limit.
*   **VFD Performance:** Line charts showing Motor Current (A) and Speed (m/s) to track mechanical wear (such as belt slippage or bearing wear).
*   **Comms Status:** Diagnostic stats for the Scanner (ping latency, retry counts) and the OPC UA Server (active sessions, read/write latency).

#### 3.4 Screen 4: Alarm History & Analysis (Quality view)
*Presents historical trends and root-cause analysis metrics.*
*   **Historical Alarm Table:** Filterable grid with timestamp, alarm name, severity, message, active time, and duration.
*   **Pareto Chart:** Visual breakdown showing which jam scenarios or sensor faults are responsible for the highest downtime.
*   **Throughput vs. Jams Time-Series:** Dual-axis chart comparing throughput rates against active alarm counts to isolate bottleneck intervals.

---

### 4. Graphic Design & Aesthetics Guidelines
To deliver a premium interface, the Grafana dashboards and HMI interfaces will comply with these style rules:

-   **Color Palette (Dark Theme):**
    *   *Background:* `#0C0F12` (Deep Charcoal Black)
    *   *Card/Panel Background:* `#161920` (Sleek Obsidian)
    *   *Accents/Primary:* `#00ADB5` (Vibrant Cyan)
    *   *Success/State Execute:* `#393E46` & `#4ECCA3` (Teal/Emerald Green)
    *   *Warnings (Holding/Suspended):* `#FF9F43` (Amber Orange)
    *   *Alarms (Faulted/Aborted):* `#FF4D4D` (Cherry Red)
-   **Typography:** Montserrat or Inter (Google Fonts) loaded via custom CSS. Default browser monospaced fonts for numerical counters (throughput, speeds).
-   **Layout Grid:** 12-column responsive grid layout. Main indicators (OEE, Status, counts) positioned on the upper third of the canvas (following the Gutenberg diagram for reading gravity).
-   **Micro-Animations:** Pulsing glow rings around active/fault indicators, and smooth state transition indicators to enhance visual telemetry mapping.
