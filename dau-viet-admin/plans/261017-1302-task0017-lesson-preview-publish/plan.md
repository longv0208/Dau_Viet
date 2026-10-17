---
title: "TASK-0017 — Lesson Preview, Validation UX & Publishing"
description: "Hoàn thiện luồng soạn Admin: preview mobile → validate → publish → verify → republish, kèm publish sự kiện."
status: pending
priority: P1
effort: 14h
branch: main
tags: [admin, preview, publish, validation, bff]
created: 2026-10-17
---

# TASK-0017 — Lesson Preview, Validation & Publishing

Hoàn tất chu trình authoring Admin: Preview → Validate → Publish → Verify learner-facing → Republish sau khi sửa.

## Phát hiện từ research (quan trọng — không suy đoán)

| Hợp đồng | Tình trạng | Ghi chú |
|---|---|---|
| `POST /admin/events/{id}/publish` | Backend ĐÃ CÓ (`AdminEventController`); UI CHƯA gọi | Thêm nút vào `event-editor-page`. Body empty; trả `AdminEventResponse`. |
| `POST /admin/lessons/{id}/preview` | Backend ĐÃ CÓ; trả `LearnerLessonContent { lessonId, lessonVersionId:null, versionNo:null, content: JsonNode }` | `content` = projection của draft hiện tại — shape draft nhưng đã strip `validation`, `evidenceRefs`, `requiredEvidenceIds`, `LEARNER_HIDDEN_KEYS`. |
| `POST /admin/lessons/{id}/validate` | Backend ĐÃ CÓ; `PublishReadinessResponse { ready, errors[], warnings[], summary: Map<String,Object> }` | **`summary` là Map** — DTO hiện tại khai `summary?: string` (SAI, cần fix). Keys: `stageCount, activityCount, evidenceRefs, schemaVersion, errorCount, warningCount`. |
| `POST /admin/lessons/{id}/publish` | Backend ĐÃ CÓ; body `{expectedRowVersion?}` → `{lessonId, lessonVersionId, versionNo, status:"PUBLISHED", publishedAt}` | 422 `DRAFT_SCHEMA_INVALID` kèm `details.errors[]` (gồm `EVENT_NOT_PUBLISHED`); 409 `OPTIMISTIC_LOCK_CONFLICT`; 409 `INVALID_STATUS_TRANSITION` khi ARCHIVED. Republish được phép (version_no tăng). |
| `GET /api/v1/lessons/{id}/content` | ĐÃ CÓ — learner-safe, yêu cầu Bearer (mọi role). Dùng cho verify sau publish. | Qua `/api/proxy` như mọi admin call khác — path `/lessons/{id}/content` (không prefix `/admin`). |
| `PublishReadinessCard` | ĐÃ GỌI `/validate` | Cần: fix `summary` Map, phân tách errors/warnings rõ, nút "Đi tới chỉnh sửa" nhảy đến stage/activity (tái dùng `resolveErrorPath`). |
| Preview renderers | CHƯA CÓ | Cần tạo `features/lessons/preview/` — render projection content (đọc-only, không chấm điểm, không lộ đáp án). |
| Stub `scripts/e2e-backend-stub.mjs` | THIẾU: `events/{id}/publish`, `events/{id}/archive`, `lessons/{id}/preview`, `lessons/{id}/publish`, `lessons/{id}/versions*`, learner `GET /lessons/{id}/content` | Mở rộng stub trung thực (projection phải strip answer keys giống backend). |
| Unsaved-guard | `useUnsavedChangesGuard` đã chặn nav; preview/validate đọc **draft đã lưu** | Builder cần cảnh báo khi dirty: "Lưu và xem trước" hoặc "Bỏ qua — xem bản đã lưu". |
| `/versions` page | Chỉ empty-state | TASK-0017 giữ nguyên; chỉ link từ publish screen (không build A-15 đầy đủ). |

## Nguyên tắc

- KHÔNG bịa field (hint/attempts-limit không có trong schema → không emit).
- KHÔNG tự chấm điểm/không đánh giá câu trả lời trong preview — chỉ render.
- KHÔNG lộ answer keys (`correctOptionIds`, `correctPairs`, `expectedOrder`, `requiredEvidenceIds`, `expectedHypothesis`) — backend đã strip, client tin tưởng projection nhưng KHÔNG đọc draftJson trực tiếp cho preview.
- KHÔNG tạo file "enhanced" mới — update file hiện có.
- Type mới giữ <200 LOC/file.

## Phase list

