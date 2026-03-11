# ADR-003: LLM Output Must Be Explicitly Marked as Advisory

- Status: Accepted
- Date: 2026-03-11

## Context

LLM outputs can appear authoritative to operators and stakeholders. Without clear labels, advisory text may be mistaken for control decisions.

## Decision

Every LLM-rendered response must display:

- `AI ADVISORY`
- confidence band (`HIGH`/`MEDIUM`/`LOW`)
- disclaimer: `Not a control action`

## Consequences

- Pros:
  - Enforces human-in-the-loop understanding.
  - Improves governance and demo clarity.
  - Reduces legal/operational ambiguity.
- Cons:
  - Requires UI discipline from first dashboard build.
  - Adds small formatting overhead to responses.
