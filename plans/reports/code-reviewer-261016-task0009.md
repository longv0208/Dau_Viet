# Code Review — TASK-0009 Lesson Builder Core

- Date: 2026-10-16
- Reviewer: code-reviewer
- Scope: uncommitted diff vs baseCommit 47179b9 (dau-viet-backend + docs)
- Plan: `plans/261015-2315-task0009-lesson-builder/` (plan + 7 phase files)
- AC source: `tasks/TASK-0009/task.json`

## Verdict

**APPROVE WITH CHANGES** — implementation is solid and broadly faithful to plan/ACs, but AC-1 is missing two endpoints (`GET /stages/{stageId}` and `GET /stages/{sid}/activities/{aid}`), AC-5 lacks a "reachable terminal stage" check, AC-7 lacks an IT for stage/activity `expectedRowVersion` (only evidence PATCH is covered), and AC-9's `summary` payload omits `evidenceRefs`. AC-10 has no new-endpoint auth-negative tests. These are P1 gaps — small fixes, no structural rework needed.

## Findings (severity-ordered)

### P0 (blocker)
None.

### P1 (major — AC gaps / behavior correctness)

1. **AC-1 / AC-2 — missing single-resource GETs.** `AdminLessonDraftController` (dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonDraftController.java) exposes `GET /stages` (line 51) and `GET /stages/{stageId}/activities` (line 90) but no `GET /stages/{stageId}` and no `GET /stages/{sid}/activities/{aid}` — both listed in plan §"Endpoint surface" and AC-1 text "list, get, create…". Fix: add two handlers + service lookups delegating to existing `requireStage`/`requireActivity`.

2. **AC-5 — no reachable-terminal-stage check.** `DraftValidator.validateStageGraph` (dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftValidator.java:225-247) checks unknown targets + DFS cycles but never verifies "at least one stage reachable with empty nextStageIds" at PUBLISH level — required by AC-5 text and phase-02 §"Cross-cutting checks". Fix: at PUBLISH, compute reachable set from any stage with in-degree 0 (or all stages if none) and emit `NO_TERMINAL_STAGE` when none has empty `nextStageIds`.

3. **AC-9 — summary missing `evidenceRefs`.** `LessonService.checkPublishReadiness` (dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java:258-263) returns `stageCount/activityCount/schemaVersion/errorCount/warningCount` but AC-9 specifies `summary{stages,activities,evidenceRefs}`. Fix: count `evidenceRefs` + `requiredEvidenceIds` occurrences during the existing draft walk.

4. **AC-7 — no IT for optimistic lock on stage/activity mutations.** `AdminLessonStageIT` and `AdminLessonActivityIT` contain zero `expectedRowVersion`/`OPTIMISTIC_LOCK_CONFLICT` tests; only `AdminLessonIT.updateDraft_staleRowVersion_409` and `AdminEvidenceIT.update_200_andStaleVersion_409` cover the contract. Fix: add a test in `AdminLessonStageIT` — capture `rowVersion` from `GET /stages`, submit a PATCH with stale `expectedRowVersion`, expect 409.

5. **AC-10 — no auth-negative tests for new endpoints.** `AdminLessonIT.auth_anon401_learner403` covers `/admin/lessons` + `/admin/lesson-templates` only; the new sub-resources and `/admin/evidences`/`/admin/lessons/{id}/validate` have no LEARNER→403 / anonymous→401 coverage. Fix: extend `auth_anon401_learner403` (or add per-controller methods) to hit `POST /stages`, `GET /evidences`, `POST /validate` with `learnerToken` (403) and no token (401).

6. **PUBLISH — required-stage/non-READ-activity check missing.** Phase-02 §"Publish-only checks" requires "at least one `required=true` stage with non-READ `required=true` activity"; not implemented (only stage-array presence checked, DraftValidator.java:83). Without it, an all-READ draft passes `ready=true`. Fix: at PUBLISH, scan stages for `required==true` and any activity `required==true && type!=READ`; emit `NO_REQUIRED_ACTIVITY` if absent.

7. **`requireAllRequiredStages` semantics not enforced.** `DraftValidator.validateCompletion` (line 273-282) checks `requiredStageIds` references but doesn't enforce "if `requireAllRequiredStages`, at least one required stage exists". Fix: at PUBLISH, when `completion.requireAllRequiredStages==true`, verify at least one stage has `required=true`.

