# Brief: TASK-0004 — Khởi tạo & Phát triển Mobile App Demo (dau-viet-mobile)

## Yêu cầu người dùng
Người dùng yêu cầu phát triển phần mobile app trước dựa trên các thiết kế từ Stitch, sử dụng dữ liệu mock (hard code / mock repository) để chạy demo đánh giá giao diện thực tế trước khi phát triển database và backend.

## Hướng giải quyết
1. Khởi tạo Flutter application trong module `dau-viet-mobile/`.
2. Thiết lập kiến trúc Clean Architecture / Feature-First với tầng Mock Repository giả lập backend.
3. Cài đặt các thư viện: `flutter_riverpod`, `go_router`, `google_fonts`.
4. Cấu hình DauVietTheme với các màu sắc văn hiến và typography Noto Serif & Be Vietnam Pro.
5. Triển khai theo từng phase nhỏ từ 1 đến 3 màn hình, hoàn thành mỗi phase đều dừng lại cho người dùng kiểm tra.
