# Phase 05 — Kiểm thử Hồi quy Tự động & Chụp lại Bộ Minh chứng E2E (`360×800`, `390×844`, `430×932`)

## 1. Mục tiêu
Sau khi hoàn tất Phase 01 $\rightarrow$ Phase 04, thực thi toàn bộ cổng kiểm chứng tự động (Unit/Widget/Integration Test + Live Playwright E2E) để xác nhận mọi lỗi thị giác và nghiệp vụ đã được xử lý triệt để, không phát sinh hồi quy.

---

## 2. Các Bước Thực thi & Cổng Kiểm chứng (Verification Gates)

### Bước 1: Kiểm tra Định dạng & Phân tích Tĩnh toàn dự án (`AC-4`)
```bash
cd dau-viet-mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
```
- **Yêu cầu:** `0` file cần format lại; `flutter analyze --no-pub` toàn bộ repo trả về `No issues found!`.

### Bước 2: Mở rộng & Chạy Toàn bộ Widget / Integration Tests (`AC-3`)
- Cập nhật `dau-viet-mobile/test/learning/learning_flow_issue_29_test.dart` để bổ sung kiểm thử tự động cho các bản sửa lỗi của Phase 01–04:
  - Kiểm tra `ShimmerProgressBar` ở `progress = 0.0` vẫn có chiều rộng bằng `totalWidth` (không bị co về `0px`).
  - Kiểm tra `BattleSabanScreen` render ở `360×800` không lỗi `RenderFlex`.
  - Kiểm tra `CerChoiceRenderer` hiển thị khung `TỔNG HỢP LẬP LUẬN LỊCH SỬ (C–E–R)`.
  - Kiểm tra `LessonResultScreen` hiển thị tên bài học thật từ `LessonMetadataDto` và nút `TIẾP TỤC HÀNH TRÌNH`.
```bash
cd dau-viet-mobile
flutter test --no-pub
```
- **Yêu cầu:** 100% test suite vượt qua (`0 failures`).

### Bước 3: Build lại Flutter Web & Chạy Kịch bản Playwright E2E Thực tế (`AC-1`, `AC-3`, `AC-4`)
```bash
cd dau-viet-mobile
flutter build web --no-pub
python e2e/verify_issue_29_learning_flow_e2e.py
```
- **Yêu cầu:**
  - Chụp lại toàn bộ 17 ảnh chụp màn hình trên `390×844` và `360×800` tại `tasks/TASK-0029/screenshots/`.
  - Kiểm tra trực quan từng ảnh chụp màn hình:
    1. `stage1_dashboard_360x800.png`: Chữ không đè lên nón lá Kabi; thẻ bài học hiển thị tên bài học thật + tiến độ (không còn `'Giai đoạn: ctx'`).
    2. `stage2_lesson_entry_360x800.png`: Không còn nền lộ trình bị lỗi phía dưới nút CTA; hiển thị danh sách Stage tư duy.
    3. `stage3_lesson_player_360x800.png`: Thanh `ShimmerProgressBar` ở bước `0/3` hiển thị rõ toàn bộ chiều ngang; tiêu đề Stage không bị cắt cụt.
    4. `stage7_lesson_result_360x800.png`: Hiển thị đúng tên bài học vừa hoàn thành; linh vật ăn mừng không bị chữ cắt góc.
  - `tasks/TASK-0029/e2e_audit_report.json` ghi nhận `consoleErrorsCount: 0`, `pageErrorsCount: 0`, `overflowErrorsCount: 0`.
