# Phase 05 — Navigation (Sidebar, Breadcrumbs, Return-Context)

## Context links
- [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md)
- [phase-02-lessons-tab.md](./phase-02-lessons-tab.md) — `return-to.ts` helper
- `src/components/admin-shell.tsx`
- `src/components/breadcrumbs.tsx`
- Routes hiện có: `/lessons`, `/lessons/[id]`, `/evidence`, `/evidence/[id]`, `/animations`, `/animations/[id]/edit`, `/versions`, `/assets`, `/templates`, `/items`

## Overview
- **Priority**: P1
- **Status**: pending
- **Effort**: 2h
- Tinh chỉnh sidebar + breadcrumbs cho luồng event-centric; hoàn thiện `?return=` mechanism qua các detail/edit pages; giữ backward compat các routes cũ.

## Key insights
- Sidebar hiện 9 items ngang hàng. Theo flow mới: Sự kiện là hub → các trang global khác (Thư viện media, Hoạt họa, Mẫu bài học, Phiên bản, Vật phẩm) vẫn cần truy cập trực tiếp. **Quyết định**: giữ nguyên 9 items nhưng **reorder** để Sự kiện lên đầu + gom nhóm logic:
  1. Tổng quan
  2. **Sự kiện** (primary hub)
  3. Bài học (fallback list)
  4. Bằng chứng (fallback list)
  5. Hoạt họa lịch sử
  6. Thư viện media
  7. Mẫu bài học
  8. Phiên bản
  9. Vật phẩm thưởng

  → Chỉ swap vị trí, không bớt item. KISS.
- Breadcrumbs hiện render segment UUID → "Chi tiết" (isIdLike check). Cần hiển thị `<event title>`/`<lesson title>` — Phase 01 đã cover việc fetch event title; Phase 05 mở rộng cho lesson/evidence/animation/animation-scene.
- Return-context: detail pages `/lessons/[id]`, `/evidence/[id]`, `/animations/[id]/edit` hiện không có nút "Quay lại" — cần thêm `?return=` reading + nút back.
- Legacy routes: KHÔNG redirect — giữ nguyên `/lessons`, `/evidence`, `/animations` list pages (dùng cho cross-event search).

## Requirements
- Sidebar reorder theo thứ tự mới.
- Breadcrumbs:
  - `/events/<uuid>` → `Sự kiện / <event title>`
  - `/events/<uuid>?tab=lessons` → `Sự kiện / <event title>` (không thêm tab vào crumb — tab là state không phải segment)
  - `/lessons/<uuid>` → `Bài học / <lesson title>`
  - `/evidence/<uuid>` → `Bằng chứng / <evidence title>`
  - `/animations/<uuid>/edit` → `Hoạt họa / <scene title> / Soạn`
- Detail/edit pages: khi `?return=` hợp lệ → render "Quay lại" button top-left.
- `/events/[id]` giữ nguyên URL; không redirect từ `/lessons/[id]` → event workspace (vì lesson có thể thuộc nhiều event? — không, lesson chỉ 1 eventId; nhưng giữ cả 2 entry points — `/lessons/[id]` không redirect để giữ deep-link cũ).

## Architecture
- `admin-shell.tsx` — chỉ reorder `NAV_ITEMS` array.
- `breadcrumbs.tsx` — thêm `useQuery` lookup:
  - Detect UUID segment → check parent segment → query tương ứng (`qk.events.detail`, `qk.lessons.detail`, `qk.evidences.detail`, `qk.animationScenes.detail`) để lấy `title`.
  - Fallback: nếu query pending → render segment rút gọn; nếu 404 → "Chi tiết".
- `return-to.ts` (đã tạo Phase 02):
  ```ts
  export function parseReturnTo(sp: URLSearchParams | ReadonlyURLSearchParams): string | null;
  export function withReturnTo(href: string, returnTo: string | null | undefined): string;
  ```
- Detail pages: thêm `<BackLink />` component — đọc `useSearchParams`, `parseReturnTo`, render `<Link href={returnTo}>Quay lại</Link>` nếu non-null.

## Related code files

