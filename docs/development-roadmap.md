# DẤU VIỆT — Development Roadmap

> Living document tracking project phases, milestones và progress. Update sau mỗi feature/milestone lớn.

## Phase: Gamification (GAME series)

| Task | Scope | Status | Notes |
|---|---|---|---|
| GAME-01 | Business rules baseline | Complete | `docs/GAMIFICATION_BUSINESS_RULES.md` |
| GAME-02 | Backend Thể lực (energy) | Complete | V21 `user_energy` + `energy_transactions`; `GET /me/energy`; penalty submit graded |
| GAME-03 | Flutter Thể lực UI | Complete | Energy display, ENERGY_DEPLETED handling, countdown |
| GAME-04 | Event Completion & Historical Dossier Collection | **Complete (2026-10-25)** | Xem bên dưới |
| GAME-05 | Item Unlock Rule Engine | **Complete (2026-10-25)** | V24–V27 AST `condition_json`, scope guard, provenance |
| GAME-06 | Admin CMS quản lý policy/dossier/rule | **Complete (2026-10-25)** | V28 + 3 admin modules + Gamification tab, `/dossiers`, Rule Builder |
| LEARN-STREAK | Chuỗi Ngày Học — Ngọn Lửa Hào Khí | **Complete (2026-10-26)** | V31 + backend streak module + Flutter UI end-to-end |
| GAME-07 | Wallet/Level/chi tiêu | Pending | |
| GAME-08 | Regression tổng thể | Pending | |

### GAME-04 — delivered (2026-10-25)

- **Schema** — `V22__event_completion_dossiers.sql`: 5 bảng mới (`event_completion_policies`, `user_event_progress`, `historical_dossiers`, `event_dossiers`, `user_dossier_unlocks`), idempotent seed theo event slug, 1 PUBLISHED policy/event, 8 dossiers canonical với citation thật.
- **Backend** — module `com.dauviet.collection`: `EventCompletionPolicyService`, `EventProgressEvaluator`, `EventMilestoneRecorder` (pg advisory lock per user+event), `EventProgressQueryService` (reconcile-on-read), `DossierService`, `DossierController`, `EventProgressController`. `CompleteAttemptResponse.newlyUnlockedDossiers` additive field.
- **Mobile** — collection screen 4-tab dossier UI (Dấu / Nhân vật / Địa điểm / Hiện vật), dossier detail screen, `EventProgressSection` trên campaign detail, once-only unlock banner trên lesson result.
- **Tests** — `EventCompletionIT` 20/20, `EventProgressEvaluatorTest` 10/10, `FlywayMigrationIT` updated to 18 tables. Backend `mvnw verify` **green 293/293** (2026-10-25). Flutter `flutter analyze` clean, `flutter test` **424/424**.

### GAME-06 — delivered (2026-10-25)

- **Schema** — `V28__historical_dossier_versions.sql`: bảng snapshot append-only `historical_dossier_versions` (UNIQUE `(dossier_id, dossier_version)`), `historical_dossiers` +`row_version` optimistic lock; backfill dossier PUBLISHED có sẵn. Không sửa V22–V27.
- **Backend** — Module A `AdminCompletionPolicyController` (list/detail/create DRAFT/`PUT` in-place DRAFT/`validate`/`publish` atomic với archive `saveAndFlush` + `expectedPolicyVersion` 409); Module B `AdminDossierController` (CRUD structured source — không raw JSON, publish → snapshot V28 + `pendingChanges`, `PUT /events/{id}/dossiers` replace-list); Module C `AdminItemRuleController` (`rule/validate` dry-run đúng pipeline scope-check, `rule/history` + grantCount). `GlobalExceptionHandler` bắt superclass `OptimisticLockingFailureException` → 409.
- **Admin UI** — tab `gamification` trong Event Workspace (PolicyEditor + DossierLinkTable), trang `/dossiers` (list/filter/editor + publish/archive), Rule Builder V2 + scope banner + history + `ReconcilePanel` trong `/items/[id]`.
- **Tests** — Backend `mvnw verify` **green 363 IT + 486 unit** (AdminCompletionPolicyIT, AdminDossierIT, AdminItemRuleIT); admin `typecheck` PASS, `vitest` **288/288**, `build` PASS (2026-10-25).

### LEARN-STREAK — delivered (2026-10-26)

- **Schema** — `V31__learning_streak.sql`: `user_learning_streaks` (current/longest/last_qualified_date, optimistic row) + `user_learning_streak_days` (ledger `UNIQUE(user_id, study_date)` — 3-layer idempotency); mirror `dau-viet-db/db/migration` + backfill script `dau-viet-db/scripts/` từ `learner_attempts.completed_at`.
- **Backend** — module `com.dauviet.streak`: `LearningStreakService` (pessimistic lock, thứ tự lock sau `learner_attempts`, `advanceTo` — same-day = 1, ngày liên tiếp +1, ngày bỏ lỡ reset 1, `longestStreak` không bao giờ giảm, timezone `Asia/Ho_Chi_Minh` server-side), `LearningStreakController` `GET /me/streak` + `GET /me/streak/calendar?from&to` (cap 92 ngày, 400 khi range ngược), hook trong `LearnerAttemptService.doComplete` cùng tx completion, `CompleteAttemptResponse.streak` additive — non-null CHỈ khi server ghi ngày học mới (không reward transaction — POINT-03).
- **Mobile** — `lib/features/streak/` (dto, api client, repository api/mock, `streakProvider` AsyncNotifier mirror energy + `streakCalendarProvider` family); `LearningStreakScreen` tại route `/streak` (flame hero, today message 4 trạng thái, stat cards, month calendar); dashboard pills đọc provider thật thay `'⚡12'`/`'❤️3'` hard-code; `_StreakCard` + menu trong profile; `_StreakBadge` số thật trong lesson player header; `_StreakFlameBanner` animation một-lần trên result screen qua `LessonResultDto.newlyRecordedStreak` (client-only).
- **Tests** — `LearningStreakServiceTest` 14/14, `LearnerAttemptServiceTest` 19/19; `flutter analyze` 0 errors, `flutter test` **438 pass** (2 fail `lesson_player_energy_test` pre-existing trên HEAD — ngoài phạm vi); IT Testcontainers blocked do Docker off (pre-existing).

