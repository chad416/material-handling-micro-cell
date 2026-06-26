# MHMC SCADA Prototype

This is a dependency-free HMI/SCADA mockup for the Material Handling Micro Cell.
It renders the overview, station control, diverter control, and alarm list using
mock tags from `docs/hmi_scada_tag_list.md`.

Open `index.html` directly in a browser. No build step is required.

The prototype is intentionally not a production HMI runtime. It is a screen and
tag-binding demonstrator that can later be connected to the OPC UA query API or
a proper HMI framework.
