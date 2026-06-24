# Commissioning Checklist
## Material Handling Micro Cell (MHMC-01)
**Project Ref:** PX-MHMC-01  
**Commissioning Phase:** Cold & Hot Commissioning  
**Author:** Lead Automation Engineer (MIT Graduate)  

---

### 1. Pre-Commissioning Safety & Mechanical Checks
Before applying electrical or pneumatic power to the cell, verify the following conditions:

| Ref | Item Description | Verification Standard | Status (P/F) | Checked By | Date |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **S-01** | Structural & Frame Mounting | Frame is level and securely bolted to the floor. Conveyor bed is aligned. | | | |
| **S-02** | Guard Doors & RFID Interlocks | Enclosure panels are rigid; RFID safety switches match alignment criteria ($< 5\text{mm}$ gap). | | | |
| **S-03** | Pneumatic Service Unit (FRL) | Filter-Regulator-Lubricator is securely mounted. Main shutoff slide valve is accessible. | | | |
| **S-04** | E-Stop Buttons | Physical buttons check out (twist-to-release functions cleanly). | | | |
| **S-05** | Wiring & Conduit Routing | Cable trays are covered. High-voltage (400V VFD) and low-voltage (24VDC control) lines are separated. | | | |

---

### 2. Electrical & I/O Verification (Cold Checks)
Isolate mains power. Use a digital multimeter (DMM) to verify voltage levels and loop integrity.

| Ref | Signal Name | Device Tag | Test Description | Target Value | Measured | P/F |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **IO-01**| E-Stop Safety Loop | `ES_Loop_OK` | Measure resistance between terminal blocks TB1-1 and TB1-2 (E-Stops released). | $< 2.0\ \Omega$ | | |
| **IO-02**| Control Power | `24VDC_Bus` | Verify output voltage of primary DC power supply. | $24.0 \pm 0.5\text{ VDC}$ | | |
| **IO-03**| Conveyor Infeed PE | `PE1` | Break beam. Verify LED indicator on sensor and PLC input card transitions. | 0VDC to 24VDC | | |
| **IO-04**| Scanner Trigger PE | `PE2` | Break beam. Verify LED indicator and PLC input card. | 0VDC to 24VDC | | |
| **IO-05**| Diverter 1 Home LS | `LS1_Home` | Verify proximity switch status when cylinder is retracted. | 24VDC | | |
| **IO-06**| Diverter 1 Work LS | `LS1_Work` | Verify proximity switch status when cylinder is extended. | 0VDC (unextended)| | |
| **IO-07**| Diverter 1 Solenoid | `SOL1` | Actuate solenoid manually from valve manifold. Verify cylinder stroke extends. | Direct mechanical extension | | |
| **IO-08**| Diverter 2 Home LS | `LS2_Home` | Verify proximity switch status when cylinder is retracted. | 24VDC | | |
| **IO-09**| Diverter 2 Work LS | `LS2_Work` | Verify proximity switch status when cylinder is extended. | 0VDC (unextended)| | |
| **IO-10**| Diverter 2 Solenoid | `SOL2` | Actuate solenoid manually from valve manifold. Verify cylinder stroke extends. | Direct mechanical extension | | |

---

### 3. Network & Communications Verification (Hot Checks)
Apply network power. Validate connectivity across the system architecture.

| Ref | Node / Device | Protocol | Configured IP Address | Ping Latency | Communication Status (Online/Offline) |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **NC-01**| PLC CPU | EtherNet/IP | `192.168.1.10 / 24` | | |
| **NC-02**| Conveyor VFD | PROFINET | `192.168.1.20 / 24` | | |
| **NC-03**| Barcode Scanner 1 | Modbus TCP | `192.168.1.30 / 24` | | |
| **NC-04**| HMI Panel | Modbus TCP | `192.168.1.40 / 24` | | |
| **NC-05**| OPC UA Server Gateway | OPC UA | `192.168.1.10:4840` | | |

---

### 4. Calibration & Dynamic Checks
Configure conveyor speed setpoints and calibrate sensor/actuator timings.

| Ref | Procedure | Test Method | Expected Target | Measured | P/F |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **CD-01**| Conveyor Velocity Calibration | Command VFD speed setpoint to $0.5\text{ m/s}$. Measure actual package speed using a tachometer or stopwatch over a 2m track. | $0.50 \pm 0.02\text{ m/s}$ | | |
| **CD-02**| Diverter Extension Time | Trigger Diverter 1. Measure delay between solenoid output `SOL1` transitioning and limit switch `LS1_Work` closing. | $\le 0.45\text{ seconds}$ | | |
| **CD-03**| Scanner Read Verification | Pass 10 sample test envelopes with standard 2D barcode `*LANE-A*` past scanner. Verify output string received. | 10/10 successful reads | | |

---

### 5. Commissioning Sign-Off
We, the undersigned, certify that the commissioning checklist has been completed successfully according to the specifications above.

**Lead Commissioning Engineer:**  
*Name:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Signature:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Date:* \_\_\_\_\_\_\_\_\_\_\_\_

**Customer Representative:**  
*Name:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Signature:* \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ *Date:* \_\_\_\_\_\_\_\_\_\_\_\_
