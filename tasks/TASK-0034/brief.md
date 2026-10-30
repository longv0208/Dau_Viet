# TASK-0034 — Issue #43: Làm rõ UX & cơ chế bước Thu thập bằng chứng (`EVIDENCE_SELECT`)

## Bối cảnh & Vấn đề

Issue #43 phản ánh người học và quản trị viên đều khó hiểu mục tiêu và cơ chế của hoạt động `EVIDENCE_SELECT`:
1. **Copy mâu thuẫn trên Mobile**: Eyebrow luôn in `"THU THẬP DẤU VẾT · CHỌN ÍT NHẤT {minRequired}"` trong khi chế độ `graded:true` chấm exact-set theo `acceptedEvidenceIds` (F1 score) và instruction của bài học yêu cầu chọn đủ các nhóm dấu vết cốt lõi.
2. **Vùng chạm (tap zone) gây nhầm**: Subtitle ghi *"Chạm vào thẻ để xem chi tiết; chạm dấu tích để chọn"*, nhưng thực tế chạm vào thân thẻ lại toggle chọn, còn xem chi tiết chỉ mở qua link nhỏ.
3. **Thiếu phản hồi học tập sau khi nộp**: Khi chọn sai/thiếu ở chế độ `graded:true`, học viên chỉ thấy `"Đúng k/n"` hoặc không thấy gì nếu chỉ có `score`, không biết thẻ nào mình đã chọn là đúng hay sai.
4. **Thanh tiến độ thiếu nhãn**: Chip tiến độ chỉ hiện `"2/6"` không rõ đơn vị.
5. **Phía Admin thiếu giải thích cơ chế**: `EvidenceSelectEditor` khoá cứng `graded = true` và thiếu hướng dẫn khi nào dùng chế độ Thu thập tự do (`COLLECT`, `graded:false` — hậu quả kiểm chứng ở bước `VERIFICATION`) so với Đánh giá (`ASSESS`, `graded:true` — chấm F1 ngay + trừ Thể lực), cũng như ý nghĩa của `minRequired`, `maxAttempts`, `remedialAttempts`.

## Kế hoạch

Xem chi tiết tại `plans/261030-issue-43-evidence-select-ux/plan.md`.

## Mapping AC → Kiểm chứng

| AC | Nội dung | Kiểm chứng |
|---|---|---|
| AC-1 | Copy header/subtitle theo chế độ `COLLECT` / `ASSESS`, không mâu thuẫn | `evidence_select_renderer_test.dart` |
| AC-2 | Chạm thân thẻ mở bottom sheet chi tiết; nút Chọn/Bỏ chọn riêng; nhắc khi đạt `maxSelect` | `evidence_select_renderer_test.dart` |
| AC-3 | Backend phát `selectedVerdicts` (chỉ trên các id đã nộp, không lộ đáp án bị sót) + Mobile hiển thị đúng/sai trên từng thẻ đã chọn & `InlineGradingHint` | `SelectionHandlersTest.java`, `evidence_select_renderer_test.dart` |
| AC-4 | Nhãn tiến độ `"Bước x/y"` trên `LessonPlayerScreen` | `lesson_player_test.dart`, `learning_flow_issue_29_test.dart` |
| AC-5 | Admin `EvidenceSelectEditor` mở chọn 2 chế độ COLLECT/ASSESS + hướng dẫn chi tiết + Learner Preview + cảnh báo distractor/validation | `evidence-select-editor.test.tsx` |
| AC-6 | Cập nhật `docs/LEARNING_ENGINE_DESIGN.md` và chạy pass toàn bộ test gates | Maven, Vitest/TSC, Flutter analyze & test |
