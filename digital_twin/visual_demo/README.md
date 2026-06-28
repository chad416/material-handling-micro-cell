# MHMC Visual Digital Twin Demo

This dependency-free browser demo gives the portfolio a visual twin layer
without requiring hardware. It animates package flow through the conveyor,
scanner, diverters, reject lane, alarms, and KPI tiles using the same semantic
concepts exposed by the PLC, OPC UA server, historian, and HMI/SCADA assets.

Run it directly from the repository root:

```powershell
python -m http.server 8093 --bind 127.0.0.1 --directory digital_twin\visual_demo
```

Open:

```text
http://127.0.0.1:8093/
```

The demo is intentionally local and deterministic. It is for portfolio
walkthroughs, design reviews, and software-side validation storytelling. It
does not replace physical commissioning.
