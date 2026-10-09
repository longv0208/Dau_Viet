# Kế hoạch Kỹ thuật: Khởi tạo và Xây dựng Mobile Demo App (dau-viet-mobile)

## Mục tiêu
Khởi tạo và phát triển ứng dụng di động Flutter `dau-viet-mobile` với kiến trúc Clean Architecture / Feature-First và Mock Repository, cho phép chạy thử nghiệm và đánh giá trực quan toàn bộ 28 màn hình di động theo đúng hệ thống thiết kế Dấu Việt v2.0 (Illustrated Heritage).

## Phạm vi kỹ thuật
- `dau-viet-mobile/` (Khởi tạo Flutter project, lib/, assets/, pubspec.yaml)
- Mock Data & Mock Repositories cho Chiến dịch Bạch Đằng 938 (Hồi 2: Kế sách cọc ngầm)
- Bộ Design Tokens và Theme di sản: giấy dó `#FFFBF4`, đỏ chu sa `#A51F18`, vàng ngự xưởng `#E7B451`, mực nho `#30251F`, Noto Serif + Be Vietnam Pro
- Các màn hình Flutter `M-01` -> `M-28`

## Các giai đoạn thực thi (Sequential Phases)
1. Phase M1: Khởi tạo Flutter project `dau-viet-mobile`, theme di sản, component nền tảng.
2. Phase M2: Màn hình M-01 Splash, M-02 Auth/Guest, M-03 Learner Dashboard.
3. Phase M3: Màn hình M-04 Timeline, M-06 Sa bàn thời kỳ, M-07 Chi tiết sự kiện.
4. Phase M4: Màn hình M-08 Trung tâm 4 Dấu Vết, M-09 Bối cảnh, M-16 Trắc nghiệm MCQ.
5. Phase M5: Màn hình M-11 Ghép thẻ Matching, M-12 Kéo thả sắp xếp niên đại.
6. Phase M6: Màn hình M-13 Kiểm chứng giả thuyết, M-14 Lập luận CER.
7. Phase M7: Màn hình M-18 Hoàn thành, M-19 Nhận thưởng, M-21 Cổ vật Thuyền chiến.
8. Phase M8: Màn hình M-22 Đảo di sản 2.5D, M-27 Túi đồ, M-28 Năng lượng Viện Thái Y.
