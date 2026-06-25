<# 
Build a TwinCAT solution through TcXaeShell DTE automation.

TwinCAT XAE exposes the reliable project build surface through a 32-bit COM
automation server. This script re-launches itself in 32-bit STA PowerShell when
needed, opens the solution, selects the requested TwinCAT configuration, builds,
and writes the Build/TwinCAT output panes to a log file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,

    [string]$Configuration = "Release",
    [string]$Platform = "TwinCAT RT (x64)",

    [string]$LogPath = ""
)

$ErrorActionPreference = "Stop"

if ([Environment]::Is64BitProcess) {
    $powerShell32 = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path -LiteralPath $powerShell32)) {
        throw "32-bit Windows PowerShell is required for TcXaeShell COM automation: $powerShell32"
    }

    $arguments = @(
        "-NoProfile",
        "-STA",
        "-ExecutionPolicy", "Bypass",
        "-File", $PSCommandPath,
        "-SolutionPath", $SolutionPath,
        "-Configuration", $Configuration,
        "-Platform", $Platform
    )

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $arguments += @("-LogPath", $LogPath)
    }

    & $powerShell32 @arguments
    exit $LASTEXITCODE
}

$resolvedSolution = Resolve-Path -LiteralPath $SolutionPath
$workspace = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $logDir = Join-Path $workspace "twincat\logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $LogPath = Join-Path $logDir "twincat_dte_build.txt"
}
else {
    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}

$openXae = @(Get-Process -Name "TcXaeShell" -ErrorAction SilentlyContinue)
if ($openXae.Count -gt 0) {
    $processIds = ($openXae.Id | Sort-Object) -join ", "
    throw "Close all interactive TwinCAT XAE Shell windows before automated build (running process IDs: $processIds)."
}

$messageFilterSource = @'
using System;
using System.Runtime.InteropServices;

[ComImport]
[Guid("00000016-0000-0000-C000-000000000046")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IOleMessageFilter
{
    [PreserveSig]
    int HandleInComingCall(int callType, IntPtr taskCaller, int tickCount, IntPtr interfaceInfo);

    [PreserveSig]
    int RetryRejectedCall(IntPtr taskCallee, int tickCount, int rejectType);

    [PreserveSig]
    int MessagePending(IntPtr taskCallee, int tickCount, int pendingType);
}

public sealed class OleMessageFilter : IOleMessageFilter
{
    [DllImport("ole32.dll")]
    private static extern int CoRegisterMessageFilter(
        IOleMessageFilter newFilter,
        out IOleMessageFilter oldFilter
    );

    public static void Register()
    {
        IOleMessageFilter oldFilter;
        CoRegisterMessageFilter(new OleMessageFilter(), out oldFilter);
    }

    public static void Revoke()
    {
        IOleMessageFilter oldFilter;
        CoRegisterMessageFilter(null, out oldFilter);
    }

    int IOleMessageFilter.HandleInComingCall(
        int callType,
        IntPtr taskCaller,
        int tickCount,
        IntPtr interfaceInfo
    )
    {
        return 0;
    }

    int IOleMessageFilter.RetryRejectedCall(
        IntPtr taskCallee,
        int tickCount,
        int rejectType
    )
    {
        return rejectType == 2 ? 250 : -1;
    }

    int IOleMessageFilter.MessagePending(
        IntPtr taskCallee,
        int tickCount,
        int pendingType
    )
    {
        return 2;
    }
}
'@

function Invoke-ComWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [int]$Attempts = 60,
        [int]$DelayMilliseconds = 500
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return & $Action
        }
        catch [System.Runtime.InteropServices.COMException] {
            $isBusy = $_.Exception.HResult -eq -2147418111 -or $_.Exception.HResult -eq -2147417846
            if (-not $isBusy -or $attempt -eq $Attempts) {
                throw
            }

            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }
}

$dte = $null
$messageFilterRegistered = $false
$transcriptStarted = $false
$scriptStartTime = Get-Date

