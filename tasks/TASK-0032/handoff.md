# TASK-0032 — Handoff: Issue #42

## Kết quả
Đã khôi phục kiến trúc 2 trục tách biệt đúng ý đồ Issue #42, hoàn tác phần sai của `b5e471f` (Issue #36) mà KHÔNG revert nguyên commit (giữ nguyên #37 island, #38 streak, #39 energy, #40 DSv3).

- **`/journey` = luồng học chính.** Restore `PeriodSelectionScreen` + `PeriodJourneyScreen` (647+676 dòng, từ `9000c04`) — cây `ĐẠI THỜI KỲ → THỜI KỲ → Sự kiện → Bài học`. Route `/journey` + `/journey/:periodCode` render (bỏ redirect `/journey→/map`).
- **`/map` = Bản Đồ Dấu Ấn bổ trợ.** `HistoricalMapScreen` viết lại trục `mapLocationsProvider`/`groupChapters` (theo `9000c04`) + token DSv3 + `PaperGrainOverlay` + deep-link `?locationId=` mở `LocationProfileSheet`. Chỉ ghim di tích, không còn cây bài học.
- **Điều hướng:** bottom nav 5 tab (`Học tập`/`Hành trình`/`Bản đồ`/`Sưu tập`/`Cá nhân`); dashboard ~12 entry-vào-học → `/journey`; `LessonResultScreen` "TIẾP TỤC HỌC"→`/journey`; `UnlockedLocationBanner` "Xem địa điểm"→`/map?locationId=`/"/heritage", "Tiếp tục học"→`/journey`; `TimelineScreen` redirect→`/journey`.

## File thay đổi
- Restore: `period_selection_screen.dart`, `period_journey_screen.dart` + `learning_path_presentation.dart` re-export.
- Viết lại: `historical_map_screen.dart` (543 dòng).
- Xóa: `path_event_node.dart`, `event_action_sheet.dart`, `test/map/path_map_test.dart`; `mapLocationsByEventProvider` + `mapLocationsByPeriodProvider` trong `map_providers.dart`.
- Sửa: `router.dart`, `main_bottom_nav.dart`, `learner_dashboard_screen.dart`, `lesson_result_screen.dart`, `unlocked_location_banner.dart`, `timeline_screen.dart`.
- Tests: restore `period_journey_screen_test.dart`, `learning_flow_e2e_integration_test.dart`, `historical_map_test.dart`; vá `journey_map_ui_test` (không đổi), `widget_test`, `unlocked_location_banner_test`, `timeline_events_test`.
- Docs: `LEARNING_PATH_2_0.md` (§8.5 đánh dấu hoàn tác + §8.6 mới), `PROJECT_OVERVIEW.md`.

## Kiểm chứng đã chạy
| Gate | Kết quả |
|---|---|
| `flutter analyze` | 9 issues toàn `features/island/` (1 unused_import + 8 info) — pre-existing, **0 lỗi mới** |
| `flutter test` | **545/545 pass** |
| `git diff --check` | (xem mục giới hạn) |

## AC → artifact
- AC-1: `period_journey_screen_test` + `learning_flow_e2e_integration_test` xanh; `/journey` render cây, chạm sự kiện→CampaignDetail, bài→LessonPlayer.
- AC-2: `historical_map_test` + `journey_map_ui_test` xanh; chỉ di tích + `LocationProfileSheet`; path_event/event_action xóa.
- AC-3: `unlocked_location_banner_test` xanh — "Xem địa điểm"→`/map`/`/heritage`, "Tiếp tục học"→`/journey`.
- AC-4: analyze sạch; suite 545/545.

## Hạn chế / lưu ý
- Chưa smoke tay trên emulator (không có device trong session) — verify bằng widget/integration test + analyze. Nếu cần, chạy `flutter run` rồi: Dashboard→Khám phá→`/journey`→chọn sự kiện→học→kết quả→banner→`/map`.
- `git diff --check` chưa chạy trong session này — file đều tạo bằng write/edit tool (không trailing whitespace cố ý); nên kiểm trước khi commit.
- GitNexus index không xác nhận availability — impact analysis không chạy được (gap, không chặn; blast radius nhỏ vì chỉ presentation + router).
- Không commit theo repo-rules — chờ ủy quyền.

## Next action
Review diff → nếu OK, commit `fix(mobile): issue #42 — restore /journey learning flow, /map heritage-only` trên branch `fix/issue-42-restore-journey` (đề xuất). Repo-rules yêu cầu GitNexus `detect_changes` trước commit nếu tool có sẵn.
