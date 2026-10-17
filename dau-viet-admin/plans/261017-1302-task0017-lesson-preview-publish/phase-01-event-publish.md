# Phase 01 — Event Publish + DTO fix + stub event-publish/archive

**Priority:** P1 · **Status:** pending · **Effort:** 2h

## Context links

- Backend `AdminEventController.publish`: `POST /api/v1/admin/events/{id}/publish` — no body, returns `AdminEventResponse`.
- Backend `AdminEventController.archive`: `POST /{id}/archive` — returns `AdminEventResponse`; 409 `EVENT_IN_USE` khi còn lesson non-archived.
- Event editor `src/features/events/event-editor-page.tsx` — hiện chỉ có StatusChip + link tạo lesson.
- Stub `scripts/e2e-backend-stub.mjs` — chưa có `/publish` `/archive` cho events.

## Overview

Thêm nút **Xuất bản sự kiện** vào event editor + **Lưu trữ** (nếu cần trong e2e) + mở rộng stub. Đồng thời fix `PublishReadiness.summary` thành `Map<string,unknown>` trong DTO (không breaking vì chưa ai render).

## Requirements

- Chỉ hiển thị "Xuất bản sự kiện" khi `status === "DRAFT"`; không publish ARCHIVED.
- Confirm dialog trước khi publish (dùng `confirmDiscard` hoặc `window.confirm` pattern — không cần Radix confirm mới nếu `confirm()` đủ).
- Thành công → invalidate `qk.events.detail(id)` + `qk.events.list` → StatusChip refresh.
- Lỗi → `toUserMessage` VN; 409 `INVALID_STATUS_TRANSITION` → message riêng.
- Fix `PublishReadiness.summary` type: `Record<string, unknown>` (không phải `string`).
- Stub: thêm `POST /api/v1/admin/events/{id}/publish` (DRAFT→PUBLISHED, +rowVersion), `/archive` (tương tự; trả 409 `EVENT_IN_USE` khi còn lesson non-archived thuộc event).

## Architecture

- Component `event-publish-button.tsx` trong `features/events/` — `useMutation` POST publish/archive, confirm, hiển thị lỗi inline.
- `event-editor-page.tsx` render `<EventPublishButton event={ev} />` cạnh StatusChip; sau publish nút biến mất (status PUBLISHED).
- `api-error.ts` thêm mapping VN: `EVENT_IN_USE` → "Sự kiện đang được bài học tham chiếu — không thể lưu trữ"; `INVALID_STATUS_TRANSITION` → "Trạng thái hiện tại không cho phép thao tác này".

## Related files

**Modify**
- `src/lib/dto/publish.ts` — `summary?: Record<string, unknown>`; thêm `PublishResponse`, `LearnerLessonContent`.
- `src/lib/api-error.ts` — VN mappings.
- `src/features/events/event-editor-page.tsx` — render nút publish (+archive nếu cần cho e2e).
- `src/lib/query-keys.ts` — không đổi (dùng `qk.events.detail/list` sẵn).
- `scripts/e2e-backend-stub.mjs` — events publish/archive endpoints.

**Create**
- `src/features/events/event-publish-button.tsx` (~80 LOC)

## Implementation steps

1. `dto/publish.ts`:
   ```ts
   export interface PublishReadiness { ready: boolean; errors: PublishIssue[]; warnings: PublishIssue[]; summary?: Record<string, unknown>; }
   export interface PublishResponse { lessonId: string; lessonVersionId: string; versionNo: number; status: string; publishedAt: string; }
   export interface LearnerLessonContent { lessonId: string; lessonVersionId: string | null; versionNo: number | null; content: unknown; }
   ```
2. `api-error.ts`: thêm case `EVENT_IN_USE`, `INVALID_STATUS_TRANSITION`, `OPTIMISTIC_LOCK_CONFLICT`, `DRAFT_SCHEMA_INVALID`, `EVENT_NOT_PUBLISHED`.
3. `event-publish-button.tsx`:
   ```ts
   "use client";
   export function EventPublishButton({ event }: { event: AdminEventDetail }) {
     const qc = useQueryClient();
     const publish = useMutation({
       mutationFn: () => apiFetch<AdminEventDetail>(`/admin/events/${event.id}/publish`, { method: "POST" }),
       onSuccess: () => {
         qc.invalidateQueries({ queryKey: qk.events.detail(event.id) });
         qc.invalidateQueries({ queryKey: ["events"] });
       },
     });
     if (event.status !== "DRAFT") return null;
     return (...)
   }
   ```
   Confirm `window.confirm("Xuất bản sự kiện này cho học viên?")`. Disabled trong khi pending. Hiển thị error message `toUserMessage`.
4. `event-editor-page.tsx` — chèn `<EventPublishButton event={ev} />` trước nút "Tạo bài học".
5. Stub:
   ```js
   const evPub = path.match(/^\/api\/v1\/admin\/events\/([0-9a-f-]+)\/publish$/);
   if (evPub && m === "POST") {
     const e = events.find(x => x.id === evPub[1]);
     if (!e) return json(res,404,{code:"EVENT_NOT_FOUND",message:"not found"});
     if (e.status !== "DRAFT") return json(res,409,{code:"INVALID_STATUS_TRANSITION",message:"status not DRAFT"});
     e.status = "PUBLISHED"; e.rowVersion++; return json(res,200,e);
   }
   const evArch = path.match(/^\/api\/v1\/admin\/events\/([0-9a-f-]+)\/archive$/);
   if (evArch && m === "POST") {
     const e = events.find(x => x.id === evArch[1]);
     if (!e) return json(res,404,{code:"EVENT_NOT_FOUND",message:"not found"});
     const inUse = lessons.some(l => l.eventId === e.id && l.status !== "ARCHIVED");
     if (inUse) return json(res,409,{code:"EVENT_IN_USE",message:"lessons reference event"});
     e.status = "ARCHIVED"; e.rowVersion++; return json(res,200,e);
   }
   ```
6. (Tuỳ chọn) nút "Lưu trữ" trong editor — chỉ thêm nếu e2e cần; YAGNI.

## Todo list

- [ ] `dto/publish.ts` — `summary` Map + `PublishResponse` + `LearnerLessonContent`
- [ ] `api-error.ts` — VN codes
- [ ] `event-publish-button.tsx` — component + mutation + confirm
- [ ] `event-editor-page.tsx` — mount button
- [ ] Stub: `/admin/events/{id}/publish` + `/archive`
- [ ] Manual check: event list re-render sau publish

## Success criteria

- Event DRAFT có nút "Xuất bản"; bấm → confirm → status đổi PUBLISHED ngay (invalidate re-fetch).
- Event PUBLISHED/ARCHIVED không hiển thị nút.
- Stub trả 409 `EVENT_IN_USE` khi archive event có lesson non-archived.
- `tsc` sạch — không lỗi từ `summary` Map (card chưa render keys của summary).

## Risks

- Stub archive check `lessons` array — lessons store hiện là `const lessons = []` — đảm bảo push/filter đúng.
- `summary` Map → các chỗ render `data.summary` hiện chỉ `{data.summary && <p>{data.summary}</p>}` — React sẽ render object → lỗi. Phải đồng thời sửa `publish-readiness-card.tsx` (giao Phase 03) HOẶC sửa tạm hiển thị JSON.stringify cho tới Phase 03. → **Quyết định:** sửa card trong Phase 01 tối thiểu (render generic), Phase 03 polish.