### P2 (minor — perf / consistency)

8. **N+1 query on `requiredEvidenceIds` per stage.** `DraftValidator.evidenceUsable` (line 320-329) issues `existsByIdAndEventIdAndStatusIn` per evidence id; `validateStageEvidenceRefs` (line 162-175) loops all refs. For a draft with K stage refs + M activity refs → K+M queries at PUBLISH. `buildContext` (line 331-342) is then invoked per activity (line 205), re-issuing the same `findIdsByEventIdAndStatusIn` + `findActiveIds` once per activity. Fix: hoist `buildContext` outside the per-activity loop, build `valid`/`activeAssets` once per `validate()` call, and have `validateStageEvidenceRefs`/`evidenceRefs` use `ctx.evidenceUsable` instead of the repository — single round trip.

9. **`assets.findActiveIds()` loads every ACTIVE asset in DB.** `AssetRepository.findActiveIds` (dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/AssetRepository.java:14-15) is unbounded — fine for MVP but will grow. Fix: collect asset ids referenced by `imageAssetId` during the stage walk, then `existsByIdInAndState(ids,"ACTIVE")`. Documented as MVP trade-off — keep as P2.

10. **`STAGE_ALLOWED_ACTIVITIES` wider than phase-01 spec.** `DraftSchema` (dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java:42-53) allows `MULTIPLE_CHOICE` under `EVIDENCE`, `REASONING`, `VERIFICATION`; phase-01 table restricts EVIDENCE→{EVIDENCE_SELECT, READ}, REASONING→{MATCHING, REASONING_CONNECT, READ}, VERIFICATION→{VERIFICATION, READ}. Either plan or code is wrong; spec is the narrower one. Fix: confirm intent, narrow map, or update phase-01 + DATABASE_DESIGN to record the widening.

11. **`objectives` dropped from `TOP_LEVEL_KEYS`.** `DraftSchema.TOP_LEVEL_KEYS = {schemaVersion, stages, completion}` (line 21-22) but phase-01 canonical schema includes `objectives` as a valid top-level field ("duplicated into `lessons.objectives_json` on save"). Currently `objectives` → `UNKNOWN_FIELD` at SAVE. Fix: add `objectives` to `TOP_LEVEL_KEYS` and (optionally) sync to `objectives_json` on save — or document the divergence.

12. **`AssetRepository.existsByIdAndState` unused.** Defined (line 17) but never called; `assets.existsById` is used in `EvidenceService.checkAsset` instead (any state). Decide whether the intent is "any state exists" (matches plan §"existence check, any state") or "must be ACTIVE"; if the latter, switch call site.

13. **`reorderArray` failure surfaces as 400 `VALIDATION_ERROR`, not 422.** `LessonDraftService.reorderArray` throws `IllegalArgumentException` (line 340, 345) → mapped to `VALIDATION_ERROR`/`400` by `GlobalExceptionHandler` (line 106). Plan §"PUT order: … -> 400" matches; tests assert 400. OK as-is, but the code path also returns `VALIDATION_ERROR` when callers might expect `INVALID_DRAFT`/`422` for the orderedIds-vs-current-set mismatch (similar to draft errors). Suggest a dedicated `DraftOrderMismatchException` → 422 with structured `details` listing missing/extra ids, per phase-03 §149.

14. **`LessonDraftService.reorderStages`/`removeStage`/`reorderActivities`/`removeActivity` return `rowVersion=null`** in the wrapper responses (lines 138, 174, 238, 257). Contract per phase-03 and AC-1 says "return new `rowVersion` in every response" so client can chain the next mutation. Fix: after `lessons.saveAndFlush(l)`, capture `l.getRowVersion()` and include it.

15. **`DELETE` endpoints take `expectedRowVersion` as `?query=`.** Phase-03 spec shows `?expectedRowVersion=N` so it's consistent, but POST/PATCH/PUT accept it in the body — slight asymmetry may surprise clients. Acceptable; document.

16. **`checkPublishReadiness` always-200 contract may mask real problems.** `LessonService.checkPublishReadiness` (line 202-265) catches `JsonProcessingException` but if `lessons.findById` fails inside a lazy JPA call or `templates.findById` throws, response becomes 500. Acceptable — endpoint is a dry-run but genuine infra errors should still surface. OK.

