# Generate a TwinCAT PLC project wrapper from the loose IEC ST files in ./plc.
#
# The generated project lives under ./twincat/MHMC_PLC and is intentionally
# mechanical: edit ./plc/*.st, then regenerate this wrapper.

[CmdletBinding()]
param(
    [string]$ProjectName = "MHMC_PLC",
    [string]$RuntimeName = "MHMC_Runtime",
    [string]$SolutionName = "MHMC_Runtime"
)

$ErrorActionPreference = "Stop"

$workspace = Resolve-Path (Join-Path $PSScriptRoot "..")
$plcSource = Join-Path $workspace "plc"
$outRoot = Join-Path $workspace "twincat"
$projectRoot = Join-Path $outRoot $ProjectName
$runtimeRoot = Join-Path $outRoot "RuntimeSystem"
$pouDir = Join-Path $projectRoot "POUs"
$dutDir = Join-Path $projectRoot "DUTs"
$existingProjectPath = Join-Path $projectRoot "$ProjectName.plcproj"
$preservedProjectExtensions = ""

function New-TcGuid {
    param([string]$Seed = "")

    if ([string]::IsNullOrWhiteSpace($Seed)) {
        return "{" + ([guid]::NewGuid().ToString().ToUpperInvariant()) + "}"
    }

    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $seedBytes = [System.Text.Encoding]::UTF8.GetBytes("material-handling-cell/$Seed")
        $hashBytes = $md5.ComputeHash($seedBytes)
        $guid = New-Object System.Guid -ArgumentList (, $hashBytes)
        return "{" + ($guid.ToString().ToUpperInvariant()) + "}"
    }
    finally {
        $md5.Dispose()
    }
}

function New-TcPouXml {
    param(
        [string]$Name,
        [string]$Declaration,
        [string]$Implementation,
        [string]$Guid
    )

@"
<?xml version="1.0" encoding="utf-8"?>
<TcPlcObject Version="1.1.0.1">
  <POU Name="$Name" Id="$Guid">
    <Declaration><![CDATA[$Declaration]]></Declaration>
    <Implementation>
      <ST><![CDATA[$Implementation]]></ST>
    </Implementation>
  </POU>
</TcPlcObject>
"@
}

function ConvertTo-CDataSafe {
    param([string]$Text)
    if ($Text -match "\]\]>") {
        throw "Source text contains CDATA terminator sequence, cannot emit TwinCAT XML safely."
    }
    $Text.TrimEnd() + "`r`n"
}

function Split-PouBlock {
    param(
        [string]$Block,
        [string]$EndKeyword
    )

    $withoutEnd = [regex]::Replace($Block, "(?im)^\s*$EndKeyword\s*;?\s*$", "").TrimEnd()
    $endVarMatches = [regex]::Matches($withoutEnd, "(?im)^\s*END_VAR\s*$")

    if ($endVarMatches.Count -gt 0) {
        $lastEndVar = $endVarMatches[$endVarMatches.Count - 1]
        $splitIndex = $lastEndVar.Index + $lastEndVar.Length
        return [PSCustomObject]@{
            Declaration = $withoutEnd.Substring(0, $splitIndex).TrimEnd()
            Implementation = $withoutEnd.Substring($splitIndex).Trim()
        }
    }

    $firstLineEnd = $withoutEnd.IndexOf("`n")
    if ($firstLineEnd -lt 0) {
        return [PSCustomObject]@{
            Declaration = $withoutEnd.TrimEnd()
            Implementation = ""
        }
    }

    [PSCustomObject]@{
        Declaration = $withoutEnd.Substring(0, $firstLineEnd).TrimEnd()
        Implementation = $withoutEnd.Substring($firstLineEnd + 1).Trim()
    }
}

if (Test-Path -LiteralPath $existingProjectPath) {
    $existingProjectText = Get-Content -LiteralPath $existingProjectPath -Raw
    $projectExtensionsMatch = [regex]::Match(
        $existingProjectText,
        "(?ms)^\s*<ProjectExtensions>.*?^\s*</ProjectExtensions>"
    )

    if ($projectExtensionsMatch.Success) {
        $preservedProjectExtensions = $projectExtensionsMatch.Value.TrimEnd()
    }
}