**Modify**
- `src/components/admin-shell.tsx` — reorder `NAV_ITEMS`.
- `src/components/breadcrumbs.tsx` — fetch entity title khi gặp UUID segment.
- `src/app/(admin)/lessons/[id]/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/lessons/[id]/builder/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/lessons/[id]/preview/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/lessons/[id]/publish/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/evidence/[id]/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/animations/[id]/edit/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/animations/[id]/versions/page.tsx` — thêm `<BackLink />`.
- `src/app/(admin)/events/[id]/page.tsx` — đọc `searchParams.tab` (đã làm Phase 01).

**Create**
- `src/lib/return-to.ts` — `parseReturnTo` + `withReturnTo` (nếu Phase 02 chưa tạo).
- `src/components/back-link.tsx` — `<BackLink />` client component.

**Delete**
- (none)

## Implementation steps
1. Reorder `NAV_ITEMS` trong `admin-shell.tsx`.
2. Update `breadcrumbs.tsx`:
   - Detect UUID segment (regex UUID v4).
   - Determine parent segment → call `qk.<entity>.detail(uuid)` với `useQuery` enabled khi UUID match.
   - Render title thay vì "Chi tiết".
3. Tạo `src/components/back-link.tsx`:
   ```tsx
   "use client";
   export function BackLink() {
     const sp = useSearchParams();
     const returnTo = parseReturnTo(sp);
     if (!returnTo) return null;
     return (
       <Link href={returnTo} className="...">
         ← Quay lại
       </Link>
     );
   }
   ```
4. Thêm `<BackLink />` vào đầu các detail/edit pages (trong Suspense boundary).
5. Update page `lessons/[id]/page.tsx` để forward `?return=` vào các Link con (Edit, Builder, Publish, Versions) — dùng `withReturnTo`.
6. Verify `/lessons`, `/evidence`, `/animations` list pages vẫn hoạt động độc lập.

## Todo list
- [ ] Sidebar reorder
- [ ] `breadcrumbs.tsx` fetch entity titles
- [ ] `BackLink` component + `return-to.ts` helpers
- [ ] Wire `<BackLink />` vào 7 detail/edit pages
- [ ] Forward `?return=` qua các nested links trong lesson detail
- [ ] Manual verify: từ `/events/{id}?tab=lessons` → click Mở lesson → sửa → Quay lại → về đúng tab

## Success criteria
- Sidebar có thứ tự hợp lý theo luồng event-centric.
- Breadcrumbs hiển thị `<event title>`/`<lesson title>` thay UUID.
- Từ workspace, click "Mở"/"Sửa"/"Xuất bản"/"Phiên bản" một entity → sửa xong → Quay lại → đúng tab của đúng event.
- Không `?return=` → không có nút back → giữ nguyên behavior cũ.
- Routes `/lessons`, `/evidence`, `/animations` vẫn truy cập được độc lập (cross-event search).

## Risk assessment
- **R-01**: Breadcrumbs fetch cho mọi UUID → tốn queries; chấp nhận được (cache + rare).
- **R-02**: Suspense boundary cho `useSearchParams` ở layout-level — Next.js yêu cầu Suspense khi dùng `useSearchParams` trong Client Component. **Giải pháp**: wrap `<BackLink />` trong `<Suspense>` ở page level.
- **R-03**: User edit `?return=` URL thủ công với path độc hại → `parseReturnTo` regex chặn.
- **R-04**: Sidebar reorder thay đổi muscle memory — chấp nhận được (UI mới, không break function).
- **R-05**: Breadcrumbs fetch fail (403/404) → fallback "Chi tiết" → không crash.

## Security considerations
- `?return=` validation bắt buộc — regex `^/(events|lessons|evidence|animations)/[a-f0-9-]{36}(\\?tab=(overview|lessons|hoc-lieu|info))?$`. Reject bất kỳ path nào khác.
- Không log full URL có `?return=` vào analytics nếu có PII.
- Breadcrumb fetch dùng `apiFetch` (auth headers) → không leak data ra ngoài.

## Next steps
- Phase 06 — empty states.
- Phase 07 — test `BackLink` + `parseReturnTo` + breadcrumb lookup.
