# Phase 02 — Khắc phục UI/UX `LessonEntryScreen` & `LessonPlayerScreen` Shell

## 1. Bối cảnh & Danh mục Vấn đề Phát hiện
Qua kiểm tra trực quan ảnh chụp màn hình E2E (`stage2_lesson_entry_360x800.png`, `stage3_lesson_player_360x800.png`, `stage6_reload_continuity_390x844.png`) và rà soát code:

| Mã | Màn hình / File | Vấn đề cụ thể (Root Cause) | Ảnh hưởng UI/UX & TC |
|---|---|---|---|
| **P2-01** | `ShimmerProgressBar`<br>(`shimmer_progress_bar.dart:61-101`) | `Container(height: widget.height)` bên ngoài `ShimmerProgressBar` **không khai báo `width: double.infinity`**, và `Stack` bên trong có `fit: StackFit.loose` với phần tử con duy nhất là `Container(width: fillWidth)`. Khi bài học ở bước `0/N` (`progress = 0.0` $\Rightarrow$ `fillWidth = 0`), toàn bộ thanh tiến trình bị co rút về chiều ngang **`2.4px`** (chỉ còn một vạch dọc nhỏ xíu dưới tiêu đề Stage trên ảnh `stage3_lesson_player_360x800.png`). | Lỗi hiển thị nghiêm trọng ở đầu mọi bài học (`TC-PLAYER-01`, `UX-02`). |
| **P2-02** | `LessonPlayerScreen`<br>(`lesson_player_screen.dart:886-969`) | Trong `_buildTopBar`, tiêu đề Stage (`cur.stage?.title`) nằm chung một hàng `Row` với `_EnergyBadge`, `_StreakBadge`, và chip bước `0/3`. Trên màn hình nhỏ `360×800`, tiêu đề Stage chỉ còn ~`95px` chiều ngang nên bị cắt cụt thành `'Bối cảnh lịc...'`. | Vi phạm `UX-02` (*"Không bị cắt chữ tiêu đề Stage/Bài học mất ý nghĩa"*), `TC-PLAYER-01`. |
| **P2-03** | `LessonEntryScreen`<br>(`lesson_entry_screen.dart:170-185`) | Ảnh nền chân trang `assets/images/ancient_village_footer.png` thực chất là một ảnh chụp màn hình lộ trình dọc (có số `6`, `7` trong vòng tròn xanh và khung thẻ trắng), bị lộ rõ phía sau nút `'TIẾP TỤC BÀI HỌC ›'` trên ảnh `stage2_lesson_entry_360x800.png`. | Lỗi asset gây nhiễu thị giác (`UX-01`, `UX-02`). |
| **P2-04** | `LessonEntryScreen`<br>(`lesson_entry_screen.dart:23-34, 188-324`) | `LessonEntryScreen` mới chỉ gọi `getLessonMetadata` mà chưa hiển thị danh sách các **Stage tư duy lịch sử** của bài học (`TC-NAV-08`: *"Hiển thị đầy đủ: Tiêu đề bài học, Câu hỏi lịch sử trung tâm nổi bật trên thẻ giấy dó, danh sách các Stage tư duy"*). | Thiếu thông tin cấu trúc bài học theo `TC-NAV-08`. |
| **P2-05** | `KabiMascotWidget`<br>(`kabi_mascot_widget.dart:107-110`) | Khi Rive `kabi.riv` tải trên Web với `_colorInput?.value = 2` và `_headOnlyInput?.value = true`, nhân vật Rive hiển thị lệch xuống nửa dưới của vòng tròn avatar trong `MascotSpeechBubble`. | Giảm tính thẩm mỹ di sản (`UX-01`, `TC-PLAYER-02`). |
| **P2-06** | `LessonHeaderTopBar`<br>(`lesson_header_top_bar.dart:1-183`) | Widget `LessonHeaderTopBar` không được sử dụng ở bất kỳ đâu (dead code) do `LessonPlayerScreen` tự định nghĩa `_buildTopBar`. | Dead code cần dọn dẹp hoặc hợp nhất. |

---

## 2. Thiết kế Giải pháp Kỹ thuật

### 2.1. Sửa dứt điểm lỗi co rút `ShimmerProgressBar` ở tiến độ `0%` (`shimmer_progress_bar.dart`)
- Thêm `width: double.infinity` vào `Container` gốc của `ShimmerProgressBar` và đặt `Stack(fit: StackFit.expand, ...)` hoặc thêm `SizedBox(width: totalWidth, height: widget.height)` bên trong `Stack` để đường ray nền (`trackColor`) luôn trải dài 100% chiều ngang ngay cả khi `progress == 0.0`:
```dart
return Container(
  width: double.infinity,
  height: widget.height,
  decoration: BoxDecoration(
    color: widget.trackColor,
    borderRadius: radius,
    border: Border.all(
      color: DauVietColors.outlineVariant.withValues(alpha: 0.6),
      width: 1.2,
    ),
  ),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: clampedProgress),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          final fillWidth = totalWidth * animatedProgress;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              SizedBox(width: totalWidth, height: widget.height),
              if (fillWidth > 0)
                Container(
                  width: fillWidth,
                  height: widget.height,
                  ...
```

### 2.2. Tối ưu bố cục `_buildTopBar` trong `LessonPlayerScreen` cho màn hình `360×800`
- Đảm bảo tiêu đề Stage (`Bối cảnh lịch sử`, `Điều tra chứng cứ & Đánh giá`, v.v.) có không gian hiển thị rộng rãi, không bị cắt cụt mất chữ trên `360×800` bằng cách thu gọn khoảng đệm giữa các badge (`_EnergyBadge`, `_StreakBadge`, `0/3`) và cho phép tiêu đề chiếm trọn chiều ngang hoặc hiển thị gọn.

### 2.3. Thay thế Footer lỗi & Bổ sung Danh sách Stage tư duy trên `LessonEntryScreen`
- Thay `assets/images/ancient_village_footer.png` (ảnh bị nhầm thành screenshot roadmap) bằng `assets/images/lotus_footer.png` (họa tiết hoa sen chân trang chuẩn dùng ở `AuthScreen`).
- Bổ sung hiển thị danh sách các Stage tư duy lịch sử của bài học (lấy từ `LessonContentDto.stages` hoặc fallback khung tư duy) dưới dạng các bước đánh số trang nhã trên thẻ giấy dó (`TC-NAV-08`).

---

## 3. Tiêu chí Nghiệm thu Phase 02
- [ ] Khi vào bài học ở bước `0/N`, thanh `ShimmerProgressBar` hiển thị đầy đủ chiều ngang 100% trên cả `360×800` và `390×844`.
- [ ] Tiêu đề Stage `'Bối cảnh lịch sử'` hiển thị trọn vẹn chữ trên màn `360×800` (không còn bị cắt thành `'Bối cảnh lịc...'`).
- [ ] `LessonEntryScreen` không còn ảnh lộ trình bị lỗi phía dưới nút bấm và hiển thị rõ các bước/stage tư duy lịch sử.
