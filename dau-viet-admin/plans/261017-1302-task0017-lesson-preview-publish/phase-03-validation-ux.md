# Phase 03 — Validation UX: `PublishReadinessCard` fix + summary Map + jump-to-edit

**Priority:** P1 · **Status:** pending · **Effort:** 2h

## Context links

- Backend `PublishReadinessResponse { ready, errors[], warnings[], summary: Map<String,Object> }` — `summary` keys: `stageCount, activityCount, evidenceRefs, schemaVersion, errorCount, warningCount`.
- `publish-readiness-card.tsx` hiện render `{data.summary && <p>{data.summary}</p>}` — object sẽ crash render.
- `validation-panel.tsx` có `resolveErrorPath(draft, path)` — tái dùng cho click-to-jump.
- Builder right-pane hiện mount `PublishReadinessCard lessonId={lesson.id}` — cần pass thêm `draft` + `onJump` để jump.

## Overview

Fix `summary` rendering (Map → structured list), phân biệt rõ **errors (blocking)** vs **warnings**, click error nhảy tới stage/activity trong builder qua `resolveErrorPath`, và stub `/validate` trả `summary` Map giống backend.

## Requirements

- DTO `PublishReadiness.summary` là `Record<string, unknown>` (đã fix Phase 01) — render như key-value grid.
- Errors section: tiêu đề đỏ "Lỗi chặn xuất bản (N)" + list issues (path+code+message); click → `onJump(stageId, activityId)` qua `resolveErrorPath`.
- Warnings section: tiêu đề vàng "Cảnh báo (N)" — không chặn publish.
- Nếu `ready=false` → banner "Chưa sẵn sàng xuất bản — xem chi tiết bên dưới" (giữ text cho e2e cũ assert).
- Nếu `ready=true` → banner xanh "Bài học đủ điều kiện xuất bản." + nút "Đi tới xuất bản" → `/lessons/{id}/publish`.
- Card phải nhận props: `lessonId`, `draft` (để resolve path), `onJump` (callback builder cung cấp), `disabled?` (khi readOnly ARCHIVED vẫn cho validate nhưng jump vẫn hoạt động để inspect).
- Stub `/validate` trả `summary` object: `{ stageCount, activityCount, evidenceRefs, schemaVersion, errorCount, warningCount }` (số thật từ draft parse).

## Architecture

```
BuilderPage right-pane
  └─ PublishReadinessCard(lessonId, draft, onJump)
       ├─ banner ready/not-ready
       ├─ summary grid (dt/dd)
       ├─ errors list (button → resolveErrorPath → onJump)
       ├─ warnings list (button → onJump)
       └─ actions: "Kiểm tra xuất bản" (re-run) + "Đi tới xuất bản" khi ready
```

- `onJump` signature: `(stageId: string|null, activityId: string|null) => void` — reuse `actions.selectStage`/`selectActivity` từ `useBuilder`.
- Publish screen (Phase 04) cũng mount card này nhưng `draft=null` → jump buttons hidden (card handle internally).

## Related files

**Modify**
- `src/features/lessons/builder/publish-readiness-card.tsx` — Map summary + sections + props
- `src/features/lessons/builder/builder-page.tsx` — pass `draft` + `onJump` vào card
- `scripts/e2e-backend-stub.mjs` — `/validate` trả `summary` object

**Create**
- (Không — chỉ update file hiện có.)

## Implementation steps

1. `publish-readiness-card.tsx` — update props:
   ```ts
   interface Props {
     lessonId: string;
     draft?: Draft | null;
     onJump?: (stageId: string | null, activityId: string | null) => void;
   }
   ```
2. Render summary Map: nếu `data.summary` object → render `<dl>` key-value, format key camelCase → VN label qua map:
   ```ts
   const SUMMARY_LABELS: Record<string,string> = {
     stageCount: "Số giai đoạn", activityCount: "Số hoạt động",
     evidenceRefs: "Bằng chứng tham chiếu", schemaVersion: "Phiên bản schema",
     errorCount: "Số lỗi", warningCount: "Số cảnh báo",
   };
   ```
   Key không biết → hiển thị raw key.
3. Errors list — mỗi `<li>` là `<button>` khi `draft && onJump`; resolve path → `onJump`. Style giống `ValidationPanel`.
4. Warnings section tương tự, màu `warning`.
5. Actions row:
   - "Kiểm tra xuất bản" — `mutation.mutate()` (giữ).
   - Khi `ready` → nút Link `Đi tới xuất bản` → `/lessons/${lessonId}/publish`.
6. `builder-page.tsx` — pass `draft={state.draft}` + `onJump={(sid,aid)=>{ actions.selectStage(sid); if(aid) actions.selectActivity(aid); }}`.
7. Stub `/validate` — tính `summary` từ draft:
   ```js
   const summary = {
     stageCount: draft.stages?.length ?? 0,
     activityCount: (draft.stages??[]).reduce((n,s)=>n+(s.activities?.length??0),0),
     evidenceRefs: 0,
     schemaVersion: draft.schemaVersion ?? null,
     errorCount: errors.length,
     warningCount: warnings.length,
   };
   ```

## Todo list

- [ ] Update `PublishReadinessCard` props + summary rendering + sections + jump
- [ ] Update `builder-page.tsx` pass props
- [ ] Stub `/validate` summary object
- [ ] Kiểm tra e2e `builder.spec.ts` "validate shows readiness" vẫn pass (banner text giữ nguyên)

## Success criteria

- `summary` render structured (không crash khi Map).
- Errors và warnings phân tách rõ; click error chuyển stage/activity.
- Nút "Đi tới xuất bản" chỉ hiển thị khi `ready=true`.
- Stub trả `summary` object với số đếm thật.

## Risks

- `resolveErrorPath` cần `draft` hiện tại — nếu user sửa sau khi validate, path có thể stale → jump fail silently (target=null → no-op). Chấp nhận; ghi comment.
- `onJump` prop optional → publish screen không truyền draft → buttons không render (đơn giản).
