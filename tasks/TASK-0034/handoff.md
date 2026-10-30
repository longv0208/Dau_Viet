# TASK-0034 — Handoff: Issue #43 (`EVIDENCE_SELECT` UX & Mechanism)

## 1. Tóm tắt thay đổi

### 1.1 Backend (`dau-viet-backend`)
- `SelectionHandlers.java` (`EvidenceSelectHandler.evaluateGraded`):
  - Bổ sung trường additive `selectedVerdicts` vào `output`: map từng `id` học viên **đã nộp** sang `"correct"` hoặc `"incorrect"`.
  - Tuyệt đối không đưa các `id` thuộc `acceptedEvidenceIds` mà học viên chưa chọn vào `selectedVerdicts` (không lộ đáp án).
  - Khi vượt quá ngân sách (`overBudget == true`, Policy B), giữ nguyên `selectedVerdicts` đã khóa của lượt cuối trong ngân sách — chặn việc thử dò đáp án sau khi đã hết lượt.
  - Ở chế độ `COLLECT` (`graded:false`), không phát `selectedVerdicts`.
- `SelectionHandlersTest.java`:
  - Thêm kiểm chứng `selectedVerdicts` chỉ chứa id đã nộp, không lộ id bị bỏ sót (`e2`), không lộ `acceptedEvidenceIds`.
  - Thêm test `evidenceSelect_ungraded_doesNotEmitSelectedVerdicts` và `evidenceSelect_overBudget_doesNotLeakNewVerdicts`.

### 1.2 Web Admin (`dau-viet-admin`)
- `evidence-select-editor.tsx`:
  - Thêm khung **Hướng dẫn cơ chế hoạt động Chọn bằng chứng (`EVIDENCE_SELECT`)** giải thích rõ cách `selectedEvidenceIds` chuyển tiếp sang bước Đặt giả thuyết (`HYPOTHESIS_CHOICE`), Kiểm chứng (`VERIFICATION`) và Kết luận (`CER_CHOICE`).
  - Thay checkbox khoá cứng bằng 2 Radio Card chọn chế độ:
    1. **Thu thập bằng chứng (không chấm điểm — `COLLECT`, `graded:false`)**: học viên chọn tự do `≥ minRequired`, không trừ Thể lực; hậu quả kiểm chứng ở bước `VERIFICATION` phía sau (khi chuyển sang chế độ này sẽ tự động dọn sạch `acceptedEvidenceIds`, `maxAttempts`, `remedialAttempts`).
    2. **Đánh giá bằng chứng (chấm điểm — `ASSESS`, `graded:true`)**: học viên chọn đúng tập `acceptedEvidenceIds` (chấm F1, trừ Thể lực khi sai, giới hạn `maxAttempts` + `remedialAttempts`).
  - Nâng cấp chú thích từng trường (`visibleEvidenceIds`, `acceptedEvidenceIds`, `maxAttempts`, `remedialAttempts`, `minRequired`).
  - Thêm kiểm tra lỗi tại chỗ khi `acceptedEvidenceIds ⊄ visibleEvidenceIds` và cảnh báo thiết kế khi `acceptedEvidenceIds.length === visibleEvidenceIds.length` (chưa có dấu vết bẫy / distractor).
  - Thêm khung **Xem trước trải nghiệm học viên trên ứng dụng (`Learner Preview`)** cập nhật động theo cấu hình.
- `draft-local-validator.ts`:
  - Cho phép lưu/xuất bản `EVIDENCE_SELECT` ở cả chế độ `COLLECT` (`graded:false`) lẫn `ASSESS` (`graded:true`); ở chế độ `COLLECT` chỉ bắt buộc feedback `COMPLETED`.
- `evidence-select-editor.test.tsx`:
  - 4 unit/component tests kiểm tra hướng dẫn, chuyển chế độ `ASSESS → COLLECT`, cảnh báo tập con/distractor, và `validateDraftLocally`.

### 1.3 Mobile (`dau-viet-mobile`)
- `attempt_dtos.dart` (`EvaluationDto`):
  - Thêm getters `score`, `correctCount`, `falseCount`, `budgetExhausted`, `selectedVerdicts`.
- `evidence_select_renderer.dart`:
  - Eyebrow & subtitle phân nhánh rõ theo chế độ:
    - `COLLECT` (`graded:false`): `"THU THẬP DẤU VẾT · CHỌN ÍT NHẤT {minRequired}"` + subtitle xác nhận không mất Thể lực.
    - `ASSESS` (`graded:true`): `"THU THẬP DẤU VẾT · CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN"` + subtitle hiện chi phí Thể lực (`incorrectPenalty`) và số lượt thử/sửa còn lại.
  - Tách vùng chạm trên `_EvidenceCard`: chạm thân thẻ mở bottom sheet `_EvidenceDetailSheet`; chỉ nút `Chọn`/`Đã chọn` riêng biệt ở cạnh phải (hoặc nút trong sheet) mới toggle chọn.
  - Hiển thị thông báo khi người học chạm chọn vượt quá `maxSelect`.
  - Hiển thị nhãn `✓ Đúng dấu vết liên quan` / `✗ Chưa liên quan câu hỏi` và viền màu tương ứng trên các thẻ đã nộp theo `selectedVerdicts`.
- `renderer_base.dart` (`InlineGradingHint`):
  - Hỗ trợ hiển thị số dấu vết đúng/sai (`correctCount`/`falseCount`), `score` phần trăm và trạng thái `Đã hết lượt — bước này được tính hoàn thành` khi `exhausted`/`budgetExhausted`.
- `lesson_player_screen.dart`:
  - Đổi nhãn tiến độ thành `"Bước {completedRequired}/{totalRequired}"` (bọc `ConstrainedBox` + `FittedBox` để không làm hẹp `StepProgressBar` trên màn 360px).
- `evidence_select_renderer_test.dart`:
  - 6 widget tests mới bao phủ đầy đủ AC-1..AC-4.

### 1.4 Tài liệu (`docs/`)
- Cập nhật `docs/LEARNING_ENGINE_DESIGN.md` (§13.1 & §14 Open decisions).

## 2. Kết quả kiểm chứng

| Module | Lệnh | Kết quả |
|---|---|---|
| Backend | `mvn test -Dtest=SelectionHandlersTest,HandlerSafetyTest,LearnerAttemptServiceTest` | **50/50 pass** |
| Admin | `npx vitest run --testTimeout=20000 src/features/lessons/ src/features/templates/` | **17/17 files, 96/96 tests pass** |
| Mobile Analyze | `flutter analyze` | **0 lỗi mới** (9 warnings pre-existing ở `features/island/`) |
| Mobile Tests | `flutter test test/learning/` | **309/309 pass** (gồm 6 test mới trong `evidence_select_renderer_test.dart`) |
| Git Diff | `git diff --check` | **Clean** |

## 3. Hành động tiếp theo

Chờ người dùng review và ủy quyền commit/push.
