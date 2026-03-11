param(
    [string]$InputCsvPath = "C:\Users\pavan\Desktop\ARGODREIGN\data\industrial_dummy_1gb.csv",
    [string]$OutputRoot = "C:\Users\pavan\Desktop\ARGODREIGN\data\partitioned\sensor_events",
    [long]$MaxRows = 0,
    [int]$MaxOpenWriters = 40,
    [switch]$UploadToS3,
    [string]$BucketName = "iot-alert-engine-mahindra",
    [string]$S3Prefix = "data/partitioned/sensor_events/",
    [string]$Region = "ap-south-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputCsvPath)) {
    throw "Input CSV not found: $InputCsvPath"
}

Add-Type -AssemblyName Microsoft.VisualBasic

function Convert-ToCsvField {
    param($value)
    if ($null -eq $value) { return "" }
    $text = [string]$value
    if ($text.Contains('"')) { $text = $text.Replace('"', '""') }
    if ($text.Contains(',') -or $text.Contains('"') -or $text.Contains("`n") -or $text.Contains("`r")) {
        return '"' + $text + '"'
    }
    return $text
}

function Sanitize-PartitionValue {
    param([string]$v)
    if ([string]::IsNullOrWhiteSpace($v)) { return "unknown" }
    $x = $v.Trim().ToLowerInvariant()
    $x = [regex]::Replace($x, "[^a-z0-9_\-]", "_")
    if ([string]::IsNullOrWhiteSpace($x)) { return "unknown" }
    return $x
}

if (Test-Path $OutputRoot) {
    Remove-Item -Recurse -Force $OutputRoot
}
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

$parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($InputCsvPath)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

$writers = @{}
$writerLastUsed = @{}

function Close-LeastRecentlyUsedWriter {
    param(
        [hashtable]$Writers,
        [hashtable]$WriterLastUsed
    )

    if ($Writers.Count -eq 0) { return }
    $oldest = $WriterLastUsed.GetEnumerator() | Sort-Object Value | Select-Object -First 1
    if ($null -ne $oldest) {
        $key = [string]$oldest.Key
        $Writers[$key].Flush()
        $Writers[$key].Dispose()
        $Writers.Remove($key)
        $WriterLastUsed.Remove($key)
    }
}

function Get-PartitionWriter {
    param(
        [string]$FilePath,
        [string]$HeaderLine,
        [hashtable]$Writers,
        [hashtable]$WriterLastUsed,
        [int]$MaxOpen
    )

    if ($Writers.ContainsKey($FilePath)) {
        $WriterLastUsed[$FilePath] = [DateTime]::UtcNow.Ticks
        return $Writers[$FilePath]
    }

    if ($Writers.Count -ge $MaxOpen) {
        Close-LeastRecentlyUsedWriter -Writers $Writers -WriterLastUsed $WriterLastUsed
    }

    $dir = [System.IO.Path]::GetDirectoryName($FilePath)
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $fileExists = Test-Path $FilePath
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $sw = [System.IO.StreamWriter]::new($FilePath, $true, $encoding, 65536)
    if (-not $fileExists -or (Get-Item $FilePath).Length -eq 0) {
        $sw.WriteLine($HeaderLine)
    }

    $Writers[$FilePath] = $sw
    $WriterLastUsed[$FilePath] = [DateTime]::UtcNow.Ticks
    return $sw
}

$stats = [ordered]@{
    rows_read = 0
    rows_written = 0
    rows_skipped_invalid_ts = 0
    rows_with_column_mismatch = 0
    partitions_created = 0
}

$partitionSet = New-Object 'System.Collections.Generic.HashSet[string]'

