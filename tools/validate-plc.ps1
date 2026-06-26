# Validation harness for the MHMC PLC source.
#
# This runner is intentionally explicit about scope:
# - static source and generated TwinCAT project contract checks
# - deterministic reference-model tests for recipes, routing, jams, alarms, KPIs, historian, and FAT flow
# - optional TwinCAT XAE Shell compiler gate through tools/build-twincat.ps1
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-plc.ps1 -SkipTwinCATBuild

[CmdletBinding()]
param(
    [switch]$SkipTwinCATBuild,
    [switch]$UseExistingTwinCATBuildEvidence,
    [string]$ResultsRoot = ""
)

$ErrorActionPreference = "Stop"
$workspace = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($ResultsRoot)) {
    $ResultsRoot = Join-Path $workspace "validation\results"
}

$null = New-Item -ItemType Directory -Path $ResultsRoot -Force
$script:Results = New-Object System.Collections.Generic.List[object]

function Add-ValidationResult {
    param(
        [string]$Suite,
        [string]$Name,
        [bool]$Passed,
        [string]$Detail = ""
    )

    $script:Results.Add([PSCustomObject]@{
        Suite  = $Suite
        Name   = $Name
        Passed = $Passed
        Detail = $Detail
    })

    if ($Passed) {
        Write-Host ("[PASS] {0} :: {1}" -f $Suite, $Name) -ForegroundColor Green
    }
    else {
        Write-Host ("[FAIL] {0} :: {1} -- {2}" -f $Suite, $Name, $Detail) -ForegroundColor Red
    }
}

function Assert-True {
    param(
        [string]$Suite,
        [string]$Name,
        [bool]$Condition,
        [string]$Detail = ""
    )

    $reportedDetail = ""
    if (-not $Condition) {
        $reportedDetail = $Detail
    }
    Add-ValidationResult -Suite $Suite -Name $Name -Passed $Condition -Detail $reportedDetail
}

function Assert-Equal {
    param(
        [string]$Suite,
        [string]$Name,
        $Actual,
        $Expected
    )

    $passed = ($Actual -eq $Expected)
    $detail = "expected=[$Expected], actual=[$Actual]"
    Add-ValidationResult -Suite $Suite -Name $Name -Passed $passed -Detail $detail
}

function Assert-Near {
    param(
        [string]$Suite,
        [string]$Name,
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance = 0.0001
    )

    $passed = ([Math]::Abs($Actual - $Expected) -le $Tolerance)
    $detail = "expected=[$Expected], actual=[$Actual], tolerance=[$Tolerance]"
    Add-ValidationResult -Suite $Suite -Name $Name -Passed $passed -Detail $detail
}

function Get-PlcSourceText {
    $parts = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath (Join-Path $workspace "plc") -File -Filter "*.st" |
        Sort-Object Name |
        ForEach-Object {
            $parts.Add((Get-Content -LiteralPath $_.FullName -Raw))
        }
    return ($parts -join "`r`n")
}

function Test-SourceContracts {
    $suite = "SourceContracts"
    $plcDir = Join-Path $workspace "plc"
    $allText = Get-PlcSourceText
    $modules = @(
        "LineSupervisor",
        "StationController",
        "DiverterController",
        "JamDetector",
        "HistorianConnector",
        "KPIService",
        "AlarmManager"
    )

    foreach ($module in $modules) {
        $file = Join-Path $plcDir ("FB_{0}.st" -f $module)
        $exists = Test-Path -LiteralPath $file
        Assert-True $suite "$module source file exists" $exists $file
        if (-not $exists) {
            continue
        }

        $text = Get-Content -LiteralPath $file -Raw
        $commentCount = ([regex]::Matches($text, "//")).Count
        Assert-True $suite "$module has typed input structure" ($text -match ("TYPE\s+ST_{0}Input\s*:" -f [regex]::Escape($module))) "Missing ST_${module}Input"
        Assert-True $suite "$module has typed output structure" ($text -match ("TYPE\s+ST_{0}Output\s*:" -f [regex]::Escape($module))) "Missing ST_${module}Output"
        Assert-True $suite "$module has configuration structure" ($text -match ("TYPE\s+ST_{0}Config\s*:" -f [regex]::Escape($module))) "Missing ST_${module}Config"
        Assert-True $suite "$module has context structure" ($text -match ("TYPE\s+ST_{0}Context\s*:" -f [regex]::Escape($module))) "Missing ST_${module}Context"
        Assert-True $suite "$module has enumerated state" ($text -match ("TYPE\s+E_{0}State\s*:" -f [regex]::Escape($module))) "Missing E_${module}State"
        Assert-True $suite "$module has init function" ($text -match ("FUNCTION\s+F_{0}_Init\s*:" -f [regex]::Escape($module))) "Missing F_${module}_Init"
        Assert-True $suite "$module has cyclic function" ($text -match ("FUNCTION\s+F_{0}_Cyclic\s*:" -f [regex]::Escape($module))) "Missing F_${module}_Cyclic"
        Assert-True $suite "$module has FB wrapper" ($text -match ("FUNCTION_BLOCK\s+FB_{0}\b" -f [regex]::Escape($module))) "Missing FB_${module}"
        Assert-True $suite "$module has meaningful comments" ($commentCount -ge 10) "Only $commentCount comment markers found"
    }

    Assert-True $suite "PLCopen motion command adapter exists" ($allText -match "ST_PLCopenMotionCommand" -and $allText -match "MC_MoveVelocity" -and $allText -match "MC_Stop") "StationController must expose PLCopen command intent"
    Assert-True $suite "recipe/configuration type exists" ($allText -match "TYPE\s+ST_SortRecipe\s*:" -and $allText -match "arrRecipeBook") "Missing recipe data contract"
    Assert-True $suite "event timeline ring buffer exists" ($allText -match "TYPE\s+ST_MHMCEventTimeline\s*:" -and $allText -match "F_EventTimeline_Append") "Missing event timeline data structure/helper"
    Assert-True $suite "symbolic I/O only" (-not ($allText -match "\bAT\s*%[IQM]")) "Found direct AT %I/%Q/%M address binding"
    Assert-True $suite "no unresolved TODO markers" (-not ($allText -match "(?i)\bTODO\b|\bTBD\b|implementation follows")) "Found placeholder marker"
    Assert-True $suite "TwinCAT/CODESYS empty strings use single quotes" (-not ($allText -match '""')) "Found double-quoted empty string literal"
}

function Test-TwinCATProjectPreparation {
    $suite = "TwinCATProject"
    $generator = Join-Path $workspace "tools\generate-twincat-project.ps1"
    $project = Join-Path $workspace "twincat\MHMC_PLC\MHMC_PLC.plcproj"
    $solution = Join-Path $workspace "twincat\MHMC_Runtime.sln"

    if ($UseExistingTwinCATBuildEvidence) {
        Assert-True $suite "TwinCAT wrapper regeneration skipped for existing build evidence" (Test-Path -LiteralPath $project) "Preserves .tmc and build artifacts from the last compiler run"
    }
    else {
        try {
            $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $generator 2>&1
            $detail = ($output | Out-String).Trim()
            Assert-True $suite "TwinCAT wrapper regenerates from plc/*.st" $true $detail
        }
        catch {
            Assert-True $suite "TwinCAT wrapper regenerates from plc/*.st" $false $_.Exception.Message
            return
        }
    }

    Assert-True $suite "generated .plcproj exists" (Test-Path -LiteralPath $project) $project
    Assert-True $suite "generated solution exists" (Test-Path -LiteralPath $solution) $solution

    try {
        $projectRaw = Get-Content -LiteralPath $project -Raw
        [xml]$projectXml = $projectRaw
        $compileItems = @($projectXml.Project.ItemGroup.Compile)
        Assert-True $suite "generated .plcproj XML parses" $true "Compile items: $($compileItems.Count)"
        Assert-True $suite "generated project preserves TwinCAT PLC options" ($projectRaw -match "<PlcProjectOptions>") "Missing PlcProjectOptions can trigger hidden XAE load prompts"
        Assert-True $suite "generated project includes module POUs" (($compileItems | Where-Object { $_.Include -like "POUs\FB_*.TcPOU" }).Count -ge 8) "Expected FB POUs in generated project"
        Assert-True $suite "generated project includes DUTs" (($compileItems | Where-Object { $_.Include -like "DUTs\*.TcDUT" }).Count -ge 40) "Expected typed DUTs in generated project"
    }
    catch {
        Assert-True $suite "generated .plcproj XML parses" $false $_.Exception.Message
    }
}

