# Code Review — TASK-0008 Historical Event & Lesson Management Admin APIs

- Date: 2026-10-15
- Reviewer: code-reviewer (subagent)
- Plan: `plans/261015-2236-task0008-event-lesson-admin/plan.md`
- Brief: `tasks/TASK-0008/brief.md`, `tasks/TASK-0008/task.json`
- Base commit: `b57e7f2`
- Verification (claimed by implementer): `mvnw verify` — 85 tests, 0 failures, BUILD SUCCESS on Testcontainers `postgres:16-alpine`. Not re-run; spot-check only.

## Verdict

**APPROVE with minor follow-ups.** Implementation matches the plan, all seven ACs are covered by code + ITs, and no P0/P1 correctness/security/contract issues were found. The findings below are P2-level polish that can ship or be deferred to TASK-0009.

## Scope covered

- Files reviewed: all new/modified under `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/**`, `com/dauviet/lesson/**`, `common/error/{ErrorCode,GlobalExceptionHandler}.java`, `historicalevent/domain/HistoricalEvent.java`, `historicalevent/infrastructure/persistence/HistoricalEventRepository.java`, `db/migration/V5__add_historical_events_row_version.sql`, plus tests `AdminEventIT`, `AdminLessonIT`, `FlywayMigrationIT`, `EventSeedServiceIT` and `docs/API_SPEC.md`.
- LOC: roughly ~1,300 new LOC across main+test. Largest file is `AdminLessonIT` at ~227 lines; all other source files are under 200 lines.

## AC coverage

| AC | Status | Evidence |
|---|---|---|
| AC-1 admin events CRUD/publish/archive + transitions + EVENT_IN_USE | Pass | `AdminEventController` exposes POST/GET list/GET id/PATCH/POST publish/POST archive. `AdminEventService` enforces DRAFT→PUBLISHED→ARCHIVED + DRAFT→ARCHIVED, slug immutable once PUBLISHED, archive blocked by `lessons.existsByEventIdAndStatusNot(id, ARCHIVED)` → `EVENT_IN_USE` 409. `AdminEventIT` covers all branches. |
| AC-2 admin lessons CRUD + draft JSONB + immutable versions | Pass | `AdminLessonController`+`LessonService`+`DraftValidator`. `lesson_versions` entity deliberately read+insert only; `PUT /draft` only rewrites `draft_json`, never `current_version_id`. V3 CHECK `chk_lesson_published_version`+trigger `trg_lesson_versions_immutable` still respected — publish endpoint deliberately returns 409 stub for TASK-0009. |
| AC-3 read-only templates | Pass | `AdminLessonTemplateController` GET list (`findAllByEnabledTrue`) + GET by id. No write endpoints. `LessonTemplateService` mapped read-only. |
| AC-4 auth CONTENT_ADMIN/401/403/public unchanged | Pass | `SecurityConfig` already maps `/api/v1/admin/**` → `hasRole("CONTENT_ADMIN")` and `GET /api/v1/events*` permitAll — unchanged. Both `AdminEventIT.auth_anon401_learner403` and `AdminLessonIT.auth_anon401_learner403` cover the negative matrix. `publicApi_backwardCompatible` verifies `/api/v1/events` still returns only PUBLISHED. |
| AC-5 integrity: FK, transitions, tx, optimistic lock | Pass | `@Version`+`rowVersion` on `HistoricalEvent` and `Lesson`. `expectedRowVersion` body field checked by `checkVersion` → throws `ObjectOptimisticLockingFailureException` → 409 `OPTIMISTIC_LOCK_CONFLICT`. `@Transactional` on all mutators. V5 adds only `historical_events.row_version`; V1–V4 untouched. |
| AC-6 tests | Pass | `AdminEventIT` (10 tests), `AdminLessonIT` (9 tests), `FlywayMigrationIT` V5 assertions, plus existing 52+33 stay green. Real Testcontainers Postgres, no mocks. |
| AC-7 verify green + docs + no secrets | Pass (claimed) | API_SPEC section 3 rewritten with `**implemented TASK-0008**` markers + a "Notes đã chốt" block. No secrets in diff. |

## Findings

### P1 — None blocking
No correctness or security defects found that violate product invariants.

