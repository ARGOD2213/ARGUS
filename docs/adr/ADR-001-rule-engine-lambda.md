# ADR-001: Rule Engine Runs on AWS Lambda

- Status: Accepted
- Date: 2026-03-11

## Context

EC2 dashboards are intentionally start/stop for cost control. If the rule engine runs on EC2, alerts stop whenever EC2 is off.

## Decision

Run the rule engine on AWS Lambda, triggered by SQS (`iot-events.fifo`), with SNS (`iot-alerts`) for notifications.

## Consequences

- Pros:
  - Safety alerts continue even when EC2 is stopped.
  - Cost remains near-zero when idle.
  - Scales automatically for burst event loads.
- Cons:
  - Requires separate deployment flow for Lambda rules/config.
  - Requires DLQ monitoring and dedup table setup.