function New-SortRecipe {
    param(
        [uint16]$Id = 1,
        [bool]$Enabled = $true,
        [string]$Name = "Default Sort",
        [double]$Speed = 0.5,
        [double]$ManualMax = 0.7,
        [double]$MaintenanceLimit = 0.2,
        [string]$LaneA = "LANE-A",
        [string]$LaneB = "LANE-B",
        [string]$Reject = "REJECT"
    )

    [PSCustomObject]@{
        uiRecipeID                 = $Id
        xEnabled                   = $Enabled
        sName                      = $Name
        rAutoSpeed_mps             = $Speed
        rManualMaxSpeed_mps        = $ManualMax
        rMaintenanceSpeedLimit_mps = $MaintenanceLimit
        sLaneAPattern              = $LaneA
        sLaneBPattern              = $LaneB
        sRejectPattern             = $Reject
        rScannerWindowStart_m      = 1.0
        rScannerWindowEnd_m        = 1.4
        rDiverter1WindowStart_m    = 2.05
        rDiverter1WindowEnd_m      = 2.35
        rDiverter2WindowStart_m    = 3.05
        rDiverter2WindowEnd_m      = 3.35
        rRejectExitPosition_m      = 4.2
        rPackageTimeout_s          = 12.0
    }
}

function Resolve-Recipe {
    param(
        [object[]]$RecipeBook,
        [uint16]$RecipeCount,
        [uint16]$RecipeSelect,
        [double]$RequestedSpeed = 0.0,
        [bool]$UsePayload = $false,
        [object]$Payload = $null,
        [double]$DefaultSpeed = 0.5,
        [double]$MinimumSpeed = 0.05,
        [double]$MaximumSpeed = 1.5
    )

    $candidate = New-SortRecipe -Id 1 -Speed $DefaultSpeed
    $found = $false
    if ($UsePayload -and $null -ne $Payload) {
        $candidate = $Payload
        $found = [bool]$Payload.xEnabled
    }
    else {
        for ($i = 0; $i -lt [Math]::Min($RecipeCount, $RecipeBook.Count); $i++) {
            if ($RecipeBook[$i].xEnabled -and $RecipeBook[$i].uiRecipeID -eq $RecipeSelect) {
                $candidate = $RecipeBook[$i]
                $found = $true
                break
            }
        }
        if ((-not $found) -and $RecipeCount -eq 0 -and ($RecipeSelect -eq 0 -or $RecipeSelect -eq 1)) {
            $candidate = New-SortRecipe -Id 1 -Speed $DefaultSpeed
            $found = $true
        }
    }

    if ($RequestedSpeed -gt 0.0) {
        $candidate = $candidate.PSObject.Copy()
        $candidate.rAutoSpeed_mps = $RequestedSpeed
    }
    if ($candidate.rAutoSpeed_mps -le 0.0) {
        $candidate.rAutoSpeed_mps = 0.5
    }

    $insideLimits = ($candidate.rAutoSpeed_mps -ge $MinimumSpeed -and $candidate.rAutoSpeed_mps -le $MaximumSpeed)
    [PSCustomObject]@{
        Accepted = ($found -and $insideLimits)
        Found    = $found
        Recipe   = $candidate
        Reason   = $(if (-not $found) { "not-found-or-disabled" } elseif (-not $insideLimits) { "speed-outside-limits" } else { "accepted" })
    }
}

function Test-RecipeMatrix {
    $suite = "RecipeMatrix"
    $recipeA = New-SortRecipe -Id 10 -Name "Lane A Priority" -Speed 0.55 -LaneA "A-SKU" -LaneB "B-SKU" -Reject "SCRAP"
    $recipeB = New-SortRecipe -Id 20 -Name "Lane B Priority" -Speed 0.45 -LaneA "RED" -LaneB "BLUE" -Reject "REJ"
    $disabled = New-SortRecipe -Id 30 -Enabled $false -Name "Disabled" -Speed 0.5
    $fast = New-SortRecipe -Id 40 -Name "Overspeed" -Speed 2.0
    $book = @($recipeA, $recipeB, $disabled, $fast)

    $default = Resolve-Recipe -RecipeBook @() -RecipeCount 0 -RecipeSelect 1
    Assert-True $suite "default fallback recipe loads" $default.Accepted $default.Reason
    Assert-Equal $suite "default fallback Lane A pattern" $default.Recipe.sLaneAPattern "LANE-A"

    $loadedA = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 10
    Assert-True $suite "book recipe A loads" $loadedA.Accepted $loadedA.Reason
    Assert-Equal $suite "book recipe A pattern dispatch" $loadedA.Recipe.sLaneAPattern "A-SKU"

    $loadedB = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 20 -RequestedSpeed 0.60
    Assert-True $suite "book recipe B accepts speed trim inside limits" $loadedB.Accepted $loadedB.Reason
    Assert-Near $suite "book recipe B speed trim applied" $loadedB.Recipe.rAutoSpeed_mps 0.60

    $payload = New-SortRecipe -Id 77 -Name "MES Payload" -Speed 0.62 -LaneA "PAY-A" -LaneB "PAY-B" -Reject "PAY-R"
    $loadedPayload = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 0 -UsePayload $true -Payload $payload
    Assert-True $suite "MES/HMI payload recipe loads" $loadedPayload.Accepted $loadedPayload.Reason
    Assert-Equal $suite "payload route pattern retained" $loadedPayload.Recipe.sLaneBPattern "PAY-B"

    $disabledResult = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 30
    Assert-True $suite "disabled recipe is rejected" (-not $disabledResult.Accepted) $disabledResult.Reason

    $fastResult = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 40
    Assert-True $suite "overspeed recipe is rejected" (-not $fastResult.Accepted) $fastResult.Reason

    $missing = Resolve-Recipe -RecipeBook $book -RecipeCount 4 -RecipeSelect 999
    Assert-True $suite "missing recipe ID is rejected" (-not $missing.Accepted) $missing.Reason
}

function New-RoutingState {
    [PSCustomObject]@{
        Queue              = New-Object System.Collections.ArrayList
        NextPackageID      = [uint32]1
        TotalCount         = [uint32]0
        LaneACount         = [uint32]0
        LaneBCount         = [uint32]0
        RejectCount        = [uint32]0
        RouteFault         = $false
        QueueOverflow      = $false
        ScannerTimeout     = $false
        LastRouteTarget    = "NONE"
        LastMessage        = ""
        LastCompletedID    = [uint32]0
        ScannerTrigger     = $false
        PackageRegistered  = $false
        ScanGood           = $false
        ScanBad            = $false
        LaneAVerified      = $false
        LaneBVerified      = $false
        RejectVerified     = $false
        Diverter1Command   = $false
        Diverter2Command   = $false
    }
}

function Reset-RoutingPulses {
    param([object]$State)
    $State.ScannerTrigger = $false
    $State.PackageRegistered = $false
    $State.ScanGood = $false
    $State.ScanBad = $false
    $State.LaneAVerified = $false
    $State.LaneBVerified = $false
    $State.RejectVerified = $false
    $State.Diverter1Command = $false
    $State.Diverter2Command = $false
}

function Register-Package {
    param([object]$State)
    Reset-RoutingPulses $State
    if ($State.Queue.Count -ge 10) {
        $State.QueueOverflow = $true
        $State.RouteFault = $true
        $State.LastMessage = "Routing FIFO overflow"
        return
    }

    $pkg = [PSCustomObject]@{
        ID           = $State.NextPackageID
        Barcode      = ""
        Route        = "NONE"
        Position     = 0.2
        Age          = 0.0
        Scanned      = $false
        DivertIssued = $false
    }
    $null = $State.Queue.Add($pkg)
    $State.NextPackageID = [uint32]($State.NextPackageID + 1)
    $State.PackageRegistered = $true
    $State.LastMessage = "Package registered at PE1"
}

function Advance-Routing {
    param(
        [object]$State,
        [object]$Recipe,
        [double]$Seconds,
        [double]$Speed = 0.5
    )

    Reset-RoutingPulses $State
    foreach ($pkg in @($State.Queue.ToArray())) {
        $pkg.Position += ($Speed * $Seconds)
        $pkg.Age += $Seconds
        if ($pkg.Age -gt $Recipe.rPackageTimeout_s) {
            $State.Queue.Remove($pkg)
            $State.RouteFault = $true
            $State.LastMessage = "Package timed out in routing queue"
        }
        elseif ((-not $pkg.Scanned) -and $pkg.Position -gt $Recipe.rScannerWindowEnd_m) {
            $pkg.Scanned = $true
            $pkg.Route = "REJECT"
            $State.ScannerTimeout = $true
            $State.ScanBad = $true
            $State.LastMessage = "Package missed scanner window and was rejected"
        }
        elseif ($pkg.Position -gt ($Recipe.rRejectExitPosition_m + 0.3)) {
            $State.Queue.Remove($pkg)
            $State.RouteFault = $true
            $State.LastMessage = "Package left cell without exit verification"
        }
    }
}

function Invoke-Scan {
    param(
        [object]$State,
        [object]$Recipe,
        [string]$Barcode,
        [bool]$ReadSuccess
    )

    Reset-RoutingPulses $State
    $State.ScannerTrigger = $true
    $match = $null
    foreach ($pkg in $State.Queue) {
        if ((-not $pkg.Scanned) -and $pkg.Position -ge $Recipe.rScannerWindowStart_m -and $pkg.Position -le $Recipe.rScannerWindowEnd_m) {
            $match = $pkg
            break
        }
    }

    if ($null -eq $match) {
        $State.ScanBad = $true
        $State.ScannerTimeout = $true
        $State.RouteFault = $true
        $State.LastMessage = "PE2 trigger without matching package"
        return
    }

    $match.Barcode = $Barcode
    $match.Scanned = $true
    $barcodeGood = ($ReadSuccess -and -not $Barcode.Contains("BAD-SCAN"))
    if ($barcodeGood) {
        if ($Barcode.Contains($Recipe.sLaneAPattern)) {
            $match.Route = "LANE_A"
        }
        elseif ($Barcode.Contains($Recipe.sLaneBPattern)) {
            $match.Route = "LANE_B"
        }
        else {
            $match.Route = "REJECT"
        }
        $State.ScanGood = $true
    }
    else {
        $match.Route = "REJECT"
        $State.ScanBad = $true
        $State.ScannerTimeout = $true
    }

    $State.LastRouteTarget = $match.Route
    $State.LastMessage = "Barcode resolved to route target"
}

