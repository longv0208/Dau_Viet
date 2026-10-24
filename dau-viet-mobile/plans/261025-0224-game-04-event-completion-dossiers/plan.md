---
title: "GAME-04 — Event Completion & Historical Dossier Collection"
description: "Versioned event completion policies, event progress milestones, canonical historical dossiers with unlock fan-out, backend APIs and Flutter collection tabs."
status: pending
priority: P1
effort: 32h
branch: main
tags: [gamification, game-04, event-progress, dossier, flyway, flutter]
created: 2026-10-25
---

# GAME-04 — Event Completion & Historical Dossier Collection

Planner acting as `planner-researcher` (planner + research responsibility; recorded per AGENTS.md delegation rule). Plan only — no code implemented by this agent.

## Goal

Chain: HistoricalEvent -> required lessons (published policy) -> lesson COMPLETED -> EVENT_COMPLETED / EVENT_MASTERED -> unlock canonical `historical_dossiers`. Preserve Evidence (Dau), map unlock rules, reward/energy pipelines.

## Phases

| # | Phase | Status | Effort |
|---|-------|--------|--------|
| 1 | Flyway V22 schema + idempotent seed | pending | 5h |
| 2 | Backend domain, persistence, evaluator/recorder services | pending | 8h |
| 3 | Integration into `doComplete()` + progress/dossier APIs | pending | 6h |
| 4 | Flutter dossier tabs, detail, event progress UI | pending | 7h |
| 5 | Unit/IT/widget tests + verification runs | pending | 4h |
| 6 | Docs sync + Vietnamese final report (sections A-G) | pending | 2h |

## Key Dependencies

- `LearnerAttemptService.doComplete()` ~line 465-472: insertion point AFTER `rewardGrants.grantFirstCompletion` + `itemUnlocks.evaluateAfterLessonCompletion`, same tx (recon verified).
- `MapLocationUnlockQuery.completedLessonIds(userId, lessonIds)` — reuse for required-lesson completion check (verified).
- `GradedActivityClassifier.isGraded(JsonNode)` — reuse for mastery grading detection (verified).
- `LessonResult.resultJson.knowledgeScore` — best-valid-result source; `score` column is progress %, NOT mastery.
- Advisory lock idiom `pg_advisory_xact_lock(hashtextextended(:k,0))` at LearnerAttemptService:174-177 — reuse for (user,event) milestone race.
- V20 seeds 3 events (slugs `bach-dang-938`, `hai-ba-trung-40`, `ly-thai-to-1010`), 1 published lesson each, with slug re-resolution pattern — seed V22 must resolve by slug, not fixed UUID.
- Next Flyway version: **V22** (V21 = energy). Never edit old migrations.

## Risks

- Concurrent completion of last two required lessons -> milestone loss unless (user,event) advisory lock serializes evaluation.
- Route clash `/collection/dossiers/{id}` vs `/collection/{evidenceId}` — register dossier routes first (backend `@GetMapping("/dossiers/{id}")` wins by literal-match; Flutter GoRoute order matters).
- Old completed attempts before policy exists -> reconcile-on-read in `EventProgressQueryService` (idempotent).
- Docker may be unavailable locally -> Testcontainers ITs blocked; report honestly, do not claim pass.
- Dossier content must cite real sources (ĐVSKTT, Bảo tàng LSQG) — no fabricated citations; skip dossier rather than fake.

## Out of scope (brief section 20)

GAME-05 item rules, GAME-06 admin CMS, GAME-07 wallet, GAME-08 global regression, energy/map changes, badge grants, commit/push.

## Unresolved questions

- `unlockedDossiersCount` semantics for preview count (dossiers linked to event vs unlocked by user) — propose: count of user-unlocked dossiers linked to this event.
- Batch progress endpoint for campaign list — defer (YAGNI) unless Flutter renders many events; single-event endpoint suffices for campaign detail.
