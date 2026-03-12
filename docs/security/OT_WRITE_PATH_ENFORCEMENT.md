# OT Write Path Enforcement

Status: ENFORCED

- Rule engine remains Lambda-only.
- Spring Boot is read-only for analytics/dashboard APIs.
- No endpoint writes to PLC, DCS, SCADA, OPC-UA, or field devices.
- Architecture control: ADR-002 (`docs/adr/ADR-002-no-ot-write-path.md`).
- Network control: EC2 security group `sg-00ebba671bb6e22fb` egress restricted to:
  - TCP 443 to `0.0.0.0/0`
  - TCP 80 to `0.0.0.0/0`
  - UDP/TCP 53 to `169.254.169.253/32` (VPC DNS resolver)
- OT protocol ports not allowed in SG egress: 102, 502, 4840, 44818.

Evidence: `docs/security/VPC_SECURITY_GROUP_EVIDENCE.txt`
