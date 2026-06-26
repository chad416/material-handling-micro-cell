# FAT Protocol Template

## 1. Document Control

Mandatory:
- FAT document number, revision, author, approver, status, release date.
- Machine ID, software revision, PLC project revision, HMI/SCADA revision.

Guidance prompts:
- Which software commit or tagged release is under test?

## 2. FAT Scope

Mandatory:
- Included equipment.
- Excluded equipment.
- Simulation assumptions.
- Required customer witness points.

Guidance prompts:
- Which tests are software-in-the-loop versus physical bench tests?

## 3. Prerequisites

Mandatory:
- Approved FDS.
- Compiled PLC project with zero errors.
- Current HMI tag list.
- OPC UA/historian configuration.
- TestHarness results.
- Safety test method approved.

Guidance prompts:
- Are all instruments calibrated or simulated with documented assumptions?

## 4. Test Case Format

Mandatory fields:
- Test ID.
- Requirement reference.
- Preconditions.
- Steps.
- Expected result.
- Actual result.
- Pass/fail.
- Evidence reference.
- Tester/date/witness.

## 5. FAT Test Matrix

| Test ID | Description | Requirement | Expected Result | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| FAT-001 | PLC compile | FDS control architecture | 0 errors, 0 warnings | Build screenshot/log | Open |
| FAT-002 | Auto Lane A route | Sequence of operations | Package verified on Lane A | TestHarness/FAT run | Open |
| FAT-003 | Jam recovery | Alarm/recovery requirement | Jam detected, held, reset, unhold | Event log | Open |
| FAT-004 | OPC UA namespace | SCADA interface | Semantic nodes readable | OPC UA client evidence | Open |
| FAT-005 | Historian/KPI | Data requirement | KPI and event records written | Influx/Grafana evidence | Open |

## 6. Deviations and Punch List

Mandatory:
- Deviation ID.
- Severity.
- Owner.
- Resolution plan.
- Retest requirement.

Guidance prompts:
- Can the machine ship with this deviation?
- What evidence is required for closure?

## 7. FAT Sign-Off

Mandatory:
- Controls lead.
- Software lead.
- QA/customer witness.
- Open punch list acceptance.
