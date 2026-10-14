# TASK-0006 handoff — Flutter Historical Events API Integration

## Tóm tắt

Đã nối `dau-viet-mobile` vào API Spring Boot (TASK-0005): Timeline đọc
`GET /api/v1/events`, Campaign Detail đọc `GET /api/v1/events/{id}` qua Dio +
Riverpod. Chế độ mock chạy offline giữ nguyên sau flag `USE_MOCK` tường minh —
API lỗi KHÔNG BAO GIỜ tự động hiển thị dữ liệu giả.

## Đã làm

### Phase 01 — API infrastructure
- `pubspec.yaml`: thêm `dio: ^5.7.0`.
- `lib/core/api/`:
  - `api_config.dart` — `--dart-define=API_BASE_URL` (mặc định
    `http://10.0.2.2:8080` Android / `http://localhost:8080` còn lại),
    `USE_MOCK` mặc định `false`.
  - `api_client.dart` — Dio wrapper: connect 10s / receive 15s / send 10s,
    `Accept: application/json`, map `DioException` → `ApiException`
    (envelope `{code,message,details,traceId}`; timeout → `TIMEOUT`,
    mất mạng → `NETWORK_ERROR`). Không retry ngầm — mỗi request một lần gọi.
  - `api_error.dart` — parse envelope chặt, ném `FormatException` khi sai hình.
  - `api_exception.dart` — `isNotFound`/`isUnauthorized`/`isNetworkError`...

### Phase 02 — Data layer
- `lib/features/events/data/`:
  - `historical_event_dto.dart` — `HistoricalEventSummaryDto`,
    `HistoricalEventDetailDto`, `EventsPageDto` (parse chặt bằng `as`).
  - `events_api_client.dart` — `getEvents(page,size,sort)`, `getEventById(id)`.
  - `events_repository.dart` — abstract `EventsRepository` + `EventsPageResult`.
  - `api_events_repository.dart` — DTO → model qua adapter; phần tử đầu
    danh sách = `isActive` (giữ CTA Bạch Đằng).
  - `mock_events_repository.dart` — nhận cả seed UUID
    `00000000-0000-0000-0000-000000000001` lẫn legacy `evt_bach_dang_938`;
    id lạ → `ApiException(EVENT_NOT_FOUND, 404)`.
  - `event_model_adapter.dart` — map theo contract-notes §2
    (`period`→`yearLabel`, `startYear`→`yearValue`/`year`, `summary`→
    `description`/`summary`, `tags.first`→`badgeText`, `lessonIds: const []`).
  - `events_providers.dart` — `apiClientProvider`, `eventsApiClientProvider`,
    `assetResolverProvider`, `eventsRepositoryProvider` (seam `USE_MOCK`),
    `eventsListProvider` (`ref.keepAlive()`), `eventDetailProvider.family`.
- `lib/core/assets/asset_resolver.dart` — bảng slug→filename
  (`bach-dang-938` → `dv_EVT_ngoquyen_bachdang_hero_v01.jpg`), trích slug từ
  `coverAssetKey` dạng `events/<slug>/<file>` khi thiếu slug, unknown → null;
  KHÔNG BAO GIỜ trả key thành URL.
- `lib/core/widgets/event_cover_image.dart` — asset path null/rỗng hoặc
  load lỗi → placeholder thuyền buồm, không vỡ layout.
- `lib/core/widgets/async_state_view.dart` — loading spinner / error card +
  nút THỬ LẠI / empty card dùng chung.

### Phase 03 — State + UI wiring
- `timeline_screen.dart` → `ConsumerStatefulWidget`: `eventsListProvider.when`
  (loading / error+retry / data); era chips dựng từ dữ liệu tải về
  (`{'Tất cả', ...eras}`) thay vì `MockTimelineData.eras`; filter theo
  `_selectedEra` giữ nguyên; CTA `context.go('/campaign/${item.eventId}')`
  với `eventId` = UUID backend.
- `campaign_detail_screen.dart` → `ConsumerWidget`:
  `eventDetailProvider(eventId).when` (loading / error+retry / data);
  hero `Image.asset` → `EventCoverImage(assetPath: event.heroBannerUrl)`;
  metadata `Chiến dịch:` = `event.title`, `Niên đại:` = `Năm ${event.year} •
  ${event.era}`; overlay tóm tắt = `event.summary` (từ API); phần bài học/
  4 Dấu Vết/CTA điều hướng giữ nguyên `MockBachDangData` (out of scope).

