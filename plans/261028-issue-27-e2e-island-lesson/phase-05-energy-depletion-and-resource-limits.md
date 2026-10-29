# Phase 05 — Kịch bản Làm sai nhiều lần dẫn đến Hết Thể lực (`ENERGY_DEPLETED`), Hết lượt thử (`maxAttempts`) & Giới hạn Tài nguyên Đảo/Shop

## 1. Mục tiêu
Bao phủ toàn bộ các trường hợp biên khi người học **làm sai quá nhiều lần** trong bài học hoặc **không đủ tài nguyên** trên Đảo Di Sản:
1. **Làm sai liên tiếp dẫn đến cạn Thể lực (`currentEnergy == 0`)**:
   - Trừ Thể lực chính xác sau mỗi lần nộp sai câu hỏi có chấm điểm (`-10 Thể lực`), bao gồm cả trường hợp **số dư lẻ `< 10` bị clamp** (ví dụ còn `5` Thể lực thì chỉ trừ `-5 Thể lực` về `0`).
   - Khi `currentEnergy == 0`, lần nộp câu chấm điểm kế tiếp bị chặn bởi `409 ENERGY_DEPLETED` (không mất lựa chọn đang chọn, không mất lượt thử `attemptCounts`), bật hộp thoại **`"Hết Thể lực"`** kèm đồng hồ đếm ngược từ `serverTime` & `nextRecoveryAt`.
   - Điều hướng từ hộp thoại sang **`"VIỆN THÁI Y"`** (`/#/energy` — `EnergyManagementScreen`) hiển thị đúng `0 / 100`, thanh năng lượng đỏ cạn kiệt, cảnh báo hết thể lực, không tràn bố cục ở `390x844` và `360x800`.
   - Khi `currentEnergy == 0`, hoạt động **không chấm điểm (`READ`)** vẫn đọc và nộp được bình thường; sau khi Thể lực hồi phục (qua chu kỳ lazy-recovery), người học tiếp tục nộp câu hỏi chấm điểm và hoàn thành bài học.
2. **Làm sai hết sạch số lượt thử tối đa của câu hỏi (`maxAttempts` Exhaustion khi còn Thể lực — Chống kẹt bài học)**:
   - Khi người học còn Thể lực nhưng trả lời sai đủ `maxAttempts` lần (ví dụ 2/2 lần sai), server trả `outcome: INCORRECT`, `output.exhausted: true`, `completed: true` (cho phép đi tiếp để không bị soft-lock), UI hiện thông báo hết lượt thử và nút `TIẾP TỤC ›` / `HOÀN THÀNH BÀI HỌC`, điểm tổng kết bài học giảm tương ứng (`< 100`).
3. **Giới hạn Tài nguyên trên Đảo Di Sản & Cửa Hàng (`/island` & `/island/shop`)**:
   - Chưa đủ Level/EXP mở rộng đảo (`canUpgrade == false` / `422 ISLAND_UPGRADE_INSUFFICIENT_LEVEL`).
   - Không đủ Điểm Sử Ký mua vật phẩm trong Cửa Hàng Di Sản (`balance < pricePoints` -> khóa nút `MUA` / `INSUFFICIENT_FUNDS`).

---

## 2. Danh sách Test Cases Chi tiết

### `TC-ENG-01`: Trả lời sai liên tiếp làm giảm Thể lực và Clamp mức trừ khi số dư `< 10` (`15 -> 5 -> 0`)
- **Chuẩn bị dữ liệu (Fixture)**:
  - Thiết lập `user_energy.current_energy = 15` cho learner kiểm thử; bài học có câu hỏi `MULTIPLE_CHOICE` cấu hình `maxAttempts: 5` (`incorrectPenalty: 10`).
