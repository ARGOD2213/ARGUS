# ADR-005: Edge Layer Architecture — IEC 62443-3-3 Cybersecurity

**Status:** IMPLEMENTED - Sprint 7 (edge agent deployed)  
**Date:** 2025-01-04  
**Sprint:** Sprint 6 (planning), Sprint 7 (implementation)  

---

## Problem Statement

Field devices (sensors, PLCs, RTUs) in industrial facilities are distributed across multiple locations, often in network-constrained or high-latency environments. Current architecture centralizes all computation on EC2 + Lambda, which:

1. Creates a single point of failure for rule evaluation
2. Increases cloud bandwidth costs (1000+ sensor streams × 1 second = 86M events/day)
3. Violates IEC 62443-3-3 requirement for local defensive depth
4. Makes local emergency shutdown dependent on cloud connectivity
5. Increases latency for time-critical alerts (e.g., CRITICAL temperature)

Required: A distributed edge layer that:
- Evaluates critical rules locally (subsecond response)
- Maintains offline autonomy (default-safe when cloud unreachable)
- Encrypts device-to-cloud communications (TLS 1.3)
- Implements strong device authentication (mTLS + TOFU)
- Provides local audit trail (immutable event log)

---

## Solution: Three-Layer Architecture

### Layer 1: Cloud Control Plane (Existing, No Change)
```
AWS EC2 t3.micro (Spring Boot 3.2)
  ├─ API/Dashboard: Strategic decisions, history query
  ├─ Rule definition: Update rules, push to edge
  ├─ Audit: Global compliance reporting, SIL governance
  └─ LLM advisory: AI analysis (Gemini)
```

### Layer 2: Edge Gateway (New)
**Deployment:** Single per facility (e.g., inside control room, on industrial DIN rail)  
**Hardware:** Raspberry Pi 4 (8GB RAM) or equivalent industrial PC  
**OS:** Ubuntu 22.04 LTS hardened + SELinux  
**Software Stack:**
- Node.js 20 LTS (lightweight rules)
- SQLite3 (local event log, 10GB storage)
- systemd (process management, auto-restart)
- nginx reverse proxy (TLS termination)

**Responsibilities:**
1. Rule caching (download from cloud every 5 minutes)
2. Critical alert sampling (CRITICAL only, to cloud every 10s)
3. Local shutdown trigger (if cloud unreachable >5 min AND temperature > critical)
4. Device credential management (OAuth2 / JWT renewal)
5. Offline queue (buffer events, replay when cloud returns)

**Network:** 
- Ethernet + WiFi backup
- Static route to cloud API Gateway
- No internet access except to cloud endpoint
- DMZ isolation (firewall rule: outbound HTTPS only to api.argus-iot.cloud)

### Layer 3: Sensor Devices (New)
**Types:** RTU, PLC, Smart sensor, Gateway  
**Authentication:** Pre-shared symmetric key OR mTLS certificate (X.509)  
**Communication:**
- Device → Gateway: MQTT TLS (port 8883) or CoAP DTLS (port 5684)
- Gateway → Cloud: HTTPS TLS 1.3 (mTLS + TOFU pinning)
- Device ← Gateway: MQTT broadcast (rule updates, commands)

---

## Technical Specification

### Edge Gateway Startup & Health

```bash
# Typical startup flow
1. systemd starts argus-edge service
2. Load cached rules from SQLite (rules table)
3. Connect to MQTT broker (localhost:1883)
4. Attempt cloud sync:
   - POST /api/v1/edge/register {device_id, hw_signature}
   - Receive JWT token (60-min expiry)
   - Download latest rules (GET /api/v1/edge/rules)
5. Start local MQTT listener (port 8883 TLS)
6. Begin rule evaluation loop
7. Health check every 30s:
   - Send heartbeat to cloud (200 OK = connected, else offline)
   - Update local status file (~/.argus/status.json)
   - If offline >5 min: set FAILSAFE=true in environment
```

### Rule Evaluation at Edge

**Rules stored as:**
```json
{
  "id": "RULE-MOTOR-01-TEMP",
  "device_id": "MOTOR-01",
  "trigger": {
    "metric": "temperature_celsius",
    "operator": "GT",
    "threshold": 85.0
  },
  "actions": [
    {
      "type": "LOCAL_RELAY",
      "relay_id": "CONTACTOR-01",
      "command": "OPEN"
    },
    {
      "type": "ALERT",
      "level": "CRITICAL",
      "message": "Motor overheat - emergency stop engaged"
    }
  ],
  "failsafe": "OPEN",
  "sil_level": 2,
  "modified_at": "2025-01-04T12:00:00Z",
  "signature": "sha256(rule_json + secret_key)"
}
```

