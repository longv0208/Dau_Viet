# Handoff — TASK-0027 (`[E2E] Mobile: kiểm thử Đảo Di Sản và bài học`, Issue #27)

## 1. Tóm tắt kết quả
- Đã hoàn tất triển khai toàn bộ 6 Phase của kế hoạch kiểm thử End-to-End và xử lý lỗi Runtime / Tràn giao diện trong worktree độc lập `E:/Telegram Desktop/Dau viet/Dau_Viet-issue-27` (nhánh `test/issue-27-e2e-island-lesson`).
- Ứng dụng Flutter Mobile (`dau-viet-mobile`, `USE_MOCK=false`) chạy thực tế trên Chromium ở cả 2 kích thước màn hình điện thoại (`390x844` và `360x800`), kết nối trực tiếp với Spring Boot (`local` profile, cổng `8080`) và PostgreSQL (`localhost:5433/dauviet`).
- Đã khắc phục triệt để 7 lỗi Runtime & Hiển thị (`BUG-01` đến `BUG-07`):
  - **BUG-01**: `await restore()` trước `runApp()`, `await _storage.save()`, bật `GoRouter.optionURLReflectsImperativeAPIs = true` và `refreshListenable: authRouterRefreshNotifier`.
  - **BUG-02**: Bọc thanh công cụ nổi ở đáy Đảo Di Sản trong `FittedBox(fit: BoxFit.scaleDown)` để triệt tiêu lỗi `RenderFlex overflowed`.
  - **BUG-03**: Thu gọn các nút icon lặp trên Header Đảo Di Sản khi màn hình `< 480px`, giúp tiêu đề **`ĐẢO DI SẢN`** và phụ đề **`Đảo nhỏ — Level tài khoản 1`** hiển thị trọn vẹn 100%, không bị cắt `"ĐẢO DI S..."`.
  - **BUG-04**: Quản lý vòng đời `_energyToastEntry` (`-N Thể lực`) trong `LessonPlayerScreen`, tự gỡ ngay khi nộp lượt mới hoặc khi mở Dialog `"Hết Thể lực"`, không đè lên chữ phản hồi xanh.
  - **BUG-05**: Chặn chồng 2 lớp thẻ giữa `_showWelcomeCard` và `IslandTileSheet` trên Đảo Di Sản.
  - **BUG-06**: Sửa `_resolveMascotPrompt` không báo nhầm `"chọn Đúng hoặc Sai"` cho câu trắc nghiệm 2 phương án văn bản dài; bổ sung ảnh đại diện linh vật tĩnh (`turtle_welcome.png`) trong `KabiMascotWidget._buildFallbackMascot()` khi Rive đang nạp trên Web.
  - **BUG-07**: Gắn nhãn `Semantics` (`button: true`) cho từng ô slot trên Đảo Di Sản (`Ô di sản <key>: <name>`, `Ô trống <key>`, `Ô khóa <key> Cấp <tier>`).

## 2. Các lệnh kiểm chứng đã chạy thật & Kết quả
1. **Format & Analyze (`dau-viet-mobile`)**:
   - Lệnh:
     ```bash
     dart format --output=none --set-exit-if-changed lib/main.dart lib/app/router.dart lib/features/auth/data/auth_repository.dart lib/features/learning/data/learning_providers.dart lib/features/learning/presentation/lesson_player_screen.dart lib/features/island/presentation/island_screen.dart lib/features/island/presentation/widgets/island_isometric_renderer.dart lib/core/widgets/kabi_mascot_widget.dart test/island/island_dto_test.dart test/island/island_screen_test.dart
     flutter analyze --no-pub lib/main.dart lib/app/router.dart lib/features/auth/data/auth_repository.dart lib/features/learning/data/learning_providers.dart lib/features/learning/presentation/lesson_player_screen.dart lib/features/island/presentation/island_screen.dart lib/features/island/presentation/widgets/island_isometric_renderer.dart test/island/island_dto_test.dart test/island/island_screen_test.dart
     ```
   - Kết quả: `Formatted 10 files (0 changed)`, `No issues found! (ran in 2.5s)`, exit code `0`.
2. **Flutter Unit & Widget Tests (`test/island` & `test/learning/resume_test.dart`)**:
   - Lệnh:
     ```bash
     flutter test --no-pub test/island test/learning/resume_test.dart
     ```
   - Kết quả: `00:03 +18: All tests passed!`, exit code `0`.
3. **Build Flutter Web (`USE_MOCK=false`)**:
   - Lệnh:
     ```bash
     flutter build web --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:8080
     ```
   - Kết quả: `Built build\web`, exit code `0`.
4. **Playwright E2E Suite (5 kịch bản toàn diện bao phủ 6 Phase trên `390x844` & `360x800`)**:
   - Lệnh:
     ```bash
     cd dau-viet-mobile/e2e
     node ./node_modules/@playwright/test/cli.js test
     ```
   - Kết quả: `5 passed (70.3s)`, `0` lỗi runtime/overflow, `0` lỗi tài nguyên 404, `verifyCleanup()` = `0`, exit code `0`.
   - Bộ 9 ảnh chụp bằng chứng tại `dau-viet-mobile/e2e/test-results/evidence/`:
     - `ac1-lesson-server-feedback.png`
     - `ac2-lesson-result-screen.png`
     - `ac3-island-item-placed.png`
     - `ac3-island-item-removed-reloaded.png`
     - `ac4-lesson-api-error-no-fake-success.png`
     - `ac4-island-load-error-retry.png`
     - `phase5-energy-depleted-dialog.png`
     - `phase5-vien-thai-y-0-energy.png`
     - `phase6-island-shop-360x800.png`

## 3. Hành động tiếp theo
- Chờ người dùng kiểm tra worktree `E:/Telegram Desktop/Dau viet/Dau_Viet-issue-27` (nhánh `test/issue-27-e2e-island-lesson`) và cho phép commit/push.
