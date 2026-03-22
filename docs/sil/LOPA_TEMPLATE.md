# LOPA Template — ARGUS Safety Instrumented Functions
**Standard:** IEC 61511:2016 | IEC 61508:2010  
**Purpose:** Template for Layer of Protection Analysis  
**Status:** TEMPLATE — to be completed with plant data  

## How to use this template
Complete one table per Safety Instrumented Function. Obtain initiating event frequency from plant historian or industry databases (e.g. OREDA, CCPS guidelines). Each IPL must be truly independent and auditable.

---

## LOPA-01: NH3 Compressor Trip (SIF-01)

| Parameter | Value | Source |
|-----------|-------|--------|
| Initiating Event | Compressor bearing failure causing vibration exceedance | OREDA / plant history |
| Initiating Event Frequency | TBD /year | Plant historian |
| Consequence | NH3 release + production loss + fatality risk | HAZOP |
| Tolerable Risk Frequency | 1E-5 /year (typical for fatality risk) | Company risk matrix |
| IPL 1 | Operator response to ARGUS CRITICAL alert | 0.1 credit (requires < 10 min response) |
| IPL 2 | Basic Process Control System (BPCS) trip | 0.1 credit |
| IPL 3 | Safety Relief Valve | 0.01 credit |
| Residual Risk | TBD after IPL credits | |
| Required SIL | TBD — calculate: Residual / Tolerable | |
| SIL Target | NOT_ASSESSED | To be updated post-LOPA |

---

## LOPA-02: NH3 Area Evacuation (SIF-02)

| Parameter | Value | Source |
|-----------|-------|--------|
| Initiating Event | NH3 leak from synthesis loop seal failure | Plant history |
| Initiating Event Frequency | TBD /year | Plant historian |
| Consequence | Toxic exposure to workers in SYNTHESIS zone | HAZOP |
| Tolerable Risk Frequency | 1E-4 /year (toxic exposure, survivable) | Company risk matrix |
| IPL 1 | Fixed NH3 detector + ARGUS alert | 0.1 credit |
| IPL 2 | Operator evacuation response | 0.1 credit |
| IPL 3 | Wind dispersion (not an IPL — weather dependent) | Not credited |
| Residual Risk | TBD | |
| Required SIL | TBD | |
| SIL Target | NOT_ASSESSED | |

---

## LOPA-03: Urea HP Overpressure (SIF-03)

| Parameter | Value | Source |
|-----------|-------|--------|
| Initiating Event | Control valve failure in HP carbamate loop | HAZOP |
| Initiating Event Frequency | TBD /year | Plant historian |
| Consequence | HP section overpressure, potential rupture | HAZOP |
| Tolerable Risk Frequency | 1E-5 /year | Company risk matrix |
| IPL 1 | BPCS pressure control | 0.1 credit |
| IPL 2 | ARGUS CRITICAL alert to operator | 0.1 credit |
| IPL 3 | Pressure Safety Valve (PSV) | 0.01 credit (PESO certified) |
| Residual Risk | TBD | |
| Required SIL | TBD — likely SIL 1 or SIL 2 | |
| SIL Target | NOT_ASSESSED | |

---

## Consultant Briefing Notes
When engaging a LOPA consultant, provide:
1. This register and template
2. P&ID drawings for synthesis loop, urea HP section, reformer
3. Plant historical incident data (last 5 years)
4. HAZOP study (if available) or request HAZOP as part of scope
5. ADR-001 architecture document — rule engine is Lambda, not a certified SIS. Consultant must note this boundary.
