# ARGODREIGN Unified Decision Memo (Merged from GPT + Claude + Gemini)

Date: 2026-03-11
Scope: 100-acre integrated ammonia-urea fertilizer complex
Source files:
- docs/model_output/gpt_review.txt
- docs/model_output/Claude_review.txt
- docs/model_output/gemini_review.txt

## Executive Decision
Verdict: CONDITIONAL GO

Reason:
1. All three reviews agree the concept is valid, but safety/compliance boundaries are incomplete.
2. There is strong overlap on critical blockers: SIS/BPCS separation, PTW/MOC integration, gas/heat safety controls, and audit-grade evidence.
3. AI must remain advisory only; control actions must stay in rule/SIS domain with human approvals.

## Consensus P1 Blockers (Must close before any live pilot)
1. Enforce SIS/BPCS separation and AI read-only boundary for safety systems.
2. Create SIL/SIF register and map safety-critical logic to IEC 61511 lifecycle artifacts.
3. Add PTW/LOTO gating so AI recommendations cannot conflict with active maintenance permits.
4. Add MOC integration so models/rules are invalidated when equipment/process changes.
5. Build gas safety foundation: NH3 coverage design, detector health KPIs, escalation paths.
6. Implement WBGT-driven worker heat controls and shift-based fatigue gating.
7. Add alarm rationalization baseline (IEC 62682/EEMUA 191 aligned) before wide rollout.
8. Define multi-LLM arbitration and conservative override for safety-critical disagreement.
9. Add immutable audit evidence pipeline (who/what/when/why + model/rule version).
10. Add weather-to-unit action matrix (alerts must trigger specific operating decisions).

## Consensus P2 Priorities (Phase-1)
1. Compressor surge model must include anti-surge, flow, pressure ratio, gas quality context.
2. Pump cavitation detection must include NPSH margin and suction conditions.
3. Historian/data quality SLA (completeness, latency, drift, timestamp integrity).
4. OT cybersecurity zone-conduit architecture and least-privilege access model.
5. Reliability taxonomy standardization (ISO 14224 style coding and failure hierarchy).
6. Workforce model improvements: exposure-dose history, PPE/fit-test and certification validity.

## Non-Negotiable AI Governance
1. LLM allowed only for analysis, summarization, and recommendation drafting.
2. LLM blocked from setpoint writes, interlock changes, trip logic changes, and autonomous restart.
3. Human approval required for all P1 advisories and any production-impacting action.
4. If models disagree on safety-critical context, pick most conservative recommendation and escalate.

## 30/90/180-Day Execution Track

### First 30 days (Architecture + Safety Foundation)
1. Publish boundary spec: AI read-only from SIS/BPCS, data contracts for historian tags.
2. Deliver P1 register: SIF/SIL draft, PTW/MOC integration points, alarm philosophy baseline.
3. Deploy minimal dashboards: Gas Safety, Critical Asset Health, Compliance Evidence status.
4. Implement evidence ledger for every AI recommendation (inputs, outputs, confidence, reviewer).

### 90 days (Pilot on critical assets)
1. Pilot Machine-360 on 5 critical assets: syngas compressor, loop compressor, CO2 compressor, BFW pump, instrument air compressor.
2. Enable weather-to-action and worker heat/fatigue guardrails.
3. Validate false-positive rate and detection latency against real events.
4. Integrate CMMS work orders for approved recommendations.

### 180 days (Scale + Audit readiness)
1. Expand to full cell dashboards and cascade impact simulation.
2. Complete statutory evidence exports and audit workflows.
3. Conduct external safety/compliance review and close findings.
4. Approve staged expansion to 30-50 machine classes.

## KPI Starter Pack (first 12 to operationalize)
1. Critical interlock availability
2. SIF overdue proof-test percentage
3. NH3 exceedance minutes
4. Detector health availability
5. Minimum surge margin
6. Minimum NPSH margin
7. Critical asset health index
8. Unplanned shutdown rate
9. MTBF (critical rotating assets)
10. OCEMS valid data availability
11. WBGT high-risk minutes
12. Audit finding closure within 30 days

## Go/No-Go Gate for Pilot
Pilot GO only if all are TRUE:
1. SIS/BPCS read-only boundary enforced and tested.
2. PTW and MOC gates integrated.
3. Gas + heat safety dashboards live with escalation chain.
4. Evidence ledger and approval workflow active.
5. Alarm rationalization baseline completed for pilot scope.

If any gate fails, status remains NO-GO for production pilot.
