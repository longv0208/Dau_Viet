# Phase 06 — Kiểm thử Lỗi Runtime, Không Tràn Giao diện (Overflow/Visual QA) & Sửa lỗi UI

## 1. Mục tiêu
Đảm bảo khi chạy ứng dụng lên ở cả 2 kích thước màn hình điện thoại phổ biến (**`390x844`** — iPhone 13/14 và **`360x800`** — Android phổ thông):
1. **Không có bất kỳ lỗi Runtime / Console / RenderFlex Overflow nào** (`FlutterError`, `A RenderFlex overflowed by ... pixels`, `UncaughtException`).
2. **Không có hiện tượng cắt chữ tiêu đề, tràn nút, hoặc đè lớp (overlap)** giữa các thành phần UI trên toàn bộ các màn hình thuộc phạm vi kiểm thử (bao gồm cả hộp thoại `"Hết Thể lực"` và màn `"Viện Thái Y"` `/#/energy`).

---

## 2. Danh sách các điểm sửa lỗi Hiển thị & Runtime trên App (`dau-viet-mobile`)

### 2.1. Sửa cắt chữ tiêu đề `"ĐẢO DI SẢN"` trên Header màn Đảo Di Sản (`BUG-03`)
- **File**: `dau-viet-mobile/lib/features/island/presentation/island_screen.dart` (`_buildHeader`, dòng `260-482`).
- **Vấn đề**: Hiện tại trên màn `390x844`, Header đặt 4 `IconButton` (`Kho Đồ`, `Cửa Hàng`, `Mở Rộng Đảo`, `Hướng dẫn`) + `WalletPill` + `Back` trên cùng 1 hàng với tiêu đề, khiến chữ `"ĐẢO DI SẢN"` bị cắt thành **`"ĐẢO DI S..."`** và dòng phụ đề bị cắt thành **`"Đảo nhỏ — Level tài kh..."`**. Trong khi đó, 3 nút `Kho đồ`, `Cửa hàng`, `Mở rộng đảo` đã luôn hiển thị ở thanh công cụ nổi phía dưới đáy màn hình.
- **Giải pháp**:
  - Trên màn hình hẹp (`MediaQuery.sizeOf(context).width < 480`), trên thanh Header chỉ giữ: nút `Back`, cụm tiêu đề **`ĐẢO DI SẢN`** + badge `Đảo nhỏ` + phụ đề `Level tài khoản N`, `WalletPill` (nhấn vào mở Cửa hàng), và nút `?` (`Hướng dẫn`).
  - Kết quả: Tiêu đề **`ĐẢO DI SẢN`** và dòng **`Đảo nhỏ — Level tài khoản 1`** hiển thị trọn vẹn 100% trên cả màn `390x844` và `360x800`, không bao giờ bị cắt `...`.

### 2.2. Sửa lỗi Badge đỏ `⚡ -10 Thể lực` đè lên khung phản hồi ĐÚNG hoặc Dialog `"Hết Thể lực"` ở màn Bài học (`BUG-04`)
- **File**: `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart` (`_showEnergyPenaltyToast` & `_EnergyPenaltyToast`, dòng `1282-1404`).
- **Vấn đề**: Khi trả lời sai ở lượt 1 (bật `OverlayEntry` `-10 Thể lực` trong 2.2s ở `bottom: 110`) rồi trả lời đúng ngay ở lượt 2 (hoặc bật Dialog `"Hết Thể lực"` ở lượt tiếp theo), badge đỏ `-10 Thể lực` vẫn tồn tại và đè thẳng lên dòng chữ phản hồi xanh của server hoặc đè lên Dialog.
- **Giải pháp**:
  - Lưu tham chiếu `OverlayEntry? _energyToastEntry;` trong `_LessonPlayerScreenState` và tạo hàm `_dismissEnergyPenaltyToast()`.
  - Gọi `_dismissEnergyPenaltyToast()` ngay khi bắt đầu `_submit()` mới, khi `_handleEnergyDepleted()` mở Dialog `"Hết Thể lực"`, khi `_applyResult()` nhận kết quả đúng (`fb.tone == _FeedbackTone.success`), và trong `dispose()`.
  - Tăng khoảng cách `bottom` của `_EnergyPenaltyToast` lên `156` để ngay cả khi đang hiển thị ở lượt sai, badge nằm phía trên khung `_feedbackCard` chứ không che chữ bên trong `_feedbackCard`.

