# Phase 05 — Media Assets + Error Hardening + Mock-mode Split

## Context links

- Phase 01 (ApiClient auth), phase 03 (renderers dung `AuthenticatedAssetImage` stub), phase 04 (retry)
- `docs/API_SPEC.md` error envelope `{code,message,details,traceId}`; `X-Request-Id` header
- `LearnerAssetController`: `GET /api/v1/assets/{id}/content` → bytes, auth, ACTIVE only
- Snapshot `assets[]` embed: `{id, storageKey, mimeType, sizeBytes, originalFilename, altText}`
- Brief: image can token + alt/missing/expired fallback; evidence metadata tu snapshot embed; mock split: USE_MOCK giu demo, API error KHONG fallback sang mock.

## Overview

- Priority: P1 (hardening; mot so muc can cho renderers chay duoc)
- Status: pending
- Widget asset co auth + fallback day du; map error envelope → UI copy tieng Viet; giu answer khi loi mang; mock mode giu nguyen demo doc lap, khong tron voi API path.

## Key insights

- Asset bytes endpoint tra raw bytes (khong JSON) — dung Dio `ResponseType.bytes`, header Bearer. `mimeType` tu embed de validate (image/*); khong co metadata endpoint cho learner.
- `AssetResolver` hien tai chi map event cover → asset bundled trong pubspec — mo rong KHONG pha API cu: them `LearningAssetImage` widget rieng cho asset server (khac resolver local).
- Fallback chain: dang tai → shimmer; 401 → refresh + retry 1 lan; 403/404/expired/inactive → khung placeholder + `altText` + icon, KHONG crash man hinh; mimeType khong phai image → placeholder.
- Cache: `Map<int, Uint8List>` trong provider (per session), khong ghi disk (YAGNI).
- Error envelope map:
  - 400 `VALIDATION_FAILED`/`INVALID_*` → hien `message` (server viet san) + giu answer.
  - 401 → silent refresh + retry; fail → session expired → ve /auth.
  - 403 `FORBIDDEN` → "Bạn không có quyền" → ve dashboard.
  - 404 `*_NOT_FOUND` → "Không tìm thấy" + back.
  - 409 `IDEMPOTENCY_CONFLICT` → hien thong bao + refetch state (khong retry cung key).
  - 409 `ATTEMPT_ALREADY_COMPLETED` → navigate result.
  - 422/`LESSON_NOT_PUBLISHED` → copy rieng.
  - 5xx/network/timeout → retry banner giu state (phase 04).
  - fallback → `message` hoac "Đã có lỗi xảy ra, thử lại sau" + `traceId` hien nho (ho tro debug).
- Mock mode: `USE_MOCK=true` → router guard off, guest button on, mock `/learning/*` demo screens giu nguyen (KHONG xoa answer keys o do — demo docs ro rang); `USE_MOCK=false` → mock routes redirect ve /auth, repository mock khong inject. API error trong real mode → error UI, TUYET DOI khong mock fallback.

## Requirements

- `LearningAssetImage(assetDoc, {fit})`: resolve `id` → fetch bytes auth → `Image.memory`; fallback states; semantic label = `altText`.
- `AssetImageCache` provider: per-attempt/session cache; invalidate on logout.
- `ErrorMapper`: `ApiException` → `UiError{title, message, actionLabel?, onAction?}`; copy tieng Viet co dau; giu `traceId`.
- `ErrorView`/`RetryBanner` dung chung cho list/player/result (AsyncStateView error factory ton tai — extend voi action).
- Auth refresh-on-401 centralize trong repository layer (phase 01) — phase nay verify no cover asset fetch + moi call.
- Mock split check: grep `useMock` — repository switch duy nhat; khong file presentation nao import mock data truc tiep ngoai demo routes.
- Guest path: chi trong USE_MOCK; session guest khong goi API.

## Architecture

```
core/widgets/learning_asset_image.dart     auth image + fallback chain
core/api/error_mapper.dart                 ApiException -> UiError (copy vi_VN)
core/widgets/error_view.dart               title/message/action + traceId
features/learning/data/asset_cache.dart    in-memory bytes cache provider
```

Modify: renderers `view_image`/`explore_map`/`evidence_select` (gan LearningAssetImage), player/list/result screens (dung ErrorView + RetryBanner), `router.dart` (mock guard), `api_client.dart` (bytes call helper neu can).

## Related code files

Create: 4 file tren.
Modify:
- `lib/features/learning/presentation/player/renderers/{view_image,evidence_select,explore_map}_renderer.dart`
- `lib/features/learning/presentation/{lesson_player_screen,lesson_entry_screen,lesson_result_screen}.dart`
- `lib/features/campaign/presentation/campaign_detail_screen.dart` (error state nhat quan)
- `lib/app/router.dart` (guard USE_MOCK)
- `lib/core/api/api_client.dart` (`getBytes` neu chua co)

## Implementation steps

1. `ApiClient.getBytes(path)` → `Uint8List` (ResponseType.bytes + Bearer).
2. `asset_cache.dart`: `StateProvider<Map<String,Uint8List>>` + `fetchAsset(id)` repo call.
3. `LearningAssetImage`: FutureBuilder qua provider; shimmer → image → placeholder(altText).
4. `error_mapper.dart`: switch theo status+code → UiError; default giu `message` + `traceId`.
5. `error_view.dart`: full-screen variant + inline `RetryBanner` variant; action callback.
6. Renderers: thay image stub bang `LearningAssetImage`; evidence card hien `altText` khi asset fail.
7. Router: `USE_MOCK=false` → redirect `/learning/{mock-demo routes}` ve `/auth`; giu nguyen mock khi true.
8. Kiem chung mock split: `mock_mode_test.dart` mo rong — assert `USE_MOCK=false` khong build duoc `MockAttemptRepository` (provider throws/assert) va API error khong trigger mock.
9. Offline detect don gian: Dio `connectionTimeout`/SocketException → banner offline (khong them package connectivity — YAGNI; retry bang tay).

## Todo list

- [ ] getBytes + asset cache provider
- [ ] LearningAssetImage fallback chain + altText semantics
- [ ] error_mapper + error_view/retry_banner copy vi_VN
- [ ] Gan vao renderers + screens (list/player/result/campaign)
- [ ] Router mock guard + mock_mode_test coverage
- [ ] Refresh-on-401 cover asset fetch
- [ ] `flutter analyze` sach

## Success criteria

- Anh server hien voi Bearer; 401 → refresh + retry 1 lan; 403/404 → placeholder altText; khong crash.
- Moi ApiException → copy tieng Viet ro nghia; traceId co trong error view.
- Network mat giua submit → giu answer, retry dung key; khong duplicate.
- USE_MOCK=false: guest button an, mock routes redirect, API loi → error UI (khong mock). USE_MOCK=true: demo nguyen ven.
- Khong request asset nao kem token trong URL/query.

## Risk assessment

- Asset lon: `sizeBytes` co san trong embed — canh bao/khong fetch neu > nguong (vi du 8MB) → placeholder + "Tệp quá lớn".
- Secure storage tren mot so platform fail → TokenStorage da try/catch (phase 01) — session expired gracefully.
- `details` object hien da type-safe sau phase 01; giu render defensive.

## Security considerations

- Token chi trong Authorization header; bytes cache chi trong memory; clear on logout.
- Khong log `details` chua PII; traceId la du cho support.
- Alt text khong chua answer/answer key.

## Next steps

Phase 06: test suite + gates + verification report.
