# Phase 01 — Event Workspace Shell

## Context links
- [plan.md](./plan.md)
- `dau-viet-admin/src/app/(admin)/events/[id]/page.tsx`
- `dau-viet-admin/src/features/events/event-editor-page.tsx`
- `dau-viet-admin/src/components/breadcrumbs.tsx`
- `dau-viet-admin/src/lib/query-keys.ts`

## Overview
- **Priority**: P1
- **Status**: pending
- **Effort**: 3h
- Xây shell `/events/[id]` với tabs-in-page (4 tab) điều khiển bởi `?tab=` search param. Bọc page hiện có thành workspace; tách `EventForm` + `MapLocationsSection` ra khỏi page mặc định để đặt vào tab "Thông tin & địa điểm".

## Key insights
- `/events/[id]/page.tsx` hiện chỉ render `EventEditorPage` (form + map locations + nút Tạo bài học).
- Tab cần deep-link → chọn `?tab=overview|lessons|hoc-lieu|info` thay vì nested routes để không phá breadcrumb hiện có.
- `EventEditorPage` đang gộp form + map locations → cần split thành 2 components riêng (form-only / locations-only) để tái dùng trong tab riêng.
- Stats (counts) tổng hợp từ `PageResponse.totalElements` của lessons/evidences/animations (đã có endpoint) — không cần backend mới.

## Requirements
- `GET /events/[id]?tab=overview` (default): hiển thị StatusChip + actions + Stats cards (số bài học, số bằng chứng, số hoạt họa) + quick links "Tạo bài học" / "Tải hoạt họa lên" / "Thêm bằng chứng" (tất cả đều prefill eventId).
- `?tab=lessons|hoc-lieu|info` render tab content tương ứng.
- Giữ `EventPublishButton` + `EventArchiveButton` visible trên mọi tab (header khu vực).
- Breadcrumb hiển thị: `Sự kiện / <event title>` — cần tra event title (sửa `Breadcrumbs` thành fetch-aware hoặc hiển thị title trong page-header riêng).
- Không đổi behavior của `/events/new`, `/events` (list).

## Architecture
- Component tree:
  ```
  events/[id]/page.tsx (server, đọc searchParams.tab)
    └── EventWorkspacePage (client)
        ├── EventWorkspaceHeader (title + StatusChip + publish/archive buttons)
        ├── EventWorkspaceTabs (links + active state)
        └── {tab content}
            ├── overview → EventOverviewTab (stats + quick links)
            ├── lessons → EventLessonsTab (Phase 02)
            ├── hoc-lieu → EventAssetsTab (Phase 03)
            └── info → EventInfoTab (Phase 04)
  ```
- Tab state: đọc từ `searchParams`, không lưu localStorage.
- Stats: gọi 3 list APIs với `size=1` để chỉ lấy `totalElements` (cost rẻ, đủ hiển thị).

## Related code files

**Modify**
- `src/app/(admin)/events/[id]/page.tsx` — đọc `searchParams.tab`, render `EventWorkspacePage` thay `EventEditorPage`.
- `src/features/events/event-editor-page.tsx` — split: giữ fetch `AdminEventDetail`, expose `event` data + actions; phần form + map locations move sang tab riêng.
- `src/components/breadcrumbs.tsx` — fetch event title khi segment là `/events/<uuid>` (sử dụng `useQuery` + `qk.events.detail`).

**Create**
- `src/features/events/workspace/event-workspace-page.tsx` — root client component.
- `src/features/events/workspace/event-workspace-header.tsx` — title + StatusChip + publish/archive.
- `src/features/events/workspace/event-workspace-tabs.tsx` — tab nav (4 links, active state).
- `src/features/events/workspace/event-overview-tab.tsx` — stats + quick actions.
- `src/features/events/workspace/event-stats.tsx` — card counts.
- `src/features/events/workspace/types.ts` — `EventWorkspaceTab` union type, tab definitions (label, href builder).

**Delete**
- (none)

## Implementation steps
1. Đọc `searchParams` trong page.tsx; chuẩn hóa `tab` → fallback `'overview'` nếu không hợp lệ.
2. Tạo `EventWorkspacePage` nhận `{ eventId, tab }` props; fetch event detail 1 lần.
3. Tạo `EventWorkspaceHeader` — title + StatusChip + EventPublishButton + EventArchiveButton + last-updated text.
4. Tạo `EventWorkspaceTabs` — render 4 Link `?tab=<slug>`, highlight khi trùng current tab (từ prop).
5. Tạo `EventOverviewTab`:
   - 3 `EventStatCard` (Bài học / Bằng chứng / Hoạt họa) — mỗi card query `PageResponse` với `size=1` + `eventId`, hiển thị `totalElements`.
   - Quick action buttons:
     - `Link /lessons/new?event={id}&return=/events/{id}?tab=lessons`
     - `Link /evidence/new?event={id}&return=/events/{id}?tab=hoc-lieu` (nếu evidence form nhận `?event=` — verify; nếu không thì POST rồi redirect)
     - `Link /animations?event={id}&return=/events/{id}?tab=hoc-lieu` hoặc mở modal upload trong tab
   - Map section preview (3 dòng đầu) + link "Quản lý đầy đủ" sang tab `info`.
6. Refactor `EventEditorPage` — giữ fetch + actions; bỏ render `EventForm`+`MapLocationsSection` (move sang `EventInfoTab` Phase 04). Giữ API cũ `({ eventId })`.
7. Cập nhật `Breadcrumbs` để fetch event title cho path `/events/<uuid>` (dùng `useQuery` + `qk.events.detail`); fallback UUID rút gọn.

## Todo list
- [ ] `page.tsx` đọc `searchParams.tab`, validate, render workspace
- [ ] `EventWorkspacePage` + `Header` + `Tabs` components
- [ ] `EventOverviewTab` với stats + quick links
- [ ] `EventEditorPage` refactor (form + locations tách ra)
- [ ] `Breadcrumbs` hỗ trợ event title
- [ ] Manual verify: mở `/events/<id>` → tabs render; `?tab=lessons` deep link hoạt động

## Success criteria
- `/events/<uuid>` render workspace với tab "Tổng quan" mặc định.
- Mỗi tab có URL riêng `/events/<uuid>?tab=<slug>`, F5 giữ tab.
- Header hiển thị title + StatusChip + nút publish/archive luôn sẵn.
- Breadcrumb hiển thị `<event title>` thay UUID.

## Risk assessment
- **R-01**: `EventEditorPage` đang dùng ở chỗ khác? Grep `/events/[id]` → chỉ `page.tsx` dùng → safe split.
- **R-02**: Stats queries (3 list calls) nhẹ nhưng tốn network → acceptable (size=1, parallel).
- **R-03**: Tab param bị lạm dụng (`?tab=<script>`) → whitelist 4 slug cố định; còn lại fallback overview.
- **R-04**: Breadcrumb fetch event title tốn 1 request per crumb — chấp nhận được (cache react-query).

## Security considerations
- Tab param whitelist — KHÔNG reflect thẳng vào DOM.
- `return=` query khi build từ header: validate chỉ cho phép internal paths (regex `^/(events|lessons|evidence|animations)/[a-f0-9-]{36}` + optional query); reject `//`, `javascript:`, external.
- Không log eventId kèm PII.

## Next steps
- Phase 02 gắn `EventLessonsTab` vào slot `tab === 'lessons'`.
- Phase 03 gắn `EventAssetsTab`.
- Phase 04 gắn `EventInfoTab` (EventForm + MapLocationsSection).
- Phase 05 bổ sung return-context validation helper dùng chung.
