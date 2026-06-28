<#
.SYNOPSIS
Starts the MHMC software-only demo stack.

.DESCRIPTION
Starts secure OPC UA, historian collector, query API, HMI prototype, and
visual digital twin static servers. Generated logs and process IDs are written
under runtime/demo/ so the stack can be stopped repeatably.
#>
[CmdletBinding()]
param(
    [string]$Python = $env:MHMC_PYTHON,
    [switch]$UseLocalDevDefaults,
    [switch]$InsecureOpcUa,
    [switch]$SkipHistorian,
    [switch]$SkipQueryApi,
    [switch]$OpenBrowser,
    [int]$OpcUaPort = 4840,
    [int]$QueryApiPort = 8091,
    [int]$HmiPrototypePort = 8092,
    [int]$VisualTwinPort = 8093,
    [string]$GrafanaUrl = "http://localhost:3000/d/mhmc-kpi-events/mhmc-01-kpi-and-event-dashboard"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeRoot = Join-Path $RepoRoot "runtime\demo"
$LogRoot = Join-Path $RuntimeRoot "logs"
$ProcessFile = Join-Path $RuntimeRoot "processes.json"

function Repair-PathEnvironment {
    # Some Windows shells can inherit both PATH and Path. PowerShell/.NET then
    # throws when Start-Process builds the child environment. Keep the canonical
    # Windows Path key and remove the duplicate process-scope PATH key.
    $pathValue = [System.Environment]::GetEnvironmentVariable("Path", "Process")
    if (-not $pathValue) {
        $pathValue = [System.Environment]::GetEnvironmentVariable("PATH", "Process")
    }
    if ($pathValue) {
        [System.Environment]::SetEnvironmentVariable("PATH", $null, "Process")
        [System.Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
    }
}

function Resolve-Python {
    param([string]$Requested)
    if ($Requested -and (Test-Path -LiteralPath $Requested)) {
        return (Resolve-Path -LiteralPath $Requested).Path
    }

    $bundled = "C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path -LiteralPath $bundled) {
        return $bundled
    }

    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    throw "Python was not found. Pass -Python <path> or set MHMC_PYTHON."
}

function Test-TcpPort {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(250, $false)) {
            return $false
        }
        $client.EndConnect($iar)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Wait-TcpPort {
    param(
        [int]$Port,
        [System.Diagnostics.Process]$Process,
        [string]$Name,
        [string]$ErrorLog,
        [int]$TimeoutMs = 8000
    )

    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPort -Port $Port) {
            return
        }
        if ($Process.HasExited) {
            $tail = ""
            if (Test-Path -LiteralPath $ErrorLog) {
                $tail = (Get-Content -LiteralPath $ErrorLog -Tail 20) -join "`n"
            }
            throw "$Name exited before port $Port opened. Check $ErrorLog.`n$tail"
        }
        Start-Sleep -Milliseconds 200
    }

    throw "$Name did not open port $Port within $TimeoutMs ms. Check $ErrorLog."
}

