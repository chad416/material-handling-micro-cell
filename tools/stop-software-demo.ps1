<#
.SYNOPSIS
Stops processes started by tools/start-software-demo.ps1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ProcessFile = Join-Path $RepoRoot "runtime\demo\processes.json"

if (-not (Test-Path -LiteralPath $ProcessFile)) {
    Write-Host "No runtime/demo/processes.json file found. Nothing to stop."
    return
}

$processes = Get-Content -LiteralPath $ProcessFile -Raw | ConvertFrom-Json
if ($null -eq $processes) {
    Write-Host "No demo processes recorded."
    return
}

foreach ($entry in @($processes)) {
    $pidValue = [int]$entry.pid
    $name = [string]$entry.name
    $proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Stopping $name (PID $pidValue)."
        Stop-Process -Id $pidValue -Force
    }
    else {
        Write-Host "$name (PID $pidValue) is already stopped."
    }
}

Remove-Item -LiteralPath $ProcessFile -Force
Write-Host "MHMC software demo stack stopped."
