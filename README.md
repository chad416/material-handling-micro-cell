# Material Handling Micro Cell Automation Project

This directory contains the automation engineering package for the material handling micro cell, including:
- **Functional Design Specification (FDS)**
- **OPC UA Namespace Design**
- **PLC Logic (ST)**
- **Digital Twin Simulation (Python)**
- **SCADA Configuration (InfluxDB & Grafana)**
- **Semantic OPC UA Server (`opcua_server`)**
- **Buffered Historian & KPI Query Service (`historian_service`)**
- **Engineering Templates & Checklists**

## OPC UA Server
The semantic OPC UA server exposes `MHMC_Cell` with structured device, PackML
state, KPI, alarm, maintenance, recipe, and event timeline nodes.  Generate
certificates before production use:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.generate_cert --hostname localhost
```

Then run:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.server --certificate opcua_server\certs\mhmc-server.der --private-key opcua_server\certs\mhmc-server-key.pem
```

## Historian and KPI Service
The historian service collects semantic OPC UA telemetry, buffers InfluxDB line
protocol writes, computes KPI rollups, and exposes a Grafana-friendly JSON API.
Credentials are supplied through environment variables such as
`MHMC_INFLUX_TOKEN` and `MHMC_QUERY_API_TOKEN`; no production secret belongs in
the repository.

## Getting Started
To view and work on this project in your IDE:
1. Open your editor/IDE.
2. Select **Open Folder** and navigate to this workspace:
   `C:\Users\chand\.gemini\antigravity\scratch\material_handling_cell`
