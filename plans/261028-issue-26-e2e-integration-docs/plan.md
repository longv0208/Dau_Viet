---
title: "[F1] Tích hợp end-to-end, rà soát UX, cập nhật tài liệu (Issue #26)"
description: "End-to-end integration of Period Learning Flow & Heritage Map 2.0 across Backend and Mobile router, UX state verification (empty, loading, locked, error), period switching continuity, deprecation decision for map_locations.event_id and unlock_lesson_id, and full documentation sync."
status: in_progress
priority: P1
effort: 4h
branch: feat/issue-26-e2e-integration-docs
tags: [integration, e2e, docs, learning-path, heritage-map, issue-26]
created: 2026-10-28
---

# [F1] Tích hợp end-to-end, rà soát UX, cập nhật tài liệu (Issue #26)

## 1. Mục tiêu & Phạm vi

### Mục tiêu
Hoàn tất **Epic F / Issue #26 (`[F1] Tich hop end-to-end, ra soat UX, cap nhat tai lieu`)** cho **Luồng học theo thời kỳ và Bản đồ Di sản 2.0**:
1. **Tích hợp điều hướng & kiểm thử End-to-End**:
   - Đăng ký các route còn thiếu trong `dau-viet-mobile/lib/app/router.dart` (`/journey`, `/journey/:periodCode`, `/heritage/:locationId`) và đồng bộ `MainBottomNav` để kết nối liền mạch các màn từ E1–E5.
   - Kiểm chứng luồng đầy đủ trên backend thật (PostgreSQL + MockMvc IT) và mobile widget integration: `Trang chủ -> Thời kỳ -> Sự kiện -> Bài -> Kết quả có địa điểm -> Bản đồ`.
2. **Rà soát đủ trạng thái UX (`rỗng`, `đang tải`, `khóa`, `lỗi`)** và **bảo toàn tiến độ khi đổi thời kỳ qua lại**.
3. **Chốt quyết định kiến trúc (ADR-009)** về thời điểm và điều kiện gỡ bỏ 2 cột deprecated `map_locations.event_id` và `map_locations.unlock_lesson_id`.
4. **Cập nhật đồng bộ bộ tài liệu kỹ thuật**: `docs/DECISIONS.md`, `docs/DATABASE_DESIGN.md`, `docs/LEARNING_PATH_2_0.md`, `docs/API_SPEC.md`, `docs/PROJECT_OVERVIEW.md`, `docs/development-roadmap.md`, `docs/project-changelog.md`.

### Phạm vi file (`## Phạm vi`)
- **Integration & Routing**:
  - `dau-viet-mobile/lib/app/router.dart`
  - `dau-viet-mobile/lib/core/widgets/main_bottom_nav.dart`
- **End-to-End Verification Tests**:
  - `dau-viet-backend/src/test/java/com/dauviet/path/LearningFlowHeritageEndToEndIT.java`
  - `dau-viet-mobile/test/learning_path/learning_flow_e2e_integration_test.dart`
- **Documentation (`docs/*`)**:
  - `docs/DECISIONS.md`
  - `docs/DATABASE_DESIGN.md`
  - `docs/LEARNING_PATH_2_0.md`
  - `docs/API_SPEC.md`
  - `docs/PROJECT_OVERVIEW.md`
  - `docs/development-roadmap.md`
  - `docs/project-changelog.md`
- **Task & Plan Artifacts**:
  - `plans/261028-issue-26-e2e-integration-docs/plan.md`
  - `tasks/TASK-0026/brief.md`
  - `tasks/TASK-0026/task.json`
  - `tasks/TASK-0026/handoff.md`

