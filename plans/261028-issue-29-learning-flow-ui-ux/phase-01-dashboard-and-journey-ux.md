# Phase 01 — Khắc phục UI/UX Trang chủ (`/dashboard`), Lộ trình Thời kỳ (`/journey`) & Sa bàn (`/saban`)

## 1. Bối cảnh & Danh mục Vấn đề Phát hiện
Qua kiểm toán mã nguồn (`ScoutEntryPlayerResult`) và đối chiếu trực tiếp ảnh chụp màn hình E2E (`stage1_dashboard_360x800.png`, `stage1_period_selection_360x800.png`, `stage1_period_journey_360x800.png`), các vấn đề cụ thể ở Chặng 1 gồm:

| Mã | Màn hình / File | Vấn đề cụ thể (Root Cause) | Ảnh hưởng UI/UX & TC |
|---|---|---|---|
| **P1-01** | `LearnerDashboardScreen`<br>(`learner_dashboard_screen.dart:332-498`) | Trong `_buildHeroBanner`: Ảnh `assets/images/turtle_map.png` đặt `Positioned(right: -8, bottom: -6, width: 175, height: 175)` trong khi khối chữ bên trái chiếm `padding: EdgeInsets.fromLTRB(18, 16, 12, 16)` không giới hạn `right` padding theo chiều rộng linh vật. Trên màn `360×800` và `390×844`, dòng phụ đề *"Tiếp tục ngay tại hoạt động đã dừng lại trước đó"* đè trực tiếp lên nón lá và khuôn mặt Rùa Kabi. | Vi phạm `UX-01` (Tương phản chữ), `UX-02` (Zero Overlap), `TC-NAV-01`, `TC-NAV-02`. |
| **P1-02** | `LearnerDashboardScreen`<br>(`learner_dashboard_screen.dart:540-615`) | Trong `_buildTodayLessonSection`: Khi người học có bài đang làm dở (`inProgress.isNotEmpty`), thẻ bài học hiển thị cứng chuỗi `'Bài học đang tiếp diễn'` (bị cắt thành `'Bài học đang tiếp di...'` trên `360px`) thay vì tên bài học thật, và hiển thị mã kỹ thuật thô `'Giai đoạn: ${inProgress.currentStageId}'` (ví dụ: `'Giai đoạn: ctx'`) thay vì tên Stage tiếng Việt hoặc tiến độ phần trăm + huy hiệu `'Đang học'`. | Vi phạm `UX-01`, `TC-NAV-02`. |
| **P1-03** | `LearnerDashboardScreen`<br>(`learner_dashboard_screen.dart:181-260, 1377-1454`) | • `_EnergyMiniPill` & `_StreakMiniPill` cao ~`26dp` (`< 44×44dp`), dùng emoji text `'⚡'` / `'🔥'` thay vì `Icon`, thiếu `Semantics`.<br>• Nút chuông thông báo (`38×38dp`) và Avatar (`40×40dp`) nhỏ hơn chuẩn vùng chạm `44×44dp` và thiếu `tooltip` / `Semantics`. | Vi phạm `UX-01`, `UX-03`, `TC-VIS-04`. |
| **P1-04** | `PeriodSelectionScreen` & `PeriodJourneyScreen`<br>(`period_selection_screen.dart:447-622`, `period_journey_screen.dart:480-642`) | • Thẻ Thời kỳ đang ở trạng thái `LOCKED` chưa hiển thị dòng giải thích lý do khóa (cần hoàn thành thời kỳ nào trước) theo `TC-NAV-03`.<br>• Trong `PeriodJourneyScreen`, các dòng bài học con chưa hiển thị huy hiệu phân biệt `Bắt buộc` (`REQUIRED`) vs `Tùy chọn` (`OPTIONAL`) (`ParticipationTypeBadge`), và khi chạm vào bài học đang `LOCKED` chưa bật thông báo rõ cần hoàn thành bài học bắt buộc nào trước (`TC-NAV-04`, `TC-NAV-05`). | Vi phạm `TC-NAV-03`, `TC-NAV-04`, `TC-NAV-05`. |
| **P1-05** | `BattleSabanScreen`<br>(`battle_saban_screen.dart:75-122`) | Thanh nút đáy dùng `Row` chứa `Expanded(child: DongSonButton(...))` cạnh một `DongSonButton(label: 'Bàn Học')` không bọc `Expanded` và không truyền `width` (mặc định `DongSonButton.width = double.infinity`), gây lỗi `RenderFlex` unbounded width ngay khi render. | Lỗi crash layout (`TC-NAV-07`, `TC-VIS-01`, `AC-4`). |