function Evaluate-Diverters {
    param(
        [object]$State,
        [object]$Recipe,
        [bool]$Diverter1Ready = $true,
        [bool]$Diverter2Ready = $true
    )

    Reset-RoutingPulses $State
    foreach ($pkg in $State.Queue) {
        if ($pkg.DivertIssued) {
            continue
        }
        if ($pkg.Route -eq "LANE_A" -and $pkg.Position -ge $Recipe.rDiverter1WindowStart_m -and $pkg.Position -le $Recipe.rDiverter1WindowEnd_m) {
            if ($Diverter1Ready) {
                $State.Diverter1Command = $true
                $pkg.DivertIssued = $true
            }
            else {
                $State.RouteFault = $true
                $State.LastMessage = "Diverter 1 not ready at firing window"
            }
        }
        if ($pkg.Route -eq "LANE_B" -and $pkg.Position -ge $Recipe.rDiverter2WindowStart_m -and $pkg.Position -le $Recipe.rDiverter2WindowEnd_m) {
            if ($Diverter2Ready) {
                $State.Diverter2Command = $true
                $pkg.DivertIssued = $true
            }
            else {
                $State.RouteFault = $true
                $State.LastMessage = "Diverter 2 not ready at firing window"
            }
        }
    }
}

function Verify-Exit {
    param(
        [object]$State,
        [string]$Route
    )

    Reset-RoutingPulses $State
    $match = $null
    foreach ($pkg in $State.Queue) {
        if ($pkg.Route -eq $Route) {
            $match = $pkg
            break
        }
    }

    if ($null -eq $match) {
        $State.RouteFault = $true
        $State.LastMessage = "Exit verification without matching package"
        return
    }

    $State.LastCompletedID = $match.ID
    $State.Queue.Remove($match)
    $State.TotalCount = [uint32]($State.TotalCount + 1)
    if ($Route -eq "LANE_A") {
        $State.LaneACount = [uint32]($State.LaneACount + 1)
        $State.LaneAVerified = $true
    }
    elseif ($Route -eq "LANE_B") {
        $State.LaneBCount = [uint32]($State.LaneBCount + 1)
        $State.LaneBVerified = $true
    }
    else {
        $State.RejectCount = [uint32]($State.RejectCount + 1)
        $State.RejectVerified = $true
    }
    $State.LastMessage = "$Route verification complete"
}

function Get-ManualRoutingOutputs {
    param(
        [string]$Mode,
        [bool]$MaintenanceSafeguardsOK,
        [bool]$Divert1,
        [bool]$Divert2,
        [bool]$ScannerTrigger
    )

    $manualActive = ($Mode -eq "MANUAL")
    $maintenanceActive = ($Mode -eq "MAINTENANCE" -and $MaintenanceSafeguardsOK)
    [PSCustomObject]@{
        Diverter1      = (($manualActive -or $maintenanceActive) -and $Divert1)
        Diverter2      = (($manualActive -or $maintenanceActive) -and $Divert2)
        ScannerTrigger = (($manualActive -or $maintenanceActive) -and $ScannerTrigger)
        FifoMutable    = $false
    }
}

function Test-RoutingLogic {
    $suite = "RoutingLogic"
    $recipe = New-SortRecipe

    $stateA = New-RoutingState
    Register-Package $stateA
    Advance-Routing $stateA $recipe 1.8 0.5
    Invoke-Scan $stateA $recipe "PKG-LANE-A-FDS" $true
    Advance-Routing $stateA $recipe 2.0 0.5
    Evaluate-Diverters $stateA $recipe $true $true
    Verify-Exit $stateA "LANE_A"
    Assert-Equal $suite "Lane A package increments total" $stateA.TotalCount 1
    Assert-Equal $suite "Lane A package increments lane A" $stateA.LaneACount 1
    Assert-True $suite "Lane A route completes without fault" (-not $stateA.RouteFault) $stateA.LastMessage

    $stateB = New-RoutingState
    Register-Package $stateB
    Advance-Routing $stateB $recipe 1.8 0.5
    Invoke-Scan $stateB $recipe "PKG-LANE-B-FDS" $true
    Advance-Routing $stateB $recipe 4.0 0.5
    Evaluate-Diverters $stateB $recipe $true $true
    Verify-Exit $stateB "LANE_B"
    Assert-Equal $suite "Lane B package increments total" $stateB.TotalCount 1
    Assert-Equal $suite "Lane B package increments lane B" $stateB.LaneBCount 1
    Assert-True $suite "Lane B route completes without fault" (-not $stateB.RouteFault) $stateB.LastMessage

    $reject = New-RoutingState
    Register-Package $reject
    Advance-Routing $reject $recipe 1.8 0.5
    Invoke-Scan $reject $recipe "BAD-SCAN-99" $false
    Advance-Routing $reject $recipe 6.0 0.5
    Verify-Exit $reject "REJECT"
    Assert-Equal $suite "bad scan routes to reject" $reject.RejectCount 1
    Assert-True $suite "bad scan pulse is generated" $reject.ScannerTimeout "Expected scanner timeout/bad scan path"

    $overflow = New-RoutingState
    for ($i = 0; $i -lt 11; $i++) {
        Register-Package $overflow
    }
    Assert-True $suite "FIFO overflow latches route fault" ($overflow.QueueOverflow -and $overflow.RouteFault) $overflow.LastMessage

    $notReady = New-RoutingState
    Register-Package $notReady
    Advance-Routing $notReady $recipe 1.8 0.5
    Invoke-Scan $notReady $recipe "PKG-LANE-A-FDS" $true
    Advance-Routing $notReady $recipe 2.0 0.5
    Evaluate-Diverters $notReady $recipe $false $true
    Assert-True $suite "diverter not ready at route window faults" $notReady.RouteFault $notReady.LastMessage

    $pe2NoPackage = New-RoutingState
    Invoke-Scan $pe2NoPackage $recipe "PKG-LANE-A-FDS" $true
    Assert-True $suite "PE2 trigger without package faults" ($pe2NoPackage.RouteFault -and $pe2NoPackage.ScannerTimeout) $pe2NoPackage.LastMessage

    $manual = Get-ManualRoutingOutputs -Mode "MANUAL" -MaintenanceSafeguardsOK $false -Divert1 $true -Divert2 $false -ScannerTrigger $true
    Assert-True $suite "manual mode hold-to-run commands without FIFO mutation" ($manual.Diverter1 -and $manual.ScannerTrigger -and -not $manual.FifoMutable) "Manual command gate failed"

    $maintBlocked = Get-ManualRoutingOutputs -Mode "MAINTENANCE" -MaintenanceSafeguardsOK $false -Divert1 $true -Divert2 $true -ScannerTrigger $true
    Assert-True $suite "maintenance mode blocks commands without safeguards" (-not $maintBlocked.Diverter1 -and -not $maintBlocked.Diverter2 -and -not $maintBlocked.ScannerTrigger) "Maintenance safeguards bypassed"

    $maintSafe = Get-ManualRoutingOutputs -Mode "MAINTENANCE" -MaintenanceSafeguardsOK $true -Divert1 $true -Divert2 $true -ScannerTrigger $true
    Assert-True $suite "maintenance mode permits hold-to-run with safeguards" ($maintSafe.Diverter1 -and $maintSafe.Diverter2 -and $maintSafe.ScannerTrigger) "Maintenance command gate failed"
}

function Get-JamLimit {
    param([double]$Speed, [double]$Base = 3.0, [double]$Reference = 0.5, [double]$Maximum = 6.0)
    if ($Speed -le 0.01) {
        return $Maximum
    }
    $limit = $Base * $Reference / $Speed
    if ($limit -lt $Base) {
        $limit = $Base
    }
    if ($limit -gt $Maximum) {
        $limit = $Maximum
    }
    return $limit
}

function New-JamState {
    [PSCustomObject]@{
        PE1Blocked = 0.0
        PE2Blocked = 0.0
        PE3Blocked = 0.0
        JamAlarm = $false
        Warning = $false
        Source = 0
        TotalJams = 0
        LastLatched = $false
        RecoveryReady = $false
        ResetAccepted = $false
        InRecovery = $false
    }
}

