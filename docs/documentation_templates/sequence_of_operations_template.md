# Sequence of Operations Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- Machine ID and related functional specification revision.

Guidance prompts:
- Which software revision and PLC project does this sequence describe?

## 2. Operating Modes

Mandatory:
- Auto mode.
- Manual mode.
- Maintenance mode.
- Faulted/held/recovery behavior.

Guidance prompts:
- What is the operator allowed to do in each mode?
- Which actions require maintenance role or key switch?

## 3. Startup Sequence

Mandatory:
- Safety, air, VFD, diverter home, scanner, OPC UA, historian, and recipe checks.
- Reset sequence and transition to idle.
- Start command and transition to execute.

Guidance prompts:
- What happens if a package is already present at startup?
- What diagnostic is generated if a permissive is missing?

## 4. Automatic Sorting Sequence

Mandatory:
- PE1 package registration.
- Conveyor speed command and feedback.
- PE2 scanner trigger and barcode validation.
- Route selection: Lane A, Lane B, reject.
- Diverter fire windows and verification sensors.
- KPI counter update and event logging.

Guidance prompts:
- What position or time window is used for each action?
- Which failures are route faults versus jams?

## 5. Jam Detection and Recovery

Mandatory:
- Jam detection sensors and thresholds.
- Warning behavior before full jam alarm.
- Hold/quick stop action.
- Reset conditions.
- Unhold and return-to-execute sequence.

Guidance prompts:
- Which sensors must clear before reset is accepted?
- What evidence proves the recovery sequence completed?

## 6. Manual and Maintenance Sequences

Mandatory:
- Conveyor jog behavior and speed limits.
- Manual scanner trigger.
- Diverter hold-to-run controls.
- Maintenance safeguards.
- Abuse prevention behavior.

Guidance prompts:
- What commands are inhibited in Auto?
- What timeout protects a manual diverter hold?

## 7. Stop, Hold, Abort, and Power Loss

Mandatory:
- Normal stop.
- Hold/unhold.
- E-stop or safety loop loss.
- Power loss and restart assumptions.

Guidance prompts:
- Which outputs de-energize immediately?
- Which data should persist across restart?

## 8. Sequence Verification

Mandatory:
- Test cases, expected state transitions, alarm behavior, and KPI outcomes.
- Reference to FAT/SAT procedure and TestHarness scenario IDs.

Guidance prompts:
- Which sequence steps are simulated?
- Which steps require real hardware observation?
