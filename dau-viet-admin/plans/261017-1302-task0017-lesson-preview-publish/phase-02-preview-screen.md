# Phase 02 — Preview Screen `/lessons/[id]/preview`

**Priority:** P1 · **Status:** pending · **Effort:** 4h

## Context links

- Backend `POST /admin/lessons/{id}/preview` → `LearnerLessonContent { lessonId, lessonVersionId:null, versionNo:null, content: JsonNode }` — projection của draft, đã strip `validation`, `evidenceRefs`, `requiredEvidenceIds`, `LEARNER_HIDDEN_KEYS`.
- `LearnerProjectionService.project(snapshot)` — deep copy → strip container (`config`,`feedback`,`validation`) → drop `stage.requiredEvidenceIds`, `activity.evidenceRefs`, `activity.validation`.
- A-13 spec trong `design/ADMIN_SCREEN_DESIGN.md` — mobile frame 360/390/430dp + stage selector, KHÔNG chấm điểm.
- Projection content shape ≈ Draft nhưng đã lọc — client render tin tưởng projection nhưng phải đối phó missing fields một cách an toàn.

## Overview

Trang `/lessons/[id]/preview` render draft hiện tại như một learner sẽ thấy, đọc-only: không submit, không chấm điểm, không ghi attempt. Cho phép chọn stage + điều hướng activity. Asset trong `VIEW_IMAGE` cần fetch qua `/admin/assets/{id}` + `AssetImage` (Bearer-protected blob).

## Requirements

- Route: `src/app/(admin)/lessons/[id]/preview/page.tsx` — server component chỉ pass `id`.
- Container `preview-page.tsx` (client) — gọi `POST /admin/lessons/{id}/preview` một lần khi mount (mutation hoặc query+POST; chọn `useMutation` vì POST thay vì GET — giống `PublishReadinessCard`).
- Layout: header (lesson title + link quay lại + reload) + mobile frame (~390px chiều rộng, border) chứa stage/activity renderers.
- Stage nav: chip/list stages ở trên (hoặc dropdown), highlight current; click → nhảy stage đó (preview không enforce transition — admin cần xem bất kỳ stage nào).
- Activity nav: Prev/Next + chips số thứ tự activity trong stage.
- Renderers: switch theo `activity.type` — implement 11 loại trong `ACTIVITY_TYPES`:
  - `READ` — text paragraphs, evidence refs (nếu projection giữ — kiểm tra: `evidenceRefs` đã bị strip → không render refs).
  - `VIEW_IMAGE` — `AssetImage` cho `config.imageAssetId` + caption.
  - `MULTIPLE_CHOICE` — question + options (radio/checkbox theo `config.multiSelect`); không đánh dấu đáp án đúng.
  - `EVIDENCE_SELECT` — `visibleEvidenceIds` → fetch `/admin/evidences/{id}`? **KISS:** chỉ hiển thị danh sách ID/title từ `config.visibleEvidenceIds` nếu projection giữ; không fetch từng evidence (giữ nhẹ) — hiển thị chips.
  - `MATCHING` — pairs prompt, render `leftItems`/`rightItems` (nếu config có), không validate.
  - `REASONING_CONNECT` — nodes + allowedRelations, không evaluate.
  - `HYPOTHESIS_CHOICE` — `hypotheses[]` (id+label) radio.
  - `DRAG_ORDER` — `items[]`/`orderedIds` drag-list đơn giản hoặc click-to-reorder (preview không cần drag physics).
  - `VERIFICATION` — visibleSourceIds + nút "SUPPORTED"/"PARTIAL"/"CONTRADICTED" mock (không submit).
  - `CER` — claim/evidence/reasoning textarea + rubric criteria display.
  - `REFLECTION_PROMPT` — prompt + textarea.
- Honest placeholder: `unsupported-activity.tsx` cho `EXPLORE_MAP` + bất kỳ type không map (không bịa).
- KHÔNG hiển thị bất kỳ key nào trong `LEARNER_HIDDEN_KEYS` — client không đọc draft, chỉ đọc `content` đã strip; thêm warning comment trong renderer.
- Empty state: draft rỗng → "Chưa có giai đoạn — quay lại Builder để thêm."