### Nguyên tắc cô lập Merge (Zero Conflict với E4 #24 & E5 #25)
- Không sửa bất kỳ file nào thuộc quyền sở hữu của:
  - **E4 (Issue #24)**: `dau-viet-mobile/lib/features/map/**`, `dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`, `dau-viet-mobile/test/map/**`, `dau-viet-mobile/test/timeline_events_test.dart`.
  - **E5 (Issue #25)**: `dau-viet-mobile/lib/features/learning/data/attempt_dtos.dart`, `dau-viet-mobile/lib/features/learning/data/mock_attempt_repository.dart`, `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart`, `dau-viet-mobile/lib/features/learning/presentation/lesson_result_screen.dart`, `dau-viet-mobile/lib/features/learning/presentation/widgets/unlocked_location_banner.dart`, `dau-viet-mobile/test/fakes/fake_attempt_repository.dart`, `dau-viet-mobile/test/learning/**`.

---

## 2. Quyết Định Gỡ Cột Deprecated `map_locations.event_id` & `unlock_lesson_id` (ADR-009)

### 2.1. Hiện trạng kỹ thuật (từ `V40__heritage_locations.sql` & `V43__seed_heritage_location_assets_and_media.sql`)
- `map_locations.event_id` đã được nới thành `NULLABLE` và toàn bộ dữ liệu liên kết sự kiện được backfill sang bảng quan hệ N–N `map_location_events (location_id, event_id, role, sort_order)`.
- `map_locations.unlock_lesson_id` đã được gỡ ràng buộc cùng sự kiện (`fk_map_location_unlock_lesson_same_event`) và backfill sang bảng `map_location_unlock_lessons (location_id, lesson_id)` kết hợp cột `map_locations.unlock_rule_mode ∈ {'NONE', 'ANY', 'ALL'}`.
- Trong tầng ứng dụng (`dau-viet-backend`):
  - `AdminMapLocationService` (v2 `/api/v1/admin/map-locations`) đọc/ghi trực tiếp trên `map_location_events` và `map_location_unlock_lessons`.
  - Endpoint legacy `/api/v1/admin/events/{eventId}/map-locations` (`AdminMapLocationController`) vẫn được giữ lại theo yêu cầu tương thích ngược của Issue #17 (C3) và tự động đồng bộ hai chiều xuống `map_location_events` + `map_location_unlock_lessons` qua `syncLegacyJoinTables()`.
  - `MapLocationService` và `LocationUnlockEvaluator` ưu tiên đọc `map_location_events` và `map_location_unlock_lessons`, chỉ fallback sang `event_id` / `unlock_lesson_id` khi dữ liệu test cũ chèn trực tiếp vào bảng `map_locations`.

### 2.2. Lộ trình 2 giai đoạn (Expand-and-Contract) & Điều kiện gỡ bỏ (Drop Gate)
- **Giai đoạn 1 — Deprecation & Dual-Read/Sync (Hiện tại, V40–V48 / MVP Release)**:
  - Đánh dấu `@Deprecated` trên `MapLocation.eventId` / `MapLocation.unlockLessonId` ở mức tài liệu và hợp đồng dữ liệu.
  - Mọi tính năng mới trên Admin CMS (D2/D3) và Mobile (E4/E5) bắt buộc dùng `eventIds[]`, `events[]`, `unlockMode`, `unlockLessons[]` từ bảng nối.
  - Cấm thêm bất kỳ truy vấn SQL/JPQL mới nào lọc trực tiếp theo `map_locations.event_id` hoặc `map_locations.unlock_lesson_id` mà không đi qua `map_location_events` / `map_location_unlock_lessons`.
- **Giai đoạn 2 — Contract Migration (`ALTER TABLE map_locations DROP COLUMN event_id, DROP COLUMN unlock_lesson_id`)**:
  - **Thời điểm thực hiện**: Ngay tại bản phát hành đầu tiên sau khi đóng Epic E & F (Milestone M4 Cleanup / đầu chu kỳ kế tiếp sau khi nghiệm thu E2E Mobile #24, #25, #26).
  - **4 Điều kiện tiên quyết bắt buộc (Drop Gates)**:
    1. **Client Cutover Gate**: Mobile (`#24`, `#25`) và Admin (`#19`, `#20`) đã merge vào `main` và không còn đọc trường v1 đơn lẻ `unlockLessonId` hoặc phụ thuộc cứng vào `eventId` không null.
    2. **Legacy Admin Endpoint Sunset Gate**: Gỡ bỏ hoặc chuyển hoàn toàn `AdminMapLocationController` (`/api/v1/admin/events/{eventId}/map-locations`) sang truy vấn qua `map_location_events` và `map_location_unlock_lessons`.
    3. **Test Fixture Migration Gate**: Cập nhật `MapLocationIT` để seed dữ liệu qua `map_location_events` và `map_location_unlock_lessons` thay vì INSERT cột `event_id` / `unlock_lesson_id`.
    4. **Zero-Orphan Data Audit Gate**: Truy vấn kiểm toán trên DB môi trường thật trả về `0` bản ghi lệch giữa cột cũ và bảng nối:
       ```sql
       SELECT count(*) FROM map_locations m
       WHERE (m.event_id IS NOT NULL AND NOT EXISTS (
           SELECT 1 FROM map_location_events mle
           WHERE mle.location_id = m.id AND mle.event_id = m.event_id
       ))
       OR (m.unlock_lesson_id IS NOT NULL AND NOT EXISTS (
           SELECT 1 FROM map_location_unlock_lessons mlul
           WHERE mlul.location_id = m.id AND mlul.lesson_id = m.unlock_lesson_id
       ));
       ```

---

## 3. Thiết kế Tích hợp & Kiểm thử

### 3.1. Mobile Router & Bottom Nav (`router.dart` & `main_bottom_nav.dart`)
- Trong `dau-viet-mobile/lib/app/router.dart`:
  - Thêm `'/journey'` và `'/heritage'` vào `_learningPrefixes`.
  - Thêm route `/journey` $\rightarrow$ `const PeriodSelectionScreen()`.
  - Thêm route `/journey/:periodCode` $\rightarrow$ `PeriodJourneyScreen(periodCode: state.pathParameters['periodCode'] ?? '')`.
  - Thêm route `/heritage/:locationId` $\rightarrow$ redirect sang `/map?locationId=${Uri.encodeComponent(state.pathParameters['locationId'] ?? '')}` (giúp `context.push('/heritage/...')` hoặc `context.go('/heritage/...')` hoạt động an toàn cả trước và sau khi merge #24/#25).
- Trong `dau-viet-mobile/lib/core/widgets/main_bottom_nav.dart`:
  - Thêm `('/journey', 0)` và `('/heritage', 1)` vào `_routeTabs`.

### 3.2. Backend End-to-End Integration Test (`LearningFlowHeritageEndToEndIT.java`)
Kiểm thử tích hợp toàn trình với PostgreSQL thật (Testcontainers):
1. **Full E2E Journey (AC-1)**:
   - `GET /api/v1/me/learning-path` (Trang chủ): lấy lộ trình `HISTORY_MAIN` v2 với cây `ERA -> PERIOD -> EVENT -> LESSON`.
   - `POST /api/v1/me/learning-path/periods/EARLY_INDEPENDENCE/touch` (Chọn thời kỳ): cập nhật `lastPeriodCode = "EARLY_INDEPENDENCE"`.
   - `GET /api/v1/events/{eventId}` & `GET /api/v1/events/{eventId}/lessons` & `GET /api/v1/me/events/{eventId}/progress` (Sự kiện).
   - `POST /api/v1/lessons/{lessonId}/attempts` $\rightarrow$ `GET /api/v1/attempts/{attemptId}/current` $\rightarrow$ nộp đủ các hoạt động bắt buộc (`POST .../submissions`) $\rightarrow$ `POST /api/v1/attempts/{attemptId}/complete` (Hoàn thành bài học).
   - Xác nhận `CompleteAttemptResponse.newlyUnlockedLocations` trả về đúng địa điểm di sản vừa mở khóa (`Bãi cọc Bạch Đằng` / địa điểm gắn rule bài học) và gọi lặp `POST /complete` (idempotent replay) trả `newlyUnlockedLocations: []`.
   - `GET /api/v1/map/locations?periodCode=EARLY_INDEPENDENCE` & `GET /api/v1/map/locations/{locationId}` (Bản đồ Di sản): xác nhận địa điểm chuyển từ `LOCKED` (ẩn `UNLOCKED_ONLY` media) sang `UNLOCKED` (hiển thị đầy đủ `PUBLIC_PREVIEW` + `UNLOCKED_ONLY` media).
2. **UX & Error/Lock/Empty States (AC-2)**:
   - Sự kiện chưa có bài học xuất bản (`hung-vuong-van-lang` ở `FOUNDING_ERA`) trả `contentStatus = "NO_PUBLISHED_LESSON"`, `status = "NOT_READY"`, `lessons = []`.
   - Bài học thứ 2 trong thời kỳ có nhiều sự kiện bắt buộc (`chien-thang-nhu-nguyet-1077` trong `LY_DYNASTY` khi chưa xong `ly-thai-to-1010`) trả trạng thái `LOCKED`, và gọi `POST /api/v1/lessons/{lockedLessonId}/attempts` bị chặn với `409 LESSON_LOCKED_BY_PATH`.
   - Touch thời kỳ không tồn tại hoặc gọi với mã `ERA` trả `404 RESOURCE_NOT_FOUND`.
3. **Đổi Thời Kỳ & Quay Lại Không Mất Tiến Độ (AC-3)**:
   - Touch `LY_DYNASTY` $\rightarrow$ hoàn thành sự kiện 1 (`ly-thai-to-1010`) $\rightarrow$ sự kiện 2 (`chien-thang-nhu-nguyet-1077`) mở khóa (`AVAILABLE`), `periodProgress` của `LY_DYNASTY` đạt `1/2` sự kiện (`50%`).
   - Đổi sang `NORTHERN_DOMINATION` (`POST .../periods/NORTHERN_DOMINATION/touch`) $\rightarrow$ `lastPeriodCode` đổi sang `NORTHERN_DOMINATION`, `current` trỏ về bài của `NORTHERN_DOMINATION`, nhưng `periodProgress` và `currentByPeriod["LY_DYNASTY"]` vẫn giữ nguyên tiến độ `1/2` và con trỏ ở sự kiện 2.
   - Quay lại `LY_DYNASTY` (`POST .../periods/LY_DYNASTY/touch`) $\rightarrow$ `lastPeriodCode` quay về `LY_DYNASTY`, `current` trỏ đúng vào sự kiện 2 (`chien-thang-nhu-nguyet-1077`), không mất bất kỳ tiến độ bài học, sự kiện hay địa điểm đã mở nào.

### 3.3. Mobile E2E Navigation & UX State Widget Test (`learning_flow_e2e_integration_test.dart`)
- Kiểm chứng điều hướng thực qua `GoRouter`:
  - `LearnerDashboardScreen` (`/dashboard`) $\rightarrow$ `/journey` (`PeriodSelectionScreen`) $\rightarrow$ chọn thời kỳ gọi `touchPeriod` và đẩy sang `/journey/:periodCode` (`PeriodJourneyScreen`) $\rightarrow$ bấm sự kiện mở `/campaign/:eventId` (`CampaignDetailScreen`).
  - Kiểm chứng đầy đủ 4 trạng thái UX: `loading` (đang tải lộ trình/sự kiện), `empty` (thời kỳ không có sự kiện hoặc sự kiện chưa có bài học), `locked` (bài học `LOCKED` hiện badge `'Đang khóa'` + `SnackBar` chặn mở), `error` (lỗi API hiện thông báo + nút `'THỬ LẠI'` phục hồi thành công).
  - Kiểm chứng đổi thời kỳ (`EARLY_INDEPENDENCE` $\rightarrow$ `LY_DYNASTY` $\rightarrow$ `EARLY_INDEPENDENCE`) giữ nguyên tiến độ từng thời kỳ và đồng bộ chính xác lên Trang chủ.

---

## 4. Ánh xạ Acceptance Criteria (AC-to-Check Mapping)

| AC | Nội dung yêu cầu | Kiểm chứng & Artifact |
|---|---|---|
| **AC-1** | Luồng Trang chủ -> Thời kỳ -> Sự kiện -> Bài -> Kết quả có địa điểm -> Bản đồ chạy trên backend thật | `LearningFlowHeritageEndToEndIT.java` (real Postgres via Testcontainers) + `learning_flow_e2e_integration_test.dart` + `router.dart` |
| **AC-2** | Đủ trạng thái rỗng, đang tải, khóa, lỗi | `LearningFlowHeritageEndToEndIT.java` (409 locked, 404 invalid period, `NOT_READY` empty lessons, locked media hidden) + `learning_flow_e2e_integration_test.dart` (loading, empty, locked, error + retry) |
| **AC-3** | Đổi thời kỳ và quay lại không mất tiến độ | `LearningFlowHeritageEndToEndIT.java` + `learning_flow_e2e_integration_test.dart` |
| **Thay đổi** | Quyết định thời điểm gỡ cột deprecated `map_locations.event_id`, `unlock_lesson_id` & cập nhật `docs/*`, `project-changelog.md`, `development-roadmap.md` | `docs/DECISIONS.md` (ADR-009), `docs/DATABASE_DESIGN.md`, `docs/LEARNING_PATH_2_0.md`, `docs/API_SPEC.md`, `docs/PROJECT_OVERVIEW.md`, `docs/development-roadmap.md`, `docs/project-changelog.md` |
