# Phase 04 — Publish Flow `/lessons/[id]/publish` + republish + learner verify

**Priority:** P1 · **Status:** pending · **Effort:** 3h

## Context links

- Backend `POST /admin/lessons/{id}/publish` body `{expectedRowVersion?}` → `PublishResponse { lessonId, lessonVersionId, versionNo, status:"PUBLISHED", publishedAt }`.
- Error paths:
  - `422 DRAFT_SCHEMA_INVALID` — `details.errors[]` (gồm `EVENT_NOT_PUBLISHED`, `NO_TERMINAL_STAGE`, `NO_REQUIRED_ACTIVITY`, `EMPTY_COMPLETION`, `REQUIRED_IN_OPTIONAL_STAGE`, `DUPLICATE_ID`, `TEMPLATE_DISABLED`, `EVIDENCE_NOT_FOUND`, `ASSET_NOT_FOUND`, ...)
  - `409 OPTIMISTIC_LOCK_CONFLICT` — stale `expectedRowVersion`
  - `409 INVALID_STATUS_TRANSITION` — ARCHIVED
- `GET /api/v1/lessons/{id}/content` — learner-safe verify sau publish (Bearer, mọi role).
- Builder `state.rowVersion` phản ánh bản đã lưu gần nhất — dùng làm `expectedRowVersion`.

## Overview

Trang `/lessons/[id]/publish` là điểm kết thúc authoring: hiển thị metadata + status + `PublishReadinessCard` + nút Publish. Sau publish, hiển thị `versionNo` + `publishedAt`, link verify qua learner-content fetch, link version history (route placeholder cho A-15). Hỗ trợ **republish** (lesson PUBLISHED → publish lại sau draft edit → `versionNo` tăng).

## Requirements

- Route `/lessons/[id]/publish` — server component → `PublishPage` client.
- Sections:
  - Header: title, StatusChip, event link, `rowVersion` hiển thị nhỏ.
  - Metadata card: title, centralQuestion, objectives (parse JSON), event title, template name.
  - `PublishReadinessCard` (reuse, `draft=null` → không jump).
  - Actions: nút "Xem trước" (link preview) + "Xuất bản" (primary) + "Lưu trữ bài học" (secondary confirm).
  - Status panel sau publish: `versionNo`, `publishedAt`, `lessonVersionId` (mono).
  - Verify card: sau khi `currentVersionId` non-null → nút "Kiểm tra nội dung learner" → gọi `GET /lessons/{id}/content` (qua `/api/proxy`) → hiển thị `versionNo` trả về.
- `expectedRowVersion` = `lesson.rowVersion` lúc bấm; nếu 409 → banner "Bài học đã bị sửa đồng thời" + nút "Tải lại" → invalidate detail.
- `DRAFT_SCHEMA_INVALID` 422 → show `details.errors[]` list (path+code+message); `EVENT_NOT_PUBLISHED` → VN rõ: "Sự kiện cha chưa xuất bản — xuất bản sự kiện trước" + link `/events/{eventId}`.
- `INVALID_STATUS_TRANSITION` 409 → "Bài học đã lưu trữ — không thể xuất bản" + disable nút.
- Republish: khi `lesson.status === "PUBLISHED"` nút vẫn enable (label "Xuất bản phiên bản mới"); sau success hiển thị `versionNo` mới.
- Double-click protection: nút disabled `isPending`; không dùng debounce — `useMutation.isPending` đủ.
- Cache invalidation sau publish: `qk.lessons.detail(id)` + `["lessons"]` (list) + `qk.learner.content(id)` nếu có.
- Confirm dialog: "Xuất bản bài học này thành phiên bản mới cho học viên?" — KISS `window.confirm` hoặc tái dùng `confirmDiscard` pattern; nếu có `ConfirmDialog` component thì dùng.

## Architecture

```
publish/page.tsx → PublishPage(lessonId)
  ├─ queries: lesson detail + event detail + template list
  ├─ PublishReadinessCard (shared component, draft=null)
  ├─ publishMutation POST /admin/lessons/{id}/publish {expectedRowVersion}
  ├─ verifyMutation GET /lessons/{id}/content (verify learner-side)
  ├─ archiveMutation POST /admin/lessons/{id}/archive
  └─ sections: Header / Metadata / Readiness / Actions / LastPublished / Verify
```

- Không tạo feature folder mới — tất cả trong `features/lessons/publish/` (tách `publish-button.tsx` riêng nếu `publish-page.tsx` >200 LOC).

## Related files

**Create**
- `src/app/(admin)/lessons/[id]/publish/page.tsx` (~15 LOC)
- `src/features/lessons/publish/publish-page.tsx` (~180 LOC)
- `src/features/lessons/publish/publish-button.tsx` (~80 LOC — confirm + mutation + states)
- `src/features/lessons/publish/verify-content-card.tsx` (~80 LOC — GET learner content, display versionNo)

