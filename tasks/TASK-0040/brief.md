# TASK-0040 — Brief: Đại tu toàn diện Đảo Di Sản theo thiết kế mẫu 9 màn hình (Issue #50)

## 1. Bối cảnh & Vấn đề
Giao diện Đảo Di Sản (`/island`) hiện tại còn một số điểm hạn chế so với bản thiết kế mẫu 9 màn hình (`plans/261030-issue-50-heritage-island-overhaul/island-mockup.png`):
- Mặt đảo đang ghép từ các ô cỏ tối màu rời rạc và công trình thiếu bộ sprite 2.5D đồng bộ (*Nhà rông, Chùa cổ, Tháp Chăm, Cột cờ, Bức tượng...*).
- Thẻ `IslandSummaryCard` bên dưới thanh tab chiếm nhiều diện tích chiều dọc; khung thoại Rùa đang đặt ở đáy màn hình thay vì đặt gọn phía trên bên trái dưới thanh tab.
- Chưa có màn hình **Bản đồ Toàn cảnh 3 Cấp Đảo** xếp dọc trên biển mây (mở từ nút `Bản đồ`).
- Chưa có tương tác **Preview đặt vật phẩm trực tiếp trên lưới** kèm đế xanh lá `2×2`/`1×1`, cụm 3 nút tròn **`✕` / `↻` / `✓`** dưới chân vật phẩm và thẻ thông tin **`Đặt`** ở đáy màn hình.
- Chưa đồng bộ đầy đủ 4 Modal/Sheet: **`KHO VẬT PHẨM`** (4 tab lọc), **`CHI TIẾT VẬT PHẨM`** (`Kích thước: 2x2`, `⭐ 50`, nút `Đặt lên đảo`), **`NÂNG CẤP ĐẢO`** (sơ đồ chuyển đảo + 3 điều kiện `X/Y`) và hộp thoại **`Chuyển đến Đảo Vừa?`**.
- Diện tích mặt đảo & lưới ô cần được mở rộng lớn hơn ảnh mẫu (`6×6` cho `Đảo Nhỏ`, `8×8` cho `Đảo Vừa`, `10×10` cho `Đảo Lớn`) để đặt đẹp mắt cả công trình `2×2` lẫn vật phẩm `1×1`.

## 2. Phạm vi Giải pháp
1. **Backend (`V60` & `IslandLayoutService`):**
   - Nâng giới hạn `slot_count` / `slot_index` lên `256`.
   - Cấu hình `island_tier_policies` (`config_version = 5`): `Đảo Nhỏ` (`36` ô — `6×6`), `Đảo Vừa` (`64` ô — `8×8`), `Đảo Lớn` (`100` ô — `10×10`).
   - Publish layout version 4 (`10×10` đồng tâm) và bổ sung đầy đủ bộ vật phẩm mẫu (`Nhà rông`, `Đình làng`, `Chùa cổ`, `Tháp Chăm`, `Cây đa`, `Tre trúc`, `Cột cờ`, `Bức tượng`) kèm metadata `footprintWidth`/`footprintHeight` (`2×2` / `1×1`).
2. **Mobile (`dau-viet-mobile`):**
   - Bổ sung bộ artwork 2.5D cho công trình, vật phẩm, Rùa đội nón lá, cầu tàu thuyền gỗ và 3 cấp đảo.
   - Thiết kế lại mặt đảo 2.5D Illustrated Diorama rộng rãi, sáng đẹp, hỗ trợ vật phẩm `2×2` & `1×1`.
   - Triển khai trọn vẹn 5 màn hình chính và 4 modal/bottom sheet giống hệt ảnh mẫu.
3. **Admin (`dau-viet-admin`):**
   - Đồng bộ kích thước lưới `10×10` đồng tâm (`6×6 / 8×8 / 10×10`) và tên 3 cấp đảo (`Đảo Nhỏ`, `Đảo Vừa`, `Đảo Lớn`).