### Phase 04 — Tests + docs
- Test mới (`test/`):
  - `events_dto_test.dart` — parse đúng contract, nullable field,
    thiếu field → TypeError, page envelope.
  - `events_repository_test.dart` — stub `EventsApiClient`: map adapter,
    forward page/size/sort, empty content, 404 propagate; mock repo trả
    đúng milestone + nhận cả 2 id + 404 id lạ.
  - `asset_resolver_test.dart` — slug known/unknown/null, không trả URL.
  - `api_client_test.dart` — `ApiError.fromJson` + predicate `ApiException`.
  - `timeline_events_test.dart` — loading spinner, render data + era chips,
    error + THỬ LẠI re-request, empty state.
  - `campaign_detail_test.dart` — hero `EventCoverImage`, missing-asset →
    placeholder icon, error + THỬ LẠI.
  - `mock_mode_test.dart` — provider override bằng `MockEventsRepository`
    trả đúng hành trình demo; id lạ → lỗi (không suy diễn).
- `widget_test.dart` — override `eventsRepositoryProvider` bằng
  `MockEventsRepository` để journey test không lệ thuộc `--dart-define`.
- Docs: `dau-viet-mobile/README.md` (cách chạy + dart-define flags),
  `docs/backend-runbook.md` (mục Mobile), `docs/backend-flutter-contract-notes.md`
  (đánh dấu consumed-by TASK-0006).

## Kiểm chứng thực tế

- `flutter pub get`, `flutter analyze`, `flutter test` — **NOT VERIFIED**:
  Flutter SDK không có trên máy này (không trên PATH, không có pub-cache,
  không có `.dart_tool/package_config.json`, `pubspec.lock` stale chưa có
  `dio`). Tester agent xác nhận trong
  `plans/reports/tester-261015-0209-TASK-0006-flutter-events.md` —
  11 file test tồn tại, `pubspec.yaml` có `dio: ^5.7.0` đúng.
- Live end-to-end (backend + emulator/device) — **NOT VERIFIED**: cần
  Flutter SDK + emulator; ghi lại khi chạy được trên máy/CI có SDK.

## Quyết định / giới hạn

- `isActive` = sự kiện đầu danh sách published (giữ CTA "Khám phá Chiến
  dịch" Bạch Đằng theo hành trình demo). Nếu muốn cờ `featured` riêng → task sau.
- `subtitle` = `dto.period` (backend chưa có field phụ đề); `badgeText` =
  `tags.first`; `lessonIds` rỗng — lessons endpoint là task riêng.
- Các literal `evt_bach_dang_938` còn lại ở `router.dart` fallback,
  `battle_saban_screen.dart`, `learner_dashboard_screen.dart`, `traces`/learning
  screens — đều ngoài scope TASK-0006 (chỉ Timeline + Campaign Detail lấy API);
  mock repo vẫn chấp id này nên mock mode không gãy.
- Riverpod 3 `ref.keepAlive()` giữ state qua điều hướng — không gọi lại API
  khi quay về Timeline.

## Rủi ro còn lại

- `flutter analyze` có thể báo unused import hoặc lint nhỏ trên máy thật —
  tester sẽ liệt kê để sửa.
- `dio ^5.7.0` cần Dart >=3.3 — project yêu cầu ^3.12.0 nên ổn.
- Asset convention đang flat `assets/images/dv_EVT_*.jpg`; khi có nhiều
  sự kiện cần đồng bộ tên file với bảng `AssetResolver`.

## Files thay đổi

- M: `dau-viet-mobile/pubspec.yaml`, `README.md`,
  `lib/features/timeline/presentation/timeline_screen.dart`,
  `lib/features/campaign/presentation/campaign_detail_screen.dart`,
  `test/widget_test.dart`, `docs/backend-runbook.md`,
  `docs/backend-flutter-contract-notes.md`, `docs/PROGRESS.md`
- A: `lib/core/api/{api_client,api_config,api_error,api_exception}.dart`,
  `lib/core/assets/asset_resolver.dart`,
  `lib/core/widgets/{async_state_view,event_cover_image}.dart`,
  `lib/features/events/data/{historical_event_dto,events_api_client,events_repository,api_events_repository,mock_events_repository,event_model_adapter,events_providers}.dart`,
  `test/{api_client_test,asset_resolver_test,campaign_detail_test,events_dto_test,events_repository_test,mock_mode_test,timeline_events_test}.dart`,
  `plans/2026-10-15-flutter-events-integration/*`, `tasks/TASK-0006/handoff.md`

## Next action

- Chạy `flutter pub get` + `flutter analyze` + `flutter test` trên máy có
  Flutter SDK → đính kèm output vào `plans/reports/tester-...`.
- Nếu xanh: chạy `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0006`
  trên host có pwsh-7 để hoàn tất task.
- Nếu đỏ: sửa theo báo cáo tester rồi chạy lại.