17. **`EvidenceService.archive` doesn't honor `expectedRowVersion`.** Plan §38: `POST /{id}/archive body { expectedRowVersion? }`. Implementation takes `@PathVariable` only — concurrent admin could archive while a PATCH is in-flight. Fix: accept optional `expectedRowVersion` in request body (or `If-Match` header) and call `checkVersion`.

### P3 (nit)

18. **`EvidenceService.archive` doesn't return `details.lessonIds`** as plan §115 promised (`EVIDENCE_IN_USE` with `details.lessonIds`). Currently `Map.of()` — admin can't see which lesson blocks the archive. Fix: query `select lv.lesson_id` in the same native query, populate `details.lessonIds`.

19. **`AdminLessonDraftController.adminId` + `AdminLessonController.adminId` + `AdminEvidenceController.adminId` duplicated.** Phase-03 §160 explicitly says "extract to `AdminAuth` helper to avoid dup". Fix: hoist to a `com.dauviet.common.security.AdminAuth` static method.

20. **Stage `id` auto-gen uses `stage` / `stage-2`, not `stage-<slug>`** (phase-03 §15). For `title="Bối cảnh"` plan suggests `stage-bo-canh`; impl always uses bare `stage`/`act` prefix. Acceptable simplification; document.

21. **Redundant double-set in `AbstractActivityValidator.collectIds`** (lines 53-58): `ids.add(id)` called twice; the second `add` is dead code. Remove.

22. **`buildContext` called inside the activity loop** (line 205) recomputes evidence/asset lookups per activity — see P2 #8; flag once.

23. **`AdminLessonController.parseSort` / `AdminEvidenceController.parseSort` duplicated.** Same method in both files; extract to a shared helper.

24. **`ValidationContext.existingEvidenceIds` field is dead** — never populated, never read (line 14, 332 passes `Set.of()`). Remove or wire.

## AC coverage