**Local evaluation (pseudocode):**
```python
def evaluate_rule(rule, device_data, local_status):
    # Signature verification (prevent MITM)
    if not verify_signature(rule, cloud_signature):
        log_EVENT(SECURITY, "Invalid rule signature")
        return
    
    # Evaluate trigger condition
    if evaluate_condition(rule.trigger, device_data):
        # Execute local actions (relay, log)
        for action in rule.actions:
            if action.type == "LOCAL_RELAY":
                relay.set_state(action.relay_id, action.command)
            elif action.type == "ALERT":
                log_EVENT(action.level, action.message, rule.id)
        
        # Send to cloud (best-effort, non-blocking)
        send_alert_async(rule.id, device_data, timestamp=now)
    
    # Update last_evaluated timestamp
    rule.last_eval_at = now()
```

### Device ← Gateway Communication (MQTT)

**Topics:**
```
argus/gw/{gw_id}/rules/update       ← Gateway → Device (rule update)
argus/gw/{gw_id}/command/shutdown   ← Gateway → Device (emergency shutdown)
argus/device/{device_id}/telemetry  ← Device → Gateway (sensor data)
argus/device/{device_id}/events     ← Device → Gateway (abnormal events)
```

**Example payload (sensor telemetry):**
```json
{
  "device_id": "MOTOR-01",
  "timestamp": "2025-01-04T12:30:45.123Z",
  "sensor_data": {
    "temperature_celsius": 78.5,
    "vibration_mm_s": 2.3,
    "current_amps": 42.1
  },
  "sequence": 12450,
  "signature": "HMAC-SHA256(payload, device_key)"
}
```

### Gateway ← Cloud Communication (HTTPS)

**API Endpoints:**

```
POST   /api/v1/edge/register                  Handshake + JWT
POST   /api/v1/edge/heartbeat                 Keepalive (30s)
GET    /api/v1/edge/rules                     Download rules
POST   /api/v1/edge/events                    Batch event submission
GET    /api/v1/edge/commands                  Check for commands
POST   /api/v1/edge/offline-sync              Replay buffered events
PUT    /api/v1/edge/status                    Report edge health
```

**TLS Configuration:**
- Min version: TLS 1.3
- Cipher suites: TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256
- Certificate pinning: Store cloud cert fingerprint (public key pin set)
  ```
  pin-sha256="BASE64(SHA256(subject_public_key_info))";
  pin-sha256="BASE64(SHA256(backup_key))";
  max_age=86400; includeSubDomains
  ```
- Mutual TLS: Gateway cert signed by internal CA (not public CA)

### Offline Behavior

If cloud unreachable for >5 minutes AND local FAILSAFE rules triggered:

