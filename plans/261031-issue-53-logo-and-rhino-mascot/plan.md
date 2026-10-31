# Kế hoạch Triển khai Issue #53 (TASK-0041) — Đồng bộ Logo mới & Linh vật Tê Giác Dấu Việt

## 1. Bối cảnh & Phân tích Tác động (Impact Note)

- **Nguồn yêu cầu:** [GitHub Issue #53](https://github.com/longv0208/Dau_Viet/issues/53)
- **Mức độ rủi ro:** `normal` — chỉ thay đổi tầng presentation (assets + widget + screen styling) trên `dau-viet-mobile` và `dau-viet-admin`; không thay đổi API, DB schema, auth hay business logic.
- **Assets đầu vào (đã có sẵn trong worktree):**
  - `logo_fianl.svg` — SVG chứa 2 embedded base64 PNG (mask L + RGB) → xuất ra PNG trong suốt `logo_full.png` (1254×1254). Content bbox: (45,158)→(1209,1134) ≈ 1164×976.
  - `mascot.jpg` — ảnh RGB 1254×1254, nền trắng, chú Tê Giác bộ áo dài truyền thống + khăn rằn + băng đô đỏ. Content bbox: (104,9)→(1076,1223) ≈ 972×1214.
- **Code Intelligence:** GitNexus MCP không khả dụng; đã truy vết toàn bộ references bằng `grep`/`read` trực tiếp.

## 2. Inventory hiện trạng (đã khảo sát)

### Logo cũ trên `dau-viet-mobile`
| File | Đường dẫn asset | Vị trí |
|---|---|---|
| `splash_screen.dart` | `assets/images/app_logo.png` | Precache + hiển thị (w=280 h=92) |
| `onboarding_screen.dart` | `assets/images/app_logo.png` | h=36 |
| `auth_screen.dart` | `assets/images/app_logo.png` | h=54 |
| `register_screen.dart` | `assets/images/app_logo.png` | h=68 |
| `forgot_password_screen.dart` | `assets/images/app_logo.png` | h=60 |
| `otp_verification_screen.dart` | `assets/images/app_logo.png` | h=60 |
| `reset_password_screen.dart` | `assets/images/app_logo.png` | h=60 |
| `learner_dashboard_screen.dart` | `assets/images/app_logo.png` | TopBar h=38 |
| `profile_screen.dart` | `assets/images/app_seal.png` | w/h=22 |
| `web/index.html` | `logo2.svg` (web dir) | boot splash `<img>` |
| `web/favicon.png`, `web/icons/*` | 4 icons | web shell |
| `assets/images/logo2.svg` | same as old logo | bundled |

### Logo cũ trên `dau-viet-admin`
| File | Đường dẫn | Vị trí |
|---|---|---|
| `public/logo.svg` | base64 PNG 1174×385 | old logo w/ tagline |
| `public/logo-seal.svg` | base64 PNG 201×201 | seal mark |
| `public/logo2.svg` | same as logo.svg | unused or alt |
| `admin-shell.tsx` | `/logo.svg`, `/logo-seal.svg` | sidebar expanded/collapsed/mobile topbar |
| `login/page.tsx` | `/logo.svg` | h=20 |
| `not-found.tsx`, `forbidden-state.tsx` | `/logo.svg` | h=12 |
| `mobile-frame.tsx` | `/logo-seal.svg` | h=4 |

### Mascot cũ trên `dau-viet-mobile` (hình ảnh)
| Asset | Loại | Vị trí |
|---|---|---|
| `kabi_reading_book.png` | Rùa xanh | `kabi_mascot_widget.dart` (default) |
| `kabi_celebration_victory.png` | Rùa xanh | `kabi_mascot_widget.dart` (victory/cheering), `lesson_result_screen.dart` |
| `kabi_sync_scroll.png` | Rùa xanh | `event_progress_section.dart` |
| `turtle_welcome.png` | Rùa xanh | `auth_screen.dart`, `learner_dashboard_screen.dart` (TopBar avatar) |
| `turtle_map.png` | Rùa xanh | `learner_dashboard_screen.dart` (hero banner) |
| `turtle_hat_avatar.png` | Rùa xanh | `island_screen.dart` (guide bubble) |
| `profile_buffalo_mascot.png` | Trâu đỏ | `profile_screen.dart` (avatar hồ sơ) |
| `streak_card_buffalo_right.png` | Trâu đỏ | `profile_screen.dart` (thẻ chuỗi ngày) |
| `streak_torch_buffalo_right.png` | Trâu đỏ | `learning_streak_screen.dart` (hero banner) |

### Widgets cần cập nhật
- `kabi_mascot_widget.dart` — static Image, đổi asset path + semantics label → Tê Giác Dấu Việt.
- `interactive_historical_mascot_widget.dart` — bỏ `AnimationController`/`ScaleTransition`, thành StatelessWidget.
- `mascot_speech_bubble.dart` — cập nhật comment + semantics label.
- `mascot_slot.dart` — cập nhật comment.
- `empty_state_card.dart` — semantics label.

### Tests cần cập nhật
- `test/kabi_mascot_widget_test.dart` — asserts on widget type, tap, all moods render.
- `test/visual_storytelling_test.dart` — asserts on `InteractiveHistoricalMascotWidget` type.
- `test/dashboard/learner_dashboard_screen_test.dart` — asserts on `app_logo.png` image height=38.
- `test/learning/learning_flow_issue_29_test.dart` — asserts `KabiMascotWidget`, `MascotSpeechBubble`.

### Cleanup
- `pubspec.yaml` — gỡ `rive: ^0.14.11` dep và `assets/rive/` declaration; xóa `assets/rive/kabi.riv`.
- Không còn file `.dart` nào `import 'package:rive'` → dep an toàn để xóa.

## 3. Thiết kế Chi tiết

### Phase 1 — Xử lý & Xuất Assets Logo (`logo_fianl.svg` → PNG/SVG)

**Nguồn:** `logo_fianl.svg` chứa 2 embedded PNGs (alpha mask L + RGB) đã được tách thành RGBA → crop content bbox (45,158)→(1209,1134).

**Xuất ra:**
1. `scratch/logo_full.png` → `dau-viet-mobile/assets/images/app_logo.png` (1174×385→tỷ lệ giữ nguyên ~3:1, giữ kích thước PNG ~1174×385 hoặc crop sát). Crop content to (45,158)→(1209,1134) = 1164×976 → resize proportionally nếu cần. Giữ 1164×976.
2. `scratch/logo_mark.png` (emblem only, crop top ~1164×800) → `dau-viet-mobile/assets/images/app_seal.png` (square 201×201 → xuất emblem-only 400×400).
3. `dau-viet-mobile/assets/images/logo2.svg` → SVG wrapper chứa `<image>` base64 PNG (same pattern as old `logo2.svg`).
4. `dau-viet-mobile/web/logo2.svg` — cùng file trên.
5. `dau-viet-mobile/web/favicon.png` — resize logo_mark → 32×32 PNG.
6. `dau-viet-mobile/web/icons/Icon-*.png` — resize logo_mark → 192, 512, maskable variants.
7. `dau-viet-admin/public/logo.svg` — SVG wrapper base64 PNG của full logo.
8. `dau-viet-admin/public/logo2.svg` — cùng file.
9. `dau-viet-admin/public/logo-seal.svg` — SVG wrapper base64 PNG của logo_mark.

**Note:** `logo_fianl.svg` chỉ chứa embedded raster (PNG), không có vector path. Chúng ta giữ nguyên base64-PNG-in-SVG pattern hiện tại (đã dùng bởi `logo.svg`, `logo-seal.svg`, `logo2.svg`).

### Phase 2 — Xử lý & Xuất Assets Mascot Tê Giác (`mascot.jpg` → transparent PNG)

**Nguồn:** `mascot.jpg` 1254×1254 RGB, nền trắng, content bbox (104,9)→(1076,1223).

**Xử lý:**
1. Load `mascot.jpg`, convert to RGBA, remove white background (flood-fill / threshold-based white removal with edge feathering).
2. Crop to content bbox → `mascot_full.png`.
3. Tạo portrait/upper-body crop → `mascot_avatar.png` (crop head+upper torso ~60% top).

**Xuất vào các đường dẫn asset hiện hữu (giữ nguyên filename → mọi screen tự đồng bộ):**

| Đường dẫn | Nội dung mới | Note |
|---|---|---|
| `assets/images/kabi_reading_book.png` | Rhino full-body transparent | Default mascot |
| `assets/images/kabi_celebration_victory.png` | Rhino full-body transparent | Victory/celebration |
| `assets/images/kabi_sync_scroll.png` | Rhino upper-body transparent | Progress banner |
| `assets/images/turtle_welcome.png` | Rhino full-body transparent | Auth + dashboard avatar |
| `assets/images/turtle_map.png` | Rhino full-body transparent | Dashboard hero banner |
| `assets/island/scenery/turtle_hat_avatar.png` | Rhino upper-body transparent | Island guide avatar |
| `assets/images/profile_buffalo_mascot.png` | Rhino avatar transparent | Profile avatar |
| `assets/images/streak_card_buffalo_right.png` | Rhino upper-body transparent | Streak card corner |
| `assets/images/streak_torch_buffalo_right.png` | Rhino full-body transparent | Streak hero banner |

**Không đổi filename** → không cần sửa pubspec.yaml asset declarations, mọi màn hình tự động render linh vật mới.

### Phase 3 — Widget & Screen Updates trên `dau-viet-mobile`

1. **`kabi_mascot_widget.dart`:**
   - Đổi semantics label `'Linh vật Kabi'` → `'Tê Giác Dấu Việt'`.
   - Cập nhật comment → mô tả đúng linh vật Tê Giác Dấu Việt.
   - Giữ nguyên `KabiMood` enum và asset-path logic (đã trỏ đúng file names mới).
   - **Không đổi tên class** `KabiMascotWidget` (breaking change không cần thiết — tên class là implementation detail).
2. **`interactive_historical_mascot_widget.dart`:**
   - Bỏ `SingleTickerProviderStateMixin`, `AnimationController`, `ScaleTransition`, `_bounceController`.
   - Chuyển `StatefulWidget` → `StatelessWidget`.
   - Giữ nguyên constructor API, `MascotState` enum, message/status logic.
   - Bỏ `_bounceController.forward()` calls trong `didUpdateWidget` và `onTap`.
   - Update comment "Bé Sĩ Tử" → "Tê Giác Dấu Việt".
3. **`mascot_speech_bubble.dart`:** cập nhật comment `Rùa Kabi đội nón lá` → `Tê Giác Dấu Việt`; semantics label `'Hướng dẫn từ Kabi'` → `'Hướng dẫn từ Tê Giác'`.
4. **`mascot_slot.dart`:** cập nhật comment.
5. **`empty_state_card.dart`:** semantics label (nếu có).
6. **`pubspec.yaml`:** gỡ `rive: ^0.14.11` dependency + dòng `assets/rive/` declaration.
7. **Xóa `assets/rive/kabi.riv`** (file không dùng nữa).

### Phase 4 — Web Admin Updates (`dau-viet-admin`)

1. `public/logo.svg` → SVG wrapper chứa base64 PNG của `logo_full.png` (full lockup with text).
2. `public/logo2.svg` → cùng file trên.
3. `public/logo-seal.svg` → SVG wrapper chứa base64 PNG của `logo_mark.png` (emblem only, square-ish).
4. Cập nhật `alt` text trong:
   - `admin-shell.tsx` — `alt="Dấu Việt"` (đã đúng).
   - `login/page.tsx` — `alt="Dấu Việt"` (đã đúng).
   - `not-found.tsx`, `forbidden-state.tsx` — `alt="Dấu Việt"` (đã đúng).
   - `mobile-frame.tsx` — `alt=""` (đã đúng — decorative).
5. **Không cần đổi TSX code** — chỉ đổi file trong `public/`, các `<img src>` tự động hiển thị logo mới.

### Phase 5 — Verification & Cleanup

1. Chạy `flutter analyze --no-pub` trong `dau-viet-mobile`.
2. Chạy `flutter test` — update tests nếu cần (semantics labels, widget types).
3. Chạy `npm run build` hoặc `npm run lint` trong `dau-viet-admin`.
4. Visual smoke: xem logo/mascot render trong mỗi screen (nếu có thể build).
5. Update `docs/PROJECT_OVERVIEW.md` — ghi nhận Issue #53 thay đổi brand.
6. Update `tasks/TASK-0041/task.json` status + handoff.

## 4. AC → Check Mapping

| AC | Phương thức kiểm chứng |
|---|---|
| AC-1: 100% Logo mới `logo_fianl.svg` | Verify `app_logo.png` là logo mới; `logo2.svg`, `web/logo2.svg`, `web/favicon.png`, `web/icons/*`, `admin/public/logo*.svg` đều chứa ảnh mới; visual check trên screens |
| AC-2: Thay thế Trâu đỏ & Rùa xanh bằng Tê Giác | Verify tất cả 9 mascot asset files là ảnh Tê Giác; `flutter analyze` + `flutter test` pass |
| AC-3: Ảnh tĩnh sắc nét, bỏ animation | Verify `interactive_historical_mascot_widget.dart` không còn AnimationController; `pubspec.yaml` không còn rive dep; `assets/rive/kabi.riv` đã xóa |
| AC-4: Không lỗi UI | `flutter analyze` clean, `flutter test` pass, admin `npm build` pass |
