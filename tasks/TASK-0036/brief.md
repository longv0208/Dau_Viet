# TASK-0036: Issue #47 — Mặc định Bắt buộc & Tự động điền sẵn Phản hồi học viên (`dau-viet-admin`)

## Mục tiêu
Giải quyết bài toán UX biên tập nội dung trên `dau-viet-admin` theo [Issue #47](https://github.com/longv0208/Dau_Viet/issues/47):
1. **Mặc định Bắt buộc 100% & bỏ các nút tích chọn Bắt buộc / Tuỳ chọn / Tham khảo:**
   - Mọi Giai đoạn (`stage.required = true`), Hoạt động (`activity.required = true`), Chấm điểm bằng chứng (`EVIDENCE_SELECT` `config.graded = true`), Điều kiện hoàn thành bài học (`requireAllRequiredStages = true`), Chính sách hoàn thành sự kiện (`optionalLessonIds = []`, tự động chọn tất cả bài học đã xuất bản khi tạo mới) và Sự kiện trên Bản đồ Dấu Ấn (`participationType = "REQUIRED"`) đều mặc định là bắt buộc.
   - Ẩn/gỡ bỏ toàn bộ checkbox, badge và dropdown chuyển đổi *Bắt buộc / Tuỳ chọn / Tham khảo* gây rườm rà và dễ dẫn tới lỗi chặn xuất bản.
2. **Tự động khởi tạo Phản hồi học viên mặc định (Default Feedback):**
   - Cung cấp hàm `defaultFeedbackForActivity(type)` và `withDefaultFeedback(type, existing)` với bộ câu phản hồi chuẩn văn phong Dấu Việt cho từng loại hoạt động (`COMPLETED`, `INCORRECT`, `PARTIAL`, `SUPPORTED`, `CONTRADICTED`, `EXHAUSTED`).
   - Tự động điền sẵn khi tạo hoạt động mới hoặc khi mở/lưu bản nháp thiếu phản hồi; nâng cấp `FeedbackPanel` với nhãn hướng dẫn mới, tự điền lại khi `blur` ô trống và nút **Khôi phục mặc định**.

## Kế hoạch chi tiết
Xem [`plans/261030-issue-47-default-required-and-feedback/plan.md`](../../plans/261030-issue-47-default-required-and-feedback/plan.md).

## Ánh xạ Kiểm chứng (AC → Check)
| AC | Kiểm tra | Kỳ vọng |
|---|---|---|
| AC-1 | Kiểm tra `stage-editor.tsx`, `stage-navigator.tsx`, `shared-fields.tsx`, `evidence-select-editor.tsx`, `completion-editor.tsx`, `policy-editor.tsx`, `event-catalog.tsx`, `event-panel.tsx`, `path-versions.tsx`, `path-preview.tsx` | Không còn checkbox/dropdown Bắt buộc vs Tuỳ chọn/Tham khảo; tất cả mặc định `required: true`, `graded: true`, `participationType: "REQUIRED"` |
| AC-2 | `draft-model.test.ts` + `use-builder.test.ts` | Mọi activity tạo mới hoặc parse từ draft đều có sẵn đầy đủ các trường `feedback` bắt buộc theo từng `ActivityType` |
| AC-3 | `feedback-panel.test.tsx` + `builder-page.test.tsx` | Tạo activity mới không cần mở `FeedbackPanel` vẫn vượt qua `validateDraftLocally`; mở `FeedbackPanel` có thể chỉnh sửa hoặc bấm "Khôi phục mặc định" |
| AC-4 | `npx tsc --noEmit` + `npx vitest run` | 0 lỗi TypeScript mới, 100% test suite pass |
