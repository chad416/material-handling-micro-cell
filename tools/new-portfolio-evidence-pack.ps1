<#
.SYNOPSIS
Creates a reproducible portfolio evidence pack for MHMC-01.

.DESCRIPTION
Copies software validation reports, key docs, and demo instructions into a
timestamped folder under portfolio_evidence/generated/. GUI screenshots are
kept as explicit capture slots so they can be collected consistently during a
live walkthrough.
#>
[CmdletBinding()]
param(
    [string]$Name = ("mhmc-software-evidence-" + (Get-Date -Format "yyyyMMdd-HHmmss")),
    [switch]$IncludeRuntimeLogs
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PackRoot = Join-Path $RepoRoot ("portfolio_evidence\generated\" + $Name)
$ReportsRoot = Join-Path $PackRoot "reports"
$DocsRoot = Join-Path $PackRoot "docs"
$ScreenshotsRoot = Join-Path $PackRoot "screenshots"
$LogsRoot = Join-Path $PackRoot "runtime-logs"

New-Item -ItemType Directory -Force -Path $PackRoot, $ReportsRoot, $DocsRoot, $ScreenshotsRoot | Out-Null

$reportFiles = @(
    "validation\results\validation-report.md",
    "validation\results\test-harness-report.md",
    "validation\results\twincat-manual-build-evidence.md",
    "validation\results\opcua-historian-test-report.md",
    "validation\results\software-polish-report.md"
)

foreach ($relative in $reportFiles) {
    $source = Join-Path $RepoRoot $relative
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $ReportsRoot -Force
    }
}

$docFiles = @(
    "README.md",
    "docs\final_report.md",
    "docs\portfolio_demo_narrative.md",
    "docs\hmi_scada_interface_spec.md",
    "docs\hmi_scada_tag_list.md",
    "docs\opc_ua_namespace_design.md",
    "docs\simulation_plan_digital_twin.md"
)

foreach ($relative in $docFiles) {
    $source = Join-Path $RepoRoot $relative
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $DocsRoot -Force
    }
}

if ($IncludeRuntimeLogs) {
    $runtimeLogs = Join-Path $RepoRoot "runtime\demo\logs"
    if (Test-Path -LiteralPath $runtimeLogs) {
        New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null
        Copy-Item -LiteralPath (Join-Path $runtimeLogs "*") -Destination $LogsRoot -Force
    }
}

$screenshotReadme = @'
# Screenshot Capture Slots

Save screenshots here with these exact names during the portfolio recording:

1. `01-twincat-rebuild-success.png` - TwinCAT XAE Shell with 0 errors / 0 warnings.
2. `02-opcua-semantic-namespace.png` - OPC UA browser showing MHMC_Cell nodes.
3. `03-hmi-overview.png` - HMI prototype overview screen.
4. `04-visual-digital-twin.png` - Visual twin running a package scenario.
5. `05-grafana-kpi-dashboard.png` - Grafana KPI/event dashboard.
6. `06-historian-preview.png` - Query API historian preview page.
7. `07-test-harness-report.png` - TestHarness PASS summary.

These screenshots are software evidence. Physical machine footage belongs in a
future hardware commissioning evidence pack.
'@
$screenshotReadme | Set-Content -LiteralPath (Join-Path $ScreenshotsRoot "README.md") -Encoding UTF8

$indexLines = @(
    "# MHMC-01 Software Portfolio Evidence Pack",
    "",
    ("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")),
    "",
    "## Contents",
    "",
    "- ``reports/`` - validation, TestHarness, TwinCAT, OPC UA/historian, and polish reports.",
    "- ``docs/`` - README, final report, demo narrative, HMI/SCADA tag and namespace docs.",
    "- ``screenshots/`` - screenshot capture slots for the live software walkthrough."
)
if ($IncludeRuntimeLogs) {
    $indexLines += "- ``runtime-logs/`` - logs copied from the latest software demo run."
}
$indexLines += @(
    "",
    "## Software Completion Boundary",
    "",
    "The software-side package includes PLC logic, SIL TestHarness, semantic OPC UA,",
    "historian/KPI service, HMI prototype, visual digital twin, Grafana assets,",
    "validation reports, and portfolio demo narrative.",
    "",
    "The only remaining items for full production release are hardware tasks:",
    "physical I/O mapping, safety validation, VFD/pneumatic/scanner commissioning,",
    "real package matrix tests, signed FAT/SAT, and as-built release.",
    "",
    "## Demo Commands",
    "",
    "Start the software stack:",
    "",
    "``````powershell",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\start-software-demo.ps1 -UseLocalDevDefaults -OpenBrowser",
    "``````",
    "",
    "Stop the software stack:",
    "",
    "``````powershell",
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\stop-software-demo.ps1",
    "``````"
)
$index = $indexLines -join [Environment]::NewLine
$index | Set-Content -LiteralPath (Join-Path $PackRoot "index.md") -Encoding UTF8

Write-Host "Created evidence pack: $PackRoot"
