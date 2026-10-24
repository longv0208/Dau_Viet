# Phase 02 — Tab Bài học

## Context links
- [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md)
- `src/features/lessons/lessons-table.tsx`
- `src/features/lessons/lesson-wizard.tsx`
- `src/lib/dto/lesson.ts`

## Overview
- **Priority**: P1
- **Status**: pending
- **Effort**: 2h
- Render `EventLessonsTab` — danh sách lesson thuộc event + nút "Tạo bài học" prefill `eventId` + links Edit/Preview/Publish/Versions với `?return=` để quay về tab.

## Key insights
- `AdminLessonController.list` đã có `eventId` → chỉ cần reuse `LessonsTable` logic nhưng hide event-filter dropdown + hide "Sự kiện" column (đã biết context).
- `LessonWizard` đã nhận `?event=` search param (line 49) → tạo mới từ workspace chỉ cần `Link /lessons/new?event={eventId}&return=...`.
- `LessonsTable` hiện tại self-contained với own state → không thể reuse trực tiếp vì cần `eventId` forced + hide event column. **Quyết định**: tạo `EventLessonsTable` (component mới, đơn giản hơn) hoặc refactor `LessonsTable` nhận optional `lockedEventId` prop. **Chọn refactor**: thêm prop `lockedEventId?: string` vào `LessonsTable` — khi set: hide event dropdown, hide "Sự kiện" column, force `eventId` filter. Tái sử dụng hoàn toàn, không duplicate.

## Requirements
- List lesson của event hiển thị: Tiêu đề / Trạng thái / Xuất bản / Version / Thao tác (Mở, Preview, Xuất bản, Phiên bản).
- Mỗi row link kèm `?return=/events/{id}?tab=lessons` để quay về workspace sau khi sửa.
- Nút "Tạo bài học" → `/lessons/new?event={eventId}&return=/events/{eventId}?tab=lessons`.
- Empty state: "Chưa có bài học nào — bắt đầu bằng cách tạo bài học đầu tiên cho sự kiện này" + CTA button.
- Search + Status filter giữ nguyên (vẫn hữu ích trong event có nhiều lesson).
- Sort: `updatedAt desc` mặc định.

## Architecture
- `EventLessonsTab({ eventId })` → `<LessonsTable lockedEventId={eventId} returnTo={`/events/${eventId}?tab=lessons`} />`.
- `LessonsTable` modifications:
  - Props mới: `lockedEventId?: string`, `returnTo?: string`.
  - Khi `lockedEventId` set: force `eventId` filter (bỏ `useState`), hide event dropdown, hide "Sự kiện" column.
  - Tất cả `Link /lessons/{id}`, `Link /versions?lesson={id}` append `?return=` (hoặc `&return=` nếu đã có query).
- `LessonWizard` — sau submit thành công, đọc `?return=` và `router.push(returnTo)` thay `router.push(/lessons/{id})`.

## Related code files

**Modify**
- `src/features/lessons/lessons-table.tsx` — thêm `lockedEventId` + `returnTo` props; hide event column + dropdown khi locked.
- `src/features/lessons/lesson-wizard.tsx` — đọc `?return=`, redirect tới đó sau success (fallback `/lessons/{id}`).
- `src/features/lessons/lesson-basic-form.tsx` — nếu có nút "Huỷ" / "Quay lại" thì cũng tôn trọng `?return=`.
- `src/app/(admin)/lessons/[id]/page.tsx` — đọc `?return=`, render nút "Quay lại" với link validated.
- `src/app/(admin)/lessons/[id]/builder/page.tsx`, `preview/page.tsx`, `publish/page.tsx` — pass `?return=` vào nút back / breadcrumb.

**Create**
- `src/features/events/workspace/event-lessons-tab.tsx` — wrapper.
- `src/lib/return-to.ts` — helper `parseReturnTo(searchParams): string | null` + `withReturnTo(href, returnTo)` (dùng chung Phase 05).

**Delete**
- (none)

## Implementation steps
1. Tạo `return-to.ts`: `parseReturnTo` validate regex `^/(events|lessons|evidence|animations)/[a-f0-9-]{36}(\\?.*)?$`, return null nếu fail; `withReturnTo` append `?return=` hoặc `&return=` encodeURIComponent.
2. Refactor `LessonsTable` — thêm props, conditional render event column + dropdown.
3. Trong cell "actions", dùng `withReturnTo(\`/lessons/${r.id}\`, returnTo)` tương tự cho các link.
4. Tạo `EventLessonsTab` — header (title + Create button) + `LessonsTable lockedEventId={eventId} returnTo={...}`.
5. `LessonWizard` — đọc `?return=`, sau POST thành công `router.push(parseReturnTo(...) ?? /lessons/{newId})`.
6. `/lessons/[id]/page.tsx` + builder/preview/publish pages — đọc `?return=`, render "Quay lại {event title}" button góc trên.

## Todo list
- [ ] `return-to.ts` helper
- [ ] `LessonsTable` refactor với `lockedEventId` + `returnTo`
- [ ] `EventLessonsTab` component
- [ ] `LessonWizard` respect `?return=`
- [ ] Lesson detail/builder/preview/publish pages respect `?return=`
- [ ] Wire vào `EventWorkspacePage` slot `tab === 'lessons'`

## Success criteria
- Tab "Bài học" list đúng lessons của event (eventId forced, không có dropdown sự kiện).
- Tạo lesson từ workspace → wizard prefill eventId → submit xong quay về `/events/{id}?tab=lessons`.
- Click "Mở" một lesson → sửa xong → bấm "Quay lại" → về workspace tab lessons.
- Không còn dropdown sự kiện + column "Sự kiện" trong tab.

## Risk assessment
- **R-01**: `LessonsTable` đang dùng ở `/lessons/page.tsx` — props optional nên không break; giữ behavior cũ khi không truyền.
- **R-02**: `LessonWizard` submit redirect hiện tại `/lessons/{id}` — nếu `?return=` không hợp lệ (fail regex) fallback đúng.
- **R-03**: User paste link `/events/{id}?tab=lessons&return=...` (nested return) — `parseReturnTo` sẽ validate; nếu fail → bỏ qua.

## Security considerations
- `return=` validation — bắt buộc. Regex whitelist routes + UUID; encodeURIComponent khi build link.
- Lesson list query dùng `eventId` từ props, không từ `searchParams` → tránh tampering.
- Không render raw `?return=` vào `Link href` mà không qua `parseReturnTo`.

## Next steps
- Phase 05 dùng `return-to.ts` cho evidence/animation edit pages.
- Phase 07 test `withReturnTo` + `parseReturnTo` + tab integration.
