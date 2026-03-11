param(
    [string]$CsvPath = "C:\Users\pavan\Desktop\ARGODREIGN\data\industrial_dummy_1gb.csv",
    [string]$SchemaPath = "C:\Users\pavan\Desktop\ARGODREIGN\docs\schema\sensor_event_schema.json",
    [string]$GapReportPath = "C:\Users\pavan\Desktop\ARGODREIGN\docs\schema\gaps.md",
    [string]$SummaryJsonPath = "C:\Users\pavan\Desktop\ARGODREIGN\docs\schema\validation_summary.json",
    [long]$MaxRows = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}
if (-not (Test-Path $SchemaPath)) {
    throw "Schema file not found: $SchemaPath"
}

Add-Type -AssemblyName Microsoft.VisualBasic

$schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json
$validSensorTypes = @($schema.properties.sensor_type.enum)
$validSeverities = @($schema.properties.alert_severity.enum)
$validQuality = @($schema.properties.quality_tag.enum)

$aliasMap = @{
    timestamp_epoch = @("timestamp")
    machine_id = @("machine_id", "deviceId")
    machine_class = @("machine_class")
    sensor_type = @("sensor_type", "sensorType")
    sensor_value = @("value")
    sensor_unit = @("unit")
    quality_tag = @("quality_tag")
    plant_zone = @("area", "location")
    alert_severity = @("status")
}

function Get-FirstPresentAlias {
    param(
        [hashtable]$Row,
        [string[]]$Aliases
    )
    foreach ($a in $Aliases) {
        if ($Row.ContainsKey($a) -and -not [string]::IsNullOrWhiteSpace([string]$Row[$a])) {
            return [string]$Row[$a]
        }
    }
    return ""
}

function Add-IssueSample {
    param(
        [System.Collections.Generic.List[string]]$Samples,
        [string]$Message
    )
    if ($Samples.Count -lt 30) {
        $Samples.Add($Message) | Out-Null
    }
}

$stats = [ordered]@{
    total_rows = 0
    row_length_mismatch = 0
    invalid_timestamp = 0
    missing_machine_id = 0
    missing_machine_class = 0
    invalid_sensor_type = 0
    invalid_sensor_value = 0
    missing_sensor_unit = 0
    missing_plant_zone = 0
    invalid_alert_severity = 0
    invalid_quality_tag = 0
    quality_tag_defaulted = 0
}

$severityCounts = @{}
$sensorCounts = @{}
$missingAliasForField = @()
$samples = New-Object 'System.Collections.Generic.List[string]'

$parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($CsvPath)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

