# Phase 03 — Tab Học liệu (Evidence + Media + Animations)

## Context links
- [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md)
- `src/features/evidence/evidence-table.tsx` + `evidence-form.tsx` + `evidence-form-sections.tsx`
- `src/features/assets/assets-library.tsx`
- `src/features/animations/animation-library.tsx` + `animation-api.ts` + `html-import-dropzone.tsx`
- `src/lib/query-keys.ts` — `qk.animationScenes.list` cần thêm `eventId`

## Overview
- **Priority**: P1
- **Status**: pending
- **Effort**: 3h
- Render `EventAssetsTab` gồm 3 section: **Bằng chứng** (filter theo eventId, tạo mới prefill), **Media** (assets dùng chung, hiển thị toàn bộ + phân biệt "đang dùng trong sự kiện"), **Hoạt họa HTML** (filter eventId + upload từ workspace).

## Key insights
- `AdminEvidenceController.list` + `AdminAnimationSceneController.list` đã nhận `eventId` — chỉ cần wire client.
- `EvidenceForm` chưa nhận `?event=` prefill — cần thêm: đọc `useSearchParams`, gán `defaultValues.eventId` + disable select.
- `animationApi.listScenes` thiếu `eventId` param → thêm vào `SceneListParams` + `qk.animationScenes.list`.
- `animationApi.importHtmlScene` đã nhận `eventId` (line 76) → tái sử dụng.
- `GET /admin/assets` KHÔNG có eventId (đúng thiết kế — assets shared). Phân biệt "đang dùng" bằng cách audit `evidence.assetId` và lesson draft asset refs — **QUYẾT ĐỊNH**: hiển thị toàn bộ library + badge "Đang dùng" cho assets được tham chiếu bởi evidence của event này (query `?eventId={id}&size=100` → collect unique `assetId`s). KHÔNG thêm eventId vào asset.
- `AnimationLibrary` hardcode lọc `templateId === 'html-webview'` — tái sử dụng + thêm `eventId` filter.

## Requirements
- Section **Bằng chứng**: list evidence của event (hide event dropdown + column), nút "Thêm bằng chứng" → `/evidence/new?event={id}&return=...`; `EvidenceForm` respect `?event=` (prefill + readonly) và `?return=`.
- Section **Media**: render `AssetsLibrary` toàn bộ; overlay badge "Dùng trong sự kiện này" trên `AssetCard` khi `asset.id ∈ usedAssetIds`; tooltip giải thích "Asset dùng chung — chỉ đánh dấu các ảnh được tham chiếu bởi bằng chứng của sự kiện này".
- Section **Hoạt họa HTML**: render `AnimationLibrary` với `eventId` filter + `HtmlImportDropzone` truyền `eventId` khi upload; edit link kèm `?return=`.
- Tất cả mutations invalidate `qk.evidences`, `qk.assets`, `qk.animationScenes`, `qk.events.detail`.

## Architecture
- `EventAssetsTab({ eventId })`:
  ```
  <section>Bằng chứng
    <EvidenceTable lockedEventId={eventId} returnTo={...} />
  </section>
  <section>Media
    <EventAssetsSection eventId={eventId} />   // wraps AssetsLibrary + badge overlay
  </section>
  <section>Hoạt họa
    <EventAnimationsSection eventId={eventId} />
  </section>
  ```
- `EventAnimationsSection` → tái cấu trúc `AnimationLibrary` thành `AnimationLibrary({ lockedEventId?, returnTo? })` (tương tự Phase 02 refactor `LessonsTable`).
- `EventAssetsSection` → fetch `usedAssetIds` từ evidence list rồi wrap `AssetsLibrary` với `usedAssetIds` prop truyền xuống `AssetCard` để render badge.

## Related code files

**Modify**
- `src/features/evidence/evidence-table.tsx` — thêm `lockedEventId` + `returnTo` props (mirror `LessonsTable` refactor Phase 02).
- `src/features/evidence/evidence-form.tsx` — đọc `useSearchParams`, nhận `?event=` prefill + `?return=` redirect sau submit.
- `src/features/evidence/evidence-form-sections.tsx` — `EvidenceBasicFields` disable event `<select>` khi có `lockedEventId` prop.
- `src/features/animations/animation-library.tsx` — thêm `lockedEventId` + `returnTo` props; truyền `eventId` vào `listScenes` + `importHtmlScene`.
- `src/features/animations/animation-api.ts` — `SceneListParams` thêm `eventId?: string`.
- `src/features/assets/assets-library.tsx` — thêm `usedAssetIds?: Set<string>` prop, forward xuống `AssetCard`.
- `src/features/assets/asset-card.tsx` — nhận `inUse?: boolean`, render badge overlay.
- `src/lib/query-keys.ts` — `qk.animationScenes.list` params thêm `eventId?: string`.
- `src/app/(admin)/evidence/new/page.tsx` — đọc `?event=` + `?return=`, truyền `EvidenceForm`.
- `src/app/(admin)/evidence/[id]/page.tsx` — render nút "Quay lại" từ `?return=`.
- `src/app/(admin)/animations/[id]/edit/page.tsx` + `versions/page.tsx` — respect `?return=`.

