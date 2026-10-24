# Phase 06 — Docs Sync + Final Vietnamese Report

## Context Links

- Brief section 21 (report sections A-G required, in Vietnamese).
- `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` (mark GAME-04 rows delivered), `docs/project-changelog.md`, `docs/development-roadmap.md`, `docs/PROGRESS.md` (generated — do not hand-edit), `tasks/` task.json status per AGENTS.md.
- Delegate doc edits to `docs-manager` agent per workflow rules.

## Overview

- Priority: P2.
- Status: pending.
- Sync docs to implemented reality; produce final report; stop for user review (no GAME-05).

## Key Insights

- API_SPEC: add `GET /api/v1/me/events/{eventId}/progress`, `GET /api/v1/me/collection/dossiers`, `GET /api/v1/me/collection/dossiers/{dossierId}` with response shapes + visibility rules.
- DATABASE_DESIGN: document 5 new tables, partial unique index, composite PKs, provenance columns.
- Contract section "Phan bo theo GAME" row GAME-04 -> mark delivered.
- Changelog entry: GAME-04 feature summary + V22 migration + new endpoints.
- Map vs dossier LOCATION distinction must be written explicitly (brief 13 — "tai lieu phai giai thich ro").
- Report sections A-G verbatim structure from brief; honest test results (ran/blocked).

## Requirements

Docs edits (docs-manager):
- API_SPEC.md: endpoint entries + preview/DRAFT/ARCHIVED visibility matrix.
- DATABASE_DESIGN.md: V22 tables section.
- GAMIFICATION_TECHNICAL_CONTRACT.md: status updates only where baseline changed (do not rewrite rules).
- project-changelog.md + development-roadmap.md: GAME-04 entry/status.
- Map-vs-dossier paragraph (LOCATION dossier = knowledge record; map marker = journey location; different unlock rules).

Final report (this task's deliverable, Vietnamese, saved to `plans/reports/` or returned in completion message per harness):
- A. Tong ket — implemented vs not.
- B. Database — V22, tables, constraints, seed, version protection, old-attempt reconcile.
- C. Backend — domain, repos, services, evaluator, unlock, APIs, doComplete integration.
- D. Flutter — tabs, cards, detail, progress, refresh, navigation.
- E. Nghiep vu — eventCompleted/mastered/dossier rules, replay, republish, map distinction.
- F. Testing — tests created, commands run, real PASS/FAIL, blockers, CI follow-ups.
- G. GAME-05 readiness — milestone API reuse, dossier vs inventory, triggers needed; NOT implemented.

## Architecture

N/A — documentation phase.

## Related Code Files

Modify:
- `docs/API_SPEC.md`
- `docs/DATABASE_DESIGN.md`
- `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` (status notes)
- `docs/project-changelog.md`
- `docs/development-roadmap.md`
- `tasks/<GAME-04>/task.json` status field if task exists under `tasks/`

Create:
- `plans/reports/game-04-final-report.md` (or return inline per orchestrator instruction — verify expectation; brief wants the report; write file AND summarize).

## Implementation Steps

1. Confirm GAME-04 task tracking file (`tasks/` dir) exists; update status per AGENTS.md workflow.
2. Delegate doc edits to docs-manager with exact section list.
3. Compose final report from phases 1-5 outcomes + actual command outputs.
4. Stop. No commit/push. No GAME-05.

## Todo List

- [ ] API_SPEC updated
- [ ] DATABASE_DESIGN updated
- [ ] Contract status updated
- [ ] Changelog + roadmap updated
- [ ] Map/dossier distinction documented
- [ ] task.json status synced
- [ ] Vietnamese report A-G written with real verification results
- [ ] Stop for review

## Success Criteria

- Docs match shipped behavior; no invented claims.
- Report lists actual test outcomes incl. any Docker-blocked ITs.

## Risk Assessment

- Doc drift if implementation deviates from plan -> docs written AFTER code freeze, from real code.
- Report overstating results -> template requires explicit commands + outcomes.

## Security Considerations

None.

## Next Steps

- User review -> GAME-05 planning later.