try {
    $headers = $parser.ReadFields()
    if (-not $headers -or $headers.Count -eq 0) {
        throw "CSV header missing"
    }

    $headerLookup = @{}
    foreach ($h in $headers) {
        $headerLookup[[string]$h] = $true
    }

    foreach ($canonical in $aliasMap.Keys) {
        $aliases = $aliasMap[$canonical]
        $present = $false
        foreach ($a in $aliases) {
            if ($headerLookup.ContainsKey($a)) {
                $present = $true
                break
            }
        }
        if (-not $present) {
            $missingAliasForField += $canonical
        }
    }

    while (-not $parser.EndOfData) {
        $fields = $parser.ReadFields()
        if ($null -eq $fields) {
            continue
        }

        $stats.total_rows++
        if ($MaxRows -gt 0 -and $stats.total_rows -gt $MaxRows) {
            break
        }

        if ($fields.Count -ne $headers.Count) {
            $stats.row_length_mismatch++
            Add-IssueSample -Samples $samples -Message ("Row {0}: column mismatch (expected {1}, got {2})" -f $stats.total_rows, $headers.Count, $fields.Count)
        }

        $row = @{}
        $limit = [math]::Min($headers.Count, $fields.Count)
        for ($i = 0; $i -lt $limit; $i++) {
            $row[[string]$headers[$i]] = [string]$fields[$i]
        }

        $timestampText = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.timestamp_epoch
        $machineId = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.machine_id
        $machineClass = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.machine_class
        $sensorType = (Get-FirstPresentAlias -Row $row -Aliases $aliasMap.sensor_type).ToUpperInvariant()
        $sensorValueText = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.sensor_value
        $sensorUnit = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.sensor_unit
        $qualityTag = (Get-FirstPresentAlias -Row $row -Aliases $aliasMap.quality_tag).ToUpperInvariant()
        $plantZone = Get-FirstPresentAlias -Row $row -Aliases $aliasMap.plant_zone
        $severity = (Get-FirstPresentAlias -Row $row -Aliases $aliasMap.alert_severity).ToUpperInvariant()

        if ([string]::IsNullOrWhiteSpace($qualityTag)) {
            $qualityTag = "GOOD"
            $stats.quality_tag_defaulted++
        }
        if ([string]::IsNullOrWhiteSpace($severity)) {
            $severity = "NORMAL"
        }

        [DateTimeOffset]$parsedTs = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse($timestampText, [ref]$parsedTs)) {
            $stats.invalid_timestamp++
            Add-IssueSample -Samples $samples -Message ("Row {0}: invalid timestamp '{1}'" -f $stats.total_rows, $timestampText)
        }

        if ([string]::IsNullOrWhiteSpace($machineId)) {
            $stats.missing_machine_id++
            Add-IssueSample -Samples $samples -Message ("Row {0}: missing machine_id/deviceId" -f $stats.total_rows)
        }

        if ([string]::IsNullOrWhiteSpace($machineClass)) {
            $stats.missing_machine_class++
            Add-IssueSample -Samples $samples -Message ("Row {0}: missing machine_class" -f $stats.total_rows)
        }

        if ([string]::IsNullOrWhiteSpace($sensorType) -or ($validSensorTypes -notcontains $sensorType)) {
            $stats.invalid_sensor_type++
            Add-IssueSample -Samples $samples -Message ("Row {0}: invalid sensor_type '{1}'" -f $stats.total_rows, $sensorType)
        }

        [double]$sensorValue = 0
        if (-not [double]::TryParse($sensorValueText, [ref]$sensorValue)) {
            $stats.invalid_sensor_value++
            Add-IssueSample -Samples $samples -Message ("Row {0}: invalid sensor_value '{1}'" -f $stats.total_rows, $sensorValueText)
        }

        if ([string]::IsNullOrWhiteSpace($sensorUnit)) {
            $stats.missing_sensor_unit++
            Add-IssueSample -Samples $samples -Message ("Row {0}: missing sensor_unit" -f $stats.total_rows)
        }

        if ([string]::IsNullOrWhiteSpace($plantZone)) {
            $stats.missing_plant_zone++
            Add-IssueSample -Samples $samples -Message ("Row {0}: missing plant_zone (area/location)" -f $stats.total_rows)
        }

        if ($validSeverities -notcontains $severity) {
            $stats.invalid_alert_severity++
            Add-IssueSample -Samples $samples -Message ("Row {0}: invalid alert_severity/status '{1}'" -f $stats.total_rows, $severity)
        }

        if ($validQuality -notcontains $qualityTag) {
            $stats.invalid_quality_tag++
            Add-IssueSample -Samples $samples -Message ("Row {0}: invalid quality_tag '{1}'" -f $stats.total_rows, $qualityTag)
        }

        if (-not $severityCounts.ContainsKey($severity)) { $severityCounts[$severity] = 0 }
        $severityCounts[$severity]++

        if (-not [string]::IsNullOrWhiteSpace($sensorType)) {
            if (-not $sensorCounts.ContainsKey($sensorType)) { $sensorCounts[$sensorType] = 0 }
            $sensorCounts[$sensorType]++
        }
    }
}
finally {
    $parser.Close()
}

$totalIssues = ($stats.invalid_timestamp + $stats.missing_machine_id + $stats.missing_machine_class +
    $stats.invalid_sensor_type + $stats.invalid_sensor_value + $stats.missing_sensor_unit +
    $stats.missing_plant_zone + $stats.invalid_alert_severity + $stats.invalid_quality_tag +
    $stats.row_length_mismatch)

