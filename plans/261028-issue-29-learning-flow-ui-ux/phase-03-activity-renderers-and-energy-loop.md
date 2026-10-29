# Phase 03 — Nâng cấp 14 `ActivityRenderer` & Vòng lặp Thể lực (`Energy Loop`)

## 1. Bối cảnh & Danh mục Vấn đề Phát hiện
Từ báo cáo kiểm toán chuyên sâu 16 file trong `dau-viet-mobile/lib/features/learning/presentation/renderers/` (`ScoutActivityRenderers`), các điểm cần hoàn thiện thêm để đạt 100% tiêu chuẩn sư phạm và khả năng tiếp cận gồm:

| Mã | Renderer / File | Vấn đề cụ thể (Root Cause) | Ảnh hưởng UI/UX & TC |
|---|---|---|---|
| **P3-01** | `CerChoiceRenderer`<br>(`cer_choice_renderer.dart:123-214`) | Ba phần `1. CHỌN KẾT LUẬN (Claim)`, `2. CHỌN BẰNG CHỨNG HỖ TRỢ (Evidence)`, `3. CHỌN LẬP LUẬN (Reasoning)` hiện dùng chung một kiểu `SectionLabel` xám và chưa có **Khung tổng hợp kết luận lịch sử** cập nhật trực tiếp khi người học chọn từng thành phần theo `TC-ACT-17`. | Thiếu trực quan hóa cấu trúc lập luận sử học C–E–R (`TC-ACT-17`, `UX-01`). |
| **P3-02** | `LessonPlayerScreen`<br>(`lesson_player_screen.dart:345-395`) | Hộp thoại `_showEnergyDepletedDialog` khi gặp `409 ENERGY_DEPLETED` tính thời gian chờ `waitLine` tĩnh một lần tại thời điểm mở dialog, chưa tự động đếm ngược từng giây và chưa hiển thị đồng thời nhãn gợi ý ôn tập tư liệu rõ ràng (`TC-ENG-03`). | Trải nghiệm đếm ngược tĩnh khi chờ hồi Thể lực (`TC-ENG-03`). |
| **P3-03** | `MultipleChoiceRenderer` & `MatchingRenderer`<br>(`multiple_choice_renderer.dart:153-195`, `matching_renderer.dart:65-80`) | • `MultipleChoiceRenderer` (layout Đúng/Sai) chỉ đọc `Image.asset(imagePath)` mà chưa hỗ trợ tải ảnh qua `LearningAssetImage` khi snapshot bài học cấu hình `imageAssetId` / `assetId` từ backend.<br>• `MatchingRenderer` chỉ tra cứu 4 ảnh tĩnh theo tên nhân vật cố định mà chưa đọc `leftItem['imageAssetId']` / `leftItem['assetId']` từ snapshot. | Hạn chế khả năng tái sử dụng cho bài học mới do Admin xuất bản (`CODING_RULES.md` §1). |
| **P3-04** | `ViewImageRenderer` & `LearningAssetImage`<br>(`view_image_renderer.dart:68-73`, `learning_asset_image.dart:358-370`) | • Khi `submitting == true`, chạm vào ảnh trong `ViewImageRenderer` vẫn mở hộp thoại phóng to toàn màn hình.<br>• Nút `'Thử tải lại'` trong `_Fallback` của `LearningAssetImage` dùng `VisualDensity.compact` khiến chiều cao vùng chạm `< 44dp`. | Vi phạm `UX-03` (`>= 44×44dp`) và `UX-04` (khóa tương tác khi đang `submitting`). |
| **P3-05** | `CerRenderer`<br>(`cer_renderer.dart:64`) | `CerRenderer` lấy toàn bộ `widget.content.evidence` thay vì ưu tiên lọc theo `configIdList(config, 'visibleEvidenceIds')` khi bài học có cấu hình giới hạn danh sách bằng chứng hiển thị ở bước Kết luận. | Đồng bộ contract hiển thị bằng chứng với `EvidenceSelectRenderer` & `HypothesisRenderer`. |

---

## 2. Thiết kế Giải pháp Kỹ thuật

### 2.1. Bổ sung Huy hiệu Phân màu C–E–R & Khung Tổng hợp Kết luận (`cer_choice_renderer.dart`)
- Gắn huy hiệu màu sắc phân biệt rõ 3 trụ cột tư duy lịch sử:
  - **Luận điểm (`Claim`):** Đỏ chu sa (`DauVietColors.cinnabarRed`)
  - **Bằng chứng (`Evidence`):** Vàng ngự xưởng (`DauVietColors.imperialGold`)
  - **Lập luận (`Reasoning`):** Xanh di sản (`DauVietColors.heritageGreen`)
- Khi người học đã chọn ít nhất 1 thành phần, hiển thị thẻ **`TỔNG HỢP LẬP LUẬN LỊCH SỬ (C–E–R)`** trên nền giấy dó ghép nối trực tiếp câu Luận điểm + các Bằng chứng đã chọn + câu Lập luận trước nút `GỬI CÂU TRẢ LỜI` (`TC-ACT-17`).

### 2.2. Đồng hồ Đếm ngược Trực tiếp trong Hộp thoại Hết Thể lực (`lesson_player_screen.dart`)
- Tách nội dung hộp thoại `_showEnergyDepletedDialog` thành widget `_EnergyDepletedDialog` có `Timer.periodic(const Duration(seconds: 1), ...)` (tự hủy khi `dispose()` hoặc khi không có `nextRecoveryAt`) để đồng hồ đếm ngược `mm:ss` giảm trực tiếp trên màn hình (`TC-ENG-03`).

### 2.3. Hỗ trợ `LearningAssetImage` theo `assetId` cho `MultipleChoiceRenderer` & `MatchingRenderer`
- Trong `MultipleChoiceRenderer._buildTrueFalseLayout`: Kiểm tra `configText(config, ['imageAssetId', 'assetId'])` trước; nếu có thì render `LearningAssetImage(assetId: ..., tappable: !widget.submitting)`, nếu không mới fallback sang `Image.asset(imagePath)`.
- Trong `MatchingRenderer`: Truyền `imageAssetId: (leftItem['imageAssetId'] ?? leftItem['assetId']) as String?` vào `_LeftMatchCard` để hỗ trợ ảnh từ backend cho mọi sự kiện lịch sử mới.

### 2.4. Khóa `tappable` khi `submitting` trong `ViewImageRenderer` & Chuẩn hóa nút Retry `LearningAssetImage`
- Trong `ViewImageRenderer`: truyền `tappable: !submitting` vào `LearningAssetImage`.
- Trong `LearningAssetImage._Fallback`: đặt `minimumSize: const Size(120, 44)` cho nút `'Thử tải lại'`.

---

## 3. Tiêu chí Nghiệm thu Phase 03
- [ ] `CerChoiceRenderer` hiển thị 3 nhóm màu phân biệt cho `Claim`, `Evidence`, `Reasoning` và khung tổng hợp kết luận lịch sử khi người học chọn.
- [ ] Hộp thoại `Hết Thể lực` đếm ngược thời gian thực và tự dọn dẹp timer khi đóng.
- [ ] `ViewImageRenderer`, `MultipleChoiceRenderer`, `MatchingRenderer`, `CerRenderer` hỗ trợ đầy đủ `assetId` / `visibleEvidenceIds` từ snapshot và đạt chuẩn vùng chạm `>= 44×44dp`.
