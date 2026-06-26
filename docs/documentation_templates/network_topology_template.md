# Network Topology Template

## 1. Document Control

Mandatory:
- Document number, revision, author, approver, status, release date.
- Network drawing reference and cybersecurity owner.

Guidance prompts:
- Which network topology drawing is the source of truth?

## 2. Network Overview

Mandatory:
- Control network.
- Supervisory/SCADA network.
- Historian/database network.
- Engineering access path.
- Remote access policy.

Guidance prompts:
- Which devices are on isolated industrial networks?
- Which services are allowed to cross zones?

## 3. Device Inventory

Mandatory columns:
- Device name, role, vendor/model, IP address, subnet, protocol, port, owner, backup requirement.

| Device | Role | IP/Subnet | Protocols | Ports | Owner | Backup |
| --- | --- | --- | --- | --- | --- | --- |
| PLC | Control | TBD | EtherCAT/OPC UA | TBD | Controls | Project archive |
| OPC UA server | Semantic data server | TBD | OPC UA | 4840 | Software | Config and certs |

## 4. Protocol Matrix

Mandatory:
- Source, destination, protocol, port, direction, authentication, encryption, purpose.

Guidance prompts:
- Are OPC UA secure endpoints used in production?
- Which credentials are stored outside the repository?

## 5. Time Synchronisation

Mandatory:
- NTP/PTP source.
- Device time-zone policy.
- Historian timestamp authority.

Guidance prompts:
- Are PLC, OPC UA server, InfluxDB, and Grafana using consistent time?

## 6. Security and Access Control

Mandatory:
- Firewall rules.
- Certificate management.
- User roles.
- Password/token handling.
- Backup and restore.

Guidance prompts:
- Which default credentials must be changed before production?
- How are OPC UA certificates issued and rotated?

## 7. Diagnostics and Monitoring

Mandatory:
- Heartbeats.
- Watchdogs.
- Network dropout alarms.
- Packet loss/latency checks.

Guidance prompts:
- What test proves the system recovers after network loss?