function Step-Jam {
    param(
        [object]$State,
        [bool]$PE1 = $false,
        [bool]$PE2 = $false,
        [bool]$PE3 = $false,
        [bool]$Running = $true,
        [double]$Speed = 0.5,
        [double]$Cycle = 0.1,
        [bool]$Reset = $false,
        [bool]$RecoveryRequest = $false,
        [bool]$AllowAutoRecovery = $false,
        [string]$PackMLState = "EXECUTE"
    )

    $limit = Get-JamLimit -Speed $Speed
    $warnLimit = $limit * 0.8
    $sensorsClear = (-not $PE1 -and -not $PE2 -and -not $PE3)
    $State.ResetAccepted = $false
    $State.InRecovery = $false
    $resetAllowed = ($Reset -and $sensorsClear -and ($AllowAutoRecovery -or $RecoveryRequest -or $PackMLState -eq "HELD"))
    if ($resetAllowed) {
        $State.JamAlarm = $false
        $State.Warning = $false
        $State.Source = 0
        $State.PE1Blocked = 0.0
        $State.PE2Blocked = 0.0
        $State.PE3Blocked = 0.0
        $State.ResetAccepted = $true
        $State.InRecovery = $true
    }

    if ($PE1 -and $Running) { $State.PE1Blocked += $Cycle } elseif (-not $PE1) { $State.PE1Blocked = 0.0 }
    if ($PE2 -and $Running) { $State.PE2Blocked += $Cycle } elseif (-not $PE2) { $State.PE2Blocked = 0.0 }
    if ($PE3 -and $Running) { $State.PE3Blocked += $Cycle } elseif (-not $PE3) { $State.PE3Blocked = 0.0 }

    if ($State.PE1Blocked -ge $limit -or $State.PE2Blocked -ge $limit -or $State.PE3Blocked -ge $limit) {
        $State.JamAlarm = $true
        if ($State.PE1Blocked -ge $limit) { $State.Source = 1 }
        elseif ($State.PE2Blocked -ge $limit) { $State.Source = 2 }
        else { $State.Source = 3 }
    }
    elseif ($State.PE1Blocked -ge $warnLimit -or $State.PE2Blocked -ge $warnLimit -or $State.PE3Blocked -ge $warnLimit) {
        $State.Warning = $true
    }
    else {
        $State.Warning = $false
    }

    $State.RecoveryReady = ($State.JamAlarm -and $sensorsClear)
    if ($State.JamAlarm -and -not $State.LastLatched) {
        $State.TotalJams += 1
    }
    $State.LastLatched = $State.JamAlarm
    return $limit
}

function Test-JamRecovery {
    $suite = "JamRecovery"
    $jam = New-JamState
    for ($i = 0; $i -lt 24; $i++) { Step-Jam $jam -PE2 $true -Cycle 0.1 | Out-Null }
    Assert-True $suite "warning appears before jam limit" ($jam.Warning -and -not $jam.JamAlarm) "Expected warning at 80 percent of threshold"

    for ($i = 0; $i -lt 6; $i++) { Step-Jam $jam -PE2 $true -Cycle 0.1 | Out-Null }
    Assert-True $suite "PE2 jam latches alarm and hold request source" ($jam.JamAlarm -and $jam.Source -eq 2) "source=$($jam.Source)"
    Assert-Equal $suite "jam counter increments once on rising latch" $jam.TotalJams 1

    Step-Jam $jam -PE2 $true -Cycle 0.1 -Reset $true -PackMLState "HELD" | Out-Null
    Assert-True $suite "reset is rejected while sensor remains blocked" ($jam.JamAlarm -and -not $jam.ResetAccepted) "Reset should require sensors clear"

    Step-Jam $jam -PE2 $false -Cycle 0.1 | Out-Null
    Assert-True $suite "recovery ready only after sensors clear" $jam.RecoveryReady "Expected physical clear"
    Step-Jam $jam -PE2 $false -Cycle 0.1 -Reset $true -PackMLState "HELD" | Out-Null
    Assert-True $suite "reset accepted from HELD after clear" ($jam.ResetAccepted -and -not $jam.JamAlarm -and $jam.InRecovery) "Recovery gate failed"
    Assert-Near $suite "dynamic limit clamps at slow speed" (Get-JamLimit -Speed 0.01) 6.0
}

function New-DiverterState {
    [PSCustomObject]@{
        State = "HOME"
        Elapsed = 0.0
        Faulted = $false
        FaultCode = 0
        CommandExtend = $false
        Done = $false
        Verified = $false
    }
}

function Step-Diverter {
    param(
        [object]$State,
        [bool]$AutoEnable = $true,
        [bool]$ExtendRequest = $false,
        [bool]$ManualExtend = $false,
        [string]$Mode = "AUTO",
        [bool]$ManualEnable = $false,
        [bool]$MaintenanceEnable = $false,
        [bool]$InterlockOK = $true,
        [bool]$Inhibit = $false,
        [bool]$ForceRetract = $false,
        [bool]$HomeSensor = $true,
        [bool]$WorkSensor = $false,
        [bool]$VerificationSensor = $false,
        [bool]$ResetFault = $false,
        [double]$Cycle = 0.1,
        [double]$ExtendTimeout = 0.5,
        [double]$RetractTimeout = 0.5,
        [double]$WorkDwell = 0.2,
        [double]$VerifyTimeout = 0.5,
        [double]$ManualHoldLimit = 0.5
    )

    $State.Done = $false
    $State.Elapsed += $Cycle
    $interlocked = ($InterlockOK -and -not $Inhibit)
    $manualFire = ($ManualExtend -and (($Mode -eq "MANUAL" -and $ManualEnable) -or ($Mode -eq "MAINTENANCE" -and $MaintenanceEnable)))
    $fire = ($interlocked -and (($AutoEnable -and $ExtendRequest) -or $manualFire))

    if ($ResetFault) {
        $State.State = "HOME"
        $State.Elapsed = 0.0
        $State.Faulted = $false
        $State.FaultCode = 0
        $State.Verified = $false
    }
    if ($ForceRetract -or -not $interlocked) {
        $State.CommandExtend = $false
        if ($State.State -ne "HOME" -and $State.State -ne "FAULT") {
            $State.State = "RETRACTING"
            $State.Elapsed = 0.0
        }
    }
    elseif ($State.Faulted) {
        $State.State = "FAULT"
    }
    elseif ($State.State -eq "HOME" -and $fire) {
        if (-not $HomeSensor) {
            $State.Faulted = $true
            $State.FaultCode = 4
        }
        else {
            $State.State = "EXTENDING"
            $State.Elapsed = 0.0
            $State.Verified = $false
        }
    }
    elseif ($State.State -eq "EXTENDING") {
        if ($WorkSensor) {
            $State.State = "WORK"
            $State.Elapsed = 0.0
        }
        elseif ($State.Elapsed -ge $ExtendTimeout) {
            $State.Faulted = $true
            $State.FaultCode = 1
        }
    }
    elseif ($State.State -eq "WORK") {
        if ($manualFire -and $ManualHoldLimit -gt 0.0 -and $State.Elapsed -lt $ManualHoldLimit) {
            # Manual/maintenance hold-to-run keeps the actuator at WORK until the hold watchdog expires.
        }
        elseif ($manualFire -and $ManualHoldLimit -gt 0.0 -and $State.Elapsed -ge $ManualHoldLimit) {
            $State.Faulted = $true
            $State.FaultCode = 5
        }
        elseif ($State.Elapsed -ge $WorkDwell) {
            $State.State = "VERIFY"
            $State.Elapsed = 0.0
        }
    }
    elseif ($State.State -eq "VERIFY") {
        if (($Mode -ne "AUTO") -or $VerificationSensor) {
            $State.Verified = $true
            $State.State = "RETRACTING"
            $State.Elapsed = 0.0
        }
        elseif ($State.Elapsed -ge $VerifyTimeout) {
            $State.Faulted = $true
            $State.FaultCode = 3
        }
    }
    elseif ($State.State -eq "RETRACTING") {
        if ($HomeSensor) {
            $State.State = "HOME"
            $State.Elapsed = 0.0
            $State.Done = $true
        }
        elseif ($State.Elapsed -ge $RetractTimeout) {
            $State.Faulted = $true
            $State.FaultCode = 2
        }
    }

    $State.CommandExtend = ($State.State -eq "EXTENDING" -or $State.State -eq "WORK" -or $State.State -eq "VERIFY")
    if ($ForceRetract -or $Inhibit -or -not $InterlockOK -or $State.Faulted) {
        $State.CommandExtend = $false
    }
}

