# Phase 02 — Kịch bản E2E Luồng Bài học (Lesson Lifecycle & Version Pinning)

## Mục tiêu
Kiểm chứng đầy đủ **AC-1** và **AC-2** trên giao diện thực tế của Flutter Mobile chạy trong Chrome (`390x844`), kết hợp kiểm tra không tràn giao diện và không chồng lấp phần tử.

## Danh sách Test Cases Chi tiết

### `TC-LES-01`: Đăng nhập Learner và Điều hướng từ Trang chủ vào Bài học đã xuất bản
- **Các bước thực hiện**:
  1. Mở `/#/auth` trên trình duyệt ở kích thước `390x844`.
  2. Điền email và mật khẩu của tài khoản learner test vào 2 trường `Nhập email hoặc tên đăng nhập` và `Nhập mật khẩu`.
  3. Nhấn nút `Đăng nhập`.
  4. Tại màn Trang chủ (`/#/dashboard`), kiểm tra hiển thị khối `Hành trình của bạn` và thẻ `Sự kiện nổi bật`.
  5. Cuộn tới và nhấn `Xem chi tiết →` trên thẻ sự kiện để mở màn `CHI TIẾT CHIẾN DỊCH` (`/#/campaign/{eventId}`).
  6. Kiểm tra danh sách dưới mục `BÀI HỌC LỊCH SỬ`, tìm thẻ bài học `Bài học E2E Di Sản <runId>` và nhấn vào thẻ.
  7. Tại màn `LessonEntryScreen` (`/#/learning/lesson/{lessonId}`), kiểm tra hiển thị đúng tiêu đề bài học và câu hỏi trung tâm (`centralQuestion`), nhấn nút `BẮT ĐẦU HỌC ›`.
- **Kết quả kỳ vọng**:
  - API `POST /api/v1/lessons/{lessonId}/attempts` trả về `200 OK` kèm `attemptId` và `lessonVersionId == versionV1Id`.
  - Trình duyệt cập nhật URL thành `/#/learning/attempt/{attemptId}`.
  - Màn `LessonPlayerScreen` hiển thị Stage 1 (`Bối cảnh lịch sử (v1)`), tiến độ `0/2`, và hướng dẫn của activity đọc (`READ`).

### `TC-LES-02`: Hoàn thành Activity Đọc (`READ`) và Kiểm chứng Phản hồi từ Server trước khi chuyển bước
- **Các bước thực hiện**:
  1. Kiểm tra nội dung bài đọc (`Tư liệu E2E <runId> (v1)`) hiển thị đầy đủ, không tràn khung.
  2. Nhấn nút `ĐÃ ĐỌC XONG, TIẾP TỤC`.
  3. Quan sát màn hình phản hồi ngay sau khi API `POST /api/v1/attempts/{attemptId}/activities/act-read-context/submissions` trả về.
- **Kết quả kỳ vọng**:
  - Giao diện **không tự động nhảy sang câu tiếp theo** mà dừng ở màn phản hồi, hiển thị rõ huy hiệu `CHÍNH XÁC! XUẤT SẮC!` và đúng nguyên văn phản hồi từ server: `"Phản hồi từ server: Đã ghi nhận hoàn thành đọc tư liệu bối cảnh."`.
  - Chỉ sau khi người học nhấn nút `TIẾP TỤC ›`, ứng dụng mới gọi `GET /api/v1/attempts/{attemptId}/current` và chuyển sang Stage 2 (`Kiểm chứng tư liệu (v1)`), cập nhật tiến độ trên thanh đầu trang thành `1/2`.

### `TC-LES-03`: Tải lại trang (`page.reload()`) giữa bài học khi Admin vừa xuất bản Version 2 (Kiểm chứng Attempt & Version Pinning)
- **Các bước thực hiện**:
  1. Khi người học đang ở Activity 2 (`MULTIPLE_CHOICE`, tiến độ `1/2`), gọi `fixture.publishLessonV2()` để Admin cập nhật bài học và xuất bản `versionNo: 2` (`lessonVersionV2Id != versionV1Id`).
  2. Thực hiện tải lại trang trình duyệt (`await page.reload()`).
  3. Chờ response từ `GET /api/v1/attempts/{attemptId}/content` và `GET /api/v1/attempts/{attemptId}/current`.
