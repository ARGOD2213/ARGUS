# ADR-004: Partitioned S3 + Athena for Raw Sensor Analytics

- Status: Accepted
- Date: 2026-03-11

## Context

Raw sensor-scale data in DynamoDB becomes expensive quickly for analytics-heavy dashboard refresh patterns.

## Decision

Store bulk sensor data in S3 and query through Athena using Hive partitions:

- `year=YYYY/month=MM/day=DD/machine_class=<class>/data.csv`

Use API-side caching to reduce repeated Athena scans.

## Consequences

- Pros:
  - Low cost at pilot scale.
  - Simple serverless analytics path.
  - Fast partition-pruned queries for dashboard aggregates.
- Cons:
  - Requires partition maintenance (`MSCK REPAIR TABLE` or Glue crawler).
  - Query performance depends on disciplined filtering.
