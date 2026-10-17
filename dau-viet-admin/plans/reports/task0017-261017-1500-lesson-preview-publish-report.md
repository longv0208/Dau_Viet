# TASK-0017 — Báo cáo cuối: Lesson Preview, Validation & Publishing

Ngày: 2026-10-17 · Module: `dau-viet-admin` · Trạng thái: hoàn thành

## 1. Admin làm được gì end-to-end

Luồng đầy đủ đã chạy được trên stub e2e (mirror 1:1 contract backend Spring Boot):

1. Mở sự kiện DRAFT → bấm "Xuất bản sự kiện" → confirm → event chuyển PUBLISHED.
2. Tạo bài học qua wizard → soạn nội dung trong Builder → "Lưu nháp".
3. "Xem trước" → trang `/lessons/{id}/preview` render bản nháp ĐÃ LƯU trong khung điện thoại 390px, điều hướng theo giai đoạn/hoạt động, không chấm điểm.
4. "Kiểm tra xuất bản" → POST `/admin/lessons/{id}/validate` → thẻ sẵn sàng hiển thị summary có cấu trúc + danh sách lỗi chặn / cảnh báo; bấm vào lỗi nhảy tới stage/activity trong Builder.
5. "Xuất bản" → trang `/lessons/{id}/publish` → confirm → POST publish với `expectedRowVersion` → panel thành công hiển thị `versionNo`, `publishedAt`, `lessonVersionId` thật.
6. "Kiểm tra nội dung learner" → GET `/api/v1/lessons/{id}/content` (đúng endpoint Flutter sẽ gọi) → xác nhận `versionNo` đang phát hành.
7. Sửa nháp của bài học đã PUBLISHED → "Xuất bản phiên bản mới" → `versionNo` tăng 1 → 2; snapshot cũ bất biến.

Nút Xuất bản sự kiện nằm trên trang sửa sự kiện (`event-editor-page`), chỉ hiển thị khi event ở DRAFT.

## 2. Preview hoạt động với loại nào

Renderer đầy đủ cho 11 loại hoạt động (xem `src/features/lessons/preview/renderers/`):

- READ — đoạn văn tách `\n\n`.
- VIEW_IMAGE — ảnh từ asset (blob URL) + caption.
- MULTIPLE_CHOICE — radio/checkbox theo `multiSelect`; không bao giờ đánh dấu đáp án đúng.
- EVIDENCE_SELECT — chip chọn bằng chứng + ghi chú `minRequired`.
- MATCHING — hai cột trái/phải.
- DRAG_ORDER — sắp xếp lên/xuống phía client.
- HYPOTHESIS_CHOICE — chọn giả thuyết.
- REASONING_CONNECT — node + chip quan hệ cho phép.
- VERIFICATION — nguồn + radio Củng cố / Củng cố một phần / Bác bỏ.
- CER — claim/evidence/reasoning + tiêu chí rubric.
- REFLECTION_PROMPT — prompt + textarea.

Loại chưa hỗ trợ (ví dụ EXPLORE_MAP) hiển thị placeholder trung thực: tên type + JSON config, không giả lập UI.

Preview đọc `content` từ `POST /admin/lessons/{id}/preview` — projection đã strip `correctOptionIds`, `correctPairs`, `expectedOrder`, `requiredEvidenceIds`, `expectedHypothesis`, `answerKey`, `validation`, `evidenceRefs` phía server; renderer không đọc trường đáp án nên không có key nào lọt vào DOM (đã assert trong test).

## 3. Giới hạn có chủ đích

- Preview chỉ-đọc: không chấm điểm, không submit, không ghi attempt.
- Preview/validate luôn dùng bản nháp ĐÃ LƯU trên server — toolbar hiển thị "Xem trước (bản đã lưu)" + banner khi có thay đổi chưa lưu; nút nhảy tới lỗi tắt trong lúc dirty để tránh nhảy sai.
- Không có UI lịch sử phiên bản (chỉ hiển thị `currentVersionId` + verify), không màn Flutter, không refactor auth.
- EXPLORE_MAP giữ placeholder cho tới khi backend chốt schema marker.

## 4. Publish / republish

- `POST /admin/lessons/{id}/publish` gửi `{ expectedRowVersion }`; nút bị khóa trong lúc pending (chống double-click), dialog confirm giải thích tính bất biến của phiên bản.
- 409 `OPTIMISTIC_LOCK_CONFLICT` → banner "đã bị sửa đồng thời" + nút "Tải lại bản mới nhất".
- 422 `DRAFT_SCHEMA_INVALID` → panel liệt kê `details.errors[]` (path + code + message); lỗi `EVENT_NOT_PUBLISHED` render thêm đoạn "Sự kiện lịch sử chưa được xuất bản" kèm link `/events/{eventId}` để xuất bản sự kiện trước; luôn có nút "Đi tới chỉnh sửa".
- ARCHIVED → thông báo tĩnh, không nút publish. PUBLISHED → label "Xuất bản phiên bản mới".

## 5. Nội dung learner truy cập được

`VerifyContentCard` gọi `GET /api/v1/lessons/{id}/content` (Bearer, không `/admin`) và hiển thị "Phiên bản N đang phát hành — truy cập learner OK" + `lessonVersionId` + số giai đoạn. 404 `LESSON_NOT_PUBLISHED` map sang thông báo tiếng Việt.

## 6. Kết quả test thực tế

- `npx tsc --noEmit` — sạch.
- `npm run lint` — sạch (1 warning `next lint` deprecated của Next 15, không phải lỗi code).
- `npm run build` — pass, có route `/lessons/[id]/preview` + `/lessons/[id]/publish`.
- `npx vitest run` — 101/101 test, 24 file. Mới: `preview-renderers.test.tsx` (5), `publish-page.test.tsx` (4), `publish-readiness-card.test.tsx` (3), `event-publish-button.test.tsx` (2).
- `npx playwright test` — 13/13 pass (1 worker). `publish-journey.spec.ts` mới cover cả hai kịch bản:
  - event publish → preview (không lộ answer key) → validate → publish v1 → verify learner → sửa nháp → republish v2.
  - event DRAFT → validate báo `EVENT_NOT_PUBLISHED` → publish trả 422 → thông báo VN + link trang sự kiện + link chỉnh sửa.

Lưu ý: stub e2e (`scripts/e2e-backend-stub.mjs`) mở rộng mirror `LearnerProjectionService` (LEARNER_HIDDEN_KEYS/ACTIVITY_SERVER_ONLY/STAGE_SERVER_ONLY/ACTIVITY_HIDDEN_TOP), bảng `lessonVersions` ảo, rule publish (event phải PUBLISHED, required stage cần required activity, 409/422 đúng contract) — cần giữ đồng bộ khi backend đổi rule.

## 7. Blocker trước khi Flutter

- Chưa smoke test trên Spring Boot thật (cần Docker/Postgres local theo `docs/backend-runbook.md`); stub đã mirror contract nhưng không thay thế verify thật.
- Attempt/submission API và scoring engine phía learner chưa tồn tại — preview hiện tại không phản ánh luồng làm bài.
- EXPLORE_MAP chưa có schema chốt.

## 8. Đề xuất TASK-0018

Flutter learner: đọc `GET /api/v1/lessons/{id}/content` + `GET /api/v1/assets/{id}/content`, render các activity type đã có preview, luồng attempt/submit idempotent pin vào `lessonVersionId` theo `docs/LEARNING_ENGINE_DESIGN.md`; kèm smoke test publish journey trên backend thật.