try {
    $headers = $parser.ReadFields()
    if (-not $headers -or $headers.Count -eq 0) {
        throw "CSV header missing"
    }

    $headerIndex = @{}
    for ($i = 0; $i -lt $headers.Count; $i++) {
        $headerIndex[[string]$headers[$i]] = $i
    }

    if (-not $headerIndex.ContainsKey("timestamp")) {
        throw "Required source column missing: timestamp"
    }
    if (-not $headerIndex.ContainsKey("machine_class")) {
        throw "Required source column missing: machine_class"
    }

    $machineClassSource = "machine_class"

    $outputColumns = @()
    foreach ($h in $headers) {
        if ([string]$h -ne "machine_class") {
            $outputColumns += [string]$h
        }
    }
    $headerOut = ($outputColumns | ForEach-Object { Convert-ToCsvField $_ }) -join ","

    while (-not $parser.EndOfData) {
        $fields = $parser.ReadFields()
        if ($null -eq $fields) { continue }

        $stats.rows_read++
        if ($MaxRows -gt 0 -and $stats.rows_read -gt $MaxRows) { break }

        if ($fields.Count -ne $headers.Count) {
            $stats.rows_with_column_mismatch++
        }

        $row = @{}
        $limit = [math]::Min($headers.Count, $fields.Count)
        for ($i = 0; $i -lt $limit; $i++) {
            $row[[string]$headers[$i]] = [string]$fields[$i]
        }

        $tsText = if ($row.ContainsKey("timestamp")) { [string]$row["timestamp"] } else { "" }
        [DateTimeOffset]$dto = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse($tsText, [ref]$dto)) {
            $stats.rows_skipped_invalid_ts++
            continue
        }

        $year = $dto.ToString("yyyy")
        $month = $dto.ToString("MM")
        $day = $dto.ToString("dd")

        $machineClassRaw = if ($machineClassSource -and $row.ContainsKey($machineClassSource)) { [string]$row[$machineClassSource] } else { "unknown" }
        $machineClassPart = Sanitize-PartitionValue -v $machineClassRaw

        $partitionPath = Join-Path $OutputRoot ("year={0}\month={1}\day={2}\machine_class={3}" -f $year, $month, $day, $machineClassPart)
        $filePath = Join-Path $partitionPath "data.csv"

        if (-not $partitionSet.Contains($partitionPath)) {
            $partitionSet.Add($partitionPath) | Out-Null
            $stats.partitions_created++
        }

        $writer = Get-PartitionWriter -FilePath $filePath -HeaderLine $headerOut -Writers $writers -WriterLastUsed $writerLastUsed -MaxOpen $MaxOpenWriters

        $vals = @()
        foreach ($c in $outputColumns) {
            if ($row.ContainsKey($c)) {
                $vals += $row[$c]
            }
            else {
                $vals += ""
            }
        }
        $line = ($vals | ForEach-Object { Convert-ToCsvField $_ }) -join ","
        $writer.WriteLine($line)

        $stats.rows_written++

        if (($stats.rows_read % 200000) -eq 0) {
            Write-Host ("Rows read: {0:N0}, written: {1:N0}, partitions: {2:N0}" -f $stats.rows_read, $stats.rows_written, $stats.partitions_created)
        }
    }
}
finally {
    foreach ($w in $writers.Values) {
        $w.Flush()
        $w.Dispose()
    }
    $parser.Close()
}

$manifest = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    input_csv = $InputCsvPath
    output_root = $OutputRoot
    max_rows = $MaxRows
    stats = $stats
}
$manifestPath = Join-Path $OutputRoot "partition_manifest.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "Partitioning complete"
Write-Host ("Output root: {0}" -f $OutputRoot)
Write-Host ("Rows written: {0:N0}" -f $stats.rows_written)
Write-Host ("Partitions: {0:N0}" -f $stats.partitions_created)
Write-Host ("Manifest: {0}" -f $manifestPath)

if ($UploadToS3) {
    if (-not $S3Prefix.EndsWith('/')) { $S3Prefix = "$S3Prefix/" }
    $dest = "s3://$BucketName/$S3Prefix"
    Write-Host ("Syncing partitioned data to {0}" -f $dest)
    aws s3 sync "$OutputRoot" "$dest" --exclude "partition_manifest.json" --region "$Region"
    aws s3 cp "$manifestPath" "$($dest)partition_manifest.json" --region "$Region"
    Write-Host "S3 sync complete"
}
