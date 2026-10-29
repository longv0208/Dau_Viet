# TASK-0028 — Handoff

## Trạng thái

`verifying` — implement + test hoàn tất; chờ (a) optional smoke-run app visual `/map`, (b) user authorize commit.

## Phạm vi đã làm

Issue #36 — học trực tiếp trên **Bản đồ Dấu Ấn** (`/map`) với trục `GET /api/v1/me/learning-path`; di tích = lớp phụ mở khóa sau khi học (ghim vệ tinh + `LocationProfileSheet`).

### Mobile (đã code)

| File | Thay đổi |
|---|---|
| `features/map/presentation/path_event_node.dart` | **Mới** — `PathEventNode` (canvas node), `toUnlockState(LearnerPathStatus)` |
| `features/map/presentation/event_action_sheet.dart` | **Mới** — `EventActionSheet` bottom-sheet; CTA `BẮT ĐẦU`/`TIẾP TỤC`/`ÔN LẠI` → `/learning/lesson/:lessonId`; chip di tích đã mở |
| `features/map/presentation/historical_map_screen.dart` | **Viết lại** — nguồn `learningPathProvider`; chặng=`PERIOD` nhóm `ERA`; đổi chặng → `touchPeriod`; deep-link `?period=`/`?eventId=`; `_SatellitePins`; strip đáy di tích `unlocked` theo chặng |
| `features/map/data/map_providers.dart` | + `mapLocationsByEventProvider`, `mapLocationsByPeriodProvider` |
| `app/router.dart` | `/journey` + `/journey/:periodCode` → `redirect` `/map`/`/map?period=` |
| `core/widgets/main_bottom_nav.dart` | `/journey` → tab 1; label "Khám phá" → "Hành trình" |
| `features/dashboard/presentation/learner_dashboard_screen.dart` | Card "Bài học hôm nay" → `/map?period=<code>` |
| `features/timeline/presentation/timeline_screen.dart` | redirect `/journey` → `/map` |
| `features/learning/presentation/lesson_player_screen.dart` | `complete()` invalidate `learningPathProvider` + `mapLocationsProvider` |
| `features/learning/presentation/widgets/unlocked_location_banner.dart` | "Tiếp tục học" → `/map` |
| `features/learning_path/presentation/` | **Xóa** `period_selection_screen.dart`, `period_journey_screen.dart`; `learning_path_presentation.dart` chỉ export `path_status_badge.dart` |

### Admin (đã code — chỉ copy)

- `unlocked-locations-card.tsx` — làm rõ gắn di tích là **tùy chọn** (phần thưởng sau khi học); empty-state "không bắt buộc"; badge `"hiện cạnh sự kiện X"`.
- `map-locations-page.tsx` tab `unlock` — helper text cùng thông điệp; `NONE` = "mở tự do — không gắn bài học". Không đổi mutation/API.

### Backend

Không đổi — contract hiện đủ: `GET /me/learning-path` (cây + `currentByPeriod`/`lastPeriodCode`/`sortOrder`), `POST .../periods/{code}/touch`, `newlyUnlockedLocations` trong `CompleteAttemptResponse`, `GET /map/locations?eventId=`/`?periodCode=`, `LocationProfileSheet` theo `GET /map/locations/{id}`.

## Tests

- **Mới** `test/map/path_map_test.dart` — 7 case phủ AC-1/2/3.
- **Viết lại** `test/map/journey_map_ui_test.dart` — giữ `LocationProfileScreen`/`LocationProfileSheet`.
- **Xóa** `test/map/historical_map_test.dart`, `test/learning_path/period_journey_screen_test.dart`, `test/learning_path/learning_flow_e2e_integration_test.dart` (pin vào màn/axis cũ).
- **Sửa** `unlocked_location_banner_test.dart`, `timeline_events_test.dart`, `widget_test.dart` → `/map`.

## Verification (đã chạy)

- `flutter analyze` → **0 errors**.
- `flutter test test/map/ test/learning/unlocked_location_banner_test.dart test/timeline_events_test.dart test/widget_test.dart test/dashboard/` → **all passed (24)**.
- Admin `npx vitest run src/features/events/map-locations-section.test.tsx src/features/lessons` → **83/83 pass**.
- Admin `tsc --noEmit` → chỉ còn lỗi **pre-existing** (`qk` import thiếu ở `map-locations-page.tsx:172,180,900,921`; `map-location.ts` union types) — không do thay đổi này.

## Quyết định

1. `/journey` redirect → `/map`; 2 màn danh sách gỡ hẳn (user chọn 1a).
2. Bottom-nav tab 1 label = **"Hành trình"**.
3. Ghim di tích **vệ tinh inline** trên canvas cạnh node sự kiện (user chọn 3a).
4. Backend/Flyway không đổi — contract đủ dùng.
5. Map `LearnerPathStatus` → `MapUnlockState` để tái dùng `JourneyPathPainter` không sửa.

## Known limits

- `MapLocationDto` không có `periodCode` → `mapLocationsByPeriodProvider` map `eventId→chapter` phía client; với mock, strip đáy có thể hiện di tích mọi chặng (real API lọc `?periodCode=` server-side — chấp nhận được).
- Chưa smoke-run visual `flutter run` (môi trường không có device/browser chạy tự động) — widget tests đã phủ luồng.
- Pre-existing admin `tsc`/`lint` warnings giữ nguyên (ngoài scope).

## Next

1. (Optional) `flutter run` kiểm tra visual `/map` + sheet + ghim.
2. `git status`/`git diff --check` → commit khi user authorize → `status: done`.
