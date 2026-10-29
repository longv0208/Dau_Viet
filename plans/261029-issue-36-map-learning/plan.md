# Plan — Issue #36: Học trực tiếp trên Bản đồ Dấu Ấn & Mở khóa Di tích sau khi học

> **Risk:** normal-high (đổi luồng điều hướng học chính; không đụng DB/auth/version/reward).
> **Quyết định đã chốt với PO:**
> 1. `/journey` → redirect sang `/map` (giữ deep-link), xóa `PeriodSelectionScreen`/`PeriodJourneyScreen`.
> 2. Label bottom-nav tab 1 đổi "Khám phá" → "Hành trình".
> 3. Di tích đã mở khóa render như **ghim vệ tinh inline cạnh node sự kiện** trên canvas.

## 1. Mục tiêu & AC

| AC | Nội dung |
|---|---|
| AC-1 | Người học xem lộ trình Thời kỳ → Sự kiện → Bài học và bấm Bắt đầu/Tiếp tục học trực tiếp trên Bản đồ Dấu Ấn, không qua màn danh sách rời rạc. |
| AC-2 | Bài học không gắn di tích vẫn hiển thị/học/mở khóa bài kế liền mạch trên Bản đồ. |
| AC-3 | Hoàn thành bài có gắn di tích (`ANY`/`ALL`) → mở khóa, banner trên `LessonResultScreen`, xem hồ sơ di tích ngay trên Bản đồ. |
| AC-4 | Toàn bộ unit/widget/integration test cho luồng mới pass. |

## 2. Hiện trạng (đã kiểm chứng source)

- Backend `path`: `GET /api/v1/me/learning-path` đủ cây + `LearnerPathStatus` + `currentByPeriod`/`lastPeriodCode`; `touchPeriod` có sẵn.
- Backend `map`/`learning`: `LocationUnlockEvaluator` ANY/ALL trong transaction `complete()` → `newlyUnlockedLocations[]`; `GET /map/locations?eventId=` trả `unlocked`, `unlockState`, `visibility`, `kind`, `coverAssetId`.
- **Không cần sửa Java / Flyway.** Contract hiện đủ dùng.
- Mobile `/map` hiện lấy `map_locations` làm trục → bài không gắn di tích vắng mặt. `/journey` là danh sách chữ tách rời → `CampaignDetailScreen` thêm 1 hop.
- `UnlockedLocationBanner` đã render khi `newlyUnlockedLocations` non-empty; nút "Tiếp tục học" đang về `/journey`.
- `JourneyLayout`/`JourneyPathPainter` tái dùng được (zigzag 2 lanes, path theo `MapUnlockState` — mobile map `LearnerPathStatus → MapUnlockState` 1:1).
- Admin: `UnlockedLocationsCard` (lesson builder) + `/map-locations` page đã CRUD đầy đủ link/mode — chỉ thiếu copy nói rõ **tùy chọn**.

## 3. Phạm vi thay đổi

### 3.1 Mobile — trục Bản đồ Dấu Ấn (AC-1, AC-2)

**File mới**
- `lib/features/map/presentation/path_event_node.dart` — `PathEventNode`: node sự kiện trên canvas. `LOCKED` xám-khóa, `AVAILABLE` son, `IN_PROGRESS` vàng, `COMPLETED`/`MASTERED` xanh-check; `NOT_READY`/`EXPLORATION_ONLY` style riêng; icon + nhãn chữ; chip `x/y` khi nhiều bài; hit target ≥44px.
- `lib/features/map/presentation/event_action_sheet.dart` — `EventActionSheet`: bottom sheet khi chạm node. Cover (`coverAssetKey` qua `EventCoverImage`), `yearLabel`, title, tiến độ bài, CTA:
  - `AVAILABLE`/`IN_PROGRESS` → "BẮT ĐẦU HỌC"/"TIẾP TỤC HỌC" → `/learning/lesson/:lessonId` (bài `IN_PROGRESS` đầu tiên, không có thì `AVAILABLE` đầu tiên theo `sortOrder`).
  - `COMPLETED`/`MASTERED` → "Ôn lại" + link "Chi tiết chiến dịch" → `/campaign/:eventId`.
  - `LOCKED` → text điều kiện, không CTA. `NOT_READY` → "Nội dung đang biên tập".
  - Hàng cuối: chip ghim di tích `unlocked` của event → `LocationProfileSheet`.

