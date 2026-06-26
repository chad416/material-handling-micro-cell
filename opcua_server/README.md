# MHMC OPC UA Server

This package implements the semantic OPC UA namespace for the Material Handling
Micro Cell.  It exposes the cell as a structured model rather than raw PLC tags:

- `MHMC_Cell.DeviceSet` for conveyor, scanner, and diverters.
- `MHMC_Cell.ControlState` for PackML mode/state and heartbeat.
- `MHMC_Cell.KPIs` for throughput, jams, and OEE factors.
- `MHMC_Cell.Alarms` and `MHMC_Cell.EventTimeline` for alarm state and event records.
- `MHMC_Cell.Maintenance` and `MHMC_Cell.Recipes` for guarded commands.

## Security

Production operation should use `Basic256Sha256` with `SignAndEncrypt`.
Generate a server certificate and private key:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.generate_cert --hostname localhost
```

Run the server with the secure endpoint:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.server `
  --certificate opcua_server\certs\mhmc-server.der `
  --private-key opcua_server\certs\mhmc-server-key.pem
```

For local-only SIL testing without certificates:

```powershell
C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m opcua_server.server --allow-insecure
```

Do not use `--allow-insecure` on a plant network.

## PLC Integration

The semantic-to-PLC contract is in `opcua_server/model.py`.  Every node carries a
`plc_symbol`, for example:

- `ControlState.CurrentState` -> `Main.fbStationController.stOut.ePackMLState`
- `KPIs.OEE` -> `Main.rOEEPercentage`
- `Alarms.GeneralJamAlarm` -> `Main.fbAlarmManager.stOut.xGeneralJamAlarm`
- `Recipes.TargetSpeed` -> `Main.rRecipeSpeed_mps`

The runtime uses `CellDataProvider` as the adapter boundary.  The included
`InMemoryCellDataProvider` supports local tests and digital twin bring-up.  A
TwinCAT deployment should implement the same protocol using ADS, a fieldbus
gateway, or deterministic shared memory.

## Subscription Support

SCADA clients subscribe to semantic variables directly.  The server only writes
changed values, so OPC UA data-change subscriptions receive meaningful updates
without polling raw tag blocks.  Alarm/event notifications are mirrored through
the `EventTimeline.*` variables and emitted as best-effort OPC UA events when
the installed `asyncua` runtime supports event generation.