- **Các bước thực hiện**:
  1. Learner vào bài học, hoàn thành bước đọc `READ` (không tốn Thể lực, `currentEnergy` vẫn là `15`).
  2. Sang câu hỏi `MULTIPLE_CHOICE`:
     - **Lượt sai 1**: Chọn đáp án sai -> nhấn `GỬI CÂU TRẢ LỜI`.
     - **Lượt sai 2**: Chọn đáp án sai (hoặc giữ đáp án sai với key mới) -> nhấn `GỬI CÂU TRẢ LỜI`.
- **Kết quả kỳ vọng**:
  - Sau lượt sai 1: API trả về `energyDeducted: 10`, `energy.currentEnergy: 5`; UI hiển thị phản hồi sai nối chuỗi **`−10 Thể lực`**.
  - Sau lượt sai 2: Vì chỉ còn `5` Thể lực (`< 10`), server clamp mức trừ `amount = min(10, 5) = 5`, trả về `energyDeducted: 5`, `energy.currentEnergy: 0`, `canSubmitGraded: false`; UI hiển thị phản hồi sai nối chuỗi **`−5 Thể lực`** (không hiển thị sai thành `−10 Thể lực`).
  - Trong bảng `energy_transactions`: Có đúng 2 bản ghi `DEBIT` (`10` và `5`), `balance_after` lần lượt là `5` và `0`.

### `TC-ENG-02`: Cố nộp câu hỏi chấm điểm khi `currentEnergy == 0` -> Server trả `409 ENERGY_DEPLETED`, hiện Dialog `"Hết Thể lực"` và mở `"Viện Thái Y"` (`/#/energy`)
- **Các bước thực hiện**:
  1. Ngay khi `currentEnergy == 0` (sau `TC-ENG-01`), learner chọn đáp án đúng và nhấn `GỬI CÂU TRẢ LỜI` (lượt 3).
  2. Kiểm tra hộp thoại `"Hết Thể lực"` bật lên trên màn hình `390x844`.
  3. Nhấn nút **`Ở LẠI XEM TIẾP`** trên hộp thoại, kiểm tra trạng thái màn hình câu hỏi.
  4. Nhấn lại `GỬI CÂU TRẢ LỜI` để mở lại hộp thoại `"Hết Thể lực"`, sau đó nhấn nút **`VIỆN THÁI Y`**.
- **Kết quả kỳ vọng**:
  - API trả về HTTP `409 CONFLICT` với `code: "ENERGY_DEPLETED"`, `details.currentEnergy === 0`, kèm `nextRecoveryAt` và `serverTime`.
  - Lượt nộp bị từ chối ở cổng năng lượng: **không tăng `attemptCount`**, **không chấm điểm**, **không làm mất lựa chọn người học đang chọn**.
  - Hộp thoại **`"Hết Thể lực"`** hiển thị rõ:
    - Nội dung giải thích đã hết Thể lực cho câu hỏi chấm điểm + thời gian tự hồi `+5 Thể lực sau khoảng ... phút ... giây nữa`.
    - Khi nhấn `Ở LẠI XEM TIẾP`: đóng hộp thoại, giữ nguyên màn câu hỏi.
    - Khi nhấn `VIỆN THÁI Y`: điều hướng sang `/#/energy` (`EnergyManagementScreen`), hiển thị tiêu đề `VIỆN THÁI Y`, `QUẢN LÝ THỂ LỰC`, chỉ số **`0 / 100`**, thông báo `"Thể lực đã cạn. Bạn vẫn có thể đọc tư liệu và ôn tập trong lúc chờ hồi phục."`, không bị lỗi tràn giao diện.

### `TC-ENG-03`: Hồi phục Thể lực (Lazy Recovery) và Tiếp tục Hoàn thành Bài học đang dở
- **Các bước thực hiện**:
  1. Khi learner đang cạn Thể lực (`0 / 100`), lùi mốc `user_energy.last_recovered_at` về trước đó `20 phút` (vượt qua 1 chu kỳ hồi phục `15 phút = +5 Thể lực`) hoặc cấp hồi phục trong DB.
  2. Từ màn Viện Thái Y (`/#/energy`) nhấn quay lại bài học (`/#/learning/attempt/{attemptId}`).
  3. Chọn đáp án đúng và nhấn `GỬI CÂU TRẢ LỜI`.
