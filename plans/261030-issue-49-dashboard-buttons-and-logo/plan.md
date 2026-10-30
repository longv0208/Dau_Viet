# Kế hoạch Triển khai Issue #49 (TASK-0038)

## 1. Bối cảnh & Phân tích Tác động (Impact Note)
- **Nguồn yêu cầu:** [GitHub Issue #49](https://github.com/longv0208/Dau_Viet/issues/49)
- **Mức độ rủi ro:** `normal` (cập nhật giao diện tầng presentation của `dau-viet-mobile`, không thay đổi API, DB hay logic nghiệp vụ).
- **Trạng thái công cụ Code Intelligence:** GitNexus MCP không khả dụng trong phiên làm việc này; đã thực hiện truy vết toàn bộ references bằng `grep` và `read` trực tiếp trên `dau-viet-mobile/lib` và `dau-viet-mobile/test`:
  - `LearnerDashboardScreen`: được sử dụng trong `app_router.dart`, `test/dashboard/learner_dashboard_screen_test.dart`, `test/learning_path/learning_flow_e2e_integration_test.dart`, và `test/widget_test.dart`.
  - `TactileCard`: được sử dụng tại 23 file trong `lib/`. Việc giữ nguyên giá trị mặc định `usePixelShadow = true` và bổ sung `boxShadow` tuỳ chọn + cập nhật nhánh `usePixelShadow: false` dùng `DauVietColors.softCardShadow` hoàn toàn tương thích ngược với các màn hình khác.
  - `HeroPaperBanner`: được sử dụng tại 5 file trong `lib/`. Việc thêm các tham số tuỳ chọn `borderColor`, `borderWidth`, `borderRadius`, `usePixelShadow`, `boxShadow` với giá trị mặc định giữ nguyên hoàn toàn không ảnh hưởng tới `CampaignDetailScreen`, `ThemeShowcaseScreen`, `InventoryScreen`.

## 2. Thiết kế Chi tiết

### Phase 1: Bổ sung Token Đổ bóng mềm & Tuỳ chọn cho Card/Banner (`core/`)
1. **`dau-viet-mobile/lib/core/theme/dau_viet_colors.dart`**:
   - Bổ sung hằng số `softCardShadow`:
     ```dart
     static const List<BoxShadow> softCardShadow = [
       BoxShadow(
         color: Color(0x0F5D4024),
         offset: Offset(0, 2),
         blurRadius: 6,
         spreadRadius: 0,
       ),
     ];
     ```
2. **`dau-viet-mobile/lib/core/widgets/tactile_card.dart`**:
   - Bổ sung tham số tuỳ chọn `final List<BoxShadow>? boxShadow;`.
   - Khi `usePixelShadow == false`, sử dụng `DauVietColors.softCardShadow` (nếu không truyền `boxShadow` riêng) để đồng bộ với `_MenuTile` / `_StatCell` trên `ProfileScreen`.
3. **`dau-viet-mobile/lib/core/widgets/hero_paper_banner.dart`**:
   - Bổ sung các tham số tuỳ chọn `borderColor`, `borderWidth`, `borderRadius`, `usePixelShadow`, `boxShadow` (mặc định giữ nguyên hành vi cũ cho các màn hình khác).

### Phase 2: Sửa lỗi lặp chữ dưới Logo & Đồng bộ Button/Card trên `LearnerDashboardScreen`
1. **TopBar Logo (`_buildTopBar`) — AC-1:**
   - Gỡ bỏ widget `Text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —')` và `SizedBox(height: 2)` bị lặp bên dưới `Image.asset('assets/images/app_logo.png')` (do bản thân file `app_logo.png` đã chứa sẵn dòng chữ khẩu hiệu này).
   - Nâng chiều cao `Image.asset('assets/images/app_logo.png')` lên `height: 38` kèm `filterQuality: FilterQuality.high`.
2. **TopBar Buttons (Chuông thông báo & Avatar) — AC-2:**
   - Nút Chuông thông báo: nền `Color(0xFFFAF3E4)`, viền `Color(0xFFE3D2B4)` rộng `1.1px`, bóng mềm `DauVietColors.softCardShadow` (thay cho `pixelShadowSm`).
   - Nút Avatar: nền `Color(0xFFFAF3E4)`, viền `Color(0xFFDEC69A)` rộng `1.4px`, bóng mềm `DauVietColors.softCardShadow` (thay cho `pixelShadowSm`).
3. **2 Status Pills (`_EnergyMiniPill` & `_StreakMiniPill`) — AC-2:**
   - Chuyển sang `TactileCard` với `usePixelShadow: false`, `borderWidth: 1.1`, bóng mềm `DauVietColors.softCardShadow`:
     - `_EnergyMiniPill`: nền pastel vàng ấm `Color(0xFFFFF3D6)`, viền `DauVietColors.imperialGoldDark.withValues(alpha: 0.42)`.
     - `_StreakMiniPill`: nền pastel chu sa dịu `Color(0xFFFDE3DD)`, viền `DauVietColors.cinnabarRed.withValues(alpha: 0.42)`.
4. **Hero Banner & Nút CTA (`_buildHeroBanner`, `_buildHeroCtaButton`) — AC-2:**
   - `HeroPaperBanner`: bật `usePixelShadow: false`, `borderRadius: 18`, `borderColor: const Color(0xFFDEC69A)`, `borderWidth: 1.3`.
   - `_buildHeroCtaButton`: thay thế `DongSonButton` (đế 3D dày) bằng nút phẳng bo tròn tinh tế (`BorderRadius.circular(11)`), nền xanh rêu di sản `Color(0xFF1A4B38)`, viền mảnh `Color(0xFFDEC69A).withValues(alpha: 0.55)`, bóng mềm `BoxShadow(color: Color(0x24163A2B), blurRadius: 4, offset: Offset(0, 1))`.
5. **Thẻ "Bài học hôm nay" (`_buildTodayLessonCard`) — AC-2:**
   - `TactileCard`: `usePixelShadow: false`, `borderRadius: 16`, `backgroundColor: const Color(0xFFFAF3E4)`, `borderColor: const Color(0xFFE3D2B4)`, `borderWidth: 1.1`.
   - Khung icon bên trái: nền `DauVietColors.heritageGreenSurface` (`#EBF4EF`), viền mảnh `DauVietColors.heritageGreenLight.withValues(alpha: 0.25)`.
6. **4 nút "Hành trình của bạn" (`_buildJourneyCard`) — AC-2:**
   - `TactileCard`: `usePixelShadow: false`, `borderRadius: 14`, `backgroundColor: const Color(0xFFFAF3E4)`, `borderColor: const Color(0xFFE3D2B4)`, `borderWidth: 1.1`.
   - Phối màu vòng tròn icon đồng bộ bảng màu `_StatCell` / `_MenuTile` của `ProfileScreen`:
     - *Bài học*: `heritageGreenLight` trên nền `heritageGreenSurface` (`#EBF4EF`)
     - *Ôn tập*: `imperialGoldDark` trên nền `Color(0xFFFFF3D6)`
     - *Thành tích*: `cinnabarRed` trên nền `Color(0xFFFDE3DD)`
     - *Thư viện*: `jadeDark` trên nền `Color(0xFFDCEFED)`
7. **Khối "Nhiệm vụ hôm nay" & "Sự kiện nổi bật" (`_buildQuestCard`, `_buildFeaturedEventCard`) — AC-2:**
   - `_buildQuestCard`: `usePixelShadow: false`, `borderRadius: 16`, `backgroundColor: const Color(0xFFFAF3E4)`, `borderColor: const Color(0xFFE3D2B4)`, `borderWidth: 1.1`.
   - `_buildFeaturedEventCard`: `HeroPaperBanner` với `usePixelShadow: false`, `borderRadius: 16`, `borderColor: const Color(0xFFDEC69A)`, `borderWidth: 1.2`.
   - Nút CTA `"Khám phá ngay →"`: bỏ `pixelShadowSm`, dùng nút phẳng đỏ chu sa bo góc `10px`, viền mảnh `Color(0xFFE6B665).withValues(alpha: 0.75)` (`1.0px`) và bóng mềm `BoxShadow(color: Color(0x24381713), blurRadius: 4, offset: Offset(0, 1))`.

### Phase 3: Kiểm thử & Nghiệm thu (AC-3)
- Cập nhật và bổ sung widget tests trong `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`:
  - Kiểm chứng không còn `Text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —')` bị lặp dưới `app_logo.png`.
  - Kiểm chứng toàn bộ `TactileCard` và `HeroPaperBanner` trên `LearnerDashboardScreen` đều có `usePixelShadow == false`, không còn `DongSonButton` hay `pixelShadowSm` trên màn hình Dashboard.
  - Kiểm chứng đầy đủ các luồng điều hướng từ Hero CTA, Bài học hôm nay, 4 nút Hành trình của bạn, Nhiệm vụ hôm nay và Sự kiện nổi bật.
- Chạy `flutter analyze --no-pub` và `flutter test`.
