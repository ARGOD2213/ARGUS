# ARGUS Edge Agent

Event-driven local data processing for offline resilience
and real plant integration.

## What it does
- Reads sensor data from local MQTT broker
- Normalises raw events to the ARGUS canonical schema
- Buffers events locally in SQLite (4-hour ring buffer)
- Forwards events to AWS SQS when connected
- Runs a local rule engine when cloud forwarding is unavailable
- Sends a health beacon every 60 seconds for ops visibility

## Prerequisites
- Python 3.12+
- `pip install -r edge/agent/requirements.txt`
- MQTT broker running locally (for example, Mosquitto)
- AWS credentials with SQS send, SNS publish, and DynamoDB write permissions
- Network access to AWS SQS and SNS endpoints

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| AWS_REGION | Yes | Example: ap-south-1 |
| SQS_QUEUE_URL | Yes | `iot-events.fifo` URL |
| SNS_TOPIC_ARN | Yes | `iot-alerts` ARN |
| AWS_ACCESS_KEY_ID | Yes | IAM credentials |
| AWS_SECRET_ACCESS_KEY | Yes | IAM credentials |
| MQTT_HOST | No | Default: localhost |
| MQTT_PORT | No | Default: 1883 |
| MQTT_TOPIC | No | Default: `argus/sensors/#` |
| RING_BUFFER_PATH | No | Default: `/var/argus/ring_buffer.db` |
| RING_BUFFER_HOURS | No | Default: 4 |
| RULES_PATH | No | Path to `rules.json` |
| BEACON_INTERVAL_SEC | No | Default: 60 |
| EDGE_ID | No | Default: `edge-argus-001` |
| LOG_LEVEL | No | Default: INFO |
| LOG_PATH | No | Default: `/var/argus/edge.log` |

## Run

```bash
pip install -r edge/agent/requirements.txt
export AWS_REGION=ap-south-1
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/061039801536/iot-events.fifo
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:061039801536:iot-alerts
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
python -m edge.agent.main
```

## MQTT Payload Format

The agent accepts any of these payload formats:

**Format 1 - ARGUS canonical:**
```json
{
  "machine_id": "COMP-01",
  "sensor_type": "VIBRATION",
  "sensor_value": 4.7,
  "sensor_unit": "mm/s",
  "plant_zone": "Ammonia-Unit",
  "timestamp": 1711094400
}
```

**Format 2 - legacy deviceId style:**
```json
{
  "deviceId": "COMP-01",
  "sensorType": "vibration",
  "value": 4.7,
  "unit": "mm/s"
}
```

**Format 3 - topic-based (machine_id from topic):**

Topic: `argus/sensors/COMP-01/vibration`

```json
{"value": 4.7, "unit": "mm/s"}
```

## Architecture Note (ADR-001 + ADR-002)

The local rule engine is a fallback replica of the Lambda
rule engine. Lambda remains authoritative when cloud is available.
The edge agent has no write path to any PLC or field device.
It reads from MQTT (OT data) and writes to SQS/DynamoDB/SNS on the IT side.
