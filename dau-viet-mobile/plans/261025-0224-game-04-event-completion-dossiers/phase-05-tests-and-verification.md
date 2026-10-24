# Phase 05 — Tests & Verification

## Context Links

- Brief section 17 (scenarios A-J), section 18 (required tests + commands).
- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` — Testcontainers postgres:16-alpine, `clearAuthoringTables(jdbc)` must gain deletes for 5 new tables (FK-safe order, inside replica-role block).
- `learning/AttemptItFixture.java`, `LearnerAttemptConcurrencyIT.java`, `IdempotencyIT.java`, `CollectionIT.java`, `AttemptCompletionIT.java` — patterns to extend.
- Env risk: Docker may be unavailable locally -> ITs cannot run; report honestly per brief 18, leverage CI after push (push not ours — report only).

## Overview

- Priority: P1.
- Status: pending.
- Backend unit tests (evaluator matrix, services) + Postgres ITs (scenarios A-J) + Flutter DTO/widget tests + fixture cleanup update.

## Key Insights

- `clearAuthoringTables` deletion order: `user_dossier_unlocks`, `user_event_progress`, `event_dossiers`, `event_completion_policies`, `historical_dossiers` — before `users`/`historical_events` deletes; inside same replica-role block.
- Concurrency IT pattern exists in `LearnerAttemptConcurrencyIT` (parallel executor + latch) — mirror for two-last-lessons scenario.
- Attempt completion helpers already in `AttemptItFixture` — verify methods (create user, publish lesson, start, submit-through, complete) before writing new helpers.
- Dossier preview test: locked PUBLISHED returns preview-only fields — assert `detailDescription` absent/null in response JSON.

## Requirements

Backend unit (`src/test/java/com/dauviet/collection/application/`):
- `EventProgressEvaluatorTest` — rules matrix: all-required-completed -> grant COMPLETED; partial -> none; mastered: all graded >= threshold + >=1 graded lesson -> MASTERED; all-ungraded -> no MASTERED (NOT_ASSESSED); below-threshold -> no grant; threshold edge (69.99 vs 70 vs 100); null threshold -> never mastered; empty required -> no grant.
- `EventCompletionPolicyServiceTest` — published lookup, malformed jsonb -> empty, NOT_CONFIGURED path.
- `DossierServiceTest` — visibility rules (DRAFT 404, locked preview, unlocked ARCHIVED readable) with mocked repos if feasible, else fold into IT.

Backend IT (`src/test/java/com/dauviet/collection/` + `learning/`):
- `EventProgressIT` — scenarios: A (sequential last-lesson grants once + dossiers unlocked), B (replay same idempotency key -> single milestone/unlock rows), C (two required lessons completed concurrently -> exactly one EVENT_COMPLETED; use two attempts on different lessons of same event), D (republish: complete v1, publish v2 via admin flow or fixture, milestone survives, old completion counts), E (policy v2 adds lesson; old entitlement kept; new user needs v2 set — simulate by inserting v2 row + new user), F (shared dossier across two events -> single ownership row, provenance = first event), G (no policy -> NOT_CONFIGURED, no grants), H (below-threshold complete -> COMPLETED not MASTERED; redo with better score via second attempt -> MASTERED; no second first-completion reward — assert reward_transactions count), I (all-ungraded policy -> completed, never mastered), J (force dossier fan-out failure? simulate via FK-safe means is hard — cover via transaction rollback test where milestone insert fails, e.g., publish-lesson guard; alternatively verify all-or-nothing by provoking DataIntegrityViolation and asserting no partial rows; keep pragmatic).
- `DossierApiIT` — list filters (type/eventId/unlocked), pagination stability, preview vs detail, DRAFT invisibility, ARCHIVED unlocked readable, ownership isolation (user B sees locked what user A unlocked), route non-clash (`/me/collection/dossiers/{id}` returns dossier not evidence 404/400), evidence endpoints regression.
- `EventProgressApiIT` — response shape, status precedence, NOT_CONFIGURED, reconcile-on-read (insert completed attempts directly via fixture bypassing recorder? simpler: complete lessons BEFORE policy inserted via SQL, then publish policy row, then GET -> grants recorded), unlockedDossiersCount.
- `V22MigrationIT` or extend `FlywayMigrationIT` — tables exist, partial unique index blocks second PUBLISHED, seed rows present (3 policies, >=8 dossiers, links), re-run safety implicitly via Flyway checksum.

Flutter tests (`dau-viet-mobile/test/`):
- `features/collection/data/dossier_dto_test.dart`, `event_progress_dto_test.dart` — parse incl. nulls, NOT_ASSESSED score null.
- `features/collection/presentation/dossier_tab_test.dart` — tabs render, evidence tab intact, locked card vs unlocked card, empty/loading/error states.
- `dossier_detail_screen_test.dart` — full vs preview render.
- `event_progress_section_test.dart` — IN_PROGRESS counts, COMPLETED banner, NOT_CONFIGURED neutral.
- Navigation test — dossier route resolves; evidence route still works (widget-level GoRouter test if pattern exists in repo; else cover via unit route match).
- Session isolation — provider keyed by session (existing pattern; add dossier case).

Commands:
- `cd dau-viet-backend && ./mvnw -B -ntp verify`
- `cd dau-viet-mobile && dart format --set-exit-if-changed lib test && flutter analyze && flutter test`
- If Docker absent: run `./mvnw -B -ntp verify -DskipITs`? Check project surefire/failsafe config — ITs may run under `verify` via failsafe; if Docker blocked, run unit tests only `./mvnw -B -ntp test -Dtest='!*IT'` or failsafe skip property; report exactly which ran and which were blocked. NEVER claim pass for unrun tests.

## Architecture

Follow existing test conventions: `*Test` for unit (no Spring), `*IT` extends `AbstractPostgresIT` (Testcontainers). Flutter: mocktail/fake repo per existing test setup — inspect `test/` dir patterns at impl time.

## Related Code Files

Modify:
- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` — add 5 deletes.
- Possibly `AttemptItFixture.java` — helper to run full lesson to COMPLETED (verify existing helpers first).