### 2.3. Sửa lỗi Thẻ Chào mừng Đảo Di Sản bật trễ đè lên `IslandTileSheet` (`BUG-05`)
- **File**: `dau-viet-mobile/lib/features/island/presentation/island_screen.dart` (`_syncOnboardingForCurrentUser` & `_buildIslandContent`) và `e2e/specs/island-and-lesson.spec.mjs`.
- **Giải pháp**:
  - Trong `island_screen.dart`: Chỉ render `IslandTileSheet` khi `!_showWelcomeCard`, và trong `_syncOnboardingForCurrentUser` nếu người dùng đã tương tác chọn slot (`_selectedSlotId != null`) thì không tự bật đè `_showWelcomeCard`.
  - Trong E2E spec: Chờ tường minh `await expect(skipWelcomeBtn).toBeVisible({ timeout: 5_000 })` rồi click `BỎ QUA`, và xác nhận `await expect(skipWelcomeBtn).toBeHidden()` trước khi thao tác và chụp ảnh đảo.

### 2.4. Sửa câu thoại Mascot bị nhầm "Đúng hoặc Sai" & Fallback Avatar Mascot trên Web (`BUG-06`)
- **File**:
  - `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart` (`_resolveMascotPrompt`, dòng `706-712`).
  - `dau-viet-mobile/lib/core/widgets/kabi_mascot_widget.dart` (`_buildFallbackMascot`, dòng `175-195`).
- **Giải pháp**:
  - Trong `_resolveMascotPrompt`: Chỉ hiển thị câu nhắc `"Bạn hãy chọn Đúng hoặc Sai nhé!"` khi 2 phương án thực sự có nhãn là `Đúng`/`Sai` (hoặc `True`/`False`).
  - Trong `KabiMascotWidget`: Khi `_controller == null` (đang tải Rive trên Web) hoặc `_hasError == true`, hiển thị hình ảnh linh vật tĩnh (`assets/images/turtle_welcome.png` kèm `errorBuilder` icon) thay vì `SizedBox` trắng trơn.

---

## 3. Các Kiểm tra Tự động về Runtime & Hiển thị trong Bộ Test E2E (`TC-VIS-01..03`)

1. **`TC-VIS-01` — Giám sát Console / PageError / Overflow**:
   - Lắng nghe `page.on('pageerror', ...)` và `page.on('console', ...)`.
   - Bất kỳ thông báo nào chứa `RenderFlex overflowed`, `A RenderFlex overflowed`, `FlutterError`, `Assertion failed`, hoặc `Uncaught` sẽ làm bài test **FAIL ngay lập tức**.
2. **`TC-VIS-02` — Giám sát Tài nguyên & API Network**:
   - Lắng nghe `page.on('response', ...)`: mọi request tải ảnh/font/asset (`/assets/...`) trả về `status >= 400` đều bị ghi nhận và đánh fail.
3. **`TC-VIS-03` — Kiểm tra Đa kích thước màn hình (`390x844` & `360x800`) và Kiểm tra Bounding Box**:
   - Kiểm tra trên cả viewport `390x844` và viewport nhỏ `360x800` cho: Màn Bài học, Dialog `"Hết Thể lực"`, Màn `"Viện Thái Y"` (`/#/energy`), Màn Kết quả, Màn Đảo Di Sản (`/#/island`), Kho vật phẩm, Bảng Mở rộng Đảo, và Cửa Hàng Di Sản (`/#/island/shop`).
