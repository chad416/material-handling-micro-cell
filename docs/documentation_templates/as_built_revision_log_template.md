# As-Built Revision Log Template

## 1. Document Control

Mandatory:
- Log owner, machine ID, repository, current release, last updated date.

Guidance prompts:
- Which repository branch/tag represents the released as-built state?

## 2. Revision Table

Mandatory columns:
- Revision, date, change summary, reason, affected documents/files, software commit, approval, release status.

| Revision | Date | Change Summary | Reason | Affected Files | Commit | Approval | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AB-001 | YYYY-MM-DD | Initial as-built release | SAT complete | TBD | TBD | TBD | Draft |

## 3. Change Classification

Mandatory:
- Software logic.
- HMI/SCADA.
- PLC hardware/I/O.
- Network/security.
- Mechanical/pneumatic.
- Documentation only.

Guidance prompts:
- Does this change require FAT retest, SAT retest, or customer approval?

## 4. Required Attachments

Mandatory:
- PLC project archive or commit hash.
- HMI/SCADA export.
- OPC UA/historian configuration.
- Network drawing.
- I/O list.
- Alarm list.
- FAT/SAT closeout evidence.

## 5. Approval and Release

Mandatory:
- Controls approval.
- Software approval.
- Maintenance/operations acceptance.
- Customer/site acceptance when required.

Guidance prompts:
- Has the previous revision been archived and backed up?
