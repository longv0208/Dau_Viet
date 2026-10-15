# Phase 05 — Integration tests

## Context links

- `tasks/TASK-0008/task.json` AC-6
- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` — shared Testcontainers base
- `dau-viet-backend/src/test/java/com/dauviet/admin/AdminPingIT.java` — admin auth test pattern (creates User + `jwtTokenService.createAccessToken`)
- `dau-viet-backend/src/test/java/com/dauviet/EventsPublicIT.java` — public surface pattern
- `dau-viet-backend/src/test/java/com/dauviet/FlywayMigrationIT.java` — extend with V5 + entity-shape checks

## Overview

- Priority: P1 — gate for AC-6 / AC-7.
- Status: pending
- Spring Boot `@SpringBootTest` + `@AutoConfigureMockMvc` ITs covering the full AC matrix. Reuse `AbstractPostgresIT`.

## Key insights

- All ITs share the static Postgres container — ordering not guaranteed. Each test class seeds its own data in `@BeforeEach` (`deleteAll` in reverse FK order) to avoid cross-test contamination.
- Test order for cleanup: `lesson_versions` → `lessons` → `lesson_templates` → `historical_events` → `users` (deleteAll in that order to respect FK). Templates have no `ON DELETE CASCADE` so `deleteAll` ordering matters.
- For "V5 applied" check, extend `FlywayMigrationIT` with a `flywayV5Applied` test that asserts `version='5'` row exists.
- For "concurrent update → 409" test: don't actually race two threads (flaky). Instead simulate stale state — load entity, modify+save it once to bump `row_version`, then send `PATCH`/`PUT draft` with the now-stale `expectedRowVersion`. Asserts the optimistic-lock path produces 409. Real concurrency coverage via `@Version` is already enforced by JPA at flush time.
- `Lesson.draftJson` is JSONB — to assert persistence round-trip, save a draft, reload via repo, assert `JsonNode` field equality on a marker field.

## Requirements (AC-6 mapping)

| Test | AC |
|---|---|
| `AdminEventsIT.create_happyPath_201` | AC-1 |
| `AdminEventsIT.create_invalidSlug_400` | AC-1 |
| `AdminEventsIT.list_paginationAndFilters` | AC-1 |
| `AdminEventsIT.getById_404` | AC-1 |
| `AdminEventsIT.update_partialFields` | AC-1 |
| `AdminEventsIT.update_slugOnPublished_409` | AC-1 |
| `AdminEventsIT.publish_draftToPublished_200` | AC-1 |
| `AdminEventsIT.publish_alreadyPublished_409` | AC-1 |
| `AdminEventsIT.archive_draft_200` | AC-1 |
| `AdminEventsIT.archive_publishedWithLiveLesson_409_EVENT_IN_USE` | AC-1 |
| `AdminEventsIT.anonymous_401` `learner_403` | AC-4 |
| `AdminLessonsIT.create_happyPath_201` | AC-2 |
| `AdminLessonsIT.create_eventNotFound_404` | AC-2 |
| `AdminLessonsIT.create_templateNotFound_404` | AC-2 |
| `AdminLessonsIT.create_templateDisabled_422` | AC-2 |
| `AdminLessonsIT.list_filtersByEventAndStatus` | AC-2 |
| `AdminLessonsIT.update_metadata` | AC-2 |
| `AdminLessonsIT.updateDraft_validJsonb_200` | AC-2 |
| `AdminLessonsIT.updateDraft_staleExpectedVersion_409` | AC-2, AC-5 |
| `AdminLessonsIT.updateDraft_invalidSchema_422` | AC-2 |
| `AdminLessonsIT.updateDraft_onArchived_409` | AC-2 |
| `AdminLessonsIT.archive_publishedKeepsVersionRow` | AC-2, AC-5 |
| `AdminLessonTemplatesIT.list_enabledOnly` | AC-3 |
| `AdminLessonTemplatesIT.getById_disabled_404` | AC-3 |
| `EventsPublicIT` (existing) — assert still 200 + only PUBLISHED | AC-4 |
| `FlywayMigrationIT.flywayV5Applied` | AC-5 |
| `FlywayMigrationIT.historicalEventsHasRowVersion` | AC-5 |

## Architecture

```
dau-viet-backend/src/test/java/com/dauviet/
├── historicalevent/admin/
│   └── AdminEventsIT.java
└── lesson/
    ├── AdminLessonsIT.java
    └── AdminLessonTemplatesIT.java
```

Test helper: extract `user(email, role)` + `bearer(u)` into a package-private `TestAuthHelper` OR copy the small private method into each IT (DRY vs locality — choose copy to keep ITs self-contained like existing pattern; `AdminPingIT`/`AuthRefreshIT` already inline this).

## Related code files

### Create

- `dau-viet-backend/src/test/java/com/dauviet/historicalevent/admin/AdminEventsIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonsIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonTemplatesIT.java`

### Modify

- `dau-viet-backend/src/test/java/com/dauviet/FlywayMigrationIT.java` — add `flywayV5Applied` + `historicalEventsHasRowVersion` tests.
- (Optional) `EventsPublicIT.java` — add assertion that published events remain visible after admin actions (only if cheap; the existing test already guards the baseline).

### Delete

- None.

## Implementation steps

1. Each IT class: `@SpringBootTest @AutoConfigureMockMvc class XIT extends AbstractPostgresIT` + `@BeforeEach` cleanup.
2. Seed helpers:
   - `adminUser()` → creates `User` with `UserRole.CONTENT_ADMIN`, returns access token.
   - `learnerUser()` → `LEARNER` token.
   - `seedEvent(status)` → `HistoricalEvent` persisted directly via `HistoricalEventRepository` (faster than going through API for setup).
   - `seedTemplate(enabled)` → `LessonTemplate` via `LessonTemplateRepository`.
   - `seedLesson(eventId, templateId, status)` → `Lesson` via `LessonRepository`.
3. Write each test per the AC-mapping table.
4. The concurrency test uses the stale-version trick (single MockMvc call with wrong `expectedRowVersion` after a save bumps `row_version`).
5. Run `mvnw -q test-compile`, then `mvnw verify` (requires Docker).

## Todo

- [ ] `AdminEventsIT` — ~10 tests.
- [ ] `AdminLessonsIT` — ~10 tests.
- [ ] `AdminLessonTemplatesIT` — ~3 tests.
- [ ] `FlywayMigrationIT` — +2 tests.
- [ ] `EventsPublicIT` — unchanged, must still pass.
- [ ] `mvnw verify` — green locally (Docker) or `NOT VERIFIED` honestly reported.

## Success criteria

- `mvnw verify` exits 0 with all new + existing tests green.
- Coverage matches AC-6 list.
- Public surface unchanged — `EventsPublicIT.events_200_unauthenticated` still passes (regression guard).

## Risk assessment

- **Risk:** tests flake if `deleteAll` ordering violates FK. Mitigation: order in `@BeforeEach` exactly as listed above.
- **Risk:** optimistic-lock test depends on `@Version` actually being mapped — phase-01 must complete first. If `row_version` is unmapped, second save won't conflict and the test fails — that's the desired signal.
- **Risk:** JSONB serialisation differences (whitespace, key order) between `JsonNode` equality. Mitigation: compare `JsonNode` trees, not raw strings.

## Security considerations

- Tests must NOT log tokens.
- Seed data uses fake emails (`@test.vn`), no real PII.

## Next steps

- Phase 06 docs + `task.json` `acEvidence` mapping.