**File sửa**
- `historical_map_screen.dart` — nguồn chính `learningPathProvider`; lớp phụ `mapLocationsProvider`. Chặng = `PERIOD` chapters (nhóm theo `ERA`); đổi chặng → `touchPeriod`; auto chọn `lastPeriodCode`/`currentByPeriod` hoặc `?period=`; canvas nodes = `path.eventsOfPeriod(period)` theo `sortOrder`; ghim vệ tinh = `mapLocationsByEventProvider(eventId)` lọc `unlocked`; `?view=timeline` redirect `/map`; danh sách đáy = di tích đã mở của chặng.
- `journey_path_painter.dart` — giữ nguyên (map `LearnerPathStatus → MapUnlockState` phía caller).
- `router.dart` — `/journey` + `/journey/:periodCode` → `redirect` sang `/map`/`/map?period=`; `/map` nhận `?period=`; `_learningPrefixes`/`_demoOnlyPrefixes` cập nhật; xóa import 2 screen cũ.
- `main_bottom_nav.dart` — `_routeTabs`: `/journey` → tab 1; label tab 1 "Hành trình".
- `learner_dashboard_screen.dart` — card "Bài học hôm nay" `→ /map?period=<code>`; các CTA `/map` giữ.
- `timeline_screen.dart` — redirect `/journey` → `/map`.
- `lesson_player_screen.dart` — sau `complete()`: invalidate `learningPathProvider` + `mapLocationsProvider`.
- `unlocked_location_banner.dart` — "Tiếp tục học" → `/map` (thử `/map` trước).
- `lesson_result_screen.dart` — nút "Tiếp tục" mặc định → `/map`.
- `map_providers.dart` — thêm `mapLocationsByEventProvider(eventId)`, `mapLocationsByPeriodProvider(periodCode)`.

**Xóa**
- `period_selection_screen.dart`, `period_journey_screen.dart` + import/caller; giữ `path_status_badge.dart`, `learning_path_presentation.dart` (còn dùng).

### 3.2 Backend

Không sửa code. Verify-only qua IT sẵn có (`HeritageLocationV2IT`, `LearningFlowHeritageEndToEndIT`).

### 3.3 Admin (`dau-viet-admin`)

- `unlocked-locations-card.tsx` — copy nói rõ "phần thưởng khám phá sau khi học (tùy chọn)"; empty-state ghi "không bắt buộc"; badge hiện event liên kết cho `linkedLocation`.
- `map-locations-page.tsx` — tab `unlock`: label/helper cùng thông điệp; `unlockRuleMode NONE` = "mở tự do — không gắn bài học". Không đổi mutation/API.

### 3.4 Tests

- Mới `test/map/path_map_screen_test.dart`: nodes theo sortOrder + status; tap `AVAILABLE` → sheet → push `/learning/lesson/:id`; `LOCKED` không CTA; đổi chặng → `touchPeriod`.
- Mới `test/map/heritage_pins_test.dart`: ghim vệ tinh chỉ khi `unlocked`; `HIDDEN_UNTIL_UNLOCKED`+locked → ẩn; tap ghim → `LocationProfileSheet`.
- Sửa `test/learning/unlocked_location_banner_test.dart`: continue → `/map`.
- Xóa/deprecate test pin vào 2 screen `/journey` cũ; giữ test pure-function còn dùng.
- Admin: cập nhật assert text trong `map-locations-section.test.tsx` / test liên quan nếu có.

### 3.5 Docs

`docs/PROJECT_OVERVIEW.md` (bảng đã code), `docs/LEARNING_PATH_2_0.md` (luồng mới), `docs/API_SPEC.md` (ghi chú client), `docs/project-changelog.md`, `docs/development-roadmap.md`.

## 4. Luồng sau khi sửa

Dashboard/CTA → `/map` (Bản đồ Dấu Ấn, nguồn `/me/learning-path`) → chọn chặng `PERIOD` (`touchPeriod`) → canvas zigzag node = `EVENT` theo `sortOrder` → tap node → sheet → "Bắt đầu/Tiếp tục" → `/learning/lesson/:id` → `LessonPlayer` → `POST /complete` (server mở bài kế + `LocationUnlockEvaluator` ANY/ALL) → `/learning/result/:id` → banner di tích (nếu có) → "Tiếp tục hành trình" → `/map` (node kế `AVAILABLE`, ghim di tích vệ tinh hiện cạnh sự kiện).

## 5. AC → check mapping

| AC | Check |
|---|---|
| AC-1 | `path_map_screen_test.dart`: render nodes từ learning path, tap→sheet→push lesson; đổi chặng→touch. |
| AC-2 | Mock path có event `hasLocation=false` → vẫn node, học xong → node kế AVAILABLE (test + manual). |
| AC-3 | `heritage_pins_test.dart` + `unlocked_location_banner_test.dart` (đã có, cập nhật route). |
| AC-4 | `flutter analyze` + `flutter test` (mobile); `npm run lint`/test admin; backend IT chạy lại nếu môi trường cho phép. |
