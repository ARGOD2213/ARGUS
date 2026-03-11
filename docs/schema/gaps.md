# Schema Validation Gaps

- Generated at: 2026-03-11 11:42:24 +05:30
- CSV: C:\Users\pavan\Desktop\ARGODREIGN\data\industrial_dummy_1gb.csv
- Schema: C:\Users\pavan\Desktop\ARGODREIGN\docs\schema\sensor_event_schema.json
- Rows validated: **3100891**
- Validation coverage score: **96.53%**

## Canonical Field Mapping Coverage
Missing source aliases for canonical fields:
- quality_tag

## Validation Summary
| Metric | Count |
|---|---:|
| total_rows | 3100891 |
| row_length_mismatch | 107462 |
| invalid_timestamp | 0 |
| missing_machine_id | 0 |
| missing_machine_class | 0 |
| invalid_sensor_type | 0 |
| invalid_sensor_value | 0 |
| missing_sensor_unit | 0 |
| missing_plant_zone | 0 |
| invalid_alert_severity | 0 |
| invalid_quality_tag | 0 |
| quality_tag_defaulted | 3100891 |

## Severity Distribution
| Severity | Count |
|---|---:|
| CRITICAL | 107462 |
| WARNING | 356138 |
| NORMAL | 2637291 |

## Top Sensor Types (by row count)
| Sensor Type | Count |
|---|---:|
| POWER_CONSUMPTION | 393468 |
| POWER_FACTOR | 224837 |
| VOLTAGE | 224837 |
| TEMPERATURE | 215472 |
| GAS_LEAK | 196735 |
| SMOKE_DENSITY | 196735 |
| CHEMICAL_CONCENTRATION | 196735 |
| MOTOR_CURRENT | 187364 |
| OIL_PRESSURE | 187364 |
| BEARING_TEMPERATURE | 187364 |

## Sample Issues
- Row 52: column mismatch (expected 35, got 37)
- Row 71: column mismatch (expected 35, got 37)
- Row 120: column mismatch (expected 35, got 37)
- Row 145: column mismatch (expected 35, got 37)
- Row 183: column mismatch (expected 35, got 37)
- Row 266: column mismatch (expected 35, got 37)
- Row 369: column mismatch (expected 35, got 37)
- Row 440: column mismatch (expected 35, got 37)
- Row 513: column mismatch (expected 35, got 37)
- Row 529: column mismatch (expected 35, got 37)
- Row 538: column mismatch (expected 35, got 37)
- Row 550: column mismatch (expected 35, got 37)
- Row 591: column mismatch (expected 35, got 37)
- Row 642: column mismatch (expected 35, got 37)
- Row 658: column mismatch (expected 35, got 37)
- Row 711: column mismatch (expected 35, got 37)
- Row 712: column mismatch (expected 35, got 37)
- Row 730: column mismatch (expected 35, got 37)
- Row 773: column mismatch (expected 35, got 37)
- Row 817: column mismatch (expected 35, got 37)
- Row 924: column mismatch (expected 35, got 37)
- Row 931: column mismatch (expected 35, got 37)
- Row 938: column mismatch (expected 35, got 37)
- Row 956: column mismatch (expected 35, got 37)
- Row 976: column mismatch (expected 35, got 37)
- Row 1053: column mismatch (expected 35, got 37)
- Row 1071: column mismatch (expected 35, got 37)
- Row 1084: column mismatch (expected 35, got 37)
- Row 1153: column mismatch (expected 35, got 37)
- Row 1191: column mismatch (expected 35, got 37)

## Recommended Fixes
1. Keep canonical output fields mandatory in all ingest/transformation stages.
2. Enforce quoting for free-text CSV fields to avoid column drift.
3. Add partition columns (year, month, day, machine_class) for Athena cost control.
4. Do not route bulk raw data through live API path; use S3 + Athena for heavy analytics.

