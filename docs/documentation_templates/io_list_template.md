# I/O List Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- Machine ID, panel ID, PLC hardware revision, and network revision.

Guidance prompts:
- Which electrical drawings and PLC symbol export are the source of truth?

## 2. I/O Naming Standard

Mandatory:
- Tag prefix rules.
- Device naming convention.
- Signal direction and data type convention.
- Fail-safe state convention.

Guidance prompts:
- Are physical I/O addresses intentionally excluded from software source?
- Which system owns final address assignment?

## 3. Discrete Inputs

Mandatory columns:
- Tag name.
- Device.
- Description.
- Type.
- Normal state.
- Fail state.
- PLC symbol.
- Fieldbus address or terminal.
- Drawing reference.
- Commissioning status.

| Tag | Device | Description | Type | Normal | Fail State | PLC Symbol | Address | Drawing | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `xPE1_Infeed` | PE1 | Infeed package detected | DI | False | False | `Main.xPE1_Infeed` | TBD | TBD | Open |
| `xDivLaneA_HomeSensor` | LS1 Home | Diverter 1 retracted | DI | True | False | `Main.xDivLaneA_HomeSensor` | TBD | TBD | Open |

## 4. Discrete Outputs

Mandatory columns:
- Tag name, device, description, type, energized state, safe state, PLC symbol, fieldbus address, drawing reference, status.

Guidance prompts:
- Which outputs must de-energize on E-stop, hold, or abort?
- Which outputs are pulse driven?

## 5. Analog and Numeric Signals

Mandatory:
- Speed setpoints, speed feedback, current feedback, scanner data, counters, and diagnostics.

Guidance prompts:
- What scaling applies between engineering units and raw fieldbus values?
- What range checks are enforced?

## 6. OPC UA and Historian Tags

Mandatory:
- Node ID, data type, access level, source ST variable, historian measurement.

Guidance prompts:
- Which tags are commands and which are read-only?
- Which tags are sampled, event-driven, or both?

## 7. Commissioning Checklist

Mandatory:
- Point-to-point check.
- Force/prove direction.
- Fail-state verification.
- Sign-off initials and date.
