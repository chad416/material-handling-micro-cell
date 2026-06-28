<#
.SYNOPSIS
Runs the MHMC software-polish validation gate.
#>
[CmdletBinding()]
param(
    [string]$Python = $env:MHMC_PYTHON
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not $Python) {
    $bundled = "C:\Users\chand\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path -LiteralPath $bundled) {
        $Python = $bundled
    }
    else {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) {
            throw "Python was not found. Pass -Python <path> or set MHMC_PYTHON."
        }
        $Python = $cmd.Source
    }
}

Push-Location $RepoRoot
try {
    & $Python -B validation\run_software_polish_checks.py
    if ($LASTEXITCODE -ne 0) {
        throw "Software polish validation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
