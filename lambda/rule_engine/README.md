# ARGODREIGN Rule Engine Lambda

This Lambda evaluates incoming SQS sensor events using threshold rules from S3 and publishes WARNING/CRITICAL alerts to SNS.

## Runtime flow

1. SQS event arrives (`iot-events.fifo`)
2. Lambda loads rules from S3 (`config/rules.json`)
3. Matching rules are evaluated
4. Highest-severity match is selected
5. Alert is deduplicated via DynamoDB (`argodreign-dedup`)
6. Alert is published to SNS (`iot-alerts`)

## Files

- `handler.py`: Lambda handler
- `config/rules.json`: baseline rules
- `test_events/`: sample payloads for invoke testing
