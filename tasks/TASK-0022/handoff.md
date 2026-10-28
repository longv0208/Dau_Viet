# Handoff — TASK-0022 ([E2] Mobile: Màn Chọn thời kỳ và Hành trình thời kỳ — Issue #22)

## 1. Kết quả thực hiện
Đã hoàn thành toàn bộ yêu cầu của **Issue #22 (`[E2] Mobile: man Chon thoi ky va Hanh trinh thoi ky`)** trong `dau-viet-mobile/lib/features/learning_path/presentation/`:
- **`path_status_badge.dart`**:
  - Cung cấp `PathStatusVisual`, `PathStatusBadge`, `ParticipationTypeBadge`, và `derivePeriodStatus`.
  - Mọi trạng thái (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) đều kết hợp cả `Icon` và nhãn tiếng Việt kèm `Semantics` (đạt **AC-1**: không chỉ dùng màu).
- **`period_selection_screen.dart` (Màn Chọn thời kỳ)**:
  - Nhóm các thời kỳ (`PERIOD`) theo đại thời kỳ (`ERA`) thông qua `path.eraGroups`.
  - Ẩn tiêu đề tầng `ERA` khi lộ trình chỉ có `<= 1` nhóm `ERA` ("ẩn tầng chỉ có 1 mục").
  - Hiển thị tiến độ từng thời kỳ (`PeriodProgressDto`), huy hiệu trạng thái có icon + nhãn, và nhãn `"Đang theo học"` cho `lastPeriodCode`.
  - Khi bấm vào thời kỳ: gọi `touchPeriod(periodCode)` và mở `PeriodJourneyScreen`.
- **`period_journey_screen.dart` (Màn Hành trình thời kỳ)**:
  - Tự động gọi `touchPeriod(periodCode)` khi vào thời kỳ (`initState` / đổi `periodCode`).
  - Ẩn tiêu đề tầng `PHASE` khi thời kỳ chỉ có `<= 1` nhóm `PHASE`; hiện tiêu đề `PHASE` khi có `>= 2` nhóm `PHASE`.
  - Ẩn danh sách bài học con dưới thẻ sự kiện khi sự kiện chỉ có `<= 1` bài học; hiện danh sách bài học kèm trạng thái khi có `>= 2` bài học.
  - Bấm vào sự kiện mở `CampaignDetailScreen(eventId: event.eventId)` (hỗ trợ cả `GoRouter` `/campaign/:eventId` và `Navigator.push` fallback).
- **Đồng bộ tầng dữ liệu `E1` (`dau-viet-mobile/lib/features/learning_path/data/`)**:
  - Đồng bộ nguyên vẹn từ nhánh `feat/issue-21-learning-path` (`E1`) để đảm bảo build/test độc lập trên worktree và merge không xung đột.
- **Bảo toàn phạm vi**:
  - Không sửa bất kỳ file nào trong `dau-viet-mobile/lib/features/map/`.

## 2. Kiểm chứng đã chạy (Verification Evidence)
- `dart format --output=none --set-exit-if-changed lib/features/learning_path test/learning_path` -> `Formatted 14 files (0 changed)`, exit code `0`.
- `flutter analyze --no-pub lib/features/learning_path test/learning_path` -> `No issues found!`, exit code `0`.
- `flutter test --no-pub test/learning_path` -> `17/17 tests passed` (9 unit tests E1 + 8 widget tests E2 trong `period_journey_screen_test.dart`), exit code `0`.
- `git diff --check` -> sạch, exit code `0`.

## 3. Hạn chế công cụ / môi trường
- Role `reviewer` mặc định thiếu cấu hình model `slow` trên máy hiện tại, nên review độc lập và thẩm định kế hoạch được ủy quyền qua subagent `scout` (`PlannerResearcher`, `CodeReviewer`) và ghi nhận trung thực trong `roleReports`.

## 4. Hành động tiếp theo (Next Action)
- Sẵn sàng commit/merge sau khi nhánh `feat/issue-21-learning-path` (E1) hợp nhất, hoặc tích hợp tiếp với E3 (`feat/issue-23-journey-home`) và E4. Không tự động commit/push khi chưa có yêu cầu của người dùng.
