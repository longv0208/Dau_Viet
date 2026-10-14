# Tester Report — TASK-0006 Flutter Historical Events API Integration

- Ngày chạy: 2026-10-15
- Agent: tester
- Work context: `E:\Telegram Desktop\Dau viet\Dau_Viet\dau-viet-mobile`
- Task: TASK-0006 — Integrate events API with Dio + Riverpod + mock flag

## Kết luận

**NOT VERIFIED** — Flutter SDK không cài đặt trên máy này. Không thể chạy `flutter pub get`, `flutter analyze`, `flutter test`. Báo cáo bên dưới chỉ ghi nhận các kiểm tra tĩnh từ filesystem/pubspec.

## Các lệnh đã cố chạy

| Lệnh | cwd | Kết quả |
|---|---|---|
| `where.exe flutter` | `E:\Telegram Desktop\Dau viet\Dau_Viet` | Not found |
| `flutter --version` | `E:\Telegram Desktop\Dau viet\Dau_Viet` | `command not found` (exit 127) |
| `Get-Command flutter` (PS) | — | No output |
| `Get-Command fvm`, `Get-Command dart`, `Get-Command choco`, `Get-Command scoop` | — | No output |
| Search filesystem `C:\`, `D:\`, `E:\` cho `flutter\bin\flutter.bat` (depth 2) | — | Không thấy |
| Kiểm tra các đường dẫn phổ biến (`C:\flutter`, `C:\src\flutter`, `E:\flutter`, `%LOCALAPPDATA%\flutter`, `%USERPROFILE%\flutter`, `~\scoop\apps\flutter`, `C:\ProgramData\chocolatey\lib\flutter`, `C:\fvm\versions`) | — | Không path nào tồn tại |
| Inspect User PATH registry (`HKCU:\Environment`) | — | Không entry nào chứa `flutter`, `dart`, `fvm` |
| Kiểm tra `.dart_tool\package_config.json` | `dau-viet-mobile\` | File không tồn tại (chưa `pub get` lần nào trên máy này) |
| Kiểm tra `android\local.properties` | `dau-viet-mobile\` | Không tồn tại (chưa có cấu hình `flutter.sdk` local) |

Không `flutter` → 3 lệnh chính (`pub get`, `analyze`, `test`) đều **không chạy được**, không có exit code.

## Kiểm tra tĩnh thay thế (đọc file, không biên dịch)

### pubspec.yaml
- `dio: ^5.7.0` đã khai báo trong `dependencies` (đúng yêu cầu task).
- `flutter_riverpod: ^3.4.3`, `go_router: ^18.0.2`, `google_fonts: ^8.2.1`, `audioplayers: ^6.8.1` đã có.
- File mtime: `pubspec.yaml` = 2026-10-15 02:02 (sau commit TASK-0006 — hợp lý).

### pubspec.lock — cảnh báo nhỏ
- **KHÔNG tìm thấy entry `dio` trong `pubspec.lock`** (search pattern `^\s+dio` và `dio` case-insensitive chỉ match `audioplayers*`).
- `pubspec.lock` mtime = 2026-10-14 23:48 (cũ hơn `pubspec.yaml` ~2h14').
- Suy ra: `pubspec.lock` chưa được regen sau khi thêm `dio`. Khi dev có SDK chạy `flutter pub get`, lock sẽ được cập nhật. Đây KHÔNG phải lỗi code, chỉ là lockfile stale — `pub get` sẽ resolve.

### Test files (tồn tại, chưa chạy được)
Đủ 7 file test theo brief + 3 file legacy:
- `test\events_dto_test.dart` (mới)
- `test\events_repository_test.dart` (mới)
- `test\api_client_test.dart` (mới)
- `test\asset_resolver_test.dart` (mới)
- `test\timeline_events_test.dart` (mới)
- `test\campaign_detail_test.dart` (mới)
- `test\mock_mode_test.dart` (mới)
- `test\widget_test.dart` (journey test — đã override `eventsRepositoryProvider`)
- `test\audio_engine_test.dart`, `test\gamification_loop_test.dart`, `test\visual_storytelling_test.dart` (legacy)

## Failed tests / Stack trace

N/A — không chạy được.

## Analyze warnings

N/A — `flutter analyze` không chạy được.

## Build status

N/A — không có SDK.

## Critical issues

1. **Flutter SDK absent on this machine** — mọi verification cho `dau-viet-mobile` đều bị block. Không `flutter`, không `dart`, không `fvm`, không `scoop`/`choco` shim, không flutter dir ở bất kỳ drive nào.
2. `pubspec.lock` stale — chưa có `dio` entry; sẽ được cập nhật tự động lần `pub get` đầu tiên trên máy có SDK.

## Recommendations

- KHÔNG tự ý cài SDK (đúng chỉ đạo).
- Cần chạy TASK-0006 verification trên máy có Flutter SDK 3.x (khớp `sdk: ^3.12.0` environment) hoặc trong CI.
- Khi SDK sẵn có, chạy theo thứ tự:
  1. `flutter pub get` — kiểm tra `dio` resolve thành công, lockfile được regen.
  2. `flutter analyze` — mong đợi "No issues found!".
  3. `flutter test` — tất cả 11 file test phải pass; journey test (`widget_test.dart`) phải pass nhờ `MockEventsRepository` override.
- Nếu `flutter pub get` fail do `dio` conflict với `flutter_riverpod ^3.4.3` hoặc `audioplayers ^6.8.1` → report lại conflict cụ thể, KHÔNG tự sửa.
- Nếu `analyze` hoặc `test` báo lỗi compile (thiếu import, signature mismatch giữa `EventsRepository` và `MockEventsRepository`) → fix theo stack trace; brief đã cấm tester sửa code, escalate cho author.

## Next steps

1. Cài Flutter SDK (ngoài scope của tester) hoặc chạy verification trên máy/CI có SDK.
2. Re-run tester trên môi trường có SDK để xác nhận 11 test file pass.
3. Cập nhật `pubspec.lock` vào git sau `pub get` đầu tiên (nếu lockfile được commit — kiểm tra `.gitignore`).

## Unresolved questions

- Máy dev nào có Flutter SDK để verify? Hay project có CI pipeline riêng cho `dau-viet-mobile`?
- `pubspec.lock` có được commit vào git không (quyết định việc regenerate lock có cần commit lại)?
- SDK version expected — `pubspec.yaml` yêu cầu `sdk: ^3.12.0` (Dart) nhưng không nói rõ Flutter channel (stable/beta)?
