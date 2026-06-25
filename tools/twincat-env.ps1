# TwinCAT command-line environment helper for this workspace.
# Dot-source this script before invoking TwinCAT/XAE build commands:
#   . .\tools\twincat-env.ps1
#
# It does not modify the global Windows PATH. It only updates the current shell.

$ErrorActionPreference = "Stop"

$TwinCATXaeShellCandidates = @(
    "C:\Program Files (x86)\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe",
    "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe"
)

$TwinCATMSBuildCandidates = @(
    "C:\Program Files (x86)\Beckhoff\TcXaeShell\MSBuild\15.0\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Beckhoff\TcXaeShell\MSBuild\15.0\Bin\amd64\MSBuild.exe",
    "C:\Program Files\Beckhoff\TcXaeShell\MSBuild\15.0\Bin\MSBuild.exe"
)

$script:TwinCATXaeShell = $TwinCATXaeShellCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$script:TwinCATMSBuild = $TwinCATMSBuildCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $script:TwinCATXaeShell) {
    throw "TwinCAT XAE Shell was not found in the known install locations."
}

if (-not $script:TwinCATMSBuild) {
    throw "TwinCAT-bundled MSBuild was not found in the known install locations."
}

$env:TWINCAT_XAE_SHELL = $script:TwinCATXaeShell
$env:TWINCAT_MSBUILD = $script:TwinCATMSBuild

$pathsToAdd = @(
    (Split-Path -Parent $script:TwinCATXaeShell),
    (Split-Path -Parent $script:TwinCATMSBuild)
) | Select-Object -Unique

foreach ($pathToAdd in $pathsToAdd) {
    if ($env:PATH -notlike "*$pathToAdd*") {
        $env:PATH = "$pathToAdd;$env:PATH"
    }
}

function Get-TwinCATToolchain {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        XaeShell = $env:TWINCAT_XAE_SHELL
        MSBuild  = $env:TWINCAT_MSBUILD
        PathReady = $true
    }
}

function Invoke-TwinCATBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,

        [string]$Configuration = "Release",
        [string]$Platform = "TwinCAT RT (x64)"
    )

    if (-not (Test-Path -LiteralPath $SolutionPath)) {
        throw "Solution path does not exist: $SolutionPath"
    }

    $dteBuilder = Join-Path $PSScriptRoot "build-twincat-dte.ps1"
    if (-not (Test-Path -LiteralPath $dteBuilder)) {
        throw "TwinCAT DTE build helper was not found: $dteBuilder"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $dteBuilder `
        -SolutionPath $SolutionPath `
        -Configuration $Configuration `
        -Platform $Platform

    if ($LASTEXITCODE -ne 0) {
        throw "TwinCAT DTE build failed with exit code $LASTEXITCODE."
    }
}