- **Kết quả kỳ vọng**:
  - `EnergyService.gateForGradedSubmit()` tự động thực hiện `recoverLocked()` (`0 -> 5 Thể lực`), cho phép lượt nộp đi qua (`200 OK`).
  - Lượt trả lời đúng không bị trừ Thể lực (`energyDeducted: 0`, `currentEnergy: 5`), hiển thị phản hồi đúng từ server và cho phép nhấn `HOÀN THÀNH BÀI HỌC`.

### `TC-ENG-04`: Làm sai hết sạch số lượt thử của câu hỏi (`maxAttempts = 2` Exhaustion khi còn Thể lực) — Không làm kẹt người học
- **Các bước thực hiện**:
  1. Learner có đầy Thể lực (`100 / 100`), vào câu hỏi `MULTIPLE_CHOICE` có `maxAttempts: 2`.
  2. Lượt 1: Chọn đáp án sai -> nhấn `GỬI CÂU TRẢ LỜI` -> nhận phản hồi sai (`attemptCount: 1`, `completed: false`), vẫn ở lại câu hỏi.
  3. Lượt 2: Tiếp tục chọn đáp án sai -> nhấn `GỬI CÂU TRẢ LỜI`.
- **Kết quả kỳ vọng**:
  - Server trả về `outcome: "INCORRECT"`, `output.exhausted: true`, `completed: true` (hoàn thành về tiến độ để không khóa cứng người học).
  - Giao diện hiển thị thông báo đã hết lượt thử (`"Chưa chính xác — đã hết lượt thử. Đi tiếp nhé. −10 Thể lực"`), và hiển thị nút **`HOÀN THÀNH BÀI HỌC`** (hoặc `TIẾP TỤC ›`).
  - Khi nhấn `HOÀN THÀNH BÀI HỌC`, màn Kết quả hiển thị điểm số thấp hơn 100 (`0/100` cho câu trắc nghiệm đã cạn lượt), chứng minh tách biệt rõ ràng giữa **tiến độ hoàn thành (progress)** và **điểm kiến thức (knowledge score)**.

### `TC-ISL-06`: Kiểm tra Mở rộng Đảo khi chưa đủ Level/EXP và Mua hàng khi không đủ Điểm Sử Ký
- **Các bước thực hiện**:
  1. Trên màn Đảo Di Sản (`/#/island`), nhấn nút `Mở rộng đảo` để mở `IslandUpgradePanel`.
  2. Kiểm tra thông tin điều kiện mở rộng sang `Đảo vừa` (`Level 2 (500 EXP)`).
  3. Mở `Cửa hàng` (`/#/island/shop`), kiểm tra trạng thái nút trên vật phẩm đã sở hữu và vật phẩm có giá cao hơn số dư Điểm Sử Ký hiện tại.
- **Kết quả kỳ vọng**:
  - Trong `IslandUpgradePanel`: Hiển thị nút `TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP` (ẩn nút nâng cấp trực tiếp); gọi API `POST /api/v1/me/island/upgrade` khi chưa đủ Level trả về `422 ISLAND_UPGRADE_INSUFFICIENT_LEVEL`.
  - Trong `IslandShopScreen` (`/#/island/shop`): Vật phẩm đã có trong kho hiện nhãn `ĐÃ SỞ HỮU`; vật phẩm chưa đủ điểm có nút `MUA` ở trạng thái vô hiệu hóa (disabled); gọi trực tiếp `POST /api/v1/me/shop/purchases` khi thiếu điểm trả về lỗi `INSUFFICIENT_FUNDS`.
