# Independent Code Review Report — TASK-0027 (Issue #27: `[E2E] Mobile: kiểm thử Đảo Di Sản và bài học`)

## Verdict: `APPROVE`

All five Acceptance Criteria (AC-1 through AC-5), security/privacy constraints, fixture isolation and FK-safe cleanup guarantees, and product invariants defined in `AGENTS.md` and `docs/CODING_RULES.md` are satisfied.

## Role Mapping Note
- `reviewer` subagent role returned `Error: No model selected` in `.omp/agent`, so independent read-only review was executed via `scout` (`IndependentCodeReviewer`) on a fresh context window.

## Summary
- **E2E Suite & Harness**: `dau-viet-mobile/e2e/specs/island-and-lesson.spec.mjs` and `dau-viet-mobile/e2e/fixtures/test-harness.mjs` execute real end-to-end user journeys on Flutter Mobile Web in a mobile Chrome viewport (`390x844`) with `USE_MOCK=false` connected to the real Spring Boot backend (`http://localhost:8080`, profile `local`) and PostgreSQL (`localhost:5433/dauviet`).
- **Flutter Mobile Production & Test Fixes**:
  - `main.dart`, `router.dart`, `auth_repository.dart`, and `learning_providers.dart` enable web URL reflection (`GoRouter.optionURLReflectsImperativeAPIs = true`), semantics binding, session restoration prior to mounting `DauVietApp`, and reactive `GoRouter` redirect evaluation (`authRouterRefreshNotifier`) when auth state changes.
  - `island_screen.dart` and `island_isometric_renderer.dart` expose stable accessibility semantics labels (`Ô di sản <key>: <name>`, `Ô trống <key>`, `Ô khóa <key> Cấp <tier>`) and `FittedBox` bottom toolbar for 390px mobile viewports without overflow.
  - `kabi_mascot_widget.dart` safely skips Rive native dynamic library loading in `flutter_test` environments.
  - `island_dto_test.dart` and `island_screen_test.dart` align unit/widget assertions with the current semantics labels and DTO contracts (`14/14` passing).

## AC-by-AC Verification Table

| AC | Requirement | Verification & Assertions | Status |
|---|---|---|---|
| **AC-1** | Learner login; navigate from UI into a published lesson, start/resume attempt, complete at least 1 read activity and 1 interactive activity; UI shows server feedback before advancing. | `island-and-lesson.spec.mjs:57-150`: Logs in via `/auth` -> `/dashboard` -> Featured Event (`Xem chi tiết →`) -> `/campaign/:eventId` -> published test lesson -> `/learning/lesson/:lessonId` -> starts attempt (`POST /api/v1/lessons/:id/attempts`). Completes `READ` (`act-read-context`) and verifies server feedback (`CHÍNH XÁC! XUẤT SẮC!` + authored `readServerFeedback`) before clicking `TIẾP TỤC ›`. Completes `MULTIPLE_CHOICE` (`act-mc-verify`), verifying both `INCORRECT` and `COMPLETED` server feedback before completing lesson. | **PASS** |
| **AC-2** | Reload page mid-lesson continues exact attempt and lesson version; completing lesson displays result/progress from backend; retrying complete is idempotent. | `island-and-lesson.spec.mjs:113-182`: Publishes `versionNo: 2` while attempt is at `1/2`, executes `page.reload()`, and verifies `page.url()` retains `attemptId`, `/api/v1/attempts/:id/content` returns `lessonVersionId === versionV1Id` (`versionNo: 1`), and progress remains `1/2`. Completes lesson -> verifies `HOÀN THÀNH BÀI HỌC`, `+100 XP`, and `/api/v1/me/progress` (`completedCount === 1`). Retries `POST /api/v1/attempts/:id/complete` 3 times (same key and no key) -> asserts `alreadyCompleted: true` and `1` row each in `lesson_results`, `EXP` rewards, and `HISTORY_POINTS` rewards. | **PASS** |
| **AC-3** | Open Heritage Island from UI, verify occupied / empty / locked slot states and account-specific inventory list; place then remove a valid item, reload page and confirm state persisted in backend. | `island-and-lesson.spec.mjs:185-298`: Opens `/island` from `/dashboard`, verifies occupied slot (`Ô di sản slot_1`), locked slot (`Ô khóa slot_5`, no place button), and empty slot (`Ô trống slot_2`). Opens `KHO VẬT PHẨM TRANG TRÍ`, checks `Đã sở hữu` filter lists both account items (`item1` and `item2`), places `item2` on `slot_2`, reloads page, verifies backend + UI persistence, removes `item2` (`CẤT VÀO KHO`), reloads page again, and verifies `placedItemId === null` in backend and `Ô trống slot_2` in UI. | **PASS** |
| **AC-4** | Verify at least one error path per flow: unauthenticated redirected to login; API error shows message and retry action; locked slot cannot place item; no fake success on API error. | `island-and-lesson.spec.mjs:301-460`: (1) Unauthenticated access to `/#/learning/lesson/:id` and `/#/island` redirects to `/auth`. (2) Lesson submit HTTP 503 displays error banner, keeps progress at `0/2` without celebration, and succeeds on retry click. (3) Island load HTTP 500 displays `Không thể kết nối Đảo Di Sản` + error message and recovers on `THỬ LẠI`. (4) Placement HTTP 500 shows error snackbar and leaves slot empty (`placedItemId === null`). (5) Locked slot has no place button in UI and `PUT /api/v1/me/island/placements/:lockedSlotId` returns `403 SLOT_LOCKED`. | **PASS** |
| **AC-5** | Independent & repeatable test: clear fixture/cleanup, no hardcoded real data IDs, no logging tokens or private answers; recorded execution evidence. | `test-harness.mjs:127-445`: Unique `runId` per test, dynamic discovery of event/template/catalog items, transactional FK-safe cleanup verified by `expect(f.verifyCleanup()).toBe(0)` in `afterEach`. Zero tokens or answer keys logged. Passed 2 consecutive full runs (`3/3` in `48.1s` and `3/3` in `58.3s`) with 6 evidence screenshots saved under `dau-viet-mobile/e2e/test-results/evidence/`. | **PASS** |

## Findings
None. No blocking or non-blocking issues found.