```
1. All alerts remain local (relays still controlled)
2. Events buffered to SQLite (offline_events table)
3. After 10 minutes: Escalate to facility operator
   - Sound local alarm (if available)
   - Display LED status (red = critical, offline)
   - Email / SMS to primary contact (if WiFi available)
4. When cloud returns:
   - Reconnect, authenticate
   - Replay offline_events (with original timestamp)
   - Clear buffer once ACK received
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Cloud (AWS)                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ EC2 Spring Boot 3.2                                  │  │
│  │ - Rule Management API                                │  │
│  │ - Dashboard & History                                │  │
│  │ - SIL Governance                                     │  │
│  │ - Gemini AI Advisory                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ API Gateway + Lambda (rule distribution, auth)       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
           ↕ HTTPS TLS 1.3 + mTLS (firewall DMZ)
┌─────────────────────────────────────────────────────────────┐
│                    Facility (Industrial Network)             │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Edge Gateway (Raspberry Pi / Industrial PC)             │ │
│  │ - Node.js Rule Engine                                  │ │
│  │ - SQLite Local Event Log (10GB)                        │ │
│  │ - MQTT Broker (TLS 1.3)                               │ │
│  │ - Key Management, Credential Renewal                  │ │
│  │ - FAILSAFE Logic (offline autonomy)                   │ │
│  │ - nginx TLS Termination                               │ │
│  └────────────────────────────────────────────────────────┘ │
│         ↕           ↕           ↕           ↕               │
│       MQTT TLS    MQTT TLS    MQTT TLS    MQTT TLS         │
│       (8883)      (8883)      (8883)      (8883)           │
│         │           │           │           │               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Sensor Network (RTU, PLC, Smart Sensors)              │ │
│  │                                                         │ │
│  │  [RTU-01]    [RTU-02]    [SENSOR-A]    [SENSOR-B]    │ │
│  │  ├─Temp      ├─Pressure  ├─NH3         ├─Dispatch   │ │
│  │  ├─Vibration ├─Level     └─Humidity    └─Status     │ │
│  │  └─Current   └─Flow                                  │ │
│  │                                                         │ │
│  │  [Relay Bank] [Safety PLC] [Interlock Controller]     │ │
│  │   ├─MOTOR-01   └─Redundant safety logic              │ │
│  │   ├─MOTOR-02      (SIL-2 rated)                      │ │
│  │   └─BLOWER-01                                         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## IEC 62443-3-3 Compliance Mapping

| Security Requirement | Implementation |
|---|---|
| **SR-2.1: Password Management** | No passwords. OAuth2 JWT tokens + mTLS certs. |
| **SR-2.2: Access Control** | Role-based: Device, Gateway, Cloud Admin. |
| **SR-2.3: Zone Protection** | DMZ firewall (outbound HTTPS only). |
| **SR-2.4: Enterprise Data Flow** | MQTT TLS + HTTPS TLS 1.3 (data-in-transit). |
| **SR-2.5: Secure Remote Access** | bastion host required (not direct SSH). |
| **SR-3.1: Ports & Services** | Only TLS (8883/5684/443). No Telnet/SSH on net. |
| **SR-3.2: Security Event Audit Trail** | DynamoDB (cloud) + SQLite (edge) immutable logs. |
| **SR-3.3: Certificate & Key Management** | X.509 certs. Key rotation every 90 days. |
| **SR-3.4: Security Patch Management** | Automatic updates (systemd timer, apt). |

---

## Deployment Procedure (Sprint 7)

### Phase 1: Hardware Preparation
```bash
1. Procure Raspberry Pi 4 (8GB, industrial enclosure, 24VDC PSU)
2. Install Ubuntu 22.04 LTS minimal
3. Hardening: SELinux, fail2ban, ufw firewall
4. Install Node.js, nginx, SQLite3
5. Generate device certificate (X.509, self-signed CA)
```

### Phase 2: Software Deployment
```bash
1. Clone argus-edge repository
2. npm install (production mode)
3. Configure nginx TLS + reverse proxy
4. Set environment variables:
   CLOUD_API_ENDPOINT=https://api.argus-iot.cloud
   GATEWAY_ID=GW-PLANT-A-001
   MQTT_PORT=8883
   FAILSAFE_TIMEOUT_MIN=5
5. Start systemd service: systemctl start argus-edge
6. Verify cloud sync: curl https://localhost:9443/api/health
```

### Phase 3: Device Onboarding
```bash
For each RTU/sensor:
  1. Exchange pre-shared symmetric key (out-of-band, QR code)
  2. Configure MQTT broker IP + port
  3. Update firmware (if applicable)
  4. Test connectivity: mosquitto_pub -test-message
  5. Verify in cloud dashboard: /admin/edge/devices
```

### Phase 4: Testing & Validation
```bash
1. Fail-over test: Disconnect cloud, verify local rules execute
2. TLS test: Verify mTLS certs, cipher suites (testssl.sh)
3. Latency test: Measure rule evaluation time (<100ms target)
4. Offline replay: Buffer 1000 events, verify replay on reconnect
5. Load test: 1000 sensors × 1Hz = 86M events/day throughput
```

---

## Rollout Plan

| Phase | Timeline | Scope |
|---|---|---|
| **Pilot (Facility A)** | Sprint 7, Week 1-2 | Single facility, 50 devices |
| **Scaling (Facilities B-C)** | Sprint 7, Week 3-4 | 2 more facilities, 200 devices |
| **Production (All Facilities)** | Sprint 8+ | Full network, 1000+ devices |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Cloud API down | Rules cached; local rules still execute | 5-min failsafe timeout + offline alarm |
| Device certificate expiry | Device can't send data | Auto-renewal 30 days before expiry |
| Network congestion | Latency → delayed alerts | Batch events (10s window), compress JSON |
| Malicious device | Injects false events | HMAC signature on every message |
| Firmware rollback | Security patch undone | Secure boot + measured boot (TPM) |

---

## Acceptance Criteria

- [x] ADR design complete
- [ ] Edge gateway implementation complete (Sprint 7)
- [ ] Device firmware update mechanism designed (Sprint 7)
- [ ] TLS 1.3 + mTLS configuration verified (Sprint 7)
- [ ] Offline failsafe tested (Sprint 7)
- [ ] 99.9% uptime SLA achieved (Sprint 7 + Sprint 8)
- [ ] IEC 62443-3-3 audit passed (Post-production)

---

## References

- **IEC 62443-3-3:2013** — Security for Industrial Automation Systems
- **OWASP IoT Security** — https://owasp.org/www-project-iot-top-10/
- **NIST SP 800-160** — Systems Security Engineering
- **RFC 8996** — TLS 1.3 Obligations and Management Transitions
- **MQTT OASIS Standard 5.0** (TLS requirement for QoS >0)