function Start-DemoProcess {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [int]$Port = 0
    )

    if ($Port -gt 0 -and (Test-TcpPort -Port $Port)) {
        Write-Host "$Name already appears to be listening on port $Port; not starting a duplicate."
        return $null
    }

    $stdout = Join-Path $LogRoot "$Name.out.log"
    $stderr = Join-Path $LogRoot "$Name.err.log"
    $process = Start-Process -FilePath $script:PythonExe `
        -ArgumentList $Arguments `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -WindowStyle Hidden `
        -PassThru

    Write-Host "Started $Name (PID $($process.Id))."
    if ($Port -gt 0) {
        Wait-TcpPort -Port $Port -Process $process -Name $Name -ErrorLog $stderr
    }
    return [pscustomobject]@{
        name = $Name
        pid = $process.Id
        port = $Port
        started_utc = (Get-Date).ToUniversalTime().ToString("o")
        stdout = $stdout
        stderr = $stderr
    }
}

Repair-PathEnvironment
New-Item -ItemType Directory -Force -Path $RuntimeRoot, $LogRoot | Out-Null
$script:PythonExe = Resolve-Python -Requested $Python
Write-Host "Using Python: $script:PythonExe"

if ($UseLocalDevDefaults) {
    if (-not $env:MHMC_INFLUX_URL) { $env:MHMC_INFLUX_URL = "http://localhost:8086" }
    if (-not $env:MHMC_INFLUX_ORG) { $env:MHMC_INFLUX_ORG = "AntigravityAutomation" }
    if (-not $env:MHMC_INFLUX_BUCKET) { $env:MHMC_INFLUX_BUCKET = "mhmc_telemetry" }
    if (-not $env:MHMC_INFLUX_TOKEN) { $env:MHMC_INFLUX_TOKEN = "mhmc-dev-token-change-me" }
    if (-not $env:MHMC_QUERY_API_TOKEN) { $env:MHMC_QUERY_API_TOKEN = "mhmc-query-token" }
}

$endpoint = "opc.tcp://127.0.0.1:$OpcUaPort/mhmc/server/"
$env:MHMC_OPCUA_ENDPOINT = $endpoint
$env:MHMC_QUERY_API_PORT = [string]$QueryApiPort

$certPath = Join-Path $RepoRoot "opcua_server\certs\mhmc-server.der"
$keyPath = Join-Path $RepoRoot "opcua_server\certs\mhmc-server-key.pem"
if (-not $InsecureOpcUa) {
    if (-not (Test-Path -LiteralPath $certPath) -or -not (Test-Path -LiteralPath $keyPath)) {
        & $script:PythonExe -m opcua_server.generate_cert --hostname 127.0.0.1 | Write-Host
    }
    $env:MHMC_OPCUA_SECURITY_POLICY = "Basic256Sha256"
    $env:MHMC_OPCUA_SECURITY_MODE = "SignAndEncrypt"
    $env:MHMC_OPCUA_CLIENT_CERT = $certPath
    $env:MHMC_OPCUA_CLIENT_KEY = $keyPath
}
else {
    $env:MHMC_OPCUA_SECURITY_POLICY = "None"
    $env:MHMC_OPCUA_SECURITY_MODE = "None"
    $env:MHMC_OPCUA_CLIENT_CERT = ""
    $env:MHMC_OPCUA_CLIENT_KEY = ""
}

$started = @()
$queryApiStarted = $false
$opcArgs = @("-m", "opcua_server.server", "--endpoint", $endpoint)
if ($InsecureOpcUa) {
    $opcArgs += "--allow-insecure"
}
else {
    $opcArgs += @("--certificate", $certPath, "--private-key", $keyPath)
}
$process = Start-DemoProcess -Name "opcua-server" -Arguments $opcArgs -Port $OpcUaPort
if ($process) { $started += $process }

Start-Sleep -Milliseconds 900

$canUseInflux = -not [string]::IsNullOrWhiteSpace($env:MHMC_INFLUX_TOKEN)
if (-not $canUseInflux -and (-not $SkipHistorian -or -not $SkipQueryApi)) {
    Write-Warning "MHMC_INFLUX_TOKEN is not set. Historian and query API will be skipped unless -UseLocalDevDefaults is used."
}

if (-not $SkipHistorian -and $canUseInflux) {
    $process = Start-DemoProcess -Name "historian-collector" -Arguments @("-m", "historian_service.collector") -Port 0
    if ($process) { $started += $process }
}

if (-not $SkipQueryApi -and $canUseInflux -and -not [string]::IsNullOrWhiteSpace($env:MHMC_QUERY_API_TOKEN)) {
    $process = Start-DemoProcess -Name "query-api" -Arguments @("-m", "historian_service.query_api") -Port $QueryApiPort
    if ($process) { $started += $process }
    $queryApiStarted = $true
}

$process = Start-DemoProcess -Name "hmi-prototype" -Arguments @("-m", "http.server", [string]$HmiPrototypePort, "--bind", "127.0.0.1", "--directory", (Join-Path $RepoRoot "scada-prototype")) -Port $HmiPrototypePort
if ($process) { $started += $process }

$process = Start-DemoProcess -Name "visual-twin" -Arguments @("-m", "http.server", [string]$VisualTwinPort, "--bind", "127.0.0.1", "--directory", (Join-Path $RepoRoot "digital_twin\visual_demo")) -Port $VisualTwinPort
if ($process) { $started += $process }

$started | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ProcessFile -Encoding UTF8

$urls = @(
    "HMI prototype:       http://127.0.0.1:$HmiPrototypePort/",
    "Visual digital twin: http://127.0.0.1:$VisualTwinPort/"
)
if ($queryApiStarted -or (Test-TcpPort -Port $QueryApiPort)) {
    $urls += "Historian preview:   http://127.0.0.1:$QueryApiPort/preview"
}
if (Test-TcpPort -Port 3000) {
    $urls += "Grafana dashboard:   $GrafanaUrl"
}

Write-Host ""
Write-Host "MHMC software demo stack is ready."
$urls | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Stop it with: powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\stop-software-demo.ps1"
Write-Host "Logs: $LogRoot"

if ($OpenBrowser) {
    Start-Process "http://127.0.0.1:$VisualTwinPort/"
    Start-Process "http://127.0.0.1:$HmiPrototypePort/"
    if (-not $SkipQueryApi -and $canUseInflux) {
        Start-Process "http://127.0.0.1:$QueryApiPort/preview"
    }
}
