# Handoff — TASK-0026 ([F1] Tích hợp end-to-end, rà soát UX, cập nhật tài liệu — Issue #26)

## 1. Tóm tắt kết quả
- **Tích hợp điều hướng & sửa lỗi tích hợp**:
  - Đăng ký route `/journey` (`PeriodSelectionScreen`), `/journey/:periodCode` (`PeriodJourneyScreen`) và `/heritage/:locationId` (chuyển hướng an toàn tới `/map?locationId=...`) trong `dau-viet-mobile/lib/app/router.dart` kèm auth guard `_learningPrefixes`; cập nhật `MainBottomNav._routeTabs` trong `dau-viet-mobile/lib/core/widgets/main_bottom_nav.dart`.
  - Sửa 3 lỗi tràn khung ngang (`RenderFlex` overflow) trên màn hình điện thoại chuẩn 412px tại `PeriodSelectionScreen` và `PeriodJourneyScreen` (`dau-viet-mobile/lib/features/learning_path/presentation/`).
  - Sửa lỗi điều hướng sự kiện từ Sa Bàn (`BattleSabanScreen`) ưu tiên `bd.eventId` thay vì `bd.id` (`ms_bach_dang_938`) và bổ sung alias trong `MockEventsRepository.getEventById`.
  - Sửa lỗi `LearningPathItFixture.java` trong `dau-viet-backend` (upsert sự kiện theo `slug` thay vì cố định PK `id`, dùng `gen_random_uuid()` cho `HISTORY_DEFAULT` template, và đồng bộ `event_completion_policies` sau khi `V42__seed_history_main_v2.sql` archive `version_no = 1`).
- **Kiểm thử End-to-End (Backend thật & Mobile)**:
  - `dau-viet-backend/src/test/java/com/dauviet/path/LearningFlowHeritageEndToEndIT.java`: kiểm chứng toàn trình trên PostgreSQL 16 (Testcontainers, Flyway V1–V48):
    - **AC-1**: `Trang chủ (GET /me/learning-path) -> Chọn thời kỳ (POST /periods/{code}/touch) -> Sự kiện (GET /events/{id}, /lessons, /progress) -> Bài học (start -> submit -> complete) -> Kết quả có địa điểm vừa mở khóa (newlyUnlockedLocations, replay idempotent rỗng) -> Bản đồ Di sản (GET /map/locations, mở khóa UNLOCKED_ONLY media)`.
    - **AC-2**: Đủ trạng thái rỗng (`NO_PUBLISHED_LESSON` / `NOT_READY`), khóa (`403 LESSON_LOCKED_BY_PATH`), bài ngoài lộ trình (`200 OK`), lỗi (`401` / `404`).
    - **AC-3**: Đổi thời kỳ (`LY_DYNASTY` -> `EARLY_INDEPENDENCE` -> `LY_DYNASTY`) bảo toàn tiến độ (`completedEvents`, `percent`, `currentByPeriod`, và trạng thái `IN_PROGRESS` của bài đang làm dở).
  - `dau-viet-mobile/test/learning_path/learning_flow_e2e_integration_test.dart`: kiểm chứng luồng điều hướng thực qua `GoRouter`, chuyển đổi thời kỳ giữ nguyên tiến độ, và đủ 4 trạng thái UX (`loading`, `error` + `THỬ LẠI`, `empty`, `locked`).
- **Quyết định gỡ cột deprecated & Cập nhật tài liệu (`ADR-009`)**:
  - Ghi nhận `ADR-009` trong `docs/DECISIONS.md` và chi tiết hóa lộ trình Expand-and-Contract cùng 4 cổng kiểm toán bắt buộc trước khi chạy `ALTER TABLE map_locations DROP COLUMN event_id, DROP COLUMN unlock_lesson_id` tại Milestone M4 Cleanup.
  - Đồng bộ số hiệu migration thực tế (`V39`–`V43`) và kết quả kiểm chứng trong `docs/DATABASE_DESIGN.md`, `docs/LEARNING_PATH_2_0.md`, `docs/API_SPEC.md`, `docs/PROJECT_OVERVIEW.md`, `docs/development-roadmap.md`, `docs/project-changelog.md`.

## 2. Kết quả kiểm chứng (Verification Gates)
- **Backend**:
  - `sh ./mvnw test -Dtest=LearningFlowHeritageEndToEndIT,LearningPathHierarchyAndPeriodIT,LearningPathApiIT,HeritageLocationV2IT` (`cwd: dau-viet-backend`) -> **PASS (12/12 tests, 0 failures, Flyway V1–V48 clean)**.
- **Mobile**:
  - `dart format --output=none --set-exit-if-changed` trên các file đã chạm -> **PASS (0 changed)**.
  - `flutter analyze --no-pub` trên các file đã chạm -> **PASS (No issues found!)**.
  - `flutter test --no-pub test/learning_path/ test/dashboard/ test/campaign/ test/campaign_detail_test.dart` (`cwd: dau-viet-mobile`) -> **PASS (35/35 tests)**.
- **Git Hygiene**:
  - `git diff --check` -> **PASS (0 whitespace/conflict issues)**.
  - Không chạm vào các file thuộc phạm vi riêng của Issue #24 (`lib/features/map/**`, `timeline_screen.dart`) và Issue #25 (`attempt_dtos.dart`, `lesson_player_screen.dart`, `lesson_result_screen.dart`, `unlocked_location_banner.dart`).

## 3. Hành động tiếp theo
- Sẵn sàng commit/merge nhánh `feat/issue-26-e2e-integration-docs` sau khi người dùng duyệt.