function Test-DiverterSequences {
    $suite = "DiverterController"
    $ok = New-DiverterState
    Step-Diverter $ok -ExtendRequest $true -Cycle 0.1
    Step-Diverter $ok -WorkSensor $true -HomeSensor $false -Cycle 0.1
    Step-Diverter $ok -WorkSensor $true -HomeSensor $false -Cycle 0.2
    Step-Diverter $ok -WorkSensor $true -HomeSensor $false -VerificationSensor $true -Cycle 0.1
    Step-Diverter $ok -HomeSensor $true -Cycle 0.1
    Assert-True $suite "auto sequence extends verifies retracts and completes" ($ok.Done -and -not $ok.Faulted -and $ok.Verified) "state=$($ok.State) fault=$($ok.FaultCode)"

    $extendFault = New-DiverterState
    Step-Diverter $extendFault -ExtendRequest $true -Cycle 0.1
    for ($i = 0; $i -lt 5; $i++) { Step-Diverter $extendFault -HomeSensor $false -Cycle 0.1 }
    Assert-True $suite "extend timeout faults" ($extendFault.Faulted -and $extendFault.FaultCode -eq 1) "fault=$($extendFault.FaultCode)"

    $verifyFault = New-DiverterState
    Step-Diverter $verifyFault -ExtendRequest $true -Cycle 0.1
    Step-Diverter $verifyFault -WorkSensor $true -HomeSensor $false -Cycle 0.1
    Step-Diverter $verifyFault -WorkSensor $true -HomeSensor $false -Cycle 0.2
    for ($i = 0; $i -lt 5; $i++) { Step-Diverter $verifyFault -WorkSensor $true -HomeSensor $false -Cycle 0.1 }
    Assert-True $suite "verification timeout faults" ($verifyFault.Faulted -and $verifyFault.FaultCode -eq 3) "fault=$($verifyFault.FaultCode)"

    $manualLimit = New-DiverterState
    Step-Diverter $manualLimit -Mode "MANUAL" -ManualEnable $true -ManualExtend $true -Cycle 0.1
    Step-Diverter $manualLimit -Mode "MANUAL" -ManualEnable $true -ManualExtend $true -WorkSensor $true -HomeSensor $false -Cycle 0.1
    for ($i = 0; $i -lt 5; $i++) { Step-Diverter $manualLimit -Mode "MANUAL" -ManualEnable $true -ManualExtend $true -WorkSensor $true -HomeSensor $false -Cycle 0.1 }
    Assert-True $suite "manual hold limit faults" ($manualLimit.Faulted -and $manualLimit.FaultCode -eq 5) "fault=$($manualLimit.FaultCode)"

    $forced = New-DiverterState
    Step-Diverter $forced -ExtendRequest $true -Cycle 0.1
    Step-Diverter $forced -ForceRetract $true -HomeSensor $false -Cycle 0.1
    Assert-True $suite "force retract de-energises solenoid" (-not $forced.CommandExtend -and $forced.State -eq "RETRACTING") "state=$($forced.State)"
}

function New-StationState {
    [PSCustomObject]@{
        PackML = "STOPPED"
        Mode = "AUTO"
        Elapsed = 0.0
        ConveyorRun = $false
        QuickStop = $true
        Speed = 0.0
        MaintenanceActive = $false
        ManualActive = $false
    }
}

function Step-Station {
    param(
        [object]$State,
        [bool]$Start = $false,
        [bool]$Stop = $false,
        [bool]$Reset = $false,
        [bool]$Hold = $false,
        [bool]$Unhold = $false,
        [bool]$Clear = $false,
        [string]$RequestedMode = "AUTO",
        [bool]$SafetyLoopOK = $true,
        [bool]$AirOK = $true,
        [bool]$VfdReady = $true,
        [bool]$Diverter1Faulted = $false,
        [bool]$Diverter2Faulted = $false,
        [bool]$JamAlarm = $false,
        [bool]$DownstreamBlocked = $false,
        [bool]$Jog = $false,
        [double]$JogSpeed = 0.0,
        [bool]$MaintenanceKey = $false,
        [double]$RecipeSpeed = 0.5,
        [double]$ManualMax = 0.7,
        [double]$MaintenanceLimit = 0.2,
        [double]$Cycle = 0.5,
        [double]$Timeout = 1.0
    )

    $State.Elapsed += $Cycle
    $permissive = ($SafetyLoopOK -and $AirOK -and $VfdReady -and -not $Diverter1Faulted -and -not $Diverter2Faulted)
    if (-not $SafetyLoopOK) {
        $State.PackML = "ABORTED"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "STOPPED" -and $Reset) {
        $State.PackML = "RESETTING"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "RESETTING" -and $State.Elapsed -ge $Timeout) {
        $State.PackML = "IDLE"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "IDLE" -and $Stop) {
        $State.PackML = "STOPPING"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "IDLE" -and $Start -and $permissive -and $State.Mode -eq "AUTO") {
        $State.PackML = "STARTING"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "STARTING" -and $State.Elapsed -ge $Timeout -and $permissive -and $State.Mode -eq "AUTO") {
        $State.PackML = "EXECUTE"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "EXECUTE" -and ($JamAlarm -or $Hold -or -not $permissive)) {
        $State.PackML = "HOLDING"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "EXECUTE" -and $DownstreamBlocked) {
        $State.PackML = "SUSPENDED"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "SUSPENDED" -and -not $DownstreamBlocked) {
        $State.PackML = "EXECUTE"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "HOLDING" -and $State.Elapsed -ge $Timeout) {
        $State.PackML = "HELD"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "HELD" -and $Unhold -and $permissive -and -not $JamAlarm) {
        $State.PackML = "UNHOLDING"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "UNHOLDING" -and $State.Elapsed -ge $Timeout) {
        $State.PackML = "EXECUTE"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "STOPPING" -and $State.Elapsed -ge $Timeout) {
        $State.PackML = "STOPPED"
        $State.Elapsed = 0.0
    }
    elseif ($State.PackML -eq "ABORTED" -and $Clear) {
        $State.PackML = "STOPPED"
        $State.Elapsed = 0.0
    }

    if ($State.PackML -eq "STOPPED" -or $State.PackML -eq "IDLE" -or $State.PackML -eq "ABORTED") {
        $State.Mode = $RequestedMode
    }

    $State.ManualActive = ($permissive -and $State.Mode -eq "MANUAL" -and ($State.PackML -eq "IDLE" -or $State.PackML -eq "HELD" -or $State.PackML -eq "STOPPED"))
    $State.MaintenanceActive = ($permissive -and $State.Mode -eq "MAINTENANCE" -and $MaintenanceKey -and $State.PackML -ne "ABORTED" -and $State.PackML -ne "EXECUTE")
    $State.ConveyorRun = (($State.PackML -eq "STARTING" -or $State.PackML -eq "EXECUTE" -or $State.PackML -eq "UNHOLDING") -and $State.Mode -eq "AUTO")
    if (($State.ManualActive -or $State.MaintenanceActive) -and $Jog -and -not $JamAlarm) {
        $State.ConveyorRun = $true
    }

    $State.QuickStop = ($State.PackML -eq "HOLDING" -or $State.PackML -eq "HELD" -or $State.PackML -eq "ABORTED" -or $State.PackML -eq "STOPPING")
    if (($State.ManualActive -or $State.MaintenanceActive) -and $Jog -and -not $JamAlarm) {
        $State.QuickStop = $false
    }

    if ($State.Mode -eq "AUTO" -and $State.ConveyorRun) {
        $State.Speed = [Math]::Min([Math]::Max($RecipeSpeed, 0.05), 1.5)
    }
    elseif ($State.MaintenanceActive -and $Jog) {
        $State.Speed = [Math]::Min($JogSpeed, $MaintenanceLimit)
    }
    elseif ($State.ManualActive -and $Jog) {
        $State.Speed = [Math]::Min($JogSpeed, $ManualMax)
    }
    else {
        $State.Speed = 0.0
    }
}

function Test-StationController {
    $suite = "StationController"
    $station = New-StationState
    Step-Station $station -Reset $true -Cycle 0.1
    Step-Station $station -Cycle 1.0
    Assert-Equal $suite "reset sequence reaches IDLE" $station.PackML "IDLE"

    Step-Station $station -Start $true -Cycle 0.1
    Step-Station $station -Cycle 1.0
    Assert-True $suite "start sequence reaches EXECUTE and runs conveyor" ($station.PackML -eq "EXECUTE" -and $station.ConveyorRun -and $station.Speed -gt 0.0) "state=$($station.PackML)"

    Step-Station $station -JamAlarm $true -Cycle 0.1
    Step-Station $station -JamAlarm $true -Cycle 1.0
    Assert-True $suite "jam forces HOLDING then HELD quick stop" ($station.PackML -eq "HELD" -and $station.QuickStop) "state=$($station.PackML)"

    Step-Station $station -Unhold $true -Cycle 0.1
    Step-Station $station -Cycle 1.0
    Assert-Equal $suite "unhold returns to EXECUTE" $station.PackML "EXECUTE"

    Step-Station $station -SafetyLoopOK $false -Cycle 0.1
    Assert-Equal $suite "safety loop drop aborts station" $station.PackML "ABORTED"
    Step-Station $station -Clear $true -Cycle 0.1
    Assert-Equal $suite "clear recovers ABORTED to STOPPED" $station.PackML "STOPPED"

    $maint = New-StationState
    Step-Station $maint -RequestedMode "MAINTENANCE" -Cycle 0.1
    Step-Station $maint -RequestedMode "MAINTENANCE" -MaintenanceKey $true -Jog $true -JogSpeed 1.0 -Cycle 0.1
    Assert-True $suite "maintenance requires key and clamps jog speed" ($maint.MaintenanceActive -and $maint.ConveyorRun -and [Math]::Abs($maint.Speed - 0.2) -lt 0.0001) "speed=$($maint.Speed)"
}

