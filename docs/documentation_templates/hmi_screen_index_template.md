# HMI Screen Index Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- HMI/SCADA software revision and tag list revision.

Guidance prompts:
- Which screens are implemented, simulated, or future scope?

## 2. User Roles

Mandatory:
- Operator.
- Maintenance.
- Engineer/admin.
- Read-only observer.

Guidance prompts:
- Which commands require elevated role?
- Which screens are view-only for operators?

## 3. Navigation Flow

Mandatory:
- Home/overview entry point.
- Screen links.
- Alarm navigation.
- Recipe and maintenance access rules.

Guidance prompts:
- Can an operator recover a jam without leaving the overview?
- How does an alarm link to the affected device screen?

## 4. Screen Index

Mandatory columns:
- Screen ID, screen name, purpose, primary users, commands, key tags, alarm links, notes.

| ID | Screen | Purpose | Users | Commands | Key Tags | Alarm Links | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HMI-001 | Overview | Cell status and start/stop | Operator | Start, stop, acknowledge | `HMI_Cell_State`, `KPI_Throughput_Total` | Any active alarm | First screen |
| HMI-002 | Station Control | Conveyor and scanner status | Operator, maintenance | Jog, scanner trigger | `HMI_Conveyor1_Running`, `HMI_Scanner1_LastBarcode` | VFD/scanner faults | Role gated |

## 5. Screen Detail Template

Mandatory:
- Objective.
- User role access.
- Status indicators.
- Commands.
- Alarms/events.
- KPI widgets.
- Validation notes.

Guidance prompts:
- Which tags drive each visible object?
- What feedback confirms a command was accepted?

## 6. HMI Acceptance Criteria

Mandatory:
- Command confirmation.
- Alarm visibility.
- Navigation behavior.
- Role restriction tests.
- Tag mapping verification.
