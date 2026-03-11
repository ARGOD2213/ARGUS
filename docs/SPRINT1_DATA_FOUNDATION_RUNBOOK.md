# Sprint 1 Data Foundation Runbook (S1-01 + S1-02)

This runbook sets up the schema contract, validates the dataset, partitions CSV for low Athena cost, and creates the partitioned Athena table.

## 1) Validate CSV against canonical schema

```powershell
cd C:\Users\pavan\Desktop\ARGODREIGN
powershell -ExecutionPolicy Bypass -File .\scripts\validate-industrial-csv.ps1 `
  -CsvPath ".\data\industrial_dummy_1gb.csv" `
  -SchemaPath ".\docs\schema\sensor_event_schema.json"
```

Outputs:
- `docs/schema/gaps.md`
- `docs/schema/validation_summary.json`

## 2) Partition CSV by year/month/day/machine_class

```powershell
cd C:\Users\pavan\Desktop\ARGODREIGN
powershell -ExecutionPolicy Bypass -File .\scripts\partition-industrial-csv.ps1 `
  -InputCsvPath ".\data\industrial_dummy_1gb.csv" `
  -OutputRoot ".\data\partitioned\sensor_events"
```

To upload partitioned output directly to S3:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\partition-industrial-csv.ps1 `
  -InputCsvPath ".\data\industrial_dummy_1gb.csv" `
  -OutputRoot ".\data\partitioned\sensor_events" `
  -UploadToS3 `
  -BucketName "iot-alert-engine-mahindra" `
  -S3Prefix "data/partitioned/sensor_events/" `
  -Region "ap-south-1"
```

## 3) Create Athena partitioned table

```powershell
cd C:\Users\pavan\Desktop\ARGODREIGN
powershell -ExecutionPolicy Bypass -File .\scripts\setup-athena-partitioned.ps1 `
  -Region "ap-south-1" `
  -Database "argodreign_analytics" `
  -Table "sensor_events_partitioned" `
  -DataLocation "s3://iot-alert-engine-mahindra/data/partitioned/sensor_events/" `
  -AthenaResults "s3://iot-alert-engine-mahindra/athena-results/"
```

## 4) Verify partition pruning (cost control)

Use Athena:

```sql
SELECT count(*)
FROM argodreign_analytics.sensor_events_partitioned
WHERE year='2026' AND month='03' AND machine_class='compressor';
```

If partition filters are present, Athena scans much less data and stays within budget.

## Notes

- If your existing `industrial_dummy_1gb.csv` was generated before CSV-quote fix, regenerate it once using:
  - `scripts/generate-industrial-dump.ps1`
- Keep dashboard refresh intervals >= 5 minutes to avoid unnecessary Athena spend.