| Phase | Nội dung | File | Effort |
|---|---|---|---|
| 01 | DTO fix + Event publish/archive buttons + stub events/{id}/publish + admin "publish event" UX + VN error khi DRAFT-event chặn lesson publish | [phase-01-event-publish.md](phase-01-event-publish.md) | 2h |
| 02 | Preview screen `/lessons/[id]/preview` — mobile frame, stage/activity nav, renderers cho 11 loại activity + honest placeholder | [phase-02-preview-screen.md](phase-02-preview-screen.md) | 4h |
| 03 | `PublishReadinessCard` fix — Map summary, errors vs warnings UI, "Đi tới chỉnh sửa" jump + stub `/validate` trả Map | [phase-03-validation-ux.md](phase-03-validation-ux.md) | 2h |
| 04 | Publish screen `/lessons/[id]/publish` — metadata + status + validate + actions; mutation `expectedRowVersion`; 409/422/DRAFT-event; cache invalidation; double-click protection; republish | [phase-04-publish-flow.md](phase-04-publish-flow.md) | 3h |
| 05 | Stub preview/publish/versions/learner-content + MSW + unit tests (renderers, validation, publish) + e2e journey Login→PublishEvent→Preview→Validate→Publish→Verify | [phase-05-tests.md](phase-05-tests.md) | 3h |

## Dependencies

- Phase 02 + 03 độc lập (có thể song song). Phase 04 phụ thuộc 03 (dùng `PublishReadinessCard`). Phase 01 độc lập. Phase 05 là cuối cùng, dùng stub mở rộng từ 01+02+04.

## File liên quan (tổng hợp)

**Modify:**
- `src/lib/dto/publish.ts` — `summary` Map + thêm `PublishResponse`, `LearnerLessonContent`
- `src/lib/dto/lesson.ts` — (tùy chọn) thêm `LessonVersionSummary` nếu cần
- `src/lib/query-keys.ts` — `qk.lessons.preview(id)`, `qk.lessons.versions(id)`, `qk.learner.content(id)`
- `src/lib/api-error.ts` — thêm VN mapping: `EVENT_NOT_PUBLISHED`, `INVALID_STATUS_TRANSITION`, `OPTIMISTIC_LOCK_CONFLICT`, `DRAFT_SCHEMA_INVALID`
- `src/features/events/event-editor-page.tsx` — nút Publish/Archive + status refresh
- `src/features/lessons/builder/publish-readiness-card.tsx` — Map summary, jump-to-edit, errors vs warnings UI
- `src/features/lessons/builder/builder-page.tsx` — link Preview + Publish, dirty-aware preview CTA
- `src/app/(admin)/lessons/[id]/page.tsx` — links tới preview/publish
- `src/components/breadcrumbs.tsx` — label `preview`, `publish`
- `scripts/e2e-backend-stub.mjs` — events publish/archive, lessons preview/publish/versions, learner `/content`
- `src/test/msw/*` — handlers + fixtures cho validate/preview/publish

**Create:**
- `src/app/(admin)/lessons/[id]/preview/page.tsx`
- `src/app/(admin)/lessons/[id]/publish/page.tsx`
- `src/features/lessons/preview/preview-page.tsx` — container
- `src/features/lessons/preview/mobile-frame.tsx` — khung 390px
- `src/features/lessons/preview/stage-view.tsx` — render stage + activity list + next/prev
- `src/features/lessons/preview/activity-renderer.tsx` — switch + dispatcher
- `src/features/lessons/preview/renderers/*.tsx` — 11 renderer (gộp 3-4 nhỏ/file để <200 LOC)
- `src/features/lessons/preview/unsupported-activity.tsx` — honest placeholder
- `src/features/lessons/publish/publish-page.tsx` — metadata + validate + publish button
- `src/features/lessons/publish/publish-button.tsx` — confirm + mutation + states
- `src/features/events/event-publish-button.tsx` — confirm + mutation

**Delete:** `.gitkeep` trong plan dir khi hoàn thành.

## Success criteria

- Admin publish event DRAFT → status refresh, list re-fetch, không publish ARCHIVED.
- Preview hiển thị learner-safe content từ `/preview` endpoint — không `validation`, không `correctOptionIds`, không `requiredEvidenceIds` của stage.
- Validate card show structured summary (`stageCount`, `activityCount`, ...); errors vs warnings phân biệt; click error nhảy đến stage/activity tương ứng.
- Publish flow: confirm → POST `{expectedRowVersion}` → success hiển thị `versionNo` + `publishedAt`; 409 conflict → reload prompt; 422 → hiển thị `details.errors[]`; event DRAFT → VN message rõ.
- Sau publish, `GET /api/v1/lessons/{id}/content` trả `versionNo` mới (verify qua admin-side fetch).
- Republish sau edit draft → `versionNo` tăng.
- Vitest + Playwright xanh; `tsc --noEmit`, `next lint`, `next build` pass.

## Câu hỏi mở

- **Preview path**: dùng `POST /admin/lessons/{id}/preview` (đã chọn) hay GET learner `/lessons/{id}/content`? → Preview vì đọc draft, learner-content chỉ sau publish. Cần gọi cả hai ở phase 04 (verify).
- **Version history page**: BA A-15 là route riêng `/lessons/{id}/versions`. TASK-0017 không build đầy đủ — chỉ nút link trong publish screen nếu có `currentVersionId`. Cần xác nhận phạm vi.
- **`expectedRowVersion` cho event publish**: backend `POST /events/{id}/publish` KHÔNG nhận body → không cần gửi; giữ đơn giản.
- **Stub `summary` shape**: khi chuyển sang Map, e2e cũ đang assert text "Chưa sẵn sàng xuất bản" — giữ text này trong card khi `ready=false` (không assert summary).
