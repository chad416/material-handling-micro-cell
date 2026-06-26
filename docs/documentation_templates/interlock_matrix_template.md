# Interlock Matrix Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- Machine ID and software revision.

Guidance prompts:
- Which FDS and safety documentation revisions define the interlocks?

## 2. Interlock Philosophy

Mandatory:
- Difference between permissive, inhibit, trip, warning, and alarm.
- Reset rules and latch rules.
- Bypass policy and authorization.

Guidance prompts:
- Which interlocks are safety-rated and outside normal PLC control?
- Which interlocks are process quality safeguards?

## 3. Interlock Matrix

Mandatory columns:
- Interlock ID.
- Equipment or function.
- Required condition.
- Source tag or device.
- Action on false/trip.
- Alarm/event generated.
- Reset condition.
- Bypass allowed: yes/no.
- Verification method.

| ID | Function | Required Condition | Source | Action | Alarm/Event | Reset Condition | Bypass | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| INT-001 | Cell start | Safety loop OK | `xSafetyLoopOK` | Block start/abort if lost | E-stop alarm | Safety restored and clear command | No | FAT/SAT safety check |
| INT-002 | Conveyor run | VFD ready and no fault | `xVfdReady`, `xVfdFault` | Stop conveyor | VFD fault alarm | VFD reset and PLC reset | No | Drive simulation and hardware test |

## 4. Mode-Specific Rules

Mandatory:
- Auto mode interlocks.
- Manual mode interlocks.
- Maintenance mode interlocks.
- Remote/SCADA command interlocks.

Guidance prompts:
- Which interlocks differ by mode?
- Which commands are blocked when a package is active?

## 5. Validation Evidence

Mandatory:
- Test reference, tester, date, result, evidence link.

Guidance prompts:
- Was each interlock tested in simulation, FAT, SAT, or all three?
- Were nuisance trips observed?
