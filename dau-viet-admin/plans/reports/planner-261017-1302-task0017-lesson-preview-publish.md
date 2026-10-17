# Planner Report — TASK-0017 Lesson Preview, Validation & Publishing

Ngày: 2026-10-17 · Plan dir: `dau-viet-admin/plans/261017-1302-task0017-lesson-preview-publish/`

## Plan đã tạo

- `plan.md` — overview + phase list + research findings + risks/open questions
- `phase-01-event-publish.md` (2h) — event publish/archive buttons + DTO `summary` Map fix + stub
- `phase-02-preview-screen.md` (4h) — `/lessons/[id]/preview` mobile-frame preview + 11 renderers
- `phase-03-validation-ux.md` (2h) — `PublishReadinessCard` Map summary + jump-to-edit
- `phase-04-publish-flow.md` (3h) — `/lessons/[id]/publish` + republish + learner verify
- `phase-05-tests.md` (3h) — stub extensions + MSW + unit tests + e2e journey

## Phát hiện chính — VERIFIED, không suy đoán

### Backend đã có sẵn (TASK-0010 đã implement đầy đủ)

- `POST /api/v1/admin/events/{id}/publish` + `/archive` — `AdminEventController.java` (đọc code)
- `POST /api/v1/admin/lessons/{id}/preview` — trả `LearnerLessonContent {lessonId, lessonVersionId:null, versionNo:null, content:JsonNode}` — projection của draft
- `POST /api/v1/admin/lessons/{id}/validate` — `PublishReadinessResponse {ready, errors[], warnings[], summary: Map<String,Object>}`
- `POST /api/v1/admin/lessons/{id}/publish` — `PublishRequest {expectedRowVersion?}` → `PublishResponse {lessonId, lessonVersionId, versionNo, status:"PUBLISHED", publishedAt}`
- `GET /api/v1/lessons/{id}/content` — learner-safe published content (Bearer)
- `LearnerProjectionService` — strip `validation`, `evidenceRefs`, `stage.requiredEvidenceIds`, `LEARNER_HIDDEN_KEYS` đệ quy trong `config`/`feedback`/`validation`

### Frontend gaps

| Item | Trạng thái | Hành động |
|---|---|---|
| `dto/publish.ts` `summary` | **SAI** — `summary?: string` | Fix thành `Record<string, unknown>` |
| `PublishReadinessCard` | Đã gọi `/validate` | Update: Map summary + sections errors/warnings + `onJump` qua `resolveErrorPath` |
| Event publish button | **CHƯA CÓ** | Tạo `event-publish-button.tsx` |
| Preview screen | **CHƯA CÓ** | Tạo `/lessons/[id]/preview` + renderers |
| Publish screen | **CHƯA CÓ** | Tạo `/lessons/[id]/publish` |
| Stub endpoints | Thiếu preview/publish/versions/learner-content/event-publish | Mở rộng stub trung thực |
| `qk.learner.*` | Thiếu | Thêm `learner.content` key |
| Breadcrumbs | Thiếu `preview`, `publish` | Thêm labels |

### Điểm quan trọng cần chú ý khi implement

1. **Preview đọc draft đã lưu**, không phải state `useBuilder` — dirty draft phải cảnh báo "xem bản đã lưu" hoặc "lưu và xem trước".
2. **Preview KHÔNG submit/chấm** — chỉ render. Backend đã strip answer keys.
3. **`expectedRowVersion`** trong `PublishRequest` = `lesson.rowVersion` lúc bấm; 409 → reload prompt.
4. **`EVENT_NOT_PUBLISHED`** là entry trong `details.errors[]` của 422 `DRAFT_SCHEMA_INVALID` — message VN rõ + link `/events/{eventId}`.
5. **Republish** — `versionNo` chỉ từ `PublishResponse` (KHÔNG từ `rowVersion`). Backend tự tăng `max+1`.
6. **Learner verify** qua `GET /api/v1/lessons/{id}/content` — path qua `/api/proxy/lessons/{id}/content` (không `/admin` prefix).
7. **Stub projection phải mirror `LearnerProjectionService`** — `LEARNER_HIDDEN_KEYS` list phải giữ sync (đọc `DraftSchema.java`).
8. **File size <200 LOC** — preview split thành 4 file renderers theo nhóm (text/choice/interaction/assessment).
9. **Proxy BFF cap 2 MiB** — không liên quan preview/publish (JSON nhỏ).
10. **Idempotency-Key** backend chưa implement cho publish — chỉ dùng `isPending` disable.

## AC → Phase mapping

| AC | Phase |
|---|---|
| Event publish + DRAFT-event VN error | 01 + 04 |
| Preview `/lessons/[id]/preview` + renderers | 02 |
| PublishReadinessCard fix | 03 |
| Publish flow + republish + verify | 04 |
| Unsaved-guard preview | 02 (builder toolbar CTA) |
| Unit + e2e | 05 |

## Câu hỏi mở

- A-15 version history (`/lessons/{id}/versions`) — chỉ link từ publish screen trong scope này, không build UI đầy đủ. Xác nhận OK?
- `Idempotency-Key` cho publish — backend chưa implement, nên client không gửi. Khi backend thêm sau này → cập nhật.
- Stub `projectSnapshot` duy trì sync với Java `LearnerProjectionService` — cần comment trong stub "keep in sync".
- Refactor `tests/e2e/helpers.ts` — extract login/createLesson. Nếu refactor, phải chạy lại `builder.spec.ts` + `evidence-authoring.spec.ts` trước khi báo cáo.
