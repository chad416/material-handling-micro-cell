# Network Topology Architecture
## Material Handling Micro Cell (MHMC-01)
**Document Ref:** DS-MHMC-NET-003  
**Version:** 1.0.0  
**Author:** Lead Automation Engineer (MIT Graduate)  
**Date:** June 24, 2026  

---

### 1. Topology Overview
The network architecture for the MHMC-01 is designed according to the Purdue Enterprise Reference Architecture (PERA), ensuring strict segmentation between the industrial control plane (OT) and the supervisory/telemetry plane (IT). The system integrates the physical cell components, the Station Controller (PLC), SCADA/Historian backend, and the Digital Twin simulator.

---

### 2. Network Layers & Protocols

#### 2.1 Field & Control Level (Level 0 & 1)
*   **Network Medium:** Industrial Ethernet (Copper/Fiber) arranged in a ring or star topology.
*   **Protocol:** PROFINET RT/IRT (or EtherCAT).
*   **Components:**
    *   **Station Controller (PLC):** Acts as the PROFINET IO Controller (Master).
    *   **Conveyor VFD:** PROFINET IO Device controlling the main drive.
    *   **Remote I/O Block:** PROFINET IO Device aggregating signals from Photoelectric sensors (PE1-PE6) and Diverter limit switches.
    *   **Pneumatic Valve Manifold:** PROFINET IO Device actuating Diverter 1 and 2 solenoids.
*   **Vision Checkpoint:** The Vision Barcode Scanner operates over a dedicated subnet using Modbus TCP to transmit string payloads to the PLC, preventing high-bandwidth image data from interfering with deterministic I/O traffic.

#### 2.2 Supervisory & Edge Level (Level 2)
*   **Network Medium:** Standard Ethernet (TCP/IP).
*   **Protocol:** OPC UA (TCP, Port 4840).
*   **Components:**
    *   **OPC UA Server (Embedded in PLC):** Exposes the information model (`ns=2`) defined in the OPC UA Namespace Design.
    *   **Digital Twin Simulator (SIL Mode):** A Python-based edge node. In a physical deployment, the Twin connects as an OPC UA client to mirror state and validate physics. During pure Software-in-the-Loop simulation, this node *hosts* the OPC UA Server, entirely replacing the physical Level 0/1 stack.

#### 2.3 SCADA & Historian Level (Level 3)
*   **Network Medium:** Standard Ethernet (TCP/IP).
*   **Protocols:** OPC UA (Subscriptions), HTTPS, Line Protocol.
*   **Components:**
    *   **Telegraf Collector:** Subscribes to the PLC's OPC UA namespace at 100ms intervals.
    *   **InfluxDB:** Time-Series Database receiving Line Protocol over HTTPS (Port 8086).
    *   **Grafana HMI:** Visualizes data via Flux queries and provides the Line Supervisor interface.

---

### 3. Architecture Diagram

```mermaid
graph TD
    %% Define Styles
    classDef control fill:#f9d0c4,stroke:#e74c3c,stroke-width:2px,color:#000
    classDef field fill:#d5f5e3,stroke:#27ae60,stroke-width:2px,color:#000
    classDef it fill:#d4e6f1,stroke:#2980b9,stroke-width:2px,color:#000
    classDef twin fill:#e8daef,stroke:#8e44ad,stroke-width:2px,color:#000
    classDef boundary stroke:#333,stroke-dasharray: 5 5,fill:none

    %% Layer 3: SCADA / IT
    subgraph Level3 ["Level 3: Supervisory Control & Data Acquisition (IT/OT Demilitarized Zone)"]
        HMI["Grafana HMI &<br/>Line Supervisor"]
        InfluxDB[("InfluxDB<br/>Time-Series Historian")]
        Telegraf["Telegraf<br/>Metrics Collector"]
        
        Telegraf -->|Line Protocol (HTTPS 8086)| InfluxDB
        HMI -->|Flux Queries| InfluxDB
    end

    %% Layer 2: Edge & Simulation
    subgraph Level2 ["Level 2: Edge & Simulation Layer"]
        Twin["Digital Twin Simulator<br/>(Python SIL Model)"]
    end

    %% Layer 1: Control
    subgraph Level1 ["Level 1: Control Layer"]
        PLC["Station Controller (PLC)<br/>OPC UA Server (Port 4840)"]
    end

    %% Layer 0: Field
    subgraph Level0 ["Level 0: Field Layer (Physical Cell)"]
        VFD["Conveyor VFD"]
        IO["Remote I/O Block"]
        Valve["Valve Manifold"]
        Scanner["Vision Scanner"]
        
        Sensors(("PE Sensors &<br/>Limit Switches"))
        Actuators(("Pneumatic Cylinders<br/>(Diverters)"))
        
        IO --- Sensors
        Valve --- Actuators
    end

    %% Networking Links
    %% IT/OT Bridge
    HMI <==>|OPC UA TCP<br/>(RPC Methods & Overrides)| PLC
    Telegraf <==>|OPC UA Subscription<br/>(100ms Polling)| PLC
    
    %% Twin Link
    Twin <==>|OPC UA Sync<br/>(State Mirroring / 50ms Tick)| PLC

    %% Fieldbus Links
    PLC <==>|PROFINET / EtherCAT<br/>(Deterministic RT/IRT)| VFD
    PLC <==>|PROFINET / EtherCAT| IO
    PLC <==>|PROFINET / EtherCAT| Valve
    PLC <==>|Modbus TCP| Scanner

    %% Apply Classes
    class HMI,InfluxDB,Telegraf it;
    class Twin twin;
    class PLC control;
    class VFD,IO,Valve,Scanner,Sensors,Actuators field;
```

---

### 4. Integration Considerations & Quality Assertions
1. **Determinism:** The separation of the PROFINET fieldbus from the OPC UA telemetry network ensures that high-frequency SCADA polling (100ms) or Digital Twin synchronizations do not introduce jitter into the PackML Station Controller's critical state execution loop.
2. **Security & Access Control:** 
    - The PLC's OPC UA server acts as the boundary between IT and OT.
    - Write access (e.g., `SpeedSetpoint`, `CommandExtend`) and RPC Methods (`StartCell`, `StopCell`) are authenticated, strictly limiting control to the authorized Line Supervisor service or Digital Twin simulation.
3. **Software-in-the-Loop Transition:** During deployment and commissioning, the `Digital Twin Simulator` seamlessly hot-swaps with the physical `Level 0/1` architecture. Because the Twin perfectly mirrors the OPC UA namespace (`ns=2`), the SCADA system, Telegraf collectors, and Grafana dashboards require zero reconfiguration between simulation and production.