try {
    Start-Transcript -LiteralPath $LogPath -Force
    $transcriptStarted = $true

    Write-Output "Registering COM message filter..."
    Add-Type -TypeDefinition $messageFilterSource -Language CSharp
    [OleMessageFilter]::Register()
    $messageFilterRegistered = $true

    Write-Output "Starting TcXaeShell DTE automation..."
    $dte = New-Object -ComObject "TcXaeShell.DTE.15.0"
    Start-Sleep -Seconds 15

    Write-Output "Configuring DTE session..."
    # Keep the solution-load phase visible. TwinCAT may show first-load PLC option
    # dialogs before DTE returns from Solution.Open; hiding UI turns those into hangs.
    Invoke-ComWithRetry { $dte.SuppressUI = $false }
    Invoke-ComWithRetry { $dte.MainWindow.Visible = $true }
    Invoke-ComWithRetry { $dte.MainWindow.Activate() } | Out-Null
    Write-Output "Opening solution: $($resolvedSolution.Path)"
    Invoke-ComWithRetry { $dte.Solution.Open($resolvedSolution.Path) }
    Start-Sleep -Seconds 5
    Invoke-ComWithRetry { $dte.SuppressUI = $true }
    Invoke-ComWithRetry { $dte.MainWindow.Visible = $false }

    $solutionFullName = Invoke-ComWithRetry { $dte.Solution.FullName }
    $projectCount = Invoke-ComWithRetry { $dte.Solution.Projects.Count }
    Write-Output "Solution: $solutionFullName"
    Write-Output "Projects: $projectCount"

    for ($index = 1; $index -le $projectCount; $index++) {
        $project = Invoke-ComWithRetry { $dte.Solution.Projects.Item($index) }
        Write-Output "Project[$index]: $($project.Name) | $($project.FullName)"
    }

    $build = Invoke-ComWithRetry { $dte.Solution.SolutionBuild }
    $configurationName = "$Configuration|$Platform"
    $activatedConfiguration = $false
    $configurationCandidates = @($Configuration, $configurationName) | Select-Object -Unique

    foreach ($candidateName in $configurationCandidates) {
        try {
            Invoke-ComWithRetry {
                $build.SolutionConfigurations.Item($candidateName).Activate()
            } | Out-Null
            $activatedConfiguration = $true
            Write-Output "Configuration: $candidateName"
            break
        }
        catch {
            if ($candidateName -eq $configurationCandidates[-1]) {
                $activeName = "<unknown>"
                try {
                    $activeName = Invoke-ComWithRetry { $build.ActiveConfiguration.Name }
                }
                catch {
                    $activeName = "<unavailable>"
                }

                Write-Warning "Unable to activate '$configurationName' through DTE: $($_.Exception.Message)"
                Write-Warning "Continuing with active TwinCAT solution configuration: $activeName"
            }
        }
    }

    Write-Output "Starting TwinCAT solution build..."
    Invoke-ComWithRetry { $build.Build($true) }
    Write-Output "LastBuildInfo: $($build.LastBuildInfo)"

    try {
        $errorItems = Invoke-ComWithRetry { $dte.ToolWindows.ErrorList.ErrorItems }
        $errorCount = Invoke-ComWithRetry { $errorItems.Count }
        Write-Output "=== Error List ($errorCount item(s)) ==="

        for ($index = 1; $index -le $errorCount; $index++) {
            try {
                $item = Invoke-ComWithRetry { $errorItems.Item($index) }
                $description = Invoke-ComWithRetry { $item.Description }
                $fileName = Invoke-ComWithRetry { $item.FileName }
                $line = Invoke-ComWithRetry { $item.Line }
                $column = Invoke-ComWithRetry { $item.Column }
                $project = Invoke-ComWithRetry { $item.Project }
                Write-Output "[$index] $project $fileName($line,$column): $description"
            }
            catch {
                Write-Warning "Unable to read error item $index`: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Warning "Unable to read Visual Studio Error List: $($_.Exception.Message)"
    }

    foreach ($pane in $dte.ToolWindows.OutputWindow.OutputWindowPanes) {
        try {
            $selection = $pane.TextDocument.Selection
            $selection.SelectAll()
            $paneText = $selection.Text
            Write-Output "=== Output: $($pane.Name) ==="
            if ([string]::IsNullOrWhiteSpace($paneText)) {
                Write-Output "<empty>"
            }
            else {
                Write-Output $paneText
            }
        }
        catch {
            Write-Warning "Unable to read output pane '$($pane.Name)': $($_.Exception.Message)"
        }
    }

    if ($build.LastBuildInfo -ne 0) {
        throw "TwinCAT build failed with $($build.LastBuildInfo) project error(s). See $LogPath"
    }
}
finally {
    if ($null -ne $dte) {
        try {
            Invoke-ComWithRetry { $dte.Quit() } | Out-Null
        }
        catch {
            Write-Warning "Unable to close TwinCAT XAE cleanly: $($_.Exception.Message)"
        }
    }

    if ($messageFilterRegistered) {
        [OleMessageFilter]::Revoke()
    }

    if ($transcriptStarted) {
        Stop-Transcript
    }

    $scriptStartWmi = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($scriptStartTime.AddSeconds(-5))
    $staleXae = @(Get-CimInstance Win32_Process -Filter "Name='TcXaeShell.exe' AND CreationDate >= '$scriptStartWmi'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*-Embedding*" })

    foreach ($process in $staleXae) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
            Write-Output "Stopped stale TwinCAT automation process $($process.ProcessId)."
        }
        catch {
            Write-Warning "Unable to stop stale TwinCAT automation process $($process.ProcessId): $($_.Exception.Message)"
        }
    }
}