Create (indicative):
- `collection/application/EventProgressEvaluatorTest.java`
- `collection/application/EventCompletionPolicyServiceTest.java`
- `collection/EventProgressIT.java`, `collection/DossierApiIT.java`, `collection/EventProgressApiIT.java`
- `test/features/collection/...` dart tests per above.

## Implementation Steps

1. Update `clearAuthoringTables` FIRST (new FK refs break every other IT otherwise).
2. Inspect `AttemptItFixture` + `LearnerAttemptConcurrencyIT` + `CollectionIT` for reusable flows.
3. Write evaluator unit tests (pure — fastest feedback).
4. Write EventProgressIT covering scenarios A-I pragmatically.
5. Write API ITs.
6. Write Flutter DTO + widget tests.
7. Run backend build; record exact output.
8. Run flutter format/analyze/test; record exact output.
9. Honest verification report: which commands ran, exit codes, ITs skipped due to Docker (if any).

## Todo List

- [ ] clearAuthoringTables extended
- [ ] Evaluator unit tests (matrix incl. edges)
- [ ] Policy service unit tests
- [ ] EventProgressIT scenarios A,B,C,D,E,F,G,H,I
- [ ] DossierApiIT (visibility, filters, pagination, route clash, ownership)
- [ ] EventProgressApiIT (shape, reconcile, count)
- [ ] Migration/seed IT
- [ ] Flutter DTO tests
- [ ] Flutter widget tests (tabs, cards, detail, progress section, navigation)
- [ ] Run `./mvnw -B -ntp verify`; capture result
- [ ] Run flutter format/analyze/test; capture result

## Success Criteria

- All new unit tests pass locally (no Docker needed).
- ITs pass when Docker available; if not, report says "blocked: Docker unavailable" explicitly.
- No existing test broken (evidence/map/reward regressions green).
- dart format --set-exit-if-changed exits 0; analyze 0 issues; flutter test all pass.

## Risk Assessment

- Docker/Testcontainers unavailable -> biggest verification risk; mitigate: unit tests cover evaluator; document IT gap for CI.
- Flaky concurrency IT -> use latch + bounded executor + assert on row counts not timing; keep timeout generous.
- Two concurrent completes of SAME user+event need two attempts on two different lessons — fixture must support creating second published lesson under event (V20-style or admin API flow in IT).

## Security Considerations

- Negative tests: other-user dossier access 404/locked; DRAFT probe 404; no userId param honored.

## Next Steps

- Phase 6: docs-manager sync + final report.
