# Phase-1 Build Backlog (Execution Ready)

Date: 2026-03-11

## Sprint 1 (Week 1): Governance and Data Contracts
1. Create `architecture/safety-boundaries.md` with explicit read/write matrix.
2. Create historian tag contract for top 5 critical assets.
3. Add AI recommendation evidence schema (input tags, rule/model version, confidence, reviewer).
4. Implement approval states: DRAFT -> REVIEWED -> APPROVED -> REJECTED.

## Sprint 2 (Week 2): Safety Guardrails
1. PTW conflict API integration and recommendation suppression.
2. MOC status integration and model invalidation marker.
3. NH3 detector health service and zone-level coverage status.
4. WBGT risk service with shift-level advisories.

## Sprint 3 (Week 3): Pilot Dashboards
1. Machine-360 dashboard for syngas compressor and BFW pump.
2. Plant Safety dashboard: gas exceedance, detector health, active PTWs, weather level.
3. Compliance dashboard: evidence completeness, overdue inspections, closure aging.
4. Add weather-to-action panel for cyclone/rain/heat.

## Sprint 4 (Week 4): Validation and Gate Review
1. Run fault replay tests (surge trend, cavitation trend, IA pressure drop).
2. Measure false-positive rate and alert latency.
3. Perform tabletop emergency scenario with operations team.
4. Close pilot Go/No-Go gate checklist.

## Acceptance Criteria for Month-1
1. Zero AI outputs shown when PTW conflict is active.
2. Every P1 alert has explicit human approval trail.
3. Safety boundary tests passed and documented.
4. Detector and WBGT services reporting continuously for pilot scope.
5. Go/No-Go memo approved by operations + safety + compliance.
