param(
    [string]$Region = "ap-south-1",
    [string]$Database = "argodreign_analytics",
    [string]$Table = "sensor_events_partitioned",
    [string]$DataLocation = "s3://iot-alert-engine-mahindra/data/partitioned/sensor_events/",
    [string]$AthenaResults = "s3://iot-alert-engine-mahindra/athena-results/",
    [switch]$DropTable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-AthenaQuery {
    param(
        [Parameter(Mandatory = $true)] [string]$Query,
        [Parameter(Mandatory = $true)] [string]$Region,
        [Parameter(Mandatory = $true)] [string]$OutputLocation,
        [string]$Database
    )

    $ctxArg = @()
    if ($Database -and $Database.Trim().Length -gt 0) {
        $ctxArg = @("--query-execution-context", "Database=$Database")
    }

    $tmpSql = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".sql")
    [System.IO.File]::WriteAllText($tmpSql, $Query, [System.Text.UTF8Encoding]::new($false))

    try {
        $startArgs = @(
            "athena", "start-query-execution",
            "--query-string", "file://$tmpSql",
            "--result-configuration", "OutputLocation=$OutputLocation",
            "--region", $Region,
            "--output", "json"
        ) + $ctxArg

        $startJson = & aws @startArgs
        $startObj = $startJson | ConvertFrom-Json
        if (-not $startObj) {
            throw "Failed to parse Athena start-query response: $startJson"
        }
        $qid = $startObj.QueryExecutionId
        if (-not $qid) {
            throw "Failed to start Athena query."
        }

        while ($true) {
            Start-Sleep -Seconds 2
            $execJson = aws athena get-query-execution --query-execution-id $qid --region $Region --output json
            $execObj = $execJson | ConvertFrom-Json
            $state = $execObj.QueryExecution.Status.State
            if ($state -in @("SUCCEEDED", "FAILED", "CANCELLED")) {
                if ($state -ne "SUCCEEDED") {
                    $reason = $execObj.QueryExecution.Status.StateChangeReason
                    throw "Athena query $qid failed with state $state. Reason: $reason"
                }
                return $qid
            }
        }
    }
    finally {
        if (Test-Path $tmpSql) {
            Remove-Item $tmpSql -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not $DataLocation.EndsWith("/")) { $DataLocation = "$DataLocation/" }
if (-not $AthenaResults.EndsWith("/")) { $AthenaResults = "$AthenaResults/" }

Write-Host "Setting up Athena partitioned table..."
Write-Host "Region: $Region"
Write-Host "Database: $Database"
Write-Host "Table: $Table"
Write-Host "Data location: $DataLocation"
Write-Host "Results location: $AthenaResults"

$null = aws s3 ls $AthenaResults --region $Region

$qCreateDb = "CREATE DATABASE IF NOT EXISTS $Database"
$qidDb = Invoke-AthenaQuery -Query $qCreateDb -Region $Region -OutputLocation $AthenaResults
Write-Host "Database ensured. QueryExecutionId: $qidDb"

if ($DropTable) {
    $qDrop = "DROP TABLE IF EXISTS $Database.$Table"
    $qidDrop = Invoke-AthenaQuery -Query $qDrop -Region $Region -OutputLocation $AthenaResults -Database $Database
    Write-Host "Dropped table (if existed). QueryExecutionId: $qidDrop"
}

$qCreateTable = @"
CREATE EXTERNAL TABLE IF NOT EXISTS $Database.$Table (
  event_id BIGINT,
  event_timestamp STRING,
  facility_id STRING,
  area STRING,
  cell_name STRING,
  machine_id STRING,
  product_stream STRING,
  sensor_type STRING,
  sensor_category STRING,
  unit STRING,
  value DOUBLE,
  status STRING,
  warning_threshold DOUBLE,
  critical_threshold DOUBLE,
  min_value DOUBLE,
  max_value DOUBLE,
  avg_value DOUBLE,
  delta_from_previous DOUBLE,
  weather_temp_c DOUBLE,
  weather_humidity_pct DOUBLE,
  weather_condition STRING,
  weather_wind_speed_ms DOUBLE,
  weather_correlation_note STRING,
  weather_alert_active BOOLEAN,
  ai_risk_score INT,
  ai_risk_level STRING,
  llm_consensus STRING,
  ai_incident_summary STRING,
  ai_recommended_action STRING,
  ai_predicted_failure_eta STRING,
  sns_message_id STRING,
  sqs_message_id STRING,
  latitude DOUBLE,
  longitude DOUBLE
)
PARTITIONED BY (
  year STRING,
  month STRING,
  day STRING,
  machine_class STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar' = '"'
)
STORED AS TEXTFILE
LOCATION '$DataLocation'
TBLPROPERTIES (
  'skip.header.line.count' = '1'
)
"@

$qidTable = Invoke-AthenaQuery -Query $qCreateTable -Region $Region -OutputLocation $AthenaResults -Database $Database
Write-Host "Table ensured. QueryExecutionId: $qidTable"

$qRepair = "MSCK REPAIR TABLE $Database.$Table"
$qidRepair = Invoke-AthenaQuery -Query $qRepair -Region $Region -OutputLocation $AthenaResults -Database $Database
Write-Host "Partition metadata repaired. QueryExecutionId: $qidRepair"

$qValidate = @"
SELECT
  year,
  month,
  day,
  machine_class,
  COUNT(*) AS row_count,
  MIN(event_timestamp) AS min_ts,
  MAX(event_timestamp) AS max_ts
FROM $Database.$Table
GROUP BY year, month, day, machine_class
ORDER BY row_count DESC
LIMIT 15
"@

$qidValidate = Invoke-AthenaQuery -Query $qValidate -Region $Region -OutputLocation $AthenaResults -Database $Database
Write-Host "Validation query executed. QueryExecutionId: $qidValidate"

Write-Host ""
Write-Host "Athena partitioned setup complete."
Write-Host "Run in Athena console:"
Write-Host "SELECT * FROM $Database.$Table WHERE year='2026' AND month='03' AND machine_class='compressor' LIMIT 20;"
