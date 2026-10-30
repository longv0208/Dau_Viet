# TASK-0032: Issue #42 — Khôi phục `/journey` làm luồng học chính, `/map` về di tích

## Goal
Commit `b5e471f` (Issue #36) đã xóa màn Hành trình Lịch sử (`/journey` — `PeriodSelectionScreen`, `PeriodJourneyScreen`) và gộp luồng học vào `/map`. Khôi phục đúng kiến trúc 2 màn tách biệt:

1. `/journey` = luồng học chính: cây ERA → PERIOD → Sự kiện → Bài học; chọn sự kiện/bài học → vào học.
2. `/map` = Bản đồ Dấu Ấn chỉ hiển thị `map_locations` di tích (vai trò bổ trợ), mở `LocationProfileSheet`; địa điểm mở khóa SAU khi hoàn thành bài học/sự kiện gắn với nó (`ANY`/`ALL`).

## Phạm vi & bản chuẩn
- Bản gốc restore: `9000c04`. KHÔNG revert `b5e471f` nguyên commit.
- Restore: `period_selection_screen.dart`, `period_journey_screen.dart` + vá DSv3.
- Revert `historical_map_screen.dart`, `map_providers.dart` về trục di tích; giữ `journey_*` (thuộc bản đồ gốc); xóa `path_event_node.dart`, `event_action_sheet.dart`.
- Điều hướng: `/journey`, `/journey/:periodCode`; `main_bottom_nav` có 2 tab `Hành trình→/journey` và `Bản đồ→/map` (đã chốt); dashboard/lesson_result/banner sửa intent.
- Xóa `test/map/path_map_test.dart`; restore 3 file test; vá `widget_test`, `unlocked_location_banner_test`, `timeline_events_test`.

## AC
Xem `task.json` AC-1..AC-4 (mirror issue #42).

## Plan
`plans/261030-issue-42-restore-journey/plan.md`

## Verification mapping
| AC | Check | Expected | Evidence |
|---|---|---|---|
| AC-1 | `flutter test test/learning_path/` + smoke Dashboard→Khám phá→/journey→chọn sự kiện | pass, cây phân cấp hiển thị, vào lesson được | test log, screenshot |
| AC-2 | `flutter test test/map/` + smoke /map | chỉ di tích + LocationProfileSheet | test log |
| AC-3 | `learning_flow_e2e_integration_test` + banner test | địa điểm unlock sau complete, banner dẫn /map | test log |
| AC-4 | `flutter analyze` + `flutter test` toàn bộ | 0 lỗi mới, 100% pass | log |

## Handoff
Cập nhật cuối task.