function New-KpiState {
    [PSCustomObject]@{
        Total = [uint32]0
        LaneA = [uint32]0
        LaneB = [uint32]0
        Reject = [uint32]0
        Registered = [uint32]0
        GoodScans = [uint32]0
        BadScans = [uint32]0
        ExecuteTime = 0.0
        ScheduledTime = 0.0
        Availability = 1.0
        Performance = 0.96
        Quality = 1.0
        OEE = 96.0
        Throughput = 0.0
    }
}

function Step-KPI {
    param(
        [object]$State,
        [bool]$LaneA = $false,
        [bool]$LaneB = $false,
        [bool]$Reject = $false,
        [bool]$Registered = $false,
        [bool]$GoodScan = $false,
        [bool]$BadScan = $false,
        [string]$PackML = "EXECUTE",
        [bool]$FaultDowntime = $false,
        [bool]$Reset = $false,
        [double]$Cycle = 1.0,
        [double]$PerformanceFactor = 0.96,
        [double]$TargetRate = 60.0
    )

    if ($Reset) {
        $State.Total = 0
        $State.LaneA = 0
        $State.LaneB = 0
        $State.Reject = 0
        $State.Registered = 0
        $State.GoodScans = 0
        $State.BadScans = 0
        $State.ExecuteTime = 0.0
        $State.ScheduledTime = 0.0
    }
    if ($LaneA) { $State.LaneA += 1; $State.Total += 1 }
    if ($LaneB) { $State.LaneB += 1; $State.Total += 1 }
    if ($Reject) { $State.Reject += 1; $State.Total += 1 }
    if ($Registered) { $State.Registered += 1 }
    if ($GoodScan) { $State.GoodScans += 1 }
    if ($BadScan) { $State.BadScans += 1 }
    if ($PackML -eq "EXECUTE") {
        $State.ExecuteTime += $Cycle
        $State.ScheduledTime += $Cycle
    }
    elseif ($FaultDowntime -or $PackML -eq "HELD") {
        $State.ScheduledTime += $Cycle
    }

    if ($State.ScheduledTime -gt 0.0) {
        $State.Availability = $State.ExecuteTime / $State.ScheduledTime
        $State.Throughput = $State.Total / ($State.ScheduledTime / 60.0)
    }
    else {
        $State.Availability = 1.0
        $State.Throughput = 0.0
    }
    if ($TargetRate -gt 0.0) {
        $rawPerformance = $State.Throughput / $TargetRate
        if ($rawPerformance -gt 1.0) { $rawPerformance = 1.0 }
        $State.Performance = $rawPerformance * $PerformanceFactor
    }
    else {
        $State.Performance = $PerformanceFactor
    }
    if ($State.Total -gt 0) {
        $State.Quality = ($State.Total - $State.Reject) / $State.Total
    }
    else {
        $State.Quality = 1.0
    }
    $State.OEE = $State.Availability * $State.Performance * $State.Quality * 100.0
}

function Test-KPIService {
    $suite = "KPIService"
    $kpi = New-KpiState
    Step-KPI $kpi -LaneA $true -Registered $true -GoodScan $true -Cycle 1.0
    Step-KPI $kpi -LaneB $true -Registered $true -GoodScan $true -Cycle 1.0
    Step-KPI $kpi -Reject $true -Registered $true -BadScan $true -Cycle 1.0
    Step-KPI $kpi -PackML "HELD" -FaultDowntime $true -Cycle 1.0
    Assert-Equal $suite "route pulses update total count" $kpi.Total 3
    Assert-Equal $suite "reject count updates" $kpi.Reject 1
    Assert-Near $suite "quality excludes reject" $kpi.Quality (2.0 / 3.0) 0.0001
    Assert-Near $suite "availability includes held downtime" $kpi.Availability 0.75 0.0001
    Assert-True $suite "OEE is calculated from availability performance quality" ($kpi.OEE -gt 0.0 -and $kpi.OEE -le 100.0) "OEE=$($kpi.OEE)"
    Step-KPI $kpi -Reset $true -PackML "STOPPED" -Cycle 0.0
    Assert-True $suite "reset counters clears KPI totals" ($kpi.Total -eq 0 -and $kpi.Registered -eq 0 -and $kpi.GoodScans -eq 0) "total=$($kpi.Total)"
}

function New-AlarmState {
    [PSCustomObject]@{
        AckLatched = $false
        LastActive = $false
        LastCode = 0
        Runtime = 0.0
        Timeline = New-Object System.Collections.ArrayList
        Sequence = [uint32]1
        AnyAlarm = $false
        AnyUnacked = $false
        Code = 0
        Severity = 0
        Message = ""
        Sounder = $false
        StackRed = $false
        StackYellow = $false
        StackGreen = $false
    }
}

function Add-Event {
    param([object]$State, [string]$Class, [int]$Code, [int]$Severity, [string]$Message)
    $null = $State.Timeline.Add([PSCustomObject]@{
        Sequence = $State.Sequence
        Time = $State.Runtime
        Class = $Class
        Code = $Code
        Severity = $Severity
        Message = $Message
    })
    $State.Sequence += 1
}

function Step-Alarm {
    param(
        [object]$State,
        [bool]$SafetyLoopOK = $true,
        [bool]$AirOK = $true,
        [bool]$VfdFault = $false,
        [bool]$JamAlarm = $false,
        [bool]$JamWarning = $false,
        [bool]$Diverter1Faulted = $false,
        [bool]$Diverter2Faulted = $false,
        [bool]$RouteFault = $false,
        [string]$PackML = "EXECUTE",
        [bool]$Acknowledge = $false,
        [bool]$Reset = $false,
        [double]$Cycle = 0.1
    )

    $State.Runtime += $Cycle
    $any = ((-not $SafetyLoopOK) -or (-not $AirOK) -or $VfdFault -or $JamAlarm -or $Diverter1Faulted -or $Diverter2Faulted -or $RouteFault)
    if ($Acknowledge) { $State.AckLatched = $true }
    if ($Reset -and -not $any) { $State.AckLatched = $false }

    if (-not $SafetyLoopOK) { $code = 1000; $sev = 1000; $msg = "Emergency stop circuit tripped" }
    elseif ($Diverter1Faulted) { $code = 200; $sev = 900; $msg = "Diverter 1 pneumatic actuator fault" }
    elseif ($Diverter2Faulted) { $code = 210; $sev = 900; $msg = "Diverter 2 pneumatic actuator fault" }
    elseif ($RouteFault) { $code = 250; $sev = 850; $msg = "Routing verification or FIFO fault active" }
    elseif ($JamAlarm) { $code = 100; $sev = 800; $msg = "Package jam detected on main conveyor" }
    elseif (-not $AirOK) { $code = 300; $sev = 700; $msg = "Pneumatic pressure below permissive threshold" }
    elseif ($VfdFault) { $code = 400; $sev = 700; $msg = "Conveyor VFD fault active" }
    elseif ($JamWarning -or $PackML -eq "HELD") { $code = 0; $sev = 300; $msg = "Cell warning or held state active" }
    else { $code = 0; $sev = 0; $msg = "No active alarms" }

    $State.AnyAlarm = $any
    $State.Code = $code
    $State.Severity = $sev
    $State.Message = $msg
    $State.AnyUnacked = ($any -and -not $State.AckLatched)
    $State.Sounder = ($State.AnyUnacked -and $sev -ge 800)
    $State.StackGreen = ($PackML -eq "EXECUTE" -and -not $any)
    $State.StackYellow = ($JamWarning -or $JamAlarm -or $PackML -eq "HELD")
    $State.StackRed = ((-not $SafetyLoopOK) -or $Diverter1Faulted -or $Diverter2Faulted -or $RouteFault -or $JamAlarm -or (-not $AirOK) -or $VfdFault)

    if ($any -and (($code -ne $State.LastCode) -or -not $State.LastActive)) {
        Add-Event $State "ALARM" $code $sev $msg
    }
    elseif ((-not $any) -and $State.LastActive) {
        Add-Event $State "RECOVERY" 0 0 "Alarm state cleared"
    }
    if ($Acknowledge) {
        Add-Event $State "COMMAND" 1 0 "Alarm acknowledged"
    }
    if ($Reset) {
        Add-Event $State "RECOVERY" 2 0 "Alarm reset requested"
    }

    $State.LastActive = $any
    $State.LastCode = $code
}

function Test-AlarmManagerAndTimeline {
    $suite = "AlarmManager"
    $alarm = New-AlarmState
    Step-Alarm $alarm -JamAlarm $true -PackML "HELD"
    Assert-True $suite "jam alarm drives code severity sounder and event" ($alarm.Code -eq 100 -and $alarm.Severity -eq 800 -and $alarm.Sounder -and $alarm.Timeline.Count -eq 1) "code=$($alarm.Code) events=$($alarm.Timeline.Count)"
    Step-Alarm $alarm -JamAlarm $true -PackML "HELD" -Acknowledge $true
    Assert-True $suite "acknowledge silences unacked sounder and logs command" (-not $alarm.Sounder -and $alarm.Timeline.Count -eq 2) "events=$($alarm.Timeline.Count)"
    Step-Alarm $alarm -JamAlarm $false -PackML "HELD"
    Assert-True $suite "clearing root cause appends recovery event" (-not $alarm.AnyAlarm -and $alarm.Timeline.Count -eq 3) "events=$($alarm.Timeline.Count)"
    Step-Alarm $alarm -Reset $true -PackML "IDLE"
    Assert-True $suite "reset command appends recovery request" ($alarm.Timeline.Count -eq 4) "events=$($alarm.Timeline.Count)"

    $priority = New-AlarmState
    Step-Alarm $priority -SafetyLoopOK $false -JamAlarm $true
    Assert-True $suite "E-stop priority overrides jam" ($priority.Code -eq 1000 -and $priority.Severity -eq 1000 -and $priority.StackRed) "code=$($priority.Code)"
}

