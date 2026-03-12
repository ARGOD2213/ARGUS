# ARGODREIGN Mobile Chat Space

This is your online browser space to continue work from phone.

Important:
- The exact Codex desktop chat thread is not available on mobile.
- This file is the live handoff bridge between desktop work and mobile updates.

## How to Use From Phone

1. Open this file in GitHub mobile browser/app.
2. Read `Latest Update` first.
3. Copy the `Reviewer Prompt` section if you need external review.
4. Run START/STOP workflows from GitHub Actions as usual.
5. Come back here for next actions.

## Latest Update (IST)

- Sprint 1: Closed.
- Sprint 2 progress in repo: machine, safety, plant, compliance dashboards added.
- LLM confidence, advisory wrapper, and day-by-day evidence files are committed.
- Remaining work should now follow reviewer checkpoint feedback and integration hardening.

## Reviewer Prompt (Copy/Paste)

Use this with your reviewer:

```
Please audit the latest ARGODREIGN master branch for Sprint 2 progress.
Focus on:
1) Dashboard functionality: /machine.html, /safety.html, /plant.html, /compliance.html
2) AI governance: AiAdvisoryWrapper present and confidence is computed (not hardcoded)
3) Safety architecture: rule engine remains Lambda-only (no control logic in Spring Boot)
4) Cost guardrails: budget + cache + no expensive always-on services
5) Evidence docs under /docs for Day 7/9/11/12/13/14

Return:
- PASS/FAIL by checkpoint
- exact gaps with file paths and line references
- only actionable fixes in priority order (P1 -> P3)
```

## Mobile Quick Links

- Actions: `START IoT Server`, `STOP IoT Server`
- Dashboards:
  - `/machine.html`
  - `/safety.html`
  - `/plant.html`
  - `/compliance.html`

## Notes

- Never paste AWS/API secrets in issues or chat.
- Keep EC2 stopped when not actively using dashboards.
