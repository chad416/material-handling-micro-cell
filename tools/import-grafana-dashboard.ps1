param(
    [string]$GrafanaUrl = "http://localhost:3000",
    [string]$GrafanaUser = "admin",
    [string]$GrafanaPassword = "admin",
    [string]$InfluxUrl = $env:MHMC_INFLUX_URL,
    [string]$InfluxOrg = $env:MHMC_INFLUX_ORG,
    [string]$InfluxBucket = $env:MHMC_INFLUX_BUCKET,
    [string]$InfluxToken = $env:MHMC_INFLUX_TOKEN,
    [string]$DashboardPath = "scada\grafana\dashboards\mhmc-kpi-dashboard.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($InfluxUrl)) { throw "InfluxUrl is required. Set MHMC_INFLUX_URL or pass -InfluxUrl." }
if ([string]::IsNullOrWhiteSpace($InfluxOrg)) { throw "InfluxOrg is required. Set MHMC_INFLUX_ORG or pass -InfluxOrg." }
if ([string]::IsNullOrWhiteSpace($InfluxBucket)) { throw "InfluxBucket is required. Set MHMC_INFLUX_BUCKET or pass -InfluxBucket." }
if ([string]::IsNullOrWhiteSpace($InfluxToken)) { throw "InfluxToken is required. Set MHMC_INFLUX_TOKEN or pass -InfluxToken." }
if (-not (Test-Path -LiteralPath $DashboardPath)) { throw "Dashboard JSON not found: $DashboardPath" }

$pair = "{0}:{1}" -f $GrafanaUser, $GrafanaPassword
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $basic"
    Accept        = "application/json"
}

function Invoke-GrafanaApi {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )

    $uri = ($GrafanaUrl.TrimEnd("/") + $Path)
    $params = @{
        Method  = $Method
        Uri     = $uri
        Headers = $headers
    }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 100)
    }
    Invoke-RestMethod @params
}

Write-Host "Checking Grafana at $GrafanaUrl..."
Invoke-GrafanaApi -Method Get -Path "/api/health" | Out-Null

$datasource = @{
    name           = "InfluxDB-Flux"
    uid            = "influxdb_flux"
    type           = "influxdb"
    access         = "proxy"
    url            = $InfluxUrl
    isDefault      = $true
    jsonData       = @{
        version       = "Flux"
        organization  = $InfluxOrg
        defaultBucket = $InfluxBucket
    }
    secureJsonData = @{
        token = $InfluxToken
    }
}

try {
    Invoke-GrafanaApi -Method Get -Path "/api/datasources/uid/influxdb_flux" | Out-Null
    Write-Host "Updating existing InfluxDB-Flux datasource..."
    Invoke-GrafanaApi -Method Put -Path "/api/datasources/uid/influxdb_flux" -Body $datasource | Out-Null
} catch {
    Write-Host "Creating InfluxDB-Flux datasource..."
    Invoke-GrafanaApi -Method Post -Path "/api/datasources" -Body $datasource | Out-Null
}

$dashboard = Get-Content -LiteralPath $DashboardPath -Raw | ConvertFrom-Json
$dashboard.id = $null
$payload = @{
    dashboard = $dashboard
    overwrite = $true
    message   = "Import MHMC KPI and event dashboard"
}

Write-Host "Importing dashboard..."
$result = Invoke-GrafanaApi -Method Post -Path "/api/dashboards/db" -Body $payload
Write-Host ("Dashboard imported: {0}{1}" -f $GrafanaUrl.TrimEnd("/"), $result.url)