**Modify**
- `src/lib/query-keys.ts` — `learner: { content: (id) => ["learner","content",id] }`
- `src/components/breadcrumbs.tsx` — `publish: "Xuất bản"`
- `src/app/(admin)/lessons/[id]/page.tsx` — link "Xuất bản" card
- `src/features/lessons/builder/builder-page.tsx` — link "Xuất bản" trong toolbar khi `!readOnly`

## Implementation steps

1. Route file `publish/page.tsx` — pass `id` vào `<PublishPage lessonId={id} />`.
2. `publish-page.tsx`:
   - `useQuery` lesson detail; nếu pending → skeleton; error → `ErrorState`.
   - `useQuery` event detail (`qk.events.detail(lesson.eventId)`).
   - `useQuery` templates list để resolve `templateId` → name.
   - Render header: `<StatusChip status>` + title + event link.
   - Render `PublishReadinessCard lessonId={lessonId}` (không draft → không jump).
   - Render `<PublishButton lesson={lesson} onPublished={...} />` + `<VerifyContentCard lessonId>` khi `currentVersionId` non-null hoặc sau publish success.
   - Sau publish success: cập nhật `lastPublished` local state từ `PublishResponse` để hiển thị ngay (không chờ refetch).
3. `publish-button.tsx`:
   ```ts
   const publishMutation = useMutation({
     mutationFn: () => apiFetch<PublishResponse>(`/admin/lessons/${lesson.id}/publish`, {
       method: "POST",
       body: JSON.stringify({ expectedRowVersion: lesson.rowVersion }),
     }),
     onSuccess: (res) => { qc.invalidateQueries(...); onPublished?.(res); },
     onError: (err) => { map ApiClientError → banner/panel },
   });
   ```
   - Disabled khi `isPending` hoặc `lesson.status === "ARCHIVED"`.
   - Label: `lesson.status === "PUBLISHED" ? "Xuất bản phiên bản mới" : "Xuất bản"`.
   - Confirm `window.confirm(...)` trước mutate.
   - Error handling:
     - `err.isConflict && code === "OPTIMISTIC_LOCK_CONFLICT"` → banner + "Tải lại" button.
     - `err.isConflict && code === "INVALID_STATUS_TRANSITION"` → "Bài học đã lưu trữ".
     - `err.status === 422` → render `details.errors[]`; đặc biệt `code === "EVENT_NOT_PUBLISHED"` → "Sự kiện cha chưa xuất bản — xuất bản sự kiện trước" + link `/events/{lesson.eventId}`.
4. `verify-content-card.tsx`:
   - Props: `lessonId`, `enabled` (true khi `currentVersionId` non-null).
   - `useMutation` GET `apiFetch<LearnerLessonContent>(\`/lessons/${lessonId}/content\`)` — note path không có `/admin`.
   - Display `versionNo`, `lessonVersionId`, optional stageCount từ `content.stages.length`.
5. `builder-page.tsx` toolbar — thêm `<Button variant="secondary" asChild><Link href={\`/lessons/${lesson.id}/publish\`}>Xuất bản</Link></Button>` sau nút Preview.
6. `lessons/[id]/page.tsx` — thêm card links "Xem trước" + "Xuất bản" (cùng nhóm với "Mở trình soạn").
7. `breadcrumbs.tsx` — `publish: "Xuất bản"`.
8. `query-keys.ts` — thêm `learner` namespace.

## Todo list

- [ ] Route `/lessons/[id]/publish` + `PublishPage`
- [ ] `publish-button.tsx` — confirm + mutation + error paths
- [ ] `verify-content-card.tsx` — learner `/content` fetch
- [ ] `qk.learner.content` + breadcrumbs label
- [ ] Builder toolbar "Xuất bản" link + lesson detail card links
- [ ] Republish label + lastPublished panel
- [ ] 422 detail errors panel (reuse pattern từ `ValidationPanel` — inline list)

## Success criteria

- Publish DRAFT lesson → success hiển thị `versionNo` (1) + `publishedAt`; StatusChip → PUBLISHED; invalidate detail.
- Publish khi event DRAFT → 422 + `EVENT_NOT_PUBLISHED` → VN message rõ + link tới event editor.
- Publish với stale `rowVersion` → 409 → reload prompt.
- Republish PUBLISHED sau draft edit → `versionNo` tăng (2, 3...).
- ARCHIVED lesson → nút disabled + reason.
- Verify: sau publish, click "Kiểm tra nội dung learner" → `GET /lessons/{id}/content` trả `versionNo` trùng publish response.
- Double-click trên nút → chỉ 1 request (isPending disable).

## Risks

- `GET /lessons/{id}/content` qua BFF — proxy path: `apiFetch` prepend `/api/proxy` → path `/lessons/{id}/content` → backend `/api/v1/lessons/{id}/content` — đúng contract.
- `expectedRowVersion` lấy từ `lesson.rowVersion` cached — nếu user sửa draft ở tab khác sau khi load publish page → 409 (đúng). Message "Tải lại" → invalidate detail.
- Verify `versionNo` đối chiếu publish response — cảnh báo nếu mismatch (republish race).
- Idempotency-Key backend chưa implement → publish button chỉ dùng `isPending` (không gửi key). Đã ghi rõ trong API spec; không bịa.
