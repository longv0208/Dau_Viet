---
title: "Critical Content & Preview Bugfix"
description: "Fix MC contract mismatch, MATCHING/DRAG_ORDER answer leaks in projection, evidence preview enrichment, preview state leak, stale readiness."
status: done
priority: P1
effort: 10h
branch: main
tags: [bugfix, backend, admin, projection, e2e]
created: 2026-10-17
---

# Critical Content & Preview Bugfix

## Overview

Six confirmed bugs split across backend projection/handlers, admin renderers/editors, e2e stub, and publish flow. Backend stays authoritative; fixes target contract drift, answer leakage in learner payload, missing evidence context in preview, and stale UI state.

## Phases

| Phase | File | Status | Effort |
|-------|------|--------|--------|
| 01 — Backend projection & handlers | `phase-01-backend-projection-and-handlers.md` | done | 3h |
| 02 — Backend preview evidence enrichment | `phase-02-backend-preview-evidence-enrichment.md` | done | 1.5h |
| 03 — Admin renderers & state | `phase-03-admin-renderers-and-state.md` | done | 3h |
| 04 — Stub sync & e2e spec | `phase-04-stub-sync-and-e2e.md` | done | 1.5h |
| 05 — Verify & report | `phase-05-verify-and-report.md` | done | 1h |

## Dependencies

- Phase 01 → Phase 02 (projection changes affect preview contract).
- Phase 01 → Phase 03 (renderer needs new learner shape).
- Phase 03 → Phase 04 (e2e asserts on the new UI/payload).
- Phase 05 gates all.

## AC-to-Check Map

- DoD 1 (MC contract) → Phase 01 (handler+schema) + Phase 03 (editor+renderer) + `ScoredHandlersTest.mcq_*` + vitest.
- DoD 2 (MATCHING leak) → Phase 01 (projection transform) + `LearnerProjectionServiceTest.matching_*` + Phase 03 renderer + e2e assert.
- DoD 3 (DRAG_ORDER leak) → Phase 01 (deterministic reorder) + `LearnerProjectionServiceTest.dragOrder_*` + Phase 03 renderer + e2e assert.
- DoD 4 (Evidence preview) → Phase 02 (embed evidence/assets in preview) + Phase 03 (renderers read `evidence[]`/`assets[]`) + e2e.
- DoD 5 (Preview state reset) → Phase 03 (`key={activity.id}`) + vitest remount test.
- DoD 6 (Readiness stale) → Phase 03 (`PublishReadinessCard` reset on `revision`).
- DoD 7 (E2E) → Phase 04 new `publish-journey.spec.ts` + stub mirror.
- DoD 8 (Verify) → Phase 05 commands + IT-noted-as-Docker-blocked.
- DoD 9 (VN report) → Phase 05 `plans/reports/`.
- DoD 10 (Scope) → all phases; no out-of-scope refactor.
- DoD 11 (TASK workflow) → preserved; no workflow edits.
