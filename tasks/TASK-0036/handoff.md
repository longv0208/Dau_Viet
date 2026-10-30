# Handoff — TASK-0036 (Issue #47: Mặc định Bắt buộc & Phản hồi học viên mặc định trên `dau-viet-admin`)

## 1. Tóm tắt Kết quả
Đã hoàn thành toàn bộ 4 Phase theo kế hoạch `plans/261030-issue-47-default-required-and-feedback/plan.md`:
- **AC-1 (Loại bỏ tích chọn Bắt buộc/Tuỳ chọn — Mặc định Bắt buộc 100%):**
  - Chuẩn hóa `stage.required = true`, `activity.required = true`, `config.graded = true` (cho `EVIDENCE_SELECT`), và `completion.requireAllRequiredStages = true` trong `parseDraft`, `serializeDraft`, `makeStage`, `makeActivity`, `makeTemplateActivity` và `buildPresetJson`.
  - Xóa checkbox `"Bắt buộc hoàn thành"` và nhãn `"bắt buộc / tuỳ chọn"` trên `stage-navigator.tsx`, `stage-editor.tsx`, `shared-fields.tsx`, `evidence-select-editor.tsx`, `completion-editor.tsx`.
  - Trong `policy-editor.tsx`, `policy-list.tsx`, `policy-publish-dialog.tsx`: bỏ cột `"Bài học tuỳ chọn (optional)"`, tự động chọn sẵn toàn bộ bài học `PUBLISHED` khi tạo bản nháp mới, luôn gửi `optionalLessonIds: []`.
  - Trong `event-catalog.tsx`, `event-panel.tsx`, `path-versions.tsx`, `path-preview.tsx`, `learning-path/page.tsx`: mặc định gửi `participationType: "REQUIRED"` khi thêm sự kiện vào chương, gỡ bỏ dropdown chuyển đổi `"Tham khảo — không chặn tiến độ"` (`EXPLORATION_ONLY`) cùng nhãn và bộ đếm `"Tham khảo"`.
- **AC-2 & AC-3 (Phản hồi học viên mặc định & `FeedbackPanel`):**
  - Xây dựng `DEFAULT_FEEDBACK_BY_TYPE`, `defaultFeedbackForActivity(type)` và `withDefaultFeedback(type, existing)` trong `draft-model.ts` cung cấp câu phản hồi chuẩn văn phong Dấu Việt cho cả 13 `ActivityType` (đủ `COMPLETED`, `INCORRECT`, `PARTIAL`, `SUPPORTED`, `CONTRADICTED`, `EXHAUSTED` theo yêu cầu của `validateDraftLocally` và backend handlers).
  - Nâng cấp `FeedbackPanel` (`feedback-panel.tsx`): đổi tiêu đề phụ thành `(Đã có sẵn phản hồi mặc định — nhấn để xem hoặc chỉnh sửa)`, lọc đúng các trường phản hồi theo loại hoạt động, thêm nút **"Khôi phục mặc định"**, và tự động điền lại câu mặc định khi `onBlur` trên ô bị xóa trắng.
- **AC-4 (Tests & Verification):**
  - Cập nhật và bổ sung unit/integration tests trong `draft-model.test.ts`, `use-builder.test.ts`, `feedback-panel.test.tsx`, `builder-page.test.tsx`, `policy-editor.test.tsx` và tạo mới `learning-path.test.tsx`.

## 2. Kiểm chứng Thực tế (Verification Evidence)
- `npx vitest run src/features/lessons/builder/ src/features/events/workspace/gamification/ src/features/learning-path/ src/features/templates/` → **14/14 test files pass (78/78 tests pass)**.
- `npx tsc --noEmit` → **0 lỗi TypeScript** trên toàn bộ file sửa đổi/tạo mới.
- `git diff --check` → **sạch (0 lỗi whitespace/EOF)**.
- Independent Code Review (`Issue47CodeReviewer`) → **PASS (0 blockers, AC-1..AC-4 verified)**.

## 3. Hành động Tiếp theo
- Chờ người dùng kiểm tra và ủy quyền `git commit` / `git push` trên nhánh `feat/issue-47-default-required-and-feedback`.