---

## 2. Thiết kế Giải pháp Kỹ thuật

### 2.1. Sửa đè chữ trên Hero Banner & Thẻ "Bài học hôm nay" (`learner_dashboard_screen.dart`)
- **Hero Banner (`_buildHeroBanner`):**
  - Chuyển `height: 195` cố định thành `constraints: const BoxConstraints(minHeight: 195)` để không tràn dọc khi font scale lớn.
  - Dành `padding: const EdgeInsets.fromLTRB(18, 16, 136, 16)` cho cột văn bản bên trái (nhường `136px` bên phải cho linh vật Kabi) kết hợp lớp gradient nền giấy dó đậm hơn (`alpha: 0.96 -> 0.82 -> 0.15`), đảm bảo chữ không bao giờ đè lên nón lá của Kabi trên màn `360×800`.
- **Thẻ "Bài học hôm nay" (`_buildTodayLessonSection`):**
  - Tra cứu tên bài học thật từ `learningPathProvider` (`path.findLessonById(inProgress.lessonId)?.title`) hoặc `lessonMetadataProvider`, fallback về `'Bài học đang học dở'`.
  - Thay `'Giai đoạn: ${inProgress.currentStageId}'` (mã kỹ thuật `ctx`) bằng nhãn thân thiện: `'Đang học • Đã hoàn thành ${inProgress.progress.completedRequired}/${inProgress.progress.totalRequired} hoạt động (${(inProgress.progress.fraction * 100).round()}%)'` kèm huy hiệu trạng thái `'Đang học'`.

### 2.2. Chuẩn hóa Vùng chạm `>= 44×44dp` & Icon Hệ thống (`learner_dashboard_screen.dart`)
- Thay `Text('⚡')` và `Text('🔥')` trong `_EnergyMiniPill` / `_StreakMiniPill` bằng `Icon(Icons.bolt_rounded)` và `Icon(Icons.local_fire_department_rounded)`.
- Bọc `_EnergyMiniPill`, `_StreakMiniPill`, nút thông báo và avatar trong `Semantics(button: true, label: ...)` với `ConstrainedBox(constraints: const BoxConstraints(minWidth: 44, minHeight: 44))`.

### 2.3. Hiển thị Lý do khóa Thời kỳ & Bài học (`period_selection_screen.dart`, `period_journey_screen.dart`)
- Trên `PeriodSelectionScreen`: Khi `status == LearnerPathStatus.locked`, hiển thị dòng phụ đề nhỏ màu `DauVietColors.inkMuted` kèm icon khóa: `'Hoàn thành thời kỳ trước để mở khóa'`.
- Trên `PeriodJourneyScreen`:
  - Hiển thị `ParticipationTypeBadge` (`Bắt buộc` / `Tùy chọn`) trên các bài học trong sự kiện.
  - Khi người học chạm vào bài học có `status == LearnerPathStatus.locked`, hiển thị `SnackBar` / thông báo nêu rõ cần hoàn thành bài học bắt buộc đứng trước trong lộ trình (`TC-NAV-05`).

### 2.4. Sửa lỗi `Row` + `DongSonButton` trong `BattleSabanScreen` (`battle_saban_screen.dart:75-122`)
```dart
Row(
  children: [
    Expanded(
      flex: 3,
      child: DongSonButton(
        label: 'Xem Chi Tiết Chiến Dịch',
        icon: Icons.auto_stories_rounded,
        variant: DongSonButtonVariant.primaryCinnabar,
        height: 48,
        onPressed: () { ... },
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      flex: 2,
      child: DongSonButton(
        label: 'Bàn Học',
        icon: Icons.home_outlined,
        variant: DongSonButtonVariant.secondaryParchment,
        height: 48,
        onPressed: () => context.go('/dashboard'),
      ),
    ),
  ],
)
```

---

## 3. Tiêu chí Nghiệm thu Phase 01
- [ ] Ảnh chụp `/#/dashboard` ở `360×800` và `390×844` không còn hiện tượng chữ phụ đề đè lên nón lá Kabi; thẻ "Bài học hôm nay" hiển thị đúng tên bài học và tiến độ, không lộ mã `ctx`.
- [ ] `BattleSabanScreen` render sạch ở `360×800` với `0` lỗi `RenderFlex`.
- [ ] `PeriodSelectionScreen` và `PeriodJourneyScreen` hiển thị rõ lý do khóa và phân biệt bài học Bắt buộc / Tùy chọn.
