# Phase 03 — Kịch bản E2E Luồng Đảo Di Sản (Heritage Island & Persistence)

## Mục tiêu
Kiểm chứng đầy đủ **AC-3** trên giao diện Đảo Di Sản 2.5D (`/#/island`) ở viewport điện thoại `390x844`, đảm bảo cả thao tác người dùng, hiển thị trực quan (tiêu đề Header không bị cắt, thẻ chào mừng không đè lên bảng chọn ô, đảo nằm cân đối giữa màn hình) và tính bền vững dữ liệu trên backend sau khi `page.reload()`.

## Danh sách Test Cases Chi tiết

### `TC-ISL-01`: Mở Đảo Di Sản từ Trang chủ, Kiểm tra Thẻ Chào mừng & Bố cục Header / Đảo
- **Các bước thực hiện**:
  1. Sau khi đăng nhập learner, tại Trang chủ (`/#/dashboard`), cuộn đến mục `Hành trình của bạn` và nhấn vào thẻ `Đảo Di Sản`.
  2. Chờ màn Đảo Di Sản (`/#/island`) tải xong dữ liệu từ `GET /api/v1/me/island` và `GET /api/v1/me/wallet`.
  3. Chờ thẻ chào mừng lần đầu (`"Chào mừng đến Đảo Di Sản!"`) xuất hiện và nhấn nút `BỎ QUA` để đóng thẻ (lưu cờ `dv_island_onboarding_done_<userId> = true` vào `SharedPreferences`).
- **Kết quả kỳ vọng**:
  - Thẻ chào mừng đóng hoàn toàn và **không tự bật lại** khi chọn ô hay khi `page.reload()`.
  - Thanh Header hiển thị nguyên vẹn tiêu đề **`ĐẢO DI SẢN`** (không bị cắt thành `"ĐẢO DI S..."`), badge `Đảo nhỏ`, và số dư Điểm Sử Ký.
  - Bản đồ đảo Isometric 2.5D hiển thị rõ ràng ở chính giữa khung nhìn; thanh công cụ nổi ở đáy (`Kho đồ`, `Cửa hàng`, `Mở rộng đảo`, `Căn giữa`) nằm gọn trong chiều rộng `390px`, không tràn.

### `TC-ISL-02`: Kiểm tra Trạng thái 3 Loại Slot trên Đảo (Có vật phẩm / Bị khóa / Trống)
- **Các bước thực hiện**:
  1. Nhấn vào **Slot đang có vật phẩm** (`occupiedSlot`, `slot_1` chứa `item1`).
  2. Kiểm tra nội dung thẻ chi tiết `IslandTileSheet` ở đáy màn hình.
  3. Nhấn vào **Slot đang bị khóa** (`lockedSlot`, `slot_5` thuộc vùng `TIER_2`, yêu cầu Đảo Cấp 2).
  4. Kiểm tra nội dung thẻ chi tiết `IslandTileSheet`.
  5. Nhấn vào **Slot trống đã mở khóa** (`emptySlot`, `slot_2` thuộc vùng `TIER_1`).
  6. Kiểm tra nội dung thẻ chi tiết `IslandTileSheet`.
- **Kết quả kỳ vọng**:
  - **Khi chọn `occupiedSlot`**: Hiển thị trạng thái `"Đã xây dựng • Đang trưng bày di sản"`, tên vật phẩm `item1.name`, cùng 2 nút hành động `CẤT VÀO KHO` và `ĐỔI VẬT PHẨM`.
  - **Khi chọn `lockedSlot`**: Hiển thị trạng thái `"Yêu cầu mở rộng Đảo Cấp 2"`, nút `XEM ĐIỀU KIỆN MỞ KHÓA`, và **tuyệt đối không hiển thị nút `ĐẶT VẬT PHẨM DI SẢN`**.
  - **Khi chọn `emptySlot`**: Hiển thị trạng thái `"Ô đất trống • Sẵn sàng xây dựng"` và nút `ĐẶT VẬT PHẨM DI SẢN`.

