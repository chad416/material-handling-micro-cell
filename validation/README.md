# MHMC PLC Validation

Run the validation harness from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1
```

For fast source and deterministic FAT checks without the vendor compiler gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1 -SkipTwinCATBuild
```

To reuse a just-completed TwinCAT build transcript and `.tmc` without launching
XAE automation again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1 -UseExistingTwinCATBuildEvidence
```

The harness writes evidence to `validation/results/`:

- `validation-summary.json`
- `validation-report.md`
- `test-harness-results.json`
- `test-harness-report.md`

Run the TestHarness scenario matrix directly:

```powershell
python -B .\validation\run_test_harness.py
```

Scope boundary: this does not replace physical commissioning. Real I/O mapping,
E-stop checks, pneumatic timing, VFD behavior, scanner communication, OPC UA
collector connectivity, and signed FAT/SAT still require the actual cell.
