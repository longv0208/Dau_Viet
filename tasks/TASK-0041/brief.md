# TASK-0041 — Brief: Đồng bộ Logo & Linh vật Tê Giác Dấu Việt (Issue #53)

## 1. Bối cảnh & Vấn đề
Dấu Việt đang dùng logo cũ (chữ "Dấu Việt" xanh rêu + triện đỏ) và linh vật bị phân mảnh giữa 2 hình tượng — Con Trâu đỏ (`buffalo`) trên Profile/Streak và Con Rùa xanh đội nón lá (`turtle`/`Kabi`) trên Auth/Dashboard/Lesson/Island — vi phạm nguyên tắc Brand Identity thống nhất.

Issue #53 yêu cầu:
1. Đồng bộ logo mới `logo_fianl.svg` (Chim Lạc đỏ chu sa + Mặt Trời vàng đồng + chữ `— DẤU VIỆT —`) trên Mobile + Flutter Web + Admin.
2. Thống nhất linh vật Tê Giác `mascot.jpg` (băng đô đỏ, áo trống đồng Đông Sơn, khăn rằn) thay cho cả Trâu đỏ và Rùa xanh, chỉ dùng ảnh tĩnh, bỏ animation Rive.

## 2. Phạm vi
- **Mobile (`dau-viet-mobile`):** Thay `app_logo.png`, `app_seal.png`, `logo2.svg`, 9 mascot assets, `web/logo2.svg`, `web/favicon.png`, `web/icons/*`; cập nhật `kabi_mascot_widget.dart`, `interactive_historical_mascot_widget.dart`, `mascot_speech_bubble.dart`, `mascot_slot.dart`, `empty_state_card.dart`; gỡ `rive` dep + `assets/rive/kabi.riv`.
- **Admin (`dau-viet-admin`):** Thay `public/logo.svg`, `logo2.svg`, `logo-seal.svg`.
- **Không đổi:** API, DB, business logic, filename assets (giữ nguyên → screens tự đồng bộ).

## 3. Phương án
- Giữ nguyên file names → zero code changes trên screens; chỉ cần đổi nội dung file.
- Bỏ `rive` dep vì không còn file nào import `package:rive`.
- `interactive_historical_mascot_widget.dart`: StatefulWidget → StatelessWidget, bỏ bounce animation.
- `pubspec.yaml`: gỡ `rive: ^0.14.11` + `assets/rive/` entry.
