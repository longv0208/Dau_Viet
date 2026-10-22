# Phase 05 — Mock data + tests

## Context links

- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` — Testcontainers base; `clearAuthoringTables` needs `delete from map_locations` FIRST
- `dau-viet-backend/src/test/java/com/dauviet/learning/AttemptItFixture.java` — attempt seeding helpers (reuse for COMPLETED attempt fixtures)
- `dau-viet-backend/src/test/java/com/dauviet/learning/AttemptCompletionIT.java` — how completed attempts are produced
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonPublishIT.java` — publish helpers
- `dau-viet-mobile/test/fakes/fake_attempt_repository.dart` — fake pattern
- `dau-viet-mobile/test/learning/lesson_player_test.dart`, `mock_mode_test.dart` — widget test conventions
- `dau-viet-mobile/lib/features/map/data/mock_map_repository.dart` (phase 04)

## Overview

- Priority: P0
- Mock fixture data for `USE_MOCK=true` + focused backend ITs + Flutter widget tests.

## Mock data

`mock_map_repository.dart` fixture — 4-5 demo locations around Bạch Đằng / northern VN showing ALL THREE states:

- `loc-bach-dang-estuary` (AVAILABLE, no unlockLessonId) — "Cửa sông Bạch Đằng"
- `loc-yen-giang` (LOCKED, requiredLesson = demo lesson "Bí mật chiến thắng Bạch Đằng (Demo)", lessonId `demo-lesson-bach-dang` — must match `MockAttemptRepository.listLessonsForEvent` id)
- `loc-dong-son` (UNLOCKED — mock returns UNLOCKED statically; document that mock does not simulate completion-driven state changes)
- Optional `loc-hoa-lu`, `loc-co-loa` for visual density.

Decision: mock returns static states — do NOT wire mock unlock to `MockAttemptRepository._completed` state (KISS; keeps mock deterministic for tests/screenshots). Document this in repo javadoc.

## Backend integration tests

Create `dau-viet-backend/src/test/java/com/dauviet/map/MapLocationApiIT.java` (extends `AbstractPostgresIT`) covering:

1. `GET /map/locations` unauthenticated → 401.
2. Location on DRAFT/ARCHIVED event → absent from list; detail → 404 `MAP_LOCATION_NOT_FOUND`.
3. Location without `unlockLessonId` → `AVAILABLE` for any learner.
4. Location with `unlockLessonId`, learner with no completed attempt → `LOCKED` + `requiredLesson{lessonId,title}`.
5. Learner completes an attempt (reuse `AttemptItFixture`/`AttemptCompletionIT` helpers: seed lesson + published version + attempt + `lesson_results`/status COMPLETED) → state flips to `UNLOCKED`.
6. Republish the lesson (new `lesson_versions` row) → old COMPLETED attempt still unlocks (version-agnostic check on `v.lesson_id`).
7. Different learner without completion still sees LOCKED — per-learner isolation.
8. `GET /map/locations/{id}` locked → response JSON contains no fields beyond the preview contract (assert absence of `eventDescription`-like extras — trivially covered by DTO shape; assert `requiredLesson.title` present).
9. Admin CRUD: create → list → patch (`expectedRowVersion` OK + stale → 409) → delete → 404. `unlock_lesson_id` of another event → 422 `UNLOCK_LESSON_MISMATCH`. Coordinate out of range → 400 `VALIDATION_ERROR` (both @Min/@Max on DTO and DB CHECK as belt).
10. Role gating: `POST /admin/events/{id}/map-locations` as LEARNER → 403.

`MapLocationRepositoryIT` optional if service IT covers query — prefer IT over repo test (one suite).

Also update `AbstractPostgresIT.clearAuthoringTables`: add `jdbc.update("delete from map_locations")` BEFORE the lessons/events deletes.

## Flutter tests

Create `dau-viet-mobile/test/map/`:

1. `map_location_dto_test.dart` — JSON parse for all states incl. `requiredLesson` null/present.
2. `map_projection_test.dart` — lat/lng→offset mapping: center of bbox → canvas center; clamped out-of-range.
3. `historical_map_screen_test.dart` (widget):
   - Fake `MapRepository` (new `test/fakes/fake_map_repository.dart`) returning 3-state fixture → pump via `ProviderScope.overrides(mapRepositoryProvider)` — markers render with correct icons/lock state.
   - Tap locked marker → sheet shows required lesson title + CTA.
   - Error state → retry button invalidates provider.
   - Empty list → empty-state widget.
   - List-toggle renders rows.
4. `mock_mode_map_test.dart` — `USE_MOCK` path uses `MockMapRepository` (mirror `mock_mode_test.dart` structure if it asserts provider selection).

## Implementation steps

1. Update `AbstractPostgresIT`.
2. Write `MapLocationApiIT` fixture helpers (seed event PUBLISHED + lesson + published version + completed attempt) — reuse `AttemptItFixture` if it already builds that chain.
3. Backend ITs above.
4. Mock repo fixture + DTO tests + projection tests.
5. Widget tests + fake repo.
6. Run: backend `mvnw test -Dtest='*Map*IT,*Map*Test'`; mobile `flutter test test/map`.

## Todo

- [ ] `clearAuthoringTables` update
- [ ] `MapLocationApiIT` (10 cases)
- [ ] `MockMapRepository` fixture (3+ states)
- [ ] DTO/projection unit tests
- [ ] Screen widget tests + `FakeMapRepository`

## Success criteria

- All backend ITs green on Testcontainers Postgres.
- `flutter test` green incl. existing suite (no regression on TASK-0019/0020).
- No test relies on hard-coded event slug `bach-dang-938` for logic branches (fixtures may use it as data only).

## Risks

- Attempt fixture complexity — if `AttemptItFixture` lacks a "complete directly" helper, complete via `complete()` service call in the IT, not raw SQL (keeps invariant `lesson_results` row consistent).
- Widget test hitches with `CustomPaint` sizing — wrap screen in `MediaQuery` + fixed `SizedBox` per existing tests' conventions.

## Security considerations

- Negative tests are first-class (cases 1, 7, 10 above) — per AGENTS.md invariants.