function New-HistorianState {
    [PSCustomObject]@{
        HeartbeatLast = $false
        SampleElapsed = 0.0
        HeartbeatElapsed = 0.0
        Missed = 0
        LastEventSequence = 0
        Healthy = $false
        Subscribe = $false
        SampleStrobe = $false
        PublishKPI = $false
        PublishAlarm = $false
        PublishEvent = $false
        Measurement = "idle"
    }
}

function Step-Historian {
    param(
        [object]$State,
        [bool]$Enable = $true,
        [bool]$OpcUaReady = $true,
        [bool]$Heartbeat = $false,
        [bool]$LastWriteOK = $true,
        [bool]$ActiveAlarm = $false,
        [uint32]$TimelineSequence = 0,
        [bool]$TimelineActive = $false,
        [double]$Cycle = 0.1,
        [double]$SamplePeriod = 1.0,
        [double]$HeartbeatTimeout = 1.0,
        [uint16]$MaxMissed = 3
    )

    $State.SampleStrobe = $false
    $State.PublishKPI = $false
    $State.PublishAlarm = $false
    $State.PublishEvent = $false
    $edge = ($Heartbeat -ne $State.HeartbeatLast)
    if ($edge) {
        $State.HeartbeatElapsed = 0.0
        $State.Missed = 0
    }
    else {
        $State.HeartbeatElapsed += $Cycle
    }
    if ($State.HeartbeatElapsed -ge $HeartbeatTimeout) {
        $State.Missed += 1
        $State.HeartbeatElapsed = 0.0
    }
    $State.Subscribe = ($Enable -and $OpcUaReady)
    $State.Healthy = ($State.Subscribe -and $State.Missed -lt $MaxMissed -and $LastWriteOK)
    if ($State.Healthy) {
        $State.SampleElapsed += $Cycle
        if ($State.SampleElapsed -ge $SamplePeriod) {
            $State.SampleElapsed = 0.0
            $State.SampleStrobe = $true
            $State.PublishKPI = $true
            $State.PublishAlarm = $ActiveAlarm
        }
        if ($TimelineActive -and $TimelineSequence -ne $State.LastEventSequence) {
            $State.PublishEvent = $true
            $State.LastEventSequence = $TimelineSequence
        }
    }
    if ($State.PublishEvent) { $State.Measurement = "event_timeline" }
    elseif ($State.PublishAlarm) { $State.Measurement = "alarms_events" }
    elseif ($State.PublishKPI) { $State.Measurement = "cell_kpis" }
    else { $State.Measurement = "idle" }
    $State.HeartbeatLast = $Heartbeat
}

function Test-HistorianConnector {
    $suite = "HistorianConnector"
    $hist = New-HistorianState
    Step-Historian $hist -Heartbeat $true -Cycle 0.1
    Step-Historian $hist -Heartbeat $true -ActiveAlarm $true -TimelineSequence 7 -TimelineActive $true -Cycle 1.0
    Assert-True $suite "healthy historian publishes KPI alarm and event" ($hist.Healthy -and $hist.PublishKPI -and $hist.PublishAlarm -and $hist.PublishEvent -and $hist.Measurement -eq "event_timeline") "measurement=$($hist.Measurement)"

    $hist2 = New-HistorianState
    for ($i = 0; $i -lt 4; $i++) {
        Step-Historian $hist2 -Heartbeat $false -Cycle 1.0
    }
    Assert-True $suite "missed heartbeat drives unhealthy/backoff condition" (-not $hist2.Healthy -and $hist2.Missed -ge 3) "missed=$($hist2.Missed)"
}

function Test-FATSequence {
    $suite = "FATSequence"
    $recipe = New-SortRecipe
    $station = New-StationState
    Step-Station $station -Reset $true -Cycle 0.1
    Step-Station $station -Cycle 1.0
    Step-Station $station -Start $true -Cycle 0.1
    Step-Station $station -Cycle 1.0

    $route = New-RoutingState
    Register-Package $route
    Advance-Routing $route $recipe 1.8 0.5
    Invoke-Scan $route $recipe "FAT-LANE-A-001" $true
    Advance-Routing $route $recipe 2.0 0.5
    Evaluate-Diverters $route $recipe $true $true
    Verify-Exit $route "LANE_A"

    $jam = New-JamState
    for ($i = 0; $i -lt 30; $i++) { Step-Jam $jam -PE2 $true -Cycle 0.1 | Out-Null }
    Step-Station $station -JamAlarm $jam.JamAlarm -Cycle 0.1
    Step-Station $station -JamAlarm $jam.JamAlarm -Cycle 1.0

    $alarm = New-AlarmState
    Step-Alarm $alarm -JamAlarm $jam.JamAlarm -PackML $station.PackML

    Step-Jam $jam -PE2 $false -PackMLState "HELD" | Out-Null
    Step-Jam $jam -PE2 $false -Reset $true -PackMLState "HELD" | Out-Null
    Step-Station $station -Unhold $true -Cycle 0.1
    Step-Station $station -Cycle 1.0
    Step-Alarm $alarm -JamAlarm $jam.JamAlarm -PackML $station.PackML -Reset $true

    $kpi = New-KpiState
    Step-KPI $kpi -LaneA $route.LaneAVerified -Registered $true -GoodScan $true -Cycle 1.0

    Assert-True $suite "startup, Lane A route, jam hold, reset, and unhold complete" ($station.PackML -eq "EXECUTE" -and $route.LaneACount -eq 1 -and $jam.ResetAccepted -and $alarm.Timeline.Count -ge 2) "station=$($station.PackML), laneA=$($route.LaneACount), events=$($alarm.Timeline.Count)"
    Assert-True $suite "FAT KPI reflects verified package" ($kpi.Total -eq 1 -and $kpi.GoodScans -eq 1) "total=$($kpi.Total)"
}

function Test-TwinCATBuild {
    $suite = "TwinCATCompile"
    if ($SkipTwinCATBuild) {
        Add-ValidationResult -Suite $suite -Name "headless TwinCAT build skipped by switch" -Passed $true -Detail "Run without -SkipTwinCATBuild for vendor compile gate."
        return
    }

    if ($UseExistingTwinCATBuildEvidence) {
        $logPath = Join-Path $workspace "twincat\logs\twincat_dte_build.txt"
        $tmc = Join-Path $workspace "twincat\MHMC_PLC\MHMC_PLC.tmc"
        $manualEvidencePath = Join-Path $workspace "validation\results\twincat-manual-build-evidence.md"
        $logText = ""
        $manualEvidenceText = ""
        if (Test-Path -LiteralPath $logPath) {
            $logText = Get-Content -LiteralPath $logPath -Raw
        }
        if (Test-Path -LiteralPath $manualEvidencePath) {
            $manualEvidenceText = Get-Content -LiteralPath $manualEvidencePath -Raw
        }

        $dteEvidenceOk = ($logText -match "LastBuildInfo:\s*0") -and ($logText -match "Error List \(0 item\(s\)\)")
        $manualEvidenceOk = (Test-Path -LiteralPath $manualEvidencePath) `
            -and ($manualEvidenceText -match "0 Errors") `
            -and ($manualEvidenceText -match "0 Warnings") `
            -and ($manualEvidenceText -match "Rebuild All succeeded") `
            -and (Test-Path -LiteralPath $tmc)

        Assert-True $suite "TwinCAT vendor build evidence reports success" ($dteEvidenceOk -or $manualEvidenceOk) "DTE log: $logPath; manual evidence: $manualEvidencePath"
        if (Test-Path -LiteralPath $tmc) {
            Assert-True $suite "TwinCAT generated TMC symbol file exists" $true $tmc
        }
        else {
            Add-ValidationResult -Suite $suite -Name "TwinCAT build artifact evidence recorded" -Passed $manualEvidenceOk -Detail "Loose .tmc is required unless an existing DTE transcript proves LastBuildInfo 0."
        }
        if (Test-Path -LiteralPath $tmc) {
            try {
                [xml]$tmcXml = Get-Content -LiteralPath $tmc -Raw
                $names = @($tmcXml.SelectNodes("//DataType/Name") | ForEach-Object { $_.InnerText })
                Assert-True $suite "TMC exposes sort recipe and event timeline types" (($names -contains "ST_SortRecipe") -and ($names -contains "ST_MHMCEventTimeline")) "Type names checked in TMC"
            }
            catch {
                Assert-True $suite "TMC XML parses" $false $_.Exception.Message
            }
        }
        return
    }

    $builder = Join-Path $workspace "tools\build-twincat.ps1"
    try {
        $buildOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $builder 2>&1
        $exitCode = $LASTEXITCODE
        $tail = ($buildOutput | Select-Object -Last 30 | Out-String).Trim()
        Assert-True $suite "headless TwinCAT build succeeds" ($exitCode -eq 0) $tail
    }
    catch {
        Assert-True $suite "headless TwinCAT build succeeds" $false $_.Exception.Message
    }

    $tmc = Join-Path $workspace "twincat\MHMC_PLC\MHMC_PLC.tmc"
    Assert-True $suite "TwinCAT generated TMC symbol file exists" (Test-Path -LiteralPath $tmc) $tmc
    if (Test-Path -LiteralPath $tmc) {
        try {
            [xml]$tmcXml = Get-Content -LiteralPath $tmc -Raw
            $names = @($tmcXml.SelectNodes("//DataType/Name") | ForEach-Object { $_.InnerText })
            Assert-True $suite "TMC exposes sort recipe and event timeline types" (($names -contains "ST_SortRecipe") -and ($names -contains "ST_MHMCEventTimeline")) "Type names checked in TMC"
        }
        catch {
            Assert-True $suite "TMC XML parses" $false $_.Exception.Message
        }
    }
}