if (Test-Path -LiteralPath $projectRoot) {
    Remove-Item -LiteralPath $projectRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $pouDir -Force | Out-Null
New-Item -ItemType Directory -Path $dutDir -Force | Out-Null

$compileItems = New-Object System.Collections.Generic.List[string]
$dutCompileItems = New-Object System.Collections.Generic.List[string]
$pouCompileItems = New-Object System.Collections.Generic.List[string]
$sourceFiles = Get-ChildItem -LiteralPath $plcSource -File -Filter "*.st" | Sort-Object Name

foreach ($file in $sourceFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw

    $typeMatches = [regex]::Matches($text, "(?ms)^\s*TYPE\s+([A-Za-z_][A-Za-z0-9_]*)\b.*?^\s*END_TYPE\s*;?")
    foreach ($match in $typeMatches) {
        $name = $match.Groups[1].Value
        $target = Join-Path $dutDir "$name.TcDUT"
        $declaration = ConvertTo-CDataSafe $match.Value
        $guid = New-TcGuid -Seed "DUT/$name"
        $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<TcPlcObject Version="1.1.0.1">
  <DUT Name="$name" Id="$guid">
    <Declaration><![CDATA[$declaration]]></Declaration>
  </DUT>
</TcPlcObject>
"@
        Set-Content -LiteralPath $target -Value $xml -Encoding UTF8
        $dutCompileItems.Add("DUTs\$name.TcDUT")
    }

    $pouMatches = @()
    $pouMatches += [regex]::Matches($text, "(?ms)^\s*PROGRAM\s+([A-Za-z_][A-Za-z0-9_]*)\b.*?^\s*END_PROGRAM\s*;?")
    $pouMatches += [regex]::Matches($text, "(?ms)^\s*FUNCTION_BLOCK\s+([A-Za-z_][A-Za-z0-9_]*)\b.*?^\s*END_FUNCTION_BLOCK\s*;?")
    $pouMatches += [regex]::Matches($text, "(?ms)^\s*FUNCTION\s+([A-Za-z_][A-Za-z0-9_]*)\b.*?^\s*END_FUNCTION\s*;?")
    $pouMatches = $pouMatches | Sort-Object Index

    foreach ($match in $pouMatches) {
        $name = $match.Groups[1].Value
        $endKeyword = "END_FUNCTION"
        if ($match.Value -match "(?im)^\s*FUNCTION_BLOCK\s+") {
            $endKeyword = "END_FUNCTION_BLOCK"
        }
        elseif ($match.Value -match "(?im)^\s*PROGRAM\s+") {
            $endKeyword = "END_PROGRAM"
        }

        $parts = Split-PouBlock -Block $match.Value -EndKeyword $endKeyword
        $declaration = ConvertTo-CDataSafe $parts.Declaration
        $implementation = ConvertTo-CDataSafe $parts.Implementation
        $guid = New-TcGuid -Seed "POU/$name"
        $target = Join-Path $pouDir "$name.TcPOU"
        $xml = New-TcPouXml -Name $name -Declaration $declaration -Implementation $implementation -Guid $guid
        Set-Content -LiteralPath $target -Value $xml -Encoding UTF8
        $pouCompileItems.Add("POUs\$name.TcPOU")
    }
}

$taskGuid = New-TcGuid -Seed "Task/PlcTask"
$taskFbGuid = New-TcGuid -Seed "Task/PlcTask/TaskFB"
$fbInitGuid = New-TcGuid -Seed "Task/PlcTask/FbInit"
$fbExitGuid = New-TcGuid -Seed "Task/PlcTask/FbExit"
$cycleUpdateGuid = New-TcGuid -Seed "Task/PlcTask/CycleUpdate"
$postCycleUpdateGuid = New-TcGuid -Seed "Task/PlcTask/PostCycleUpdate"
$taskXml = @"
<?xml version="1.0" encoding="utf-8"?>
<TcPlcObject Version="1.1.0.1">
  <Task Name="PlcTask" Id="$taskGuid">
    <!--CycleTime in micro seconds.-->
    <CycleTime>10000</CycleTime>
    <Priority>20</Priority>
    <PouCall>
      <Name>Main</Name>
    </PouCall>
    <TaskFBGuid>$taskFbGuid</TaskFBGuid>
    <Fb_init>$fbInitGuid</Fb_init>
    <Fb_exit>$fbExitGuid</Fb_exit>
    <CycleUpdate>$cycleUpdateGuid</CycleUpdate>
    <PostCycleUpdate>$postCycleUpdateGuid</PostCycleUpdate>
    <ObjectProperties />
  </Task>
</TcPlcObject>
"@
Set-Content -LiteralPath (Join-Path $projectRoot "PlcTask.TcTTO") -Value $taskXml -Encoding UTF8

$projectGuid = New-TcGuid -Seed "PLCProject/$ProjectName"
$systemGuid = New-TcGuid -Seed "SystemProject/$RuntimeName"
$solutionGuid = New-TcGuid -Seed "Solution/$SolutionName"
$applicationGuid = New-TcGuid -Seed "PLCProject/$ProjectName/Application"
$typeSystemGuid = New-TcGuid -Seed "PLCProject/$ProjectName/TypeSystem"
$taskInfoGuid = New-TcGuid -Seed "PLCProject/$ProjectName/ImplicitTaskInfo"
$kindOfTaskGuid = New-TcGuid -Seed "PLCProject/$ProjectName/ImplicitKindOfTask"
$jitterGuid = New-TcGuid -Seed "PLCProject/$ProjectName/ImplicitJitterDistribution"
$libraryGuid = New-TcGuid -Seed "PLCProject/$ProjectName/LibraryReferences"
$compileItems.AddRange($dutCompileItems)
$compileItems.AddRange($pouCompileItems)
$compileXml = ($compileItems | ForEach-Object {
    "    <Compile Include=""$_"">`r`n      <SubType>Code</SubType>`r`n    </Compile>"
}) -join "`r`n"
$projectExtensionsXml = ""
if (-not [string]::IsNullOrWhiteSpace($preservedProjectExtensions)) {
    $projectExtensionsXml = "`r`n$preservedProjectExtensions"
}

$plcProj = @"
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <FileVersion>1.0.0.0</FileVersion>
    <SchemaVersion>2.0</SchemaVersion>
    <ProjectGuid>$projectGuid</ProjectGuid>
    <SubObjectsSortedByName>True</SubObjectsSortedByName>
    <DownloadApplicationInfo>true</DownloadApplicationInfo>
    <WriteProductVersion>true</WriteProductVersion>
    <GenerateTpy>false</GenerateTpy>
    <Name>$ProjectName</Name>
    <ProgramVersion>3.1.4024.0</ProgramVersion>
    <Application>$applicationGuid</Application>
    <TypeSystem>$typeSystemGuid</TypeSystem>
    <Implicit_Task_Info>$taskInfoGuid</Implicit_Task_Info>
    <Implicit_KindOfTask>$kindOfTaskGuid</Implicit_KindOfTask>
    <Implicit_Jitter_Distribution>$jitterGuid</Implicit_Jitter_Distribution>
    <LibraryReferences>$libraryGuid</LibraryReferences>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="PlcTask.TcTTO">
      <SubType>Code</SubType>
    </Compile>
$compileXml
  </ItemGroup>
  <ItemGroup>
    <Folder Include="DUTs" />
    <Folder Include="GVLs" />
    <Folder Include="VISUs" />
    <Folder Include="POUs" />
  </ItemGroup>
  <ItemGroup>
    <PlaceholderReference Include="Tc2_Standard">
      <DefaultResolution>Tc2_Standard, * (Beckhoff Automation GmbH)</DefaultResolution>
      <Namespace>Tc2_Standard</Namespace>
    </PlaceholderReference>
    <PlaceholderReference Include="Tc2_System">
      <DefaultResolution>Tc2_System, * (Beckhoff Automation GmbH)</DefaultResolution>
      <Namespace>Tc2_System</Namespace>
    </PlaceholderReference>
    <PlaceholderReference Include="Tc3_Module">
      <DefaultResolution>Tc3_Module, * (Beckhoff Automation GmbH)</DefaultResolution>
      <Namespace>Tc3_Module</Namespace>
    </PlaceholderReference>
  </ItemGroup>$projectExtensionsXml
</Project>
"@

$projectPath = Join-Path $projectRoot "$ProjectName.plcproj"
Set-Content -LiteralPath $projectPath -Value $plcProj -Encoding UTF8

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$tsprojPath = Join-Path $runtimeRoot "$RuntimeName.tsproj"
$relativePlcProject = "..\$ProjectName\$ProjectName.plcproj"
$relativeTmc = "..\$ProjectName\$ProjectName.tmc"

$tsproj = @"
<?xml version="1.0"?>
<TcSmProject xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.beckhoff.com/schemas/2012/07/TcSmProject" TcSmVersion="1.0" TcVersion="3.1.4024.75">
  <DataTypes />
  <Project ProjectGUID="$systemGuid" Target64Bit="true" ShowHideConfigurations="#x6">
    <System>
      <Tasks>
        <Task Id="3" Priority="20" CycleTime="100000" AmsPort="350" AdtTasks="true">
          <Name>PlcTask</Name>
        </Task>
      </Tasks>
    </System>
    <Plc>
      <Project GUID="$projectGuid" Name="$ProjectName" PrjFilePath="$relativePlcProject" TmcFilePath="$relativeTmc" ReloadTmc="true" AmsPort="851" FileArchiveSettings="#x000e" SymbolicMapping="true">
        <Instance Id="#x08502040" TcSmClass="TComPlcObjDef" KeepUnrestoredLinks="2" TmcPath="$relativeTmc">
          <Name>$ProjectName Instance</Name>
          <CLSID ClassFactory="TcPlc30">{08500001-0000-0000-F000-000000000064}</CLSID>
          <Contexts>
            <Context>
              <Id>0</Id>
              <Name>PlcTask</Name>
              <ManualConfig>
                <OTCID>#x02010030</OTCID>
              </ManualConfig>
              <Priority>20</Priority>
              <CycleTime>10000000</CycleTime>
            </Context>
          </Contexts>
          <TaskPouOids>
            <TaskPouOid Prio="20" OTCID="#x08502041" />
          </TaskPouOids>
        </Instance>
      </Project>
    </Plc>
  </Project>
</TcSmProject>
"@
Set-Content -LiteralPath $tsprojPath -Value $tsproj -Encoding UTF8

$solutionRelativeTsproj = "RuntimeSystem\$RuntimeName.tsproj"
$solutionPath = Join-Path $outRoot "$SolutionName.sln"
$solution = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# TcXaeShell Solution File, Format Version 11.00
VisualStudioVersion = 15.0.35826.109
MinimumVisualStudioVersion = 10.0.40219.1
Project("{B1E792BE-AA5F-4E3C-8C82-674BF9C0715B}") = "$RuntimeName", "$solutionRelativeTsproj", "$systemGuid"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|TwinCAT RT (x64) = Debug|TwinCAT RT (x64)
		Release|TwinCAT RT (x64) = Release|TwinCAT RT (x64)
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		${systemGuid}.Debug|TwinCAT RT (x64).ActiveCfg = Debug|TwinCAT RT (x64)
		${systemGuid}.Debug|TwinCAT RT (x64).Build.0 = Debug|TwinCAT RT (x64)
		${systemGuid}.Release|TwinCAT RT (x64).ActiveCfg = Release|TwinCAT RT (x64)
		${systemGuid}.Release|TwinCAT RT (x64).Build.0 = Release|TwinCAT RT (x64)
		${projectGuid}.Debug|TwinCAT RT (x64).ActiveCfg = Debug|TwinCAT RT (x64)
		${projectGuid}.Debug|TwinCAT RT (x64).Build.0 = Debug|TwinCAT RT (x64)
		${projectGuid}.Release|TwinCAT RT (x64).ActiveCfg = Release|TwinCAT RT (x64)
		${projectGuid}.Release|TwinCAT RT (x64).Build.0 = Release|TwinCAT RT (x64)
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
	GlobalSection(ExtensibilityGlobals) = postSolution
		SolutionGuid = $solutionGuid
	EndGlobalSection
EndGlobal
"@
Set-Content -LiteralPath $solutionPath -Value $solution -Encoding UTF8

[PSCustomObject]@{
    ProjectPath = $projectPath
    SystemPath  = $tsprojPath
    SolutionPath = $solutionPath
    PouCount    = ($compileItems | Where-Object { $_ -like "POUs\*" }).Count
    DutCount    = ($compileItems | Where-Object { $_ -like "DUTs\*" }).Count
}