$coveragePct = if ($stats.total_rows -gt 0) {
    [math]::Round((($stats.total_rows - $totalIssues) / $stats.total_rows) * 100, 2)
} else {
    0
}

$topSensors = $sensorCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10
$severityOrder = @("CRITICAL", "WARNING", "NORMAL")

$md = New-Object System.Text.StringBuilder
$null = $md.AppendLine("# Schema Validation Gaps")
$null = $md.AppendLine("")
$null = $md.AppendLine("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')")
$null = $md.AppendLine("- CSV: $CsvPath")
$null = $md.AppendLine("- Schema: $SchemaPath")
$null = $md.AppendLine("- Rows validated: **$($stats.total_rows)**")
$null = $md.AppendLine("- Validation coverage score: **$coveragePct%**")
$null = $md.AppendLine("")

$null = $md.AppendLine("## Canonical Field Mapping Coverage")
if ($missingAliasForField.Count -eq 0) {
    $null = $md.AppendLine("All required canonical fields have at least one source column alias present.")
} else {
    $null = $md.AppendLine("Missing source aliases for canonical fields:")
    foreach ($f in $missingAliasForField) {
        $null = $md.AppendLine("- $f")
    }
}
$null = $md.AppendLine("")

$null = $md.AppendLine("## Validation Summary")
$null = $md.AppendLine("| Metric | Count |")
$null = $md.AppendLine("|---|---:|")
foreach ($k in $stats.Keys) {
    $null = $md.AppendLine("| $k | $($stats[$k]) |")
}
$null = $md.AppendLine("")

$null = $md.AppendLine("## Severity Distribution")
$null = $md.AppendLine("| Severity | Count |")
$null = $md.AppendLine("|---|---:|")
foreach ($s in $severityOrder) {
    $count = if ($severityCounts.ContainsKey($s)) { $severityCounts[$s] } else { 0 }
    $null = $md.AppendLine("| $s | $count |")
}
$otherSev = $severityCounts.GetEnumerator() | Where-Object { $severityOrder -notcontains $_.Key }
foreach ($s in $otherSev) {
    $null = $md.AppendLine("| $($s.Key) | $($s.Value) |")
}
$null = $md.AppendLine("")

$null = $md.AppendLine("## Top Sensor Types (by row count)")
$null = $md.AppendLine("| Sensor Type | Count |")
$null = $md.AppendLine("|---|---:|")
foreach ($s in $topSensors) {
    $null = $md.AppendLine("| $($s.Key) | $($s.Value) |")
}
$null = $md.AppendLine("")

$null = $md.AppendLine("## Sample Issues")
if ($samples.Count -eq 0) {
    $null = $md.AppendLine("No row-level sample issues captured.")
} else {
    foreach ($sample in $samples) {
        $null = $md.AppendLine("- $sample")
    }
}
$null = $md.AppendLine("")

$null = $md.AppendLine("## Recommended Fixes")
$null = $md.AppendLine("1. Keep canonical output fields mandatory in all ingest/transformation stages.")
$null = $md.AppendLine("2. Enforce quoting for free-text CSV fields to avoid column drift.")
$null = $md.AppendLine("3. Add partition columns (year, month, day, machine_class) for Athena cost control.")
$null = $md.AppendLine("4. Do not route bulk raw data through live API path; use S3 + Athena for heavy analytics.")

$md.ToString() | Set-Content -Path $GapReportPath -Encoding UTF8

$summary = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    csv_path = $CsvPath
    schema_path = $SchemaPath
    rows_validated = $stats.total_rows
    validation_coverage_pct = $coveragePct
    missing_alias_fields = $missingAliasForField
    stats = $stats
    severity_distribution = $severityCounts
    top_sensor_types = ($topSensors | ForEach-Object { [ordered]@{ sensor_type = $_.Key; count = $_.Value } })
    sample_issues = $samples
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $SummaryJsonPath -Encoding UTF8

Write-Host "Validation complete"
Write-Host "Rows validated: $($stats.total_rows)"
Write-Host "Coverage: $coveragePct%"
Write-Host "Gap report: $GapReportPath"
Write-Host "Summary JSON: $SummaryJsonPath"