### PATH-01 — delivered (2026-10-27)

- **Schema** — `V33__learning_path_v1.sql`: 4 bảng mới (`learning_path_versions`, `learning_path_chapters`, `learning_path_event_nodes`, `learning_path_lesson_nodes`); version `HISTORY_MAIN` v1; composite FKs bảo vệ toàn vẹn bài học cùng event; trigger bảo vệ tính bất biến của phiên bản PUBLISHED.
- **Backend** — module `com.dauviet.path`: `LearningPathService`, `LearningPathValidator`, `YearLabelFormatter` (quy ước TCN La Mã, không có năm 0), `LearningPathController` `GET /api/v1/learning-path` + `AdminLearningPathController` `GET /api/v1/admin/learning-path/audit`.
- **Dữ liệu V1** — 5 Chương chuẩn hóa (Buổi đầu dựng nước, Bắc thuộc, Buổi đầu độc lập, Thời nhà Lý, Kháng chiến chống Pháp), Hai Bà Trưng xuất hiện đúng 1 lần duy nhất, đánh giá trung thực `contentStatus` (`PLAYABLE`, `NO_PUBLISHED_LESSON`, `NO_COMPLETION_POLICY`).
- **Tài liệu** — `docs/LEARNING_PATH_2_0.md` làm nền tảng cho PATH-02, PATH-03, PATH-04, PATH-05.
- **Tests** — 14/14 tests pass (`YearLabelFormatterTest` 5/5, `LearningPathValidatorTest` 2/2, `LearningPathApiIT` 7/7).

### PATH-02..05 & MAP-02 (Epics A–F, Issues #2–#26) — delivered (2026-10-28)

- **Schema** — `V39__learning_path_hierarchy.sql` (`learning_path_chapters.parent_id`, `node_type ∈ ERA|PERIOD|PHASE`; `historical_events.end_year`, `date_precision`), `V40__heritage_locations.sql` (`map_locations` độc lập, `map_location_events`, `map_location_unlock_lessons`, `map_location_media`, `user_location_unlocks`), `V41__user_path_period_state.sql` (`user_path_period_state`), `V42__seed_history_main_v2.sql` (`HISTORY_MAIN` v2 với 4 ERA, 5 PERIOD), `V43__seed_heritage_location_assets_and_media.sql` (6 tranh di sản + 12 địa điểm canonical + media).
- **Backend** — Mở khóa tuần tự độc lập theo từng `PERIOD` (`LearnerPathProgressionService`), tự động nâng cấp enrollment lên bản `PUBLISHED` mới nhất, `POST /api/v1/me/learning-path/periods/{periodCode}/touch`, mở khóa bài học ngoài lộ trình (`#8`), `LocationUnlockEvaluator` (`LessonCompletionHook`) đánh giá luật `ANY`/`ALL` trong cùng transaction `complete()` và trả `newlyUnlockedLocations`, lọc bảo mật media `UNLOCKED_ONLY`, CRUD Admin cho cây lộ trình và địa điểm độc lập (`#11`–`#17`).
- **Admin UI** — Learning Path Builder dạng cây `ERA -> PERIOD -> PHASE` (`#18`), trang quản lý Địa điểm Di sản và Media độc lập (`#19`), panel Địa điểm mở khóa trong Lesson Builder (`#20`).
- **Mobile** — Data layer Learning Path 2.0 (`#21`), màn Chọn thời kỳ và Hành trình thời kỳ tại `/journey` và `/journey/:periodCode` (`#22`, hợp nhất vào `/map` ở `#36`), Trang chủ Tiếp tục hành trình từ `currentByPeriod[lastPeriodCode]` và trạng thái bài học trong Campaign Detail (`#23`), Bản đồ Di sản v2 và hồ sơ địa điểm (`/heritage/:locationId`, `#24`), banner địa điểm vừa mở khóa trên màn kết quả (`#25`), tích hợp điều hướng E2E và rà soát UX (`#26`), học trực tiếp trên Bản Đồ Dấu Ấn với ghim di tích vệ tinh sau khi học (`#36`).
- **Quyết định kỹ thuật (ADR-009)** — Chốt lộ trình Expand-and-Contract và 4 điều kiện tiên quyết để gỡ 2 cột deprecated `map_locations.event_id` và `map_locations.unlock_lesson_id` tại Milestone M4 Cleanup.
- **Tests** — Backend `LearningFlowHeritageEndToEndIT`, `LearningPathHierarchyAndPeriodIT`, `LearningPathApiIT`, `HeritageLocationV2IT` pass trên PostgreSQL 16 Testcontainers; Mobile `test/learning_path/`, `test/dashboard/`, `test/campaign/` pass 35/35.

## Phase: Learning core (đã hoàn thành các task trước)

TASK-0005, 0007–0012, 0020–0023 — xem `docs/PROJECT_OVERVIEW.md` + `docs/PROGRESS.md` cho trạng thái generated từ task JSON.

## Next up

- GAME-07: Wallet/Level/chi tiêu — `LEVEL_AT_LEAST` leaf của rule engine hiện UNSUPPORTED chờ wallet/level model.
- GAME-08: Regression tổng thể sau khi game loop hoàn chỉnh.
