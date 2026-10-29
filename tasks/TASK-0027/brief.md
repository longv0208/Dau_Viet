# TASK-0027 — [E2E] Mobile: kiểm thử Đảo Di Sản và bài học (Issue #27)

## Mục tiêu
Kiểm thử end-to-end trên giao diện Flutter Mobile chạy bằng Chrome ở viewport điện thoại (`390x844`), nối với backend Spring Boot (`local` profile) + PostgreSQL thật (`USE_MOCK=false`). Bao phủ hai luồng người học: bài học và Đảo Di Sản.

## Phạm vi
- Khởi chạy backend profile `local`, Flutter Web với `USE_MOCK=false`, Chrome viewport điện thoại (`390x844`); xác thực bằng tài khoản learner test riêng.
- Chuẩn bị dữ liệu kiểm thử có thể tái lập: lesson version đã publish, attempt và inventory/slot phù hợp; dọn dữ liệu riêng của test sau khi chạy xong, không đụng dữ liệu người dùng.
- Tạo kịch bản E2E chạy lại được cho màn học và Đảo Di Sản; không thay bằng widget test hoặc mock repository ở luồng chính.

## Tiêu chí nghiệm thu (Acceptance Criteria)
- **AC-1**: Đăng nhập learner; từ giao diện điều hướng vào một lesson đã publish, bắt đầu/tiếp tục attempt, làm ít nhất một activity đọc và một activity tương tác; UI hiển thị feedback từ server rồi mới sang bước tiếp theo.
- **AC-2**: Tải lại trang giữa bài vẫn tiếp tục đúng attempt và phiên bản bài học; hoàn tất hiển thị kết quả/progress từ backend; retry thao tác hoàn tất không tạo kết quả hoặc phần thưởng trùng.
- **AC-3**: Mở Đảo Di Sản từ giao diện, kiểm tra trạng thái slot có vật phẩm / trống / bị khóa và danh sách vật phẩm theo tài khoản; đặt rồi cất một vật phẩm hợp lệ, tải lại trang và xác nhận trạng thái được lưu ở backend.
- **AC-4**: Kiểm tra ít nhất một đường lỗi của mỗi luồng: chưa đăng nhập bị chuyển về đăng nhập; lỗi API có thông báo và thao tác thử lại; slot bị khóa không thể đặt vật phẩm. Không giả lập thành công khi API lỗi.
- **AC-5**: Test độc lập và chạy lại được: fixture/cleanup rõ ràng, không hard-code ID dữ liệu thật, không log token hoặc đáp án riêng tư; ghi bằng chứng chạy (lệnh, trạng thái PASS/FAIL, ảnh hoặc trace khi lỗi).
