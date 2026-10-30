# TASK-0038: Issue #49 — Đồng bộ thiết kế Button/Card trên Dashboard theo phong cách trang Profile & sửa lỗi lặp khẩu hiệu dưới Logo (`dau-viet-mobile`)

## Mục tiêu
Khắc phục 2 vấn đề hiển thị trên màn hình **Trang chủ / Học tập (`LearnerDashboardScreen`)** của ứng dụng `dau-viet-mobile` theo [Issue #49](https://github.com/longv0208/Dau_Viet/issues/49):
1. **Sửa lỗi lặp dòng chữ khẩu hiệu dưới Logo trên TopBar (`_buildTopBar`):**
   - Ảnh `assets/images/app_logo.png` (xuất từ `logo2.svg`) đã bao gồm sẵn dòng chữ `— HỌC SỬ VIỆT - GÌN GIỮ HỒN VIỆT —` bên dưới chữ `Dấu Việt`.
   - Loại bỏ widget `Text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —')` render trùng lặp ngay bên dưới `Image.asset('assets/images/app_logo.png')` và tinh chỉnh kích thước hiển thị (`height: 38`, `filterQuality: FilterQuality.high`) để cụm thương hiệu sắc nét và chỉ hiển thị duy nhất 1 dòng khẩu hiệu.
2. **Đồng bộ toàn bộ các Button, Pill và Card tương tác trên Dashboard theo phong cách Soft Heritage Card của `ProfileScreen`:**
   - Loại bỏ toàn bộ `DauVietColors.pixelShadowSm`, `DauVietColors.pixelShadow` và khối nút 3D dày (`DongSonButton` / `Tactile3DButton`) trên `LearnerDashboardScreen`.
   - Chuyển sang nền giấy dó ấm (`#FAF3E4` hoặc pastel ngữ cảnh `#FFF3D6`, `#FDE3DD`, `#EBF4EF`, `#DCEFED`), viền mảnh tinh tế (`1.1px – 1.3px`, màu `#E3D2B4` / `#DEC69A` hoặc màu nhấn giảm alpha `0.42`), bo góc mềm (`14px – 18px`) và đổ bóng mềm (`BoxShadow(color: Color(0x0F5D4024), blurRadius: 6, offset: Offset(0, 2))`).

## Kế hoạch chi tiết
Xem [`plans/261030-issue-49-dashboard-buttons-and-logo/plan.md`](../../plans/261030-issue-49-dashboard-buttons-and-logo/plan.md).

## Ánh xạ Kiểm chứng (AC → Check)
| AC | Kiểm tra | Kỳ vọng |
|---|---|---|
| AC-1 | Kiểm tra `_buildTopBar` trong `learner_dashboard_screen.dart` + `learner_dashboard_screen_test.dart` | Không còn widget `Text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —')` render trùng bên dưới `app_logo.png`; `Image.asset('assets/images/app_logo.png')` hiển thị sắc nét kèm `Text('Dấu Việt')` ẩn phục vụ semantics |
| AC-2 | Kiểm tra toàn bộ button/pill/card trên `LearnerDashboardScreen` + widget test kiểm chứng decoration/shadow | Không còn `pixelShadowSm`, `pixelShadow` hay `DongSonButton` (3D button) trên `LearnerDashboardScreen`; tất cả dùng viền mảnh và bóng mềm đồng bộ `ProfileScreen` |
| AC-3 | `flutter analyze --no-pub` + `flutter test test/dashboard/learner_dashboard_screen_test.dart test/widget_test.dart test/learning_path/learning_flow_e2e_integration_test.dart` | 0 lỗi analyze, 100% test suite pass |
