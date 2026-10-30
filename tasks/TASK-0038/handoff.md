# Handoff — TASK-0038 (Issue #49)

## 1. Tóm tắt Kết quả
Đã hoàn thành triệt để [Issue #49](https://github.com/longv0208/Dau_Viet/issues/49) trên `dau-viet-mobile`:
- **AC-1 (Sửa lỗi lặp dòng chữ khẩu hiệu dưới Logo trên TopBar):**
  - Gỡ bỏ widget `Text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —')` và `SizedBox(height: 2)` bị lặp ngay bên dưới `Image.asset('assets/images/app_logo.png')` trong `_buildTopBar()` của `LearnerDashboardScreen` (do bản thân bức ảnh `app_logo.png` đã chứa sẵn dòng chữ `— HỌC SỬ VIỆT - GÌN GIỮ HỒN VIỆT —`).
  - Nâng chiều cao `Image.asset('assets/images/app_logo.png')` lên `height: 38` kèm `filterQuality: FilterQuality.high` và giữ `Text('Dấu Việt')` ẩn (`opacity: 0.0`) cho semantics/test runner.
- **AC-2 (Đồng bộ toàn bộ Button/Card/Pill/Banner trên Dashboard theo phong cách Soft Heritage Card của `ProfileScreen`):**
  - Bổ sung `DauVietColors.softCardShadow` (`BoxShadow(color: Color(0x0F5D4024), offset: Offset(0, 2), blurRadius: 6)`) trong `dau_viet_colors.dart`.
  - Cập nhật `TactileCard` (hỗ trợ `boxShadow` tuỳ chọn và dùng `DauVietColors.softCardShadow` khi `usePixelShadow == false`) và `HeroPaperBanner` (hỗ trợ `usePixelShadow`, `borderColor`, `borderWidth`, `borderRadius`, `boxShadow` tương thích ngược).
  - Loại bỏ toàn bộ `DauVietColors.pixelShadowSm`, `DauVietColors.pixelShadow` và khối nút 3D dày (`DongSonButton` / `Tactile3DButton`) trên `LearnerDashboardScreen`:
    - Nút Chuông thông báo & Avatar trên TopBar: nền `#FAF3E4`, viền mảnh `#E3D2B4` (`1.1px`) / `#DEC69A` (`1.4px`), bóng mềm `softCardShadow`.
    - 2 Pill trạng thái (`_EnergyMiniPill`, `_StreakMiniPill`): nền pastel `#FFF3D6` / `#FDE3DD`, viền mảnh `1.1px` giảm alpha `0.42`, tắt `usePixelShadow`.
    - Hero Banner & `_buildHeroCtaButton`: tắt `usePixelShadow` trên banner (viền `#DEC69A` `1.3px`, bo góc `18px`); thay `DongSonButton` 3D bằng nút phẳng bo góc `11px` màu xanh rêu `#1A4B38`, viền `#DEC69A` mảnh và bóng mềm `Color(0x24163A2B)` kèm `FittedBox(fit: BoxFit.scaleDown)` chống tràn trên màn 360px.
    - Thẻ "Bài học hôm nay" (`_buildTodayLessonCard`), 4 nút "Hành trình của bạn" (`_buildJourneyCard`) và "Nhiệm vụ hôm nay" (`_buildQuestCard`): nền `#FAF3E4`, viền `#E3D2B4` `1.1px`, tắt `usePixelShadow`, phối màu vòng tròn icon đồng bộ bảng màu `_StatCell` / `_MenuTile` trên `ProfileScreen`.
    - Thẻ "Sự kiện nổi bật" (`_buildFeaturedEventCard`): tắt `usePixelShadow` trên `HeroPaperBanner`, nút CTA `"Khám phá ngay →"` phẳng bo góc `10px`, viền `#E6B665` mảnh và bóng mềm `Color(0x24381713)`.
- **AC-3 (Visual & Widget Tests):**
  - Cập nhật và bổ sung kiểm thử trong `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart` (6/6 tests pass, bao gồm kiểm tra không lặp chữ khẩu hiệu, kiểm tra 0 `DongSonButton`/`Tactile3DButton`/`pixelShadow` trên Dashboard, và kiểm tra 0 lỗi tràn layout trên cả 2 kích thước `360x800` & `390x844`) và `dau-viet-mobile/test/theme/design_tokens_test.dart` (8/8 tests pass).

## 2. Các File Đã Thay Đổi
- `dau-viet-mobile/lib/core/theme/dau_viet_colors.dart`
- `dau-viet-mobile/lib/core/widgets/tactile_card.dart`
- `dau-viet-mobile/lib/core/widgets/hero_paper_banner.dart`
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart`
- `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`
- `dau-viet-mobile/test/theme/design_tokens_test.dart`
- `plans/261030-issue-49-dashboard-buttons-and-logo/plan.md`
- `tasks/TASK-0038/task.json`
- `tasks/TASK-0038/brief.md`
- `tasks/TASK-0038/handoff.md`
- `docs/PROJECT_OVERVIEW.md`
- `docs/PROGRESS.md`

## 3. Bằng Chứng Kiểm Chứng (Verification Evidence)
- `flutter analyze --no-pub` (cwd: `dau-viet-mobile`): `No issues found!` (exit code 0).
- `flutter test --no-pub test/dashboard/learner_dashboard_screen_test.dart` (cwd: `dau-viet-mobile`): `6/6 All tests passed!` (exit code 0).
- `flutter test --no-pub test/dashboard test/theme test/learning_path test/learning test/map test/island test/energy test/streak test/collection test/campaign` (cwd: `dau-viet-mobile`): `458/458 All tests passed!` (exit code 0).
- `git diff --check`: clean (0 whitespace/formatting errors).

## 4. Hạn chế & Ghi chú
- GitNexus MCP không khả dụng trong phiên làm việc này; đã dùng `grep`/`read` trực tiếp và chạy toàn bộ 458 tests của các phân hệ mobile để bảo đảm an toàn hồi quy.
- Các file `generated_plugin_registrant.*` của Flutter desktop (linux/macos/windows) có sẵn trong working tree được giữ nguyên theo quy tắc bảo toàn thay đổi cục bộ.

## 5. Hành động Kế tiếp (Next Action)
- Chờ người dùng review và ủy quyền commit/push trên nhánh `fix/issue-49-dashboard-buttons-and-logo`.