**Create**
- `src/features/events/workspace/event-assets-tab.tsx` — root component, 3 sections.
- `src/features/events/workspace/event-assets-section.tsx` — wrapper fetch usedAssetIds + render `AssetsLibrary`.
- `src/features/events/workspace/event-animations-section.tsx` — wrapper render `AnimationLibrary` với `lockedEventId`.

**Delete**
- (none)

## Implementation steps
1. `query-keys.ts`: `animationScenes.list` params type thêm `eventId?: string`.
2. `animation-api.ts`: `SceneListParams` + `listScenes` toQuery thêm `eventId`.
3. Refactor `EvidenceTable` — thêm `lockedEventId` + `returnTo` (pattern như `LessonsTable` Phase 02).
4. Refactor `EvidenceForm` + `EvidenceBasicFields`:
   - Page `evidence/new` đọc `?event=` + `?return=`, truyền `<EvidenceForm presetEventId returnTo>`.
   - `EvidenceForm` nhận props, gán `defaultValues.eventId = presetEventId`; disable `<select name="eventId">` khi `presetEventId` set.
   - Sau submit success → `router.push(returnTo ?? /evidence/{id})`.
5. Refactor `AnimationLibrary` — thêm `lockedEventId` + `returnTo` props:
   - Force `eventId` filter khi locked; hide event column (nếu có — check actual columns).
   - `HtmlImportDropzone` onFile → `importHtmlScene(file, { eventId })`.
   - Action links append `?return=`.
6. Refactor `AssetsLibrary` — nhận `usedAssetIds?: Set<string>`; forward xuống `AssetCard` để render badge.
7. Tạo `EventAssetsSection({ eventId })`:
   - Query `evidences?eventId={id}&size=100` (chỉ cần `assetId`) → `usedAssetIds = new Set(evidences.map(e => e.assetId).filter(Boolean))`.
   - Render `<AssetsLibrary usedAssetIds={usedAssetIds} />` + note "Thư viện media dùng chung — badge xám chỉ các ảnh đang dùng trong sự kiện này".
8. Tạo `EventAnimationsSection({ eventId })` → render `<AnimationLibrary lockedEventId={eventId} returnTo={...} />`.
9. Tạo `EventAssetsTab` — 3 sections + section headers + create buttons.
10. Update `page.tsx` evidence/animation detail để respect `?return=`.

## Todo list
- [ ] `qk.animationScenes.list` + `animationApi.listScenes` nhận `eventId`
- [ ] `EvidenceTable` refactor với `lockedEventId` + `returnTo`
- [ ] `EvidenceForm` + `EvidenceBasicFields` prefill `?event=` + redirect `?return=`
- [ ] `AnimationLibrary` refactor với `lockedEventId` + `returnTo`
- [ ] `AssetsLibrary` + `AssetCard` badge "Đang dùng"
- [ ] `EventAssetsSection` + `EventAnimationsSection` + `EventAssetsTab`
- [ ] Wire vào `EventWorkspacePage` slot `tab === 'hoc-lieu'`
- [ ] Evidence/Animation detail pages respect `?return=`

## Success criteria
- Tab "Học liệu" hiển thị 3 section rõ ràng.
- Bằng chứng list đúng eventId; "Thêm bằng chứng" prefill event + quay lại tab sau submit.
- Media hiển thị toàn bộ library; assets dùng trong event có badge.
- Hoạt họa list chỉ HTML scenes của event; upload từ workspace gán eventId; edit xong quay về.

## Risk assessment
- **R-01**: `EvidenceForm` dùng `useSearchParams` → wrap trong `<Suspense>` boundary ở page level (Next.js App Router requirement).
- **R-02**: `usedAssetIds` chỉ cover evidence — lesson draft asset refs không đếm (acceptable: chỉ cần hint; không phải hard constraint). Ghi chú trong UI.
- **R-03**: `AnimationLibrary` hiện filter `templateId` HTML — thêm `eventId` filter không break; backend hỗ trợ cả 2.
- **R-04**: `/evidence/new` không có `?event=` → form giữ behavior cũ (chọn từ dropdown).
- **R-05**: 3 sections trong 1 tab → trang dài; cân nhắc sub-tabs nếu cần (defer — giữ 1 cuộn cho MVP).

## Security considerations
- `?event=` prefill: validate UUID format, kiểm tra event tồn tại (sẽ 404 tự nhiên nếu fake).
- `?return=` validation (dùng `parseReturnTo` Phase 02).
- `html-import` vẫn multipart ≤15MB — giữ nguyên backend guard.

## Next steps
- Phase 04 gắn `EventInfoTab` (EventForm + MapLocationsSection).
- Phase 05 finalize navigation + return-context helper.
- Phase 07 test evidence prefill + usedAssetIds + animation upload context.
