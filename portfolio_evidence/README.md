# MHMC Portfolio Evidence Pack

Use this folder to produce repeatable software-side portfolio evidence for
MHMC-01.

Create a fresh pack from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\new-portfolio-evidence-pack.ps1
```

After starting the software demo stack, include runtime logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\new-portfolio-evidence-pack.ps1 -IncludeRuntimeLogs
```

Generated packs are written to `portfolio_evidence/generated/` and are ignored
by Git because they are timestamped release artifacts. Each generated pack
contains validation reports, key engineering documents, and a screenshot capture
slot checklist for TwinCAT, OPC UA, HMI, visual twin, Grafana, historian preview,
and TestHarness evidence.