- **Kết quả kỳ vọng**:
  - Phiên đăng nhập được khôi phục trước khi route mount (không bị văng về `/auth` hay báo lỗi `401`).
  - URL trình duyệt giữ nguyên `/#/learning/attempt/{attemptId}`.
  - Payload từ `/api/v1/attempts/{attemptId}/content` trả về `lessonVersionId === versionV1Id` và `versionNo === 1` (attempt đang học tiếp tục gắn chặt với snapshot `v1`, không bị ảnh hưởng bởi `v2`).
  - Giao diện hiển thị đúng Activity 2 (`Chọn nhận định phù hợp với tư liệu lịch sử (v1).`) và giữ nguyên tiến độ `1/2` (không bị reset về `0/2`).

### `TC-LES-04`: Làm Activity Tương tác (`MULTIPLE_CHOICE`) — Thử sai nhận phản hồi Server rồi chọn đúng
- **Các bước thực hiện**:
  1. Kiểm tra bóng thoại hướng dẫn của Mascot hiển thị đúng ngữ cảnh câu hỏi trắc nghiệm (không báo nhầm là câu Đúng/Sai).
  2. Chọn phương án sai (`"Bão tuyết mùa đông làm đóng băng mặt sông"`) và nhấn `GỬI CÂU TRẢ LỜI`.
  3. Kiểm tra thông báo phản hồi sai từ server và mức trừ Thể lực.
  4. Chọn lại phương án đúng (`"Thủy triều rút nhanh làm lộ trận địa ngầm"`) và nhấn `GỬI CÂU TRẢ LỜI`.
- **Kết quả kỳ vọng**:
  - Ở lượt trả lời sai: hiển thị đúng phản hồi từ server `"Phản hồi từ server: Chưa đúng, hãy xem lại chi tiết thủy triều trong tư liệu."`, giữ người học ở lại câu hỏi để làm lại (`maxAttempts: 2`).
  - Ở lượt trả lời đúng: hiển thị khung phản hồi xanh `"Phản hồi từ server: Chính xác! Thủy triều rút nhanh khớp với sử liệu."` và nút `HOÀN THÀNH BÀI HỌC`.
  - **Kiểm tra hiển thị**: Huy hiệu đỏ `-10 Thể lực` của lượt sai trước đó phải được gỡ bỏ ngay khi nộp lượt mới, **tuyệt đối không nằm đè lên khung phản hồi xanh** của lượt trả lời đúng.

### `TC-LES-05`: Hoàn tất Bài học, Kiểm tra Màn Kết quả (`LessonResultScreen`) và Tiến độ (`/api/v1/me/progress`)
- **Các bước thực hiện**:
  1. Nhấn nút `HOÀN THÀNH BÀI HỌC`.
  2. Quan sát màn `LessonResultScreen` (`/#/learning/result/{attemptId}`).
  3. Gọi `GET /api/v1/me/progress` kiểm tra tiến độ trên server.
- **Kết quả kỳ vọng**:
  - Màn Kết quả hiển thị tiêu đề `HOÀN THÀNH BÀI HỌC`, điểm số, phần thưởng `+100 XP` và `+50` Điểm Sử Ký, chuỗi ngày học (`Chuỗi 1 ngày học liên tiếp`), không bị tràn chữ ở viewport `390x844`.
  - `/api/v1/me/progress` trả về `completedCount === 1` và `inProgress.length === 0`.

### `TC-LES-06`: Kiểm chứng Idempotency khi gọi lặp thao tác Hoàn tất Bài học
- **Các bước thực hiện**:
  1. Gửi lặp 3 lần `POST /api/v1/attempts/{attemptId}/complete` (2 lần cùng `Idempotency-Key` và 1 lần không kèm header `Idempotency-Key`).
  2. Truy vấn trực tiếp PostgreSQL kiểm tra số bản ghi trong `lesson_results` và `reward_transactions` cho `attemptId`.
- **Kết quả kỳ vọng**:
  - Cả 3 lần gọi lại đều trả về `200 OK` với `alreadyCompleted: true`.
  - Trong PostgreSQL: `count(lesson_results) == 1`, `count(reward_transactions WHERE reward_type = 'EXP') == 1`, `count(reward_transactions WHERE reward_type = 'HISTORY_POINTS') == 1` (không tạo kết quả hoặc phần thưởng trùng).