### `TC-ISL-03`: Kiểm tra Danh sách Vật phẩm theo Tài khoản trong Kho Vật phẩm Trang trí (`IslandInventorySheet`)
- **Các bước thực hiện**:
  1. Từ `emptySlot` đang chọn, nhấn nút `ĐẶT VẬT PHẨM DI SẢN` để mở bottom sheet `KHO VẬT PHẨM TRANG TRÍ`.
  2. Chọn bộ lọc `Đã sở hữu` và kiểm tra danh sách vật phẩm hiển thị.
  3. Chọn bộ lọc `Có thể đặt` và kiểm tra danh sách vật phẩm có thể đặt vào `emptySlot`.
- **Kết quả kỳ vọng**:
  - Ở bộ lọc `Đã sở hữu`: Hiển thị đúng cả 2 vật phẩm thuộc sở hữu của tài khoản test (`item1.name` với nhãn trạng thái `Đang đặt` / `ĐÃ ĐẶT Ô KHÁC`, và `item2.name` với nút `ĐẶT` đang bật).
  - Ở bộ lọc `Có thể đặt`: Chỉ hiển thị vật phẩm chưa đặt (`item2.name`) kèm nút `ĐẶT`.

### `TC-ISL-04`: Đặt Vật phẩm Hợp lệ lên Ô Trống, Tải lại Trang (`page.reload()`) và Xác nhận Lưu ở Backend
- **Các bước thực hiện**:
  1. Trong `KHO VẬT PHẨM TRANG TRÍ`, nhấn nút `ĐẶT` trên thẻ của `item2`.
  2. Chờ thông báo snackbar `"Đã đặt vật phẩm lên Đảo Di Sản thành công!"`.
  3. Thực hiện tải lại trang trình duyệt (`await page.reload()`).
  4. Kiểm tra dữ liệu trả về từ `GET /api/v1/me/island` và nhấn lại vào ô `emptySlot` (`slot_2`) trên giao diện.
- **Kết quả kỳ vọng**:
  - API `PUT /api/v1/me/island/placements/{emptySlot.slotId}` trả về `200 OK` và tăng `rowVersion`.
  - Sau khi `page.reload()`, API `GET /api/v1/me/island` trả về `placedItemId === item2.id` tại `emptySlot.slotId`.
  - Trên giao diện sau khi reload, ô `slot_2` hiển thị công trình `item2.name`, khi nhấn vào hiện `"Đã xây dựng • Đang trưng bày di sản"` và tên `item2.name` (thẻ chào mừng không bật lại che màn hình).

### `TC-ISL-05`: Cất Vật phẩm về Kho, Tải lại Trang (`page.reload()`) và Xác nhận Lưu ở Backend
- **Các bước thực hiện**:
  1. Tại thẻ chi tiết của ô `slot_2` (đang chứa `item2`), nhấn nút `CẤT VÀO KHO`.
  2. Chờ thông báo snackbar `"Đã cất vật phẩm về kho. Bạn có thể chọn vật phẩm khác cho ô này."`.
  3. Thực hiện tải lại trang trình duyệt (`await page.reload()`).
  4. Kiểm tra dữ liệu trả về từ `GET /api/v1/me/island` và nhấn vào ô `slot_2` trên giao diện.
- **Kết quả kỳ vọng**:
  - API `DELETE /api/v1/me/island/placements/{emptySlot.slotId}` trả về `200 OK`.
  - Sau khi `page.reload()`, API `GET /api/v1/me/island` xác nhận `slot_2.placedItemId === null` (trong khi `slot_1.placedItemId` vẫn giữ nguyên `item1.id`).
  - Trên giao diện sau khi reload, ô `slot_2` trở về trạng thái `Ô trống slot_2` (`"Ô đất trống • Sẵn sàng xây dựng"`).