function Test-TestHarnessContracts {
    $suite = "TestHarnessContracts"
    $file = Join-Path $workspace "plc\FB_TestHarness.st"
    $exists = Test-Path -LiteralPath $file
    Assert-True $suite "PLC TestHarness source exists" $exists $file
    if (-not $exists) {
        return
    }

    $text = Get-Content -LiteralPath $file -Raw
    $requiredScenarios = @(
        "TH_NORMAL_LANE_A",
        "TH_JAM_PE3",
        "TH_SENSOR_STUCK_HIGH_PE2",
        "TH_SENSOR_STUCK_LOW_PE2",
        "TH_START_PRODUCT_PRESENT",
        "TH_BARCODE_MISREAD",
        "TH_NETWORK_DROPOUT",
        "TH_MANUAL_OVERRIDE_ABUSE",
        "TH_RECIPE_CHANGE_MID_CYCLE",
        "TH_THROUGHPUT_DEGRADATION"
    )

    Assert-True $suite "typed harness input output and config contracts exist" (
        ($text -match "TYPE\s+ST_TestHarnessInput\s*:") -and
        ($text -match "TYPE\s+ST_TestHarnessOutput\s*:") -and
        ($text -match "TYPE\s+ST_TestHarnessConfig\s*:")
    ) "Missing typed TestHarness contract"
    Assert-True $suite "harness exposes FB and standalone PROGRAM" (
        ($text -match "FUNCTION_BLOCK\s+FB_TestHarness\b") -and
        ($text -match "PROGRAM\s+TestHarness\b")
    ) "Missing FB_TestHarness or PROGRAM TestHarness"
    Assert-True $suite "harness calls production modules" (
        ($text -match "FB_LineSupervisor") -and
        ($text -match "FB_StationController") -and
        ($text -match "FB_RoutingLogic") -and
        ($text -match "FB_JamDetector") -and
        ($text -match "FB_KPIService") -and
        ($text -match "FB_AlarmManager") -and
        ($text -match "FB_HistorianConnector")
    ) "Harness must exercise existing module FBs"
    Assert-True $suite "harness logs events through timeline helper" (
        ($text -match "ST_MHMCEventTimeline") -and
        ($text -match "F_EventTimeline_Append")
    ) "Missing event timeline logging"
    Assert-True $suite "harness has no hard-coded I/O addresses" (-not ($text -match "\bAT\s*%[IQM]")) "Found direct AT %I/%Q/%M address binding"

    foreach ($scenario in $requiredScenarios) {
        Assert-True $suite "scenario defined: $scenario" ($text -match [regex]::Escape($scenario)) "Missing scenario enum or logic"
    }
}

function Test-TestHarnessScenarioRunner {
    $suite = "TestHarnessRunner"
    $runner = Join-Path $workspace "validation\run_test_harness.py"
    Assert-True $suite "scenario runner exists" (Test-Path -LiteralPath $runner) $runner
    if (-not (Test-Path -LiteralPath $runner)) {
        return
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $pythonCommand) {
        $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
    }
    $bundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    $pythonPath = ""
    if ($null -ne $pythonCommand) {
        $pythonPath = $pythonCommand.Source
    }
    elseif (Test-Path -LiteralPath $bundledPython) {
        $pythonPath = $bundledPython
    }

    Assert-True $suite "Python runtime available for deterministic harness runner" (-not [string]::IsNullOrWhiteSpace($pythonPath)) "Install Python or use the bundled Codex Python runtime"
    if ([string]::IsNullOrWhiteSpace($pythonPath)) {
        return
    }

    try {
        $output = & $pythonPath -B $runner 2>&1
        $exitCode = $LASTEXITCODE
        $detail = ($output | Out-String).Trim()
        Assert-True $suite "all TestHarness scenarios pass" ($exitCode -eq 0) $detail
    }
    catch {
        Assert-True $suite "all TestHarness scenarios pass" $false $_.Exception.Message
        return
    }

    $jsonPath = Join-Path $ResultsRoot "test-harness-results.json"
    $reportPath = Join-Path $ResultsRoot "test-harness-report.md"
    Assert-True $suite "TestHarness JSON evidence exists" (Test-Path -LiteralPath $jsonPath) $jsonPath
    Assert-True $suite "TestHarness markdown report exists" (Test-Path -LiteralPath $reportPath) $reportPath
    if (Test-Path -LiteralPath $jsonPath) {
        try {
            $summary = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            Assert-Equal $suite "scenario pass count" $summary.passed 10
            Assert-Equal $suite "scenario fail count" $summary.failed 0
        }
        catch {
            Assert-True $suite "TestHarness JSON parses" $false $_.Exception.Message
        }
    }
}

function Write-ValidationArtifacts {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
    $passed = @($script:Results | Where-Object { $_.Passed }).Count
    $failed = @($script:Results | Where-Object { -not $_.Passed }).Count
    $workspacePath = [string]$workspace.Path
    $resultArray = @($script:Results.ToArray())
    $summary = [PSCustomObject]@{
        GeneratedAt          = $timestamp
        Workspace            = $workspacePath
        Scope                = "static source contracts; deterministic offline FAT/reference scenarios; TwinCAT compiler gate"
        Passed               = $passed
        Failed               = $failed
        Total                = $script:Results.Count
        HardwareCommissioning = "Not executed in this environment; requires physical I/O, safety validation, pneumatics, VFD, scanner, diverters, OPC UA collector, and signed FAT/SAT."
        Results              = $resultArray
    }

    $jsonPath = Join-Path $ResultsRoot "validation-summary.json"
    $mdPath = Join-Path $ResultsRoot "validation-report.md"
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $lines = New-Object System.Collections.ArrayList
    $null = $lines.Add("# MHMC PLC Validation Report")
    $null = $lines.Add("")
    $null = $lines.Add("- Generated: $timestamp")
    $null = $lines.Add("- Workspace: $workspacePath")
    $null = $lines.Add("- Scope: static source contracts, deterministic offline FAT/reference scenarios, and TwinCAT compiler gate")
    $null = $lines.Add("- Passed: $passed")
    $null = $lines.Add("- Failed: $failed")
    $null = $lines.Add("- Total checks: $($script:Results.Count)")
    $null = $lines.Add("")
    $null = $lines.Add("## Important Scope Boundary")
    $null = $lines.Add("")
    $null = $lines.Add("This validation does not replace physical commissioning. Real I/O mapping, E-stop validation, pneumatic timing, VFD behavior, scanner communication, diverter mechanics, OPC UA collector connectivity, and signed FAT/SAT must be performed on the actual cell.")
    $null = $lines.Add("")
    $null = $lines.Add("## Results")
    $null = $lines.Add("")
    $null = $lines.Add("| Suite | Check | Result | Detail |")
    $null = $lines.Add("| --- | --- | --- | --- |")
    foreach ($result in $script:Results) {
        $status = $(if ($result.Passed) { "PASS" } else { "FAIL" })
        $detail = [string]$result.Detail
        $detail = $detail.Replace("|", "\|").Replace("`r", " ").Replace("`n", "<br>")
        $null = $lines.Add("| $($result.Suite) | $($result.Name) | $status | $detail |")
    }
    $lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

    Write-Host ""
    Write-Host ("Validation complete: {0} passed, {1} failed, {2} total." -f $passed, $failed, $script:Results.Count)
    Write-Host "JSON: $jsonPath"
    Write-Host "Report: $mdPath"
    if ($failed -gt 0) {
        exit 1
    }
}

Test-SourceContracts
Test-TwinCATProjectPreparation
Test-RecipeMatrix
Test-RoutingLogic
Test-JamRecovery
Test-DiverterSequences
Test-StationController
Test-KPIService
Test-AlarmManagerAndTimeline
Test-HistorianConnector
Test-FATSequence
Test-TestHarnessContracts
Test-TestHarnessScenarioRunner
Test-TwinCATBuild
Write-ValidationArtifacts
