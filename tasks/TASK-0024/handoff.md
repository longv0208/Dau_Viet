# Handoff — TASK-0024 ([E4] Mobile: Bản đồ Di sản và hồ sơ địa điểm — Issue #24)

## 1. Kết quả thực hiện
Đã hoàn thành toàn bộ yêu cầu của **Issue #24 (`[E4] Mobile: Ban do Di san va ho so dia diem`)**:
- **Xóa `_metaBySlugOrId` và chế độ timeline dựa trên map (`AC-1`)**:
  - Xóa hoàn toàn `_EventChronologicalMeta`, `_metaBySlugOrId`, `_resolveMeta`, `_buildViewModeSwitcher`, và `_buildTimelineView` khỏi `dau-viet-mobile/lib/features/map/presentation/historical_map_screen.dart`.
  - Thay thế toàn bộ UUID hardcode trong `mock_map_repository.dart` bằng định danh ngữ nghĩa v2 (`loc_den_hung`, `loc_hat_mon`, `loc_ben_bach_dang`, v.v.).
  - Giữ `enum ExploreViewMode { timeline, map }` và tham số khởi tạo `HistoricalMapScreen` tương thích 100% với `lib/app/router.dart` để không gây xung đột merge.
- **Tầng dữ liệu Bản đồ Di sản API v2 (`dau-viet-mobile/lib/features/map/data/`)**:
  - `map_location_dto.dart`: Bổ sung `MapLocationLinkedEventDto`, `MapLocationUnlockLessonDto`, `MapLocationMediaDto` và mở rộng `MapLocationDto` với đầy đủ trường v2 (`slug`, `shortSummary`, `kind`, `coordinatePrecision`, `visibility`, `unlockMode`, `unlocked`, `coverAssetId`, `eventIds`, `events`, `unlockLessons`, `media`).
  - `map_api_client.dart`, `map_repository.dart`, `api_map_repository.dart`, `mock_map_repository.dart`, `map_providers.dart`: Hỗ trợ `GET /api/v1/map/locations` (với bộ lọc `periodCode`, `eventId`, `kind`, `unlocked`) và `GET /api/v1/map/locations/{locationId}` qua `mapLocationDetailProvider`.
- **Hiển thị địa điểm khóa khi `visibility = PUBLIC` (`AC-2`)**:
  - `MapLocationDto.shouldDisplayOnMap` giữ lại mọi địa điểm đang khóa có `visibility` là `PUBLIC` hoặc `ALWAYS_VISIBLE` để hiển thị ghim (`JourneyMapNode` có icon khóa) và tên địa điểm (`location.title`) trên bản đồ và danh sách chip; chỉ ẩn địa điểm khóa có `visibility = HIDDEN_UNTIL_UNLOCKED`.
- **Màn Hồ sơ địa điểm (`dau-viet-mobile/lib/features/map/presentation/location_profile_screen.dart`)**:
  - Cung cấp `LocationProfileScreen`, `LocationProfileSheet`, và `LocationProfileContent`.
  - Hiển thị 3 tab động: **Ảnh** (`IMAGE_2D`, `PANORAMA_360`), **Video** (`DOCUMENTARY_CLIP`, `AUDIO_GUIDE`), và **Tư liệu** (`description`, `events`, `unlockLessons`), tự động ẩn mọi tab rỗng và lọc bỏ media `UNLOCKED_ONLY` khi địa điểm đang khóa.
- **Chuyển hướng Timeline sang `/journey` (`dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`)**:
  - Tự động chuyển hướng sang `/journey` khi route `/journey` được đăng ký trong `GoRouter`, đồng thời bổ sung nút điều hướng `/journey` trên thanh tiêu đề và giữ fallback an toàn khi chạy test độc lập.

## 2. Kiểm chứng đã chạy (Verification Evidence)
- `dart format --output=none --set-exit-if-changed lib/features/map lib/features/timeline/presentation/timeline_screen.dart test/map test/timeline_events_test.dart` -> `Formatted 19 files (0 changed)`, exit code `0`.
- `flutter analyze --no-pub lib/features/map lib/features/timeline/presentation/timeline_screen.dart test/map test/timeline_events_test.dart` -> `No issues found!`, exit code `0`.
- `flutter test --no-pub test/map/historical_map_test.dart test/map/journey_map_ui_test.dart test/timeline_events_test.dart` -> `31/31 tests passed`, exit code `0`.
- `git diff --check` -> sạch, exit code `0`.

## 3. Hạn chế công cụ / môi trường
- Role `reviewer` mặc định thiếu cấu hình model `slow` trên máy hiện tại; thẩm định kế hoạch và review độc lập được thực hiện qua subagent `scout` (`PlannerResearcher`, `CodeReviewer`) và lưu báo cáo tại `plans/261028-issue-24-heritage-map/`.

## 4. Hành động tiếp theo (Next Action)
- Sẵn sàng commit/push hoặc tạo PR cho nhánh `feat/issue-24-heritage-map` khi người dùng xác nhận.