## Architecture

```
preview/page.tsx (server) → PreviewPage (client)
  ├─ useMutation preview → LearnerLessonContent
  ├─ state: selectedStageId, selectedActivityIndex
  ├─ MobileFrame (390px, scrollable, status bar giả)
  │    └─ StageView (stage) → activities.map → ActivityRenderer(activity)
  │           ├─ ReadActivityView / ViewImageActivityView / ...
  │           └─ UnsupportedActivity (fallback)
  ├─ StageNav (chips)
  └─ ActivityNav (prev/next + count)
```

- AssetImage tái dùng `features/assets/asset-image.tsx` (đã có, blob-fetch).
- Không dùng `useBuilder` — preview chỉ đọc projection, không mutate.
- Draft inside `content` may be `JsonNode` (opaque). Parse defensively — backend đảm bảo shape `{stages[], completion?}`.

## Related files

**Create**
- `src/app/(admin)/lessons/[id]/preview/page.tsx` (~15 LOC)
- `src/features/lessons/preview/preview-page.tsx` (~120 LOC)
- `src/features/lessons/preview/mobile-frame.tsx` (~40 LOC)
- `src/features/lessons/preview/stage-nav.tsx` (~50 LOC)
- `src/features/lessons/preview/stage-view.tsx` (~60 LOC)
- `src/features/lessons/preview/activity-renderer.tsx` (~80 LOC — dispatcher)
- `src/features/lessons/preview/renderers/text-renderers.tsx` — READ + VIEW_IMAGE + REFLECTION_PROMPT (~120 LOC)
- `src/features/lessons/preview/renderers/choice-renderers.tsx` — MC + HYPOTHESIS_CHOICE (~120 LOC)
- `src/features/lessons/preview/renderers/interaction-renderers.tsx` — EVIDENCE_SELECT + MATCHING + REASONING_CONNECT + DRAG_ORDER (~160 LOC)
- `src/features/lessons/preview/renderers/assessment-renderers.tsx` — VERIFICATION + CER (~100 LOC)
- `src/features/lessons/preview/unsupported-activity.tsx` (~30 LOC)

**Modify**
- `src/lib/query-keys.ts` — `preview: (id) => ["lessons","preview",id]`
- `src/components/breadcrumbs.tsx` — `preview: "Xem trước"`
- `src/app/(admin)/lessons/[id]/page.tsx` — thêm button "Xem trước" → `/lessons/{id}/preview`
- `src/features/lessons/builder/builder-page.tsx` — thêm link Preview trong toolbar (bên cạnh "Lưu nháp"); khi `state.dirty` hiển thị warning text "Có thay đổi chưa lưu — preview sẽ dùng bản đã lưu" hoặc "Lưu và xem trước" (mutate trước, sau đó push route).

## Implementation steps

1. Tạo route file `preview/page.tsx`:
   ```tsx
   export const metadata = { title: "Xem trước — Dấu Việt CMS" };
   export default async function PreviewPage({ params }: { params: Promise<{id:string}> }) {
     const { id } = await params;
     return <Preview lessonId={id} />;
   }
   ```
2. `preview-page.tsx`:
   - `useMutation` gọi `apiFetch<LearnerLessonContent>(\`/admin/lessons/${lessonId}/preview\`, { method: "POST" })` trong `useEffect` (auto-load once + nút "Tải lại").
   - Parse `content.stages` → `Stage[]` (dùng `parseDraft(JSON.stringify(content))` để tái dùng — projection là draft-shape).
   - Local state `selectedStageId` (default `stages[0]?.id`), `activityIndex` (default 0).
