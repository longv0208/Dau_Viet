# Phase 04 — Kịch bản Đường lỗi, Bảo mật & Chống giả lập thành công (Error Paths)

## Mục tiêu
Kiểm chứng đầy đủ **AC-4** và **AC-5**: đảm bảo ứng dụng xử lý đúng các đường lỗi xác thực, lỗi mạng/máy chủ (`500`/`503`), lỗi phân quyền nghiệp vụ (`403 SLOT_LOCKED`), có thao tác thử lại thật và **tuyệt đối không giả lập thành công (no fake optimistic success)** khi API thất bại.

## Danh sách Test Cases Chi tiết

### `TC-ERR-01`: Chưa đăng nhập truy cập trực tiếp vào Màn Bài học và Màn Đảo Di Sản bị chuyển hướng về `/auth`
- **Các bước thực hiện**:
  1. Mở trình duyệt mới hoàn toàn chưa có token trong `localStorage`.
  2. Điều hướng trực tiếp tới `/#/learning/lesson/{lessonId}` và `/#/learning/attempt/{attemptId}`.
  3. Điều hướng trực tiếp tới `/#/island`.
- **Kết quả kỳ vọng**:
  - Bộ định tuyến `GoRouter` (sau khi `restore()` xác nhận `AuthStatus.unauthenticated`) tự động chuyển hướng cả 3 đường dẫn về `/#/auth` và hiển thị màn hình `Đăng nhập`.

### `TC-ERR-02`: Lỗi API (`503 SERVICE_UNAVAILABLE`) khi nộp Activity trong Bài học — Hiện lỗi, Không giả lập thành công & Thử lại thành công
- **Các bước thực hiện**:
  1. Đăng nhập learner và bắt đầu attempt bài học (đang ở Activity 1 `READ`, tiến độ `0/2`).
  2. Dùng `page.route('**/api/v1/attempts/*/activities/*/submissions')` chặn đúng 1 lần gọi `POST` đầu tiên và trả về HTTP `503`:
     ```json
     {
       "code": "SERVICE_UNAVAILABLE",
       "message": "Máy chủ bài học tạm thời gián đoạn, vui lòng thử lại.",
       "details": {},
       "traceId": "e2e-lesson-submit-err"
     }
     ```
  3. Nhấn nút `ĐÃ ĐỌC XONG, TIẾP TỤC`.
  4. Kiểm tra giao diện khi lỗi, sau đó nhấn lại `ĐÃ ĐỌC XONG, TIẾP TỤC` lần thứ 2 (đi thẳng tới backend thật).
- **Kết quả kỳ vọng**:
  - Ở lần nhấn thứ nhất (lỗi `503`):
    - Hiển thị khung thông báo lỗi màu đỏ dưới đáy: `"Máy chủ bài học tạm thời gián đoạn, vui lòng thử lại."`.
    - **Không giả lập thành công**: Không hiện màn chúc mừng `CHÍNH XÁC! XUẤT SẮC!`, không hiện nút `TIẾP TỤC ›`, thanh tiến độ vẫn giữ ở `0/2`.
  - Ở lần nhấn thử lại thứ hai: Request đi tới backend thật, trả về `200 OK` và hiển thị màn chúc mừng `CHÍNH XÁC! XUẤT SẮC!`.

### `TC-ERR-03`: Lỗi API (`500 INTERNAL_ERROR`) khi tải Màn Đảo Di Sản — Hiện thông báo lỗi & Nút `THỬ LẠI` khôi phục thành công
- **Các bước thực hiện**:
  1. Dùng `page.route('**/api/v1/me/island')` chặn đúng 1 lần gọi `GET` đầu tiên và trả về HTTP `500`:
     ```json
     {
       "code": "INTERNAL_ERROR",
       "message": "Mất kết nối máy chủ Đảo Di Sản khi tải dữ liệu.",
       "details": {},
       "traceId": "e2e-island-load-err"
     }
     ```
  2. Điều hướng tới `/#/island`.
  3. Kiểm tra màn hình lỗi, sau đó nhấn nút `THỬ LẠI`.
- **Kết quả kỳ vọng**:
  - Khi API lỗi: Hiển thị màn lỗi `"Không thể kết nối Đảo Di Sản"`, thông điệp `"Mất kết nối máy chủ Đảo Di Sản khi tải dữ liệu."` và nút `"THỬ LẠI"` (tuyệt đối không tự động fallback sang dữ liệu đảo giả lập `MockIslandRepository`).
  - Khi nhấn `"THỬ LẠI"`: Gọi lại `GET /api/v1/me/island` tới backend thật và hiển thị bản đồ Đảo Di Sản.

### `TC-ERR-04`: Lỗi API (`500 INTERNAL_ERROR`) khi Đặt Vật phẩm lên Đảo — Không giả lập đã đặt trên UI hoặc Backend
- **Các bước thực hiện**:
  1. Dùng `page.route('**/api/v1/me/island/placements/{emptySlot.slotId}')` chặn 1 lần `PUT` đầu tiên và trả về HTTP `500` với message `"Không thể lưu vị trí vật phẩm do lỗi máy chủ."`.
  2. Chọn `emptySlot` (`slot_2`), nhấn `ĐẶT VẬT PHẨM DI SẢN`, chọn vật phẩm `item2` và nhấn `ĐẶT`.
- **Kết quả kỳ vọng**:
  - Hiển thị snackbar báo lỗi `"Không thể lưu vị trí vật phẩm do lỗi máy chủ."`.
  - **Không giả lập thành công**: Ô `slot_2` trên UI vẫn giữ trạng thái `"Ô đất trống • Sẵn sàng xây dựng"`, và `GET /api/v1/me/island` trên backend vẫn trả về `placedItemId === null`.

### `TC-ERR-05`: Slot bị khóa không thể đặt vật phẩm trên cả Giao diện và Backend (`403 SLOT_LOCKED`)
- **Các bước thực hiện**:
  1. Trên giao diện `/#/island`, nhấn chọn `lockedSlot` (`slot_5`, yêu cầu Đảo Cấp 2).
  2. Kiểm tra bảng hành động ở đáy (`IslandTileSheet`).
  3. Gọi trực tiếp `PUT /api/v1/me/island/placements/{lockedSlot.slotId}` với token của learner và `expectedRevision` hiện tại.
- **Kết quả kỳ vọng**:
  - Trên UI: Chỉ hiển thị `"Yêu cầu mở rộng Đảo Cấp 2"` và nút `"XEM ĐIỀU KIỆN MỞ KHÓA"`, không có nút đặt vật phẩm.
  - Trên Backend: Trả về HTTP `403 FORBIDDEN` với `code === "SLOT_LOCKED"`.
