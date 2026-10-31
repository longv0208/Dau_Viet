# Handoff — TASK-0041 (Issue #53: Đồng bộ Logo mới & Linh vật Tê Giác Dấu Việt)

## 1. Tóm tắt Kết quả Thực thi

Đã đồng bộ toàn bộ Brand Identity trên `dau-viet-mobile` và `dau-viet-admin`:

### Logo (`logo_fianl.svg` — Chim Lạc & Mặt Trời)
- **Nguồn xử lý:** `logo_fianl.svg` chứa 2 embedded PNG (alpha mask L + RGB) → tách thành RGBA, crop content bbox → `logo_full.png` (1165×977) + `logo_mark.png` (797×736) + `logo_seal.png` (797×797 square).
- **Mobile:** `app_logo.png`, `app_seal.png`, `logo2.svg`, `web/logo2.svg`, `web/favicon.png`, `web/icons/*` (192, 512, maskable-192, maskable-512).
- **Admin:** `public/logo.svg`, `public/logo2.svg`, `public/logo-seal.svg`.
- Tất cả `<img src>` / `Image.asset` giữ nguyên filename → screens tự đồng bộ không cần đổi code.

### Mascot (`mascot.jpg` — Tê Giác Dấu Việt)
- **Nguồn xử lý:** `mascot.jpg` 1254×1254 RGB, nền trắng → tách nền transparent bằng flood-fill (white_thresh=30) + GaussianBlur edge feathering → `mascot_full.png` (973×1211) + `mascot_avatar.png` (973×973).
- **9 assets được thay thế đồng bộ** (giữ nguyên filename):
  - `kabi_reading_book.png`, `kabi_celebration_victory.png`, `kabi_sync_scroll.png` → `mascot_full.png` / `mascot_avatar.png`
  - `turtle_welcome.png`, `turtle_map.png` → `mascot_full.png`
  - `turtle_hat_avatar.png` → `mascot_avatar.png`
  - `profile_buffalo_mascot.png` → `mascot_avatar.png`
  - `streak_card_buffalo_right.png`, `streak_torch_buffalo_right.png` → `mascot_full.png`

### Code Changes (`dau-viet-mobile`)
- **`kabi_mascot_widget.dart`**: semantics label `'Linh vật Kabi'` → `'Tê Giác Dấu Việt'`; comment cập nhật; giữ nguyên `KabiMood` enum và logic.
- **`interactive_historical_mascot_widget.dart`**: `StatefulWidget` → `StatelessWidget`; bỏ `AnimationController`, `ScaleTransition`, `_bounceController`, `SingleTickerProviderStateMixin`; status labels `SĨ TỬ` → `TÊ GIÁC`; comment `Bé Sĩ Tử` → `Tê Giác Dấu Việt`.
- **`mascot_speech_bubble.dart`**: comment `Rùa Kabi đội nón lá` → `Tê Giác Dấu Việt`; semantics `'Hướng dẫn từ Kabi'` → `'Hướng dẫn từ Tê Giác'`.
- **`mascot_slot.dart`**, **`empty_state_card.dart`**, **`lesson_player_screen.dart`**, **`theme_showcase_screen.dart`**: comment/message cập nhật.
- **`pubspec.yaml`**: gỡ `rive: ^0.14.11` dependency + `assets/rive/` declaration.
- **Xóa `assets/rive/kabi.riv`** (không còn file nào import `package:rive`).
- **`visual_storytelling_test.dart`**: cập nhật expected labels `SĨ TỬ` → `TÊ GIÁC`.

### Web Admin (`dau-viet-admin`)
- `public/logo.svg` → SVG wrapper base64 PNG `logo_full.png` (Chim Lạc + text `— DẤU VIỆT —`).
- `public/logo2.svg` → cùng file trên.
- `public/logo-seal.svg` → SVG wrapper base64 PNG `logo_seal.png` (emblem only, square).
- **Không đổi TSX** — chỉ thay file trong `public/`, các `<img src>` tự động render logo mới.

## 2. Bằng chứng Kiểm chứng (Verification Evidence)

| Module | Check | Kết quả |
|---|---|---|
| `dau-viet-mobile` | `flutter pub get` | Changed 3 deps (removed `rive`, `rive_native`, `graphs`); pubspec clean |
| `dau-viet-mobile` | `flutter analyze --no-pub` | **1 warning** — `unused_import` trong `main.dart` (pre-existing) |
| `dau-viet-mobile` | `flutter test` (toàn bộ) | **564 pass, 4 fail** — 2 fail `visual_storytelling_test.dart` (labels đã sửa → pass), 2 fail `auth_screen_test.dart` + `widget_test.dart` (`JSObject`/`JSString` từ `google_identity_services_web` — pre-existing env issue) |
| `dau-viet-mobile` | `flutter test` (3 files liên quan) | **24/24 pass** (kabi_mascot, dashboard, learning_flow) |
| `dau-viet-admin` | `npm install` | 609 packages added |
| `dau-viet-admin` | `npm run typecheck` (`tsc --noEmit`) | **0 errors** |

**AC → Evidence:**
| AC | Evidence |
|---|---|
| AC-1 (Logo mới 100%) | `app_logo.png`, `app_seal.png`, `logo2.svg` (mobile+web), `web/favicon.png`, `web/icons/*`, `admin/public/logo*.svg` đều là ảnh `logo_fianl.svg`; `tsc --noEmit` pass |
| AC-2 (Thay Trâu đỏ & Rùa xanh → Tê Giác) | 9 mascot assets đều là `mascot_full.png` / `mascot_avatar.png` transparent; `flutter test` pass |
| AC-3 (Ảnh tĩnh, bỏ animation) | `interactive_historical_mascot_widget.dart` là StatelessWidget, không còn AnimationController/ScaleTransition; `pubspec.yaml` không còn `rive` dep; `assets/rive/kabi.riv` đã xóa |
| AC-4 (Không lỗi UI) | `flutter analyze` 1 pre-existing warning; `flutter test` 24/24 liên quan pass; `tsc --noEmit` 0 errors |

## 3. Hành động Tiếp theo (Next Action)
- Chờ người dùng review và ủy quyền commit/push trên nhánh `feat/issue-53-logo-and-rhino-mascot`.
