# Plan — Issue #42: Khôi phục `/journey` làm luồng học chính, `/map` về bản đồ di tích

> Issue: https://github.com/longv0208/Dau_Viet/issues/42 — bug + enhancement, area:mobile.
> Commit sai: `b5e471f` (Issue #36). Bản gốc chuẩn: `9000c04`.
> Quyết định đã chốt: risk `normal`; `/map` giữ tab riêng "Bản đồ" trong bottom nav.

## Nguyên tắc

- KHÔNG `git revert b5e471f` (sẽ mất #37 island, #38 streak, #39 energy, #40 DSv3).
- Restore có chọn lọc file từ `9000c04`, vá Design System v3 (token màu/font/widget atoms mới).
- Không đổi backend/Flyway/API contract. Không hard-code event.

## Phát hiện then chốt (đã khảo sát)

- `learning_path/data/` (providers/repository/DTO) còn nguyên → restore screen không cần động data layer.
- `historical_map_screen.dart` @ `9000c04` ĐÃ import `journey_chapter.dart`, `journey_layout.dart`, `journey_map_node.dart`, `journey_path_painter.dart`, `journey_location_list.dart`, `journey_progress_legend.dart` → các file `journey_*` thuộc bản đồ gốc, GIỮ, chỉ xóa `path_event_node.dart` + `event_action_sheet.dart`.
- `path_status_badge.dart` vẫn dùng `DauVietColors.imperialGold/heritageGreen/cinnabarRed` (alias DSv2) → map sang token v3.
- `period_*_screen.dart` @ `9000c04` import `parchment_card.dart`, `main_bottom_nav.dart`, `path_status_badge.dart` → verify tồn tại, vá nếu #40 đổi tên.
- `learner_dashboard_screen.dart` có ~12 callsite `context.go('/map')` cần phân loại intent (học → `/journey`, mở địa điểm → `/map?locationId=`).

## Phase 1 — Khôi phục màn Hành trình `/journey`

1. `git show 9000c04:.../period_selection_screen.dart` + `period_journey_screen.dart` → restore vào `lib/features/learning_path/presentation/`.
2. Vá DSv3: thay `DauVietColors.<v2>` → token v3 (paper `#F8F0E0`, lacquer `#B93430`, gold `#E0AE45`, jade `#247D78`); `ParchmentCard` → `TactileCard`/atom mới nếu đã rename; font Noto Serif/Be Vietnam Pro qua `DauVietTypography`.
3. Đảm bảo cây `ERA` (thẻ đỏ) → `PERIOD` (thụt lề + vạch dọc) → `Sự kiện` (timeline chấm đỏ: năm, `Bắt buộc/Tham khảo`, số bài học, trạng thái) → `Bài học` khớp mockup; data từ `learningPathProvider`.
4. `learning_path_presentation.dart`: re-export 2 screen.
5. `router.dart`: xóa redirect `/journey→/map`; thêm `/journey` → `PeriodSelectionScreen`, `/journey/:periodCode` → `PeriodJourneyScreen`. Giữ `/map?period=` và `/map?locationId=` deep-link hợp lệ.

## Phase 2 — Revert `/map` về trục di tích

1. `historical_map_screen.dart`: lấy nền `9000c04`, chèn lại atoms DSv3 đã dùng (clue_tag, paper_grain_overlay, section_divider, stamp_seal_badge, tactile_card) — vá thủ công, không checkout nguyên file vì #40 đã polish.
2. `map_providers.dart`: về `9000c04` + GIỮ `mapLocationsByEventProvider`/`mapLocationsByPeriodProvider` nếu banner/dashboard/bottom-strip còn dùng (quyết theo callsite).
3. Xóa `path_event_node.dart`, `event_action_sheet.dart`. `journey_*` giữ. Kiểm tra `journey_chapter_header.dart` còn được screen dùng không; nếu không → xóa.
4. Địa điểm `LOCKED→UNLOCKED` theo `unlockRuleMode` (backend giữ nguyên); `lesson_player.complete()` vẫn invalidate `mapLocationsProvider` + `learningPathProvider`.
5. Tap địa điểm → `LocationProfileSheet` (tab Ảnh/Video/Tư liệu).

## Phase 3 — Điều hướng

- `main_bottom_nav.dart`: tab "Hành trình" → `/journey`; thêm tab "Bản đồ" → `/map`. Cập nhật index map `{'/map':?,'/journey':?}`.
- `learner_dashboard_screen.dart`: duyệt 12 callsite `/map`:
  - "Khám phá ngay", thẻ Bài học/Hành trình, today-card, timeline (điểm-vào-học) → `/journey` (hoặc `/journey/:periodCode` khi đã biết period).
  - Entry xem địa điểm mở khóa → giữ `/map?locationId=`.
- `lesson_result_screen.dart`: "Tiếp tục học" → `/journey`; `newlyUnlockedLocations.isNotEmpty` → `UnlockedLocationBanner` "Xem địa điểm" → `/map`.
- `unlocked_location_banner.dart`: fallback tiếp-tục-học → `/journey`; "Xem địa điểm" → `/map` (giữ nguyên).

## Phase 4 — Tests

- Restore: `test/learning_path/period_journey_screen_test.dart`, `learning_flow_e2e_integration_test.dart`, `test/map/historical_map_test.dart` (từ `9000c04`, vá widget DSv3).
- `journey_map_ui_test.dart`: về cover `LocationProfile*` như bản gốc.
- Xóa `test/map/path_map_test.dart`.
- Sửa `widget_test.dart`, `unlocked_location_banner_test.dart`, `timeline_events_test.dart` theo điều hướng mới.

## Phase 5 — Verify & Docs

1. `flutter analyze` → 0 lỗi (9 warnings island/* pre-existing chấp nhận).
2. `flutter test` → 100% pass.
3. Smoke tay: Dashboard → Khám phá → `/journey`; chọn sự kiện → lesson; hoàn thành → banner → `/map`.
4. Sửa `docs/LEARNING_PATH_2_0.md` §8.5, `docs/PROJECT_OVERVIEW.md` dòng "Issue #36 `/map` lấy learning-path làm trục" → mô tả đúng 2 màn; changelog/roadmap; `tasks/TASK-0032/brief.md` + handoff.

## Rủi ro

| Rủi ro | Kiểm soát |
|---|---|
| File restore dùng token/widget DSv2 đã đổi | `flutter analyze` lộ ngay; vá import/màu theo `core/theme` hiện tại |
| Xóa nhầm `journey_*` đang được map gốc dùng | Đã xác nhận bản `9000c04` import; giữ |
| 12 callsite `/map` lẫn intent | Phân loại theo semantics, sửa từng cái |
| Mất deep-link cũ | Giữ `/map?period=` + `/map?locationId=`; chỉ gỡ `/journey→/map` redirect |
| Test restore fail vì DSv3 | Vá test theo widget mới, giữ assertion hành vi |