3. `stage-nav.tsx` — list chips stage; click → set selected + reset activityIndex 0; badge số activity.
4. `stage-view.tsx` — render stage title + activities; highlight current activity; callbacks onSelect.
5. `activity-renderer.tsx` — `switch (activity.type)` → từng renderer; default → `UnsupportedActivity`.
6. Renderers — mỗi cái nhận `{ activity }` (đã projection-safe). Không submit, không onChange (chỉ `value` local cho radio/checkbox để demo UI).
   - `ReadView`: `config.text` → paragraphs (`\n\n` split), `instruction` header.
   - `ViewImageView`: `config.imageAssetId` → `useQuery qk.assets.detail(id)` + `AssetImage`; `config.caption` caption.
   - `MultipleChoiceView`: `config.question` + `config.options[]` (`{id,text}`); radio nếu `!multiSelect` else checkbox; không mark correct.
   - `EvidenceSelectView`: `config.visibleEvidenceIds[]` → chips (id); footer "Chọn tối thiểu X" nếu `minRequired`.
   - `MatchingView`: columns `leftItems`/`rightItems` (nếu config dùng `pairs`/`items` — kiểm tra editor hiện tại: matching-editor dùng `pairs: [{left,right}]`); render 2 cột.
   - `ReasoningConnectView`: `nodes[]` list + `allowedRelations[]` chips; note "Hoạt động tương tác — preview hiển thị schema".
   - `HypothesisChoiceView`: `hypotheses[]` radio — item `{id,label}`.
   - `DragOrderView`: `items[]`/`orderedIds` — list với nút ↑/↓ để reorder local (không persist).
   - `VerificationView`: `visibleSourceIds[]` chips + 3 nút mock SUPPORTED/PARTIAL/CONTRADICTED — click chỉ đổi local state demo.
   - `CerView`: textareas Claim/Evidence/Reasoning + `rubric.criteria[]` list.
   - `ReflectionPromptView`: `config.prompt` + textarea.
   - `UnsupportedActivity`: "Loại hoạt động `{type}` chưa có preview" + collapse JSON config (read-only).
7. `mobile-frame.tsx`: wrapper `w-[390px] max-h-[75vh] overflow-y-auto rounded-3xl border shadow-sm bg-white` + fake status bar.
8. `builder-page.tsx`: thêm `<Button variant="secondary" asChild><Link href={\`/lessons/${lesson.id}/preview\`}>Xem trước</Link></Button>` + warning nếu dirty. **Quan trọng:** preview đọc draft đã lưu trên server — khi dirty, text "Xem trước (bản đã lưu)" + tooltip "Lưu để xem bản mới nhất".
9. `lesson detail page`: thêm card/link "Xem trước" + "Xuất bản" (link `/lessons/{id}/publish`).
10. `breadcrumbs.tsx`: thêm `preview: "Xem trước"`, `publish: "Xuất bản"`.

## Todo list

- [ ] Route + `preview-page.tsx` gọi preview endpoint
- [ ] `mobile-frame.tsx` + `stage-nav.tsx` + `stage-view.tsx` + `activity-renderer.tsx`
- [ ] 4 file renderers (grouped theo loại, mỗi file <200 LOC)
- [ ] `unsupported-activity.tsx` fallback
- [ ] `qk.lessons.preview` key + breadcrumb labels
- [ ] Builder toolbar link + dirty-aware CTA
- [ ] Lesson detail page links Preview/Publish
- [ ] Smoke: mở preview sau khi lưu draft → hiển thị stage + activity đã soạn

## Success criteria

- Điều hướng được giữa stages + activities.
- Renderers hiển thị đúng `instruction` + `config` cho 11 loại; EXPLORE_MAP + type lạ → placeholder rõ ràng.
- `VIEW_IMAGE` hiển thị ảnh qua `AssetImage` (blob fetch authenticated).
- Preview KHÔNG hiển thị `validation`, `evidenceRefs`, `requiredEvidenceIds`, `correctOptionIds` — đã được backend strip; renderer không cần lọc thêm.
- Dirty draft: banner rõ "Preview đang hiển thị bản đã lưu gần nhất — lưu để cập nhật."

## Risks

- `content` JsonNode — TS không biết shape → cần `parseDraft(JSON.stringify(content))` reuse; nếu projection thiếu `stages` → fallback `[]`.
- Asset trong `VIEW_IMAGE` — `AdminAsset` dto đã có `contentUrl` field từ `/admin/assets/{id}` — dùng `useAssetObjectUrl` cho blob fetch.
- Preview gọi POST (mutation) chứ không phải GET — `useQuery` không phù hợp; chọn `useMutation` + auto-fire hoặc `useEffect` manual fetch.