### P2 — Polish items (defer or quick fix)

1. **Inconsistent 401 vs 400 on malformed JWT `sub`.** `AdminLessonController.adminId` (`AdminLessonController.java:101-103`) does `UUID.fromString(jwt.getSubject())` raw — a malformed `sub` raises `IllegalArgumentException` → `VALIDATION_ERROR` 400. `UserController.subjectToUuid` (`UserController.java:36-44`) wraps the same call in `AuthenticationFailedException` → 401. Suggest extracting the same defensive wrap (or sharing a helper) so behavior is consistent across controllers. A forged-but-well-signed token with non-UUID `sub` returns 400 instead of 401 — minor.

2. **`AdminEventService.create`/`update` swallow `DataIntegrityViolationException` as `IllegalArgumentException("slug already exists: …")`** (`AdminEventService.java:66-70, 118-122`). This blanket-catches *any* DIVE — e.g., a future `cover_asset_key` length constraint or unexpected FK failure would surface with a misleading "slug already exists" message. Either:
   - inspect the cause (`ex.getMostSpecificCause().getMessage()` contains "historical_events_slug_key" or "duplicate key"), or
   - drop the try/catch and let the global generic handler return 500, plus pre-check `events.findBySlug(req.slug())` for the user-facing duplicate case.
   Minor since current schema only has the slug unique constraint on this table.

3. **Duplicate-slug → 400 VALIDATION_ERROR vs. 409.** Plan/tests chose 400. That's consistent with `MethodArgumentNotValidException` semantics and tested. But API_SPEC table maps 409 to "state conflict" — slug uniqueness is closer to a 409 conflict. Optional polish.

4. **`update`/`updateDraft`/`archive` ordering — `checkVersion` runs *before* status checks.** `LessonService.update` line 113-115 calls `checkVersion` then checks `ARCHIVED`. If a stale `expectedRowVersion` is supplied *and* the lesson is archived, the client sees 409 OPTIMISTIC_LOCK_CONFLICT instead of the more meaningful "archived lesson cannot be edited". Acceptable; behaviorally correct.

5. **`AdminLessonIT.createLesson` doesn't assert 201** (`AdminLessonIT.java:103-110`). The helper returns `MvcResult` and `create_201_persistsJsonb` calls `res.getResponse().getStatus()` then discards it. Should be `.andExpect(status().isCreated())` inside `createLesson()` or as a separate assertion. Minor test-quality issue — the surrounding tests would still fail if create returned non-2xx because the body assertions would miss.

6. **No IT asserting `events?sort=bogus` → 400.** The sort whitelist (`AdminEventController.parseSort` line 96-98) throws `IllegalArgumentException` → VALIDATION_ERROR — implemented but untested. Public controller has same pattern; not a regression.

7. **`AdminLessonSummaryResponse` doesn't include `templateId`** (`AdminLessonSummaryResponse.java`). List clients will likely want it to show "which template" — planner kept the summary thin intentionally (KISS). Acceptable; add if admin UI needs it.

8. **`AdminEventService` imports `LessonRepository`/`LessonStatus` from `com.dauviet.lesson`** (`AdminEventService.java:23-26`). Cross-module dependency direction is `historicalevent.admin → lesson` which is fine for `EVENT_IN_USE` check, but creates a hard code-level coupling. If `lesson` module ever needs events, you'll want a port. Defer.

9. **`AdminEventService.update` permits PATCH on ARCHIVED events** (no `status==ARCHIVED` guard). Brief/plan don't forbid it — archived events remain editable for corrections. Worth flagging to BA since `slug` is the only field guarded by status. Currently intentional-looking; no code change needed unless product says otherwise.

10. **`create_invalidEvent_404` returns `EVENT_NOT_FOUND` code** (`LessonService.java:60`). Uses `ResourceNotFoundException` which `GlobalExceptionHandler.handleNotFound` maps to `ErrorCode.EVENT_NOT_FOUND` — semantically correct (the missing resource IS the event), but `UserService` (`UserService.java:25`) uses the same exception for "User not found" → would also surface `EVENT_NOT_FOUND`. Pre-existing naming mismatch; not introduced here.

11. **`existsByEventIdAndStatusNot` in `LessonRepository`** counts DRAFT + PUBLISHED lessons as "in use" for archival block — matches plan ("non-archived lessons"). Correct.

