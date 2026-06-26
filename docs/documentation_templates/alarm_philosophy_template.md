# Alarm Philosophy Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- Machine ID and alarm list revision.

Guidance prompts:
- Which site alarm standard or ISA-18.2 guidance is applicable?

## 2. Alarm Objectives

Mandatory:
- Protect personnel and equipment.
- Preserve product quality.
- Support fast fault isolation.
- Avoid nuisance alarms.

Guidance prompts:
- Which conditions require operator action?
- Which events are informational only?

## 3. Alarm Classes and Severity

Mandatory:
- Severity bands and meaning.
- Warning, fault, abort, and safety alarm definitions.
- Color, sounder, and HMI presentation rules.

| Class | Severity Range | Operator Meaning | Audible | Example |
| --- | ---: | --- | --- | --- |
| Warning | 100-399 | Action may be needed soon | No | Jam warning |
| Fault | 700-899 | Process stopped or degraded | Yes | Jam, route fault |
| Abort/Safety | 900-1000 | Immediate safe state required | Yes | E-stop |

## 4. Alarm Lifecycle

Mandatory:
- Detection.
- Latching.
- Acknowledgement.
- Root-cause clear.
- Reset.
- Return to service.

Guidance prompts:
- Which alarms self-clear?
- Which alarms require acknowledgement and reset?

## 5. Required Alarm List

Mandatory columns:
- Alarm code, name, trigger condition, severity, state action, reset condition, HMI text, historian field.

| Code | Name | Trigger | Severity | Action | Reset | HMI Text | Historian |
| ---: | --- | --- | ---: | --- | --- | --- | --- |
| 100 | General jam | PE watchdog exceeded | 800 | Hold/quick stop | Sensors clear and ResetJam | Package jam detected | `alarms_events.general_jam_alarm` |
| 250 | Route fault | Verification or FIFO fault | 850 | Hold/stop routing | Reset after cause clear | Routing fault active | `alarms_events.active_code` |

## 6. Event Timeline Rules

Mandatory:
- Required event fields.
- Event classes.
- Minimum event retention.
- Historian publication requirements.

Guidance prompts:
- Which command, recipe, recovery, and KPI events must be retained?

## 7. Alarm Testing

Mandatory:
- FAT and SAT test references.
- False alarm and missed alarm acceptance criteria.

Guidance prompts:
- How will each alarm be forced safely during FAT and SAT?
