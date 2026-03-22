# ARGUS Edge Layer - Hardware and Software Setup Guide
**Standard:** IEC 62443-3-3 Industrial Cybersecurity
**Estimated setup time:** 4-6 hours first time

## Hardware Requirements

| Component | Specification | Notes |
|-----------|---------------|-------|
| PC | Industrial fanless, DIN rail | Example: Advantech ARK series |
| CPU | Intel Core i3 or equivalent | Atom sufficient for demo |
| RAM | 8 GB minimum | 4 GB acceptable for demo |
| Storage | 64 GB SSD | For OS, agent, and 4-hour ring buffer |
| OS | Ubuntu 22.04 LTS | Tested and recommended |
| NIC 1 | OT network (isolated VLAN) | Read-only from historian |
| NIC 2 | IT network (internet access) | AWS endpoints only |

## Network Configuration

### OT NIC (eth0) - isolated

```bash
# /etc/network/interfaces or netplan
# Static IP on OT VLAN - no default gateway
address: 192.168.10.50/24
# No gateway entry - cannot route to internet
```

Firewall rules (iptables or ufw):

```bash
# Allow only from OPC-UA historian IP
ufw allow in on eth0 from 192.168.10.10 to any port 4840
ufw deny in on eth0
ufw deny out on eth0
```

### IT NIC (eth1) - AWS only

```bash
# DHCP from IT network
# Firewall: outbound to AWS endpoints only
ufw allow out on eth1 to 52.0.0.0/8
ufw allow out on eth1 to 54.0.0.0/8
ufw deny out on eth1
ufw deny in on eth1
```

## Software Installation

```bash
# 1. Update OS
sudo apt update && sudo apt upgrade -y

# 2. Install Python 3.12
sudo apt install python3.12 python3.12-venv python3-pip -y

# 3. Install Mosquitto MQTT broker
sudo apt install mosquitto mosquitto-clients -y
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# 4. Clone ARGUS repo (IT NIC only)
git clone https://github.com/ARGOD2213/ARGUS.git /opt/argus

# 5. Install edge agent dependencies
cd /opt/argus
pip3 install -r edge/agent/requirements.txt

# 6. Create runtime directories
sudo mkdir -p /var/argus
sudo chown $USER /var/argus

# 7. Create environment file (never commit this)
cat > /opt/argus/edge/.env << EOF
AWS_REGION=ap-south-1
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/061039801536/iot-events.fifo
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:061039801536:iot-alerts
AWS_ACCESS_KEY_ID=your_key_here
AWS_SECRET_ACCESS_KEY=your_secret_here
EDGE_ID=edge-argus-001
RING_BUFFER_PATH=/var/argus/ring_buffer.db
RULES_PATH=/opt/argus/lambda/rule_engine/config/rules.json
SCHEMA_PATH=/opt/argus/docs/schema/sensor_event_schema.json
EOF

# 8. Create systemd service for auto-start
sudo tee /etc/systemd/system/argus-edge.service << EOF
[Unit]
Description=ARGUS Edge Agent
After=network.target mosquitto.service

[Service]
User=$USER
WorkingDirectory=/opt/argus
EnvironmentFile=/opt/argus/edge/.env
ExecStart=/usr/bin/python3.12 -m edge.agent.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable argus-edge
sudo systemctl start argus-edge
```

## Verification Checklist

```bash
# Check agent is running
sudo systemctl status argus-edge

# Check edge log
tail -f /var/argus/edge.log

# Send a test MQTT event
mosquitto_pub -h localhost -t argus/sensors/COMP-01/vibration \
  -m '{"value":4.7,"unit":"mm/s"}'

# Check ring buffer has data
sqlite3 /var/argus/ring_buffer.db \
  "SELECT COUNT(*) FROM sensor_events WHERE replayed=0;"

# Verify heartbeat is reaching SNS/DynamoDB
# SNS topic iot-alerts should show recent EDGE_HEARTBEAT messages
# DynamoDB table iot-sensor-events should contain edge_heartbeat# records

# Check ops.html shows Edge Agent: ONLINE
# Open http://<S3-ops-url>/ops.html on phone
```

## IEC 62443 Compliance Verification

| Requirement | Implementation | Verified |
|-------------|----------------|----------|
| Zone separation | Dual NIC, no routing between OT and IT | [ ] |
| No write path to OT | Agent reads MQTT only, no OPC-UA write | [ ] |
| Encrypted comms | AWS SDK uses TLS to SQS/SNS/DynamoDB | [ ] |
| Access control | IAM role with least privilege | [ ] |
| Audit log | `/var/argus/edge.log` and local alert log | [ ] |
| Offline capability | Local rule engine and ring buffer | [ ] |
