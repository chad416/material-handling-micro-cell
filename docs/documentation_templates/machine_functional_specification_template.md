# Machine Functional Specification Template

## 1. Document Control

Mandatory:
- Document number, revision, status, author, reviewer, approver, release date.
- Project name, machine ID, customer/site, and related contract or purchase order.

Guidance prompts:
- What baseline requirement, FDS, or customer URS does this specification satisfy?
- Which documents supersede or constrain this specification?

## 2. Machine Overview

Mandatory:
- Machine purpose and process boundary.
- Products handled, package size range, orientation assumptions, and reject criteria.
- Major equipment: conveyors, scanner, diverters, sensors, safety devices, PLC, HMI/SCADA.

Guidance prompts:
- What does the machine do, and what does it explicitly not do?
- Where are the physical infeed, discharge, reject, and operator interaction points?

## 3. Functional Requirements

Mandatory:
- Automatic mode functions.
- Manual mode functions.
- Maintenance mode functions and safeguards.
- Recipe/configuration behavior.
- Fault handling and recovery behavior.

Guidance prompts:
- What conditions must be true before the machine can start?
- What outputs are commanded during each mode?
- What behavior is required when a package is already present at startup?

## 4. Performance Requirements

Mandatory:
- Target throughput, maximum speed, nominal speed, and degraded mode behavior.
- Expected cycle times and diverter response times.
- Barcode read requirements and misread handling.
- Historian/KPI update period.

Guidance prompts:
- Which KPIs define acceptable performance?
- What tolerances apply to timing, speed, position, and verification sensors?

## 5. Control Architecture

Mandatory:
- PLC platform and task cycle.
- Structured Text modules and ownership.
- OPC UA, historian, HMI/SCADA, and Grafana interfaces.
- Symbolic tag and I/O mapping policy.

Guidance prompts:
- Which modules own each function?
- Which variables are exposed to HMI/SCADA and which remain internal?

## 6. States, Modes, and Commands

Mandatory:
- PackML states used.
- Operator commands and allowed state transitions.
- Manual and maintenance role restrictions.
- Reset, clear, hold, unhold, start, and stop behavior.

Guidance prompts:
- Which transitions are blocked by alarms or interlocks?
- Which commands are one-shot and which are maintained?

## 7. Alarms and Events

Mandatory:
- Alarm classes and severity model.
- Required alarms, event timeline fields, acknowledgement, reset, and historian behavior.
- Nuisance alarm prevention rules.

Guidance prompts:
- Which alarms latch?
- Which events are required for troubleshooting and production review?

## 8. Acceptance Criteria

Mandatory:
- FAT pass/fail criteria.
- SAT pass/fail criteria.
- Required evidence for compile, simulation, functional tests, network tests, and hardware tests.

Guidance prompts:
- What must be demonstrated before shipment?
- What must be repeated after installation?