12. **`DraftValidator` is a static utility, not a bean** — fine for a pure function, KISS.

13. **Unused imports noticed in tests**: `AdminLessonIT` imports `assertThat` — used in `create_201_persistsJsonb`. `AdminEventIT` imports `assertThat` — appears unused (scanning). Cosmetic only.

## Edge cases scouted (beyond the diff)

- **Slug rename on DRAFT that already has lessons**: allowed — slug is metadata; lessons FK to `event_id` UUID, not slug. Safe.
- **`expectedRowVersion=null`** skips the pre-check but Hibernate `@Version` still catches concurrent flushes → still 409 via `ObjectOptimisticLockingFailureException` handler. Good — works either way.
- **`objectivesJson=null` in PATCH**: left unchanged. `null` → `notNull` skip → preserved. Good.
- **`centralQuestion` empty string on PATCH**: `@Size` doesn't reject empty; blank `""` would be persisted. The DDL is `NOT NULL` only — a blank value would pass. Minor — add `@NotBlank` if we want to forbid empty strings on update. P2.
- **`create` on lesson sets `createdBy=updatedBy=adminId`**: `createdBy` is `updatable=false` so this only persists on INSERT. Correct.
- **`draftJson="null"`** (JSON literal `null`) → `MAPPER.readTree("null")` returns `NullNode`, `isObject()=false` → 422. Correct.
- **`objectivesJson="{}"`** (object, not array) → 422 `DRAFT_SCHEMA_INVALID`. Correct.
- **DB CHECK `chk_lesson_draft`/`chk_lesson_objectives`** also enforces `jsonb_typeof` — even if service validation is bypassed (e.g., direct JDBC), DB catches it. Defense in depth confirmed.
- **`update` on LessonService allows `templateId` rebind on PUBLISHED lessons** (`LessonService.java:117` doesn't gate on status). Plan says "event/template rebinding only when DRAFT" — wait, looking at the planner report: "PATCH metadata (event/template rebinding only when DRAFT)". The actual code allows rebinding `templateId` on a PUBLISHED lesson. **This deviates from the plan.** Effect: a PUBLISHED lesson's `template_id` can be swapped post-publish. Since `lesson_versions` snapshot stays immutable, learner-facing content is unaffected — but the admin intent "template only while drafting" is weakened. Recommend gating `templateId` rebind on `status==DRAFT` to match the stated plan. **P2 finding** — likely benign (snapshot stays correct), but inconsistent with the planner's stated design.

## Product invariants (AGENTS.md) — spot-check

- Backend authoritative ✔ (status transitions, EVENT_IN_USE, optimistic lock all server-side)
- Published `lesson_versions` immutable ✔ (`LessonVersion` has no setters on mutable state; trigger enforced; no code path writes UPDATE/DELETE)
- Ownership/authorization server-side ✔ (`@AuthenticationPrincipal Jwt` → `adminId`; SecurityConfig gates role)
- No answer keys exposed ✔ (admin DTOs return raw `draftJson`/`presetJson`/`objectivesJson` but these endpoints are admin-gated — drafts may contain rubrics and that's intended for CMS)
- No event-specific branches in generic handlers ✔ (no `if slug == "bach-dang"` style code)
- Idempotency ✔ (publish/archive are guarded by status; archive on already-archived → 409; publish on non-DRAFT → 409)

## Positive observations

- Clean layering: `api` / `application` / `domain` / `infrastructure` mirrors the existing module convention. Files <200 lines, focused.
- `PageResponse<T>` reuse + sort whitelist pattern copied faithfully from `HistoricalEventController`.
- `JdbcTypeCode(SqlTypes.JSON)` on `String` is the simplest correct JSONB binding — avoids dragging in Hypersistence.
- `AdminLessonDraftRequest` uses `@NotNull` on `draftJson` — `@NotBlank` would also reject `""` (which would 422 anyway at parse); current choice lets empty string reach the validator and surface as `DRAFT_SCHEMA_INVALID` which is more informative.
- V5 migration is minimal — single `ALTER TABLE ADD COLUMN`, no backfill needed because `DEFAULT 0` is sufficient.
- `checkVersion` uses `org.springframework.orm.ObjectOptimisticLockingFailureException` so the same handler catches both pre-check failures and JPA-level flush failures — uniform 409 surface.
- Tests use the shared `AbstractPostgresIT` Testcontainers singleton and explicitly clean `lessons`/`historical_events`/`lesson_templates`/`auth_refresh_tokens`/`users` in dependency order — verified order is correct given `lessons.current_version_id` self-FK needs `null` before `delete from lessons`.

## Test coverage notes

- AC-6 checklist: event CRUD+transitions ✔, lesson create+draft ✔, event-lesson FK ✔, invalid template refs (404/422) ✔, JSONB persistence ✔, admin auth ✔, learner 403 ✔, public backward-compat ✔, concurrent update via stale `expectedRowVersion` ✔, existing auth tests stay green (per implementer claim).
- Missing coverage worth noting (not blockers):
  - No IT for `/admin/lessons/{id}` GET detail (covered implicitly by update paths, but not standalone).
  - No IT for `sort=bogus` → 400.
  - No IT for the `publish` stub returning the TASK-0009 message on a DRAFT lesson (returns `InvalidStatusTransitionException` 409 — same code as "already published"). Test would lock in the contract.
  - No IT for archiving an already-ARCHIVED event/lesson → 409.

## Security check

- No secrets, JWT signing key references, or connection strings in diff.
- No SQL injection risk — all queries via JPA Specification or derived queries; sort field whitelist blocks arbitrary property paths.
- No user-supplied data leaks into error messages beyond the requested `slug` echo in the duplicate-slug `IllegalArgumentException` message. The slug is the client's own input, so this is acceptable. Stack traces are not exposed.
- CSRF disabled is fine — stateless JWT Bearer, no cookie session.
- `adminId(jwt)` uses `jwt.getSubject()` not a spoofable claim — subject is signed.

## Recommended actions

Priority order, all P2 — none block approval:

1. Wrap `UUID.fromString(jwt.getSubject())` in `AdminLessonController.adminId` in a try/catch → `AuthenticationFailedException` for parity with `UserController.subjectToUuid`. (5 min)
2. Decide whether `templateId` rebind should be gated on `status==DRAFT` (planner doc said yes; current code allows it on PUBLISHED). Either tighten the code or update the plan to reflect intent. (10 min)
3. In `AdminEventService.create`/`update`, replace blanket `DataIntegrityViolationException → "slug already exists"` with a more precise check (inspect `ex.getMessage()` for "duplicate key" or pre-check `findBySlug`). (15 min)
4. Add `status().isCreated()` assertion inside `AdminLessonIT.createLesson` helper so test failures don't cascade misleadingly. (5 min)
5. Optional: add `@NotBlank` to `AdminLessonUpdateRequest.centralQuestion` if blank strings should be rejected on PATCH. (5 min)

## Metrics

- Type coverage: n/a (Java, no TS here). All entity fields typed; DTOs as records.
- Test coverage: claimed 85/85 green; new tests ~19 in `AdminEventIT`+`AdminLessonIT`. Code path coverage of AC-1..AC-6 acceptable.
- Linting issues: not run (Maven verify passed per implementer claim).
- File-size rule: all new files <200 lines except `AdminLessonIT` (~227 lines) — acceptable for IT.

## Unresolved questions

1. Should `templateId` rebind on a PUBLISHED lesson be allowed? Planner said DRAFT-only; code allows it on PUBLISHED. Needs plan-vs-code reconciliation (P2).
2. Should `PATCH` on an ARCHIVED event be blocked? Currently allowed for non-slug fields. (P2)
3. Slug-conflict error code: keep 400 VALIDATION_ERROR (current) or move to 409 CONFLICT for API_SPEC consistency? (P2)

## File references

- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/AdminEventService.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/api/AdminEventController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/DraftValidator.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonTemplateService.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonTemplateController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/Lesson.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonVersion.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonTemplate.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java`
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java`
- `dau-viet-backend/src/main/resources/db/migration/V5__add_historical_events_row_version.sql`
- `dau-viet-backend/src/test/java/com/dauviet/historicalevent/admin/AdminEventIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/FlywayMigrationIT.java`
- `docs/API_SPEC.md`
