# Phase 04 — Tab Thông tin & Địa điểm

## Context links
- [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md)
- `src/features/events/event-form.tsx`
- `src/features/events/map-locations-section.tsx`
- `src/features/events/event-editor-page.tsx`

## Overview
- **Priority**: P2
- **Status**: pending
- **Effort**: 1h
- Render `EventInfoTab` — gộp `EventForm` (chỉnh sửa thông tin sự kiện) + `MapLocationsSection` (quản lý địa điểm bản đồ) — tái sử dụng nguyên trạng, không thêm feature mới.

## Key insights
- `EventEditorPage` hiện tại render đúng `EventForm` + `MapLocationsSection` — Phase 04 chỉ move sang tab riêng.
- `EventForm` nhận `initial: AdminEventDetail` — data đã có sẵn từ `EventWorkspacePage` (đã fetch `qk.events.detail(eventId)`).
- `MapLocationsSection` nhận `eventId` prop — wire trực tiếp.

## Requirements
- Tab "Thông tin & địa điểm" render: `<EventForm initial={event} />` + divider + `<MapLocationsSection eventId={eventId} />`.
- Form vẫn dùng `useUnsavedChangesGuard` — khi switch tab có dirty, confirm dialog hiển thị (đã implement sẵn trong `EventForm`).
- Không thêm return-context ở đây (form không navigate away).

## Architecture
- `EventInfoTab({ event })` nhận `AdminEventDetail` trực tiếp (không fetch lại — parent đã fetch).
- Đơn giản compose:
  ```tsx
  <div className="flex flex-col gap-6">
    <EventForm initial={event} />
    <hr className="border-border" />
    <MapLocationsSection eventId={event.id} />
  </div>
  ```

## Related code files

**Modify**
- `src/features/events/workspace/event-workspace-page.tsx` — case `tab === 'info'` → render `<EventInfoTab event={event} />`.

**Create**
- `src/features/events/workspace/event-info-tab.tsx` — compose `EventForm` + `MapLocationsSection`.

**Delete**
- (none — `EventEditorPage` vẫn giữ cho backward compat nếu cần, hoặc remove nếu Phase 01 đã thay thế hoàn toàn. **Quyết định**: giữ — page.tsx vẫn render `EventEditorPage` khi không có workspace logic; sau Phase 01+04 hoàn thiện thì `EventEditorPage` có thể deprecate — để Phase 05 quyết định xóa hay giữ.)

## Implementation steps
1. Tạo `event-info-tab.tsx` nhận `event: AdminEventDetail`, render compose.
2. Wire vào `EventWorkspacePage` slot `tab === 'info'`.
3. Verify `EventForm` unsaved-guard hoạt động khi switch tab (đã có sẵn `useUnsavedChangesGuard` — check có handle in-app navigation qua `<Link>` không).

## Todo list
- [ ] `EventInfoTab` component
- [ ] Wire vào `EventWorkspacePage`
- [ ] Manual verify unsaved-changes prompt khi switch tab

## Success criteria
- `/events/{id}?tab=info` render form + map locations giống page hiện tại.
- Sửa form xong switch sang tab khác → confirm dialog.
- Map locations section hoạt động đúng (không break từ refactor).

## Risk assessment
- **R-01**: `EventEditorPage` không còn dùng → orphan code. **Giải pháp**: sau Phase 05 nếu không còn import, remove.
- **R-02**: `EventForm` gọi `router.push('/events')` ở nút Huỷ → khi ở workspace, Huỷ sẽ về `/events` list (không phải tab). **Chấp nhận được** — hành vi hợp lý.
- **R-03**: Duplicate query `qk.events.detail(eventId)` giữa `EventWorkspacePage` + `EventForm` — react-query cache → chỉ 1 fetch.

## Security considerations
- Form validation Zod + server field errors đã có sẵn.
- Optimistic locking `rowVersion` giữ nguyên.

## Next steps
- Phase 05 sidebar reorder + breadcrumbs + return-context helper.
- Phase 06 empty states.
