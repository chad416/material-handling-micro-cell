# SAT Protocol Template

## 1. Document Control

Mandatory:
- SAT document number, revision, author, approver, status, release date.
- Site, machine ID, installation date, software revision.

Guidance prompts:
- Which FAT report and punch list are prerequisites?

## 2. SAT Scope

Mandatory:
- Installed equipment.
- Site utilities.
- Safety devices.
- Field I/O and network connections.
- HMI/SCADA and historian services.

Guidance prompts:
- Which FAT tests must be repeated on site?
- Which tests require production product?

## 3. Site Prerequisites

Mandatory:
- Mechanical installation complete.
- Electrical inspection complete.
- Air pressure available.
- Network addressing approved.
- Safety validation procedure approved.
- Production-like test packages available.

Guidance prompts:
- Are lockout/tagout and safe test procedures in place?

## 4. Commissioning Tests

Mandatory:
- I/O point-to-point.
- Safety loop and E-stop.
- Conveyor direction and VFD scaling.
- Diverter home/work switches and solenoids.
- Scanner communication and read quality.
- OPC UA, historian, and Grafana connectivity.
- Recipe and HMI role tests.

| Test ID | Description | Expected Result | Evidence | Result |
| --- | --- | --- | --- | --- |
| SAT-001 | I/O point-to-point | Every field signal matches symbolic tag | I/O checklist | Open |
| SAT-002 | Conveyor/VFD | Correct direction, speed, stop behavior | Measurement/log | Open |
| SAT-003 | Diverter timing | Home/work/verify within limits | Timing record | Open |
| SAT-004 | Network dropout | Historian/OPC UA recover cleanly | Event log | Open |

## 5. Production Readiness Run

Mandatory:
- Minimum run duration.
- Product mix.
- Target throughput.
- Jam and reject count limits.
- Operator sign-off.

Guidance prompts:
- What is the allowed false reject rate?
- What proves the machine is ready for handover?

## 6. SAT Punch List and Handover

Mandatory:
- Open items.
- Owner and target date.
- Operational restrictions.
- Accepted residual risks.
- Training completed.

## 7. SAT Sign-Off

Mandatory:
- Site representative.
- Controls engineer.
- Maintenance lead.
- Operations lead.
- QA/customer witness.
