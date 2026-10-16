# TASK-0015 — Báo cáo cuối: Stage & Activity Builder

- Ngày hoàn thành: 2026-10-17
- Phạm vi: `dau-viet-admin` — trình soạn bài học trực quan tại `/lessons/[id]/builder`
- Trạng thái: hoàn thành, toàn bộ gate xanh

## 1. Tóm tắt

Đã xây dựng đầy đủ trình soạn 3 pane (stage navigator | stage editor | inspector) cho phép Content Admin tạo/sửa/xoá/sắp xếp giai đoạn và hoạt động mà không cần viết JSON tay. Toàn bộ cấu trúc bài học đi qua `draftJson` với codec spread-through bảo toàn mọi trường chưa biết, lưu nguyên document qua `PUT /admin/lessons/{id}/draft` kèm `expectedRowVersion` (optimistic lock).

## 2. Contract backend đã xác minh

| Endpoint | Hành vi |
|---|---|
| `PUT /api/v1/admin/lessons/{id}/draft` | Body `{draftJson: string, expectedRowVersion?}`; 422 `DRAFT_SCHEMA_INVALID` kèm `details.errors[]{path,code,message}`; 409 `OPTIMISTIC_LOCK_CONFLICT` |
| `POST /api/v1/admin/lessons/{id}/validate` | Read-only, trả `{ready, errors[], warnings[], summary}` — đọc draft ĐÃ LƯU trên server |

- `STAGE_ALLOWED_ACTIVITIES` mirror y nguyên từ `DraftSchema` backend.
- ID theo pattern `^[a-z0-9][a-z0-9-]{1,63}$`, sinh bằng `crypto.getRandomValues` (slug, không UUID).
- Các khoá server-only (`correctOptionIds`, `multiCorrect`, `correctPairs`, `expectedOrder`, `requiredEvidenceIds`) được editor tự emit và gắn nhãn "không hiển thị cho học viên".

## 3. Thành phần đã triển khai

- `draft-model.ts` — interface Draft/Stage/Activity/Completion (index-signature bảo toàn trường lạ), `parseDraft` (tolerant: `"{}"` → stages rỗng, schemaVersion mặc định 1), `serializeDraft`, `allIds`.
- `use-builder.ts` — reducer giữ nguyên Draft; prune `nextStageIds` + `completion.requiredStageIds` khi xoá stage; `duplicateStage` re-id đệ quy với id-set cập nhật dần (đã sửa lỗi stale id mà reviewer bắt); `mergeStages` append cho template seeding.
- `stage-navigator.tsx`, `stage-editor.tsx`, `activity-picker.tsx` — 3 pane, lọc loại hoạt động theo `STAGE_ALLOWED_ACTIVITIES`, confirm xoá inline (Xoá/Giữ).
- `activity-editors/` — registry với editor riêng cho READ, VIEW_IMAGE, MULTIPLE_CHOICE, EVIDENCE_SELECT, MATCHING, DRAG_ORDER, CER, REFLECTION_PROMPT; `UnsupportedEditor` hiển thị trung thực cho loại chưa hỗ trợ. Toàn bộ editor giữ unknown keys ở cả cấp config lẫn cấp item (option/pair/item) bằng pattern `{...o, id, label}`.
- `completion-editor.tsx` — `requireAllRequiredStages` / `requiredStageIds` / `minScore` (guard NaN + giới hạn 0–100).
- `publish-readiness-card.tsx` — nút "Kiểm tra xuất bản" lazy POST /validate, phân biệt rõ SAVE (tolerant, lưu được draft dở) vs PUBLISH (cần ready).
- `validation-panel.tsx` — map `path` server → click nhảy tới stage/activity tương ứng.
- `template-seed-button.tsx` — parse `presetJson`, remap id 2 pass (stage + nextStageIds), `window.confirm`, append — không bao giờ thay thế ngầm.
- `builder-page.tsx` — parse draft trong `useMemo` (sửa lỗi `setParseError` trong useMemo mà reviewer bắt; `parseError` giờ đi từ return của useMemo), banner 409 conflict + nút reload, banner PUBLISHED (vẫn cho sửa, cảnh báo rõ), unsaved-changes guard.
- `lesson-basic-form.tsx` — nút "Mở trình soạn bài học".

## 4. Kết quả gate

| Gate | Lệnh | Kết quả |
|---|---|---|
| Type check | `npx tsc --noEmit` | Sạch, 0 lỗi |
| Lint | `npm run lint` (next lint) | 0 warning/error |
| Unit test | `npx vitest run` | 59/59 pass (14 files) |
| Build | `npm run build` | Thành công; route `/lessons/[id]/builder` 21.4 kB |
| E2E | `npx playwright test` | 8/8 pass (3 test builder + 5 test login/authoring) |

Test mới thêm theo đề xuất reviewer: banner conflict 409, banner PUBLISHED vẫn-cho-sửa, `mergeStages` unit test. Tổng builder: 23 test.

## 5. Minh bạch về môi trường kiểm thử

- E2E chạy với **stub backend có kiểm soát** (`scripts/e2e-backend-stub.mjs`, node:http) — KHÔNG phải backend Spring thật. Stub mô phỏng đủ contract: 409 khi `rowVersion` lệch, 422 `INVALID_CONFIG` khi MC thiếu câu hỏi/<2 options, `/validate` ready khi mọi stage bắt buộc có ≥1 activity bắt buộc.
- Smoke test với backend thật chưa thực hiện được (không có Docker/Postgres trên máy dev). Đây là khoảng trống kiểm chứng duy nhất — cần chạy tay một lần khi backend TASK-0005 chạy được.

## 6. Quyết định kiến trúc: server-as-validator

Không xây `draft-schemas.ts` (lớp zod client-side). Lý do: schema là của backend, backend đã trả lỗi chi tiết theo `path` qua 422 và `/validate`; duplicate schema phía client sẽ rơi vào trạng thái lệch khi backend đổi. Client chỉ validate tối thiểu những gì UI cần để không render sai (min options, NaN guards). Câu hỏi mở của reviewer được trả lời bằng quyết định này — ghi nhận là deliberate, không phải omission.

## 7. Việc còn lại (TASK-0016+)

- Trình chọn bằng chứng trực quan cho EVIDENCE_SELECT / `requiredEvidenceIds` (hiện nhập UUID thủ công + cảnh báo).
- Asset upload cho VIEW_IMAGE (ngoài phạm vi TASK-0015).
- Editor cho các loại còn lại trong `ACTIVITY_TYPES` (QUIZ_SCORED, TIMELINE_ORDER, CAUSE_EFFECT... hiện dùng UnsupportedEditor).
- Backend gap: `onPartial`/`onContradicted` trong feedback chưa có trường tương ứng — cần thảo luận với backend trước khi mở UI.
- Smoke test một lần với backend thật khi có môi trường.

## 8. Tham chiếu

- Plan: `dau-viet-admin/plans/261017-0531-task0015-stage-activity-builder/`
- Draft contract research: `dau-viet-admin/plans/reports/planner-261017-0531-task0015-draft-contract.md`
- Review: `plans/reports/reviewer-261017-task0015-builder-review.md` — verdict PASS (đã xử lý hết P2)
- E2E spec: `dau-viet-admin/tests/e2e/builder.spec.ts`
