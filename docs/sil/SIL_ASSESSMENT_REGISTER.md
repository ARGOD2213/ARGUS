# ARGUS — SIL Assessment Register
**Standard:** IEC 61511:2016 Clause 9.3  
**Status:** IN PROGRESS — LOPA not yet completed  
**Owner:** Chintala Mahindra | ARGUS Platform  
**Last updated:** 2026-03-22  

## Purpose
This register tracks the Safety Integrity Level (SIL) status for all Safety Instrumented Functions (SIFs) implemented or planned in the ARGUS platform. Per IEC 61511 Clause 9.3, SIL determination must be completed before design of any SIS.

## Current Status
> Platform is in DEMO/PILOT mode. No SIFs are connected to real plant control systems. SIL assessment is required before any production deployment to a live facility.

## SIF Register

| # | Safety Function | Sensor(s) | Consequence of Failure | SIL Target | Status | Notes |
|---|----------------|-----------|----------------------|-----------|--------|-------|
| SIF-01 | NH3 synthesis compressor trip on high-high vibration | COMPRESSOR_VIBRATION | NH3 release, production loss, fatality risk | TBD — LOPA required | NOT_ASSESSED | ADR-001: rule in Lambda only |
| SIF-02 | NH3 area evacuation alert on high ppm | GAS_LEAK | Toxic exposure, fatality risk | TBD — LOPA required | NOT_ASSESSED | ACGIH TLV-TWA = 25ppm |
| SIF-03 | Urea HP section overpressure alert | REACTOR_TEMPERATURE + pressure (future) | Catastrophic HP failure | TBD — LOPA required | NOT_ASSESSED | 2oo3 voting needed for SIL 1 |
| SIF-04 | Reformer tube temperature alarm | REFORMER_TEMPERATURE | Tube rupture, H2+CO release, fire | TBD — LOPA required | NOT_ASSESSED | Pyrometer array needed |
| SIF-05 | Instrument air pressure low alarm | INSTRUMENT_AIR_PRESSURE | Full plant trip, cascade failure | TBD — LOPA required | NOT_ASSESSED | Threshold < 5 bar = CRITICAL |
| SIF-06 | Bearing temperature escalation | BEARING_TEMPERATURE | Bearing failure, fire, downtime | SIL 1 candidate | NOT_ASSESSED | Lower consequence = SIL 1 likely |
| SIF-07 | WBGT heat stress work restriction | WBGT (computed) | Heat stroke fatality | Non-SIS — advisory only | N/A — LLM advisory | AiAdvisoryWrapper enforced |

## LOPA Requirements
Before production deployment, Layer of Protection Analysis (LOPA) must be completed for SIF-01, SIF-02, SIF-03 at minimum.

LOPA inputs required:
- Initiating event frequency (from plant historical data)
- Independent protection layer (IPL) credits
- Consequence severity (from HAZOP study)
- Required risk reduction factor → SIL target

## Platform Architecture Note
Per ADR-001, all rule evaluation runs in Lambda only. Spring Boot has no threshold logic — it provides analysis and display only. This architectural boundary must be maintained as SIL assessment progresses.

## Next Actions
- [ ] Engage LOPA consultant for SIF-01, SIF-02, SIF-03
- [ ] Obtain plant historical failure data
- [ ] Complete HAZOP for ammonia synthesis and urea sections
- [ ] Update this register with SIL targets post-LOPA
- [ ] Add SIL target to rules.json for each safety rule