| AC | Status | Evidence |
|---|---|---|
| AC-1 stage endpoints | **Partial** — list/create/patch/delete/order implemented; **`GET /stages/{id}` missing** (finding #1). Reorder+prune+envelope+lock OK; tests cover most paths but no stale-version stage test (#4). | `AdminLessonDraftController`, `LessonDraftService`, `AdminLessonStageIT` |
| AC-2 activity endpoints | **Partial** — same gap on `GET .../activities/{id}` (#1); allow-list enforced via `STAGE_ACTIVITY_MISMATCH`; IT covers mismatch path. | `AdminLessonDraftController`, `DraftValidator.validateActivities`, `AdminLessonActivityIT` |
| AC-3 type-aware registry | Covered — 12 validator beans registered, fail-fast on dup `supports()`; unsupported type → `UNSUPPORTED_ACTIVITY_TYPE` at SAVE via `parseEnum`. | `DraftValidator.<ctor>`, all `validators/*.java`, `DraftValidatorTest` |
| AC-4 evidence CRUD+lifecycle | Covered — DRAFT→APPROVED→ARCHIVED enforced; PATCH refused on ARCHIVED; LIKE-scan on `snapshot_json` for in-use; `expectedRowVersion` on PATCH only (not on archive — #17). | `EvidenceService`, `AdminEvidenceIT` |
| AC-5 transitions | **Partial** — refs + DFS cycles covered; **terminal-reachability not enforced** (#2). | `DraftValidator.validateStageGraph` |
| AC-6 unique IDs | Covered — `id` regex, `DUPLICATE_ID` at stage + activity-within-stage; tests cover both. | `DraftValidator.validateStages/validateActivities`, `DraftValidatorTest` |
| AC-7 optimistic lock | **Partial** — mechanism in place (`@Version` + explicit `expectedRowVersion` check); only evidence PATCH + draft PUT covered by test. Missing stage/activity mutation IT. | `LessonDraftService.mutateDraft`, `EvidenceService.checkVersion`, `AdminLessonIT`, `AdminEvidenceIT` |
| AC-8 incomplete saves | Covered — `ValidationLevel.SAVE` tolerates missing config/instruction/empty stages; structural checks still fire. IT asserts `READ` without config saves 201. | `DraftValidatorTest.saveLevel_toleratesIncompleteDraft`, `AdminLessonActivityIT.addActivity_201_inAllowedStage` |
| AC-9 validate endpoint | **Partial** — always-200 + no `lesson_versions` insert (verified in IT) + centralQuestion/objectives/template.schemaVersion checked; `summary` lacks `evidenceRefs` (#3); `ready` flag correctly derived. | `LessonService.checkPublishReadiness`, `AdminLessonValidateIT` |
| AC-10 auth | **Partial** — `SecurityConfig` already maps `/api/v1/admin/**` → `ROLE_CONTENT_ADMIN` (covers all new endpoints); **no LEARNER/anon tests for the new routes** (#5). | `SecurityConfig.java:66`, `AdminLessonIT.auth_anon401_learner403` |
| AC-11 regression+docs | Covered — `mvnw verify` green (user-reported: 80 ITs + 41 units); `API_SPEC.md` §3 table updated, `DATABASE_DESIGN.md` §V6/§4 contract refreshed; existing `AuthRefreshIT`/`AdminEventIT`/`AdminLessonIT`/`FlywayMigrationIT` adopt `clearAuthoringTables`. | `AbstractPostgresIT.clearAuthoringTables`, docs diff |

## Positive observations

- `mutateDraft` pipeline is clean and consistent: load → version check → status check → mutate → SAVE validate → persist. Single entry point for all sub-resource writes — hard to bypass.
- `LEARNER_HIDDEN_KEYS` marked in `DraftSchema` as the TASK-0010 strip boundary — forward-thinking.
- `EVIDENCE_IN_USE` uses a single conservative `LIKE` scan on `snapshot_json` — simple and correct for MVP.
- Registry pattern mirrors the planned TASK-0010 `ActivityHandler` registry — consistent naming, easy to extend.
- Error envelope reuse (`ApiError.of`) keeps the new handlers aligned with existing contract.
- `clearAuthoringTables` centralizes the FK-safe cleanup; every new IT uses it.
- `DraftValidator` registry fails fast on duplicate `supports()` — good defensive choice.

## Recommended actions (in order)

1. Add `GET /stages/{stageId}` and `GET /stages/{sid}/activities/{aid}` endpoints + service lookups (AC-1/AC-2 gap).
2. Implement `NO_TERMINAL_STAGE` PUBLISH-level check (AC-5) — DFS the graph, require at least one reachable stage with empty `nextStageIds`.
3. Implement "at least one required stage with non-READ required activity" + `requireAllRequiredStages` semantics at PUBLISH (AC-5 / LEARNING_ENGINE_DESIGN §9).
4. Add `evidenceRefs` count to `summary` in `checkPublishReadiness` (AC-9).
5. Add ITs: stage PATCH stale `expectedRowVersion` → 409 (AC-7); LEARNER→403 + anonymous→401 on stage/activity/evidence/validate endpoints (AC-10).
6. Hoist `buildContext` out of per-activity loop; reuse `ctx.evidenceUsable` for stage-level refs (perf).
7. Decide and document `STAGE_ALLOWED_ACTIVITIES` widening vs phase-01; tighten or update docs.
8. Return real `rowVersion` in reorder/delete responses (AC-1 client contract).
9. Accept `expectedRowVersion` on `POST /{id}/archive` for evidence (optimistic-lock parity).
10. Extract `adminId()`/`parseSort()` to shared helpers; remove dead `existingEvidenceIds` field; remove duplicated `ids.add(id)` line.

## Metrics

- LOC delta (main): ~1,900 across 30 new files + 5 modified (DraftValidator package + service + 2 controllers + 19 DTOs + 2 repositories + 2 domain entities + 6 exceptions + V6 SQL).
- Test LOC delta: ~700 (4 new ITs, 1 new unit-test class).
- `mvnw verify`: green per user report (80 ITs + 41 units, 0 failures) — not re-run.
- File sizes: `DraftValidator` 380 lines (over 200-line guideline but cohesive); `LessonDraftService` 405 lines (same); both borderline acceptable.

## Unresolved questions

- Should `STAGE_ALLOWED_ACTIVITIES` be tightened to match phase-01 (MULTIPLE_CHOICE only under EVIDENCE_SELECT-bearing stages?) or phase-01/docs updated to bless the wider map?
- Is `top-level objectives` intended (phase-01 schema includes it) or should `TOP_LEVEL_KEYS` stay strict?
- Is `expectedRowVersion` mandatory on sub-resource mutations (today optional — `null` skips check)? Recommend keeping optional for ergonomics, but tighten docs.
- Should `archive` accept `expectedRowVersion` per plan, or is the current "no body" contract intentional?

— end of report
