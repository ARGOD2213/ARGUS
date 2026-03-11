# ADR-002: No Write Path from Dashboard/LLM Layer to OT Controls

- Status: Accepted
- Date: 2026-03-11

## Context

This platform is for monitoring and advisory intelligence. Any direct write path to OT controls introduces safety and liability risk.

## Decision

Spring Boot dashboards and LLM modules are read/analyze/advisory only. They must not issue autonomous control commands to plant equipment.

## Consequences

- Pros:
  - Strong safety boundary by architecture.
  - Clear liability posture for pilot/demo.
  - Easier compliance and audit explanation.
- Cons:
  - Actions remain operator-mediated (no auto-remediation).
  - Additional handoff UX is needed for operational teams.
