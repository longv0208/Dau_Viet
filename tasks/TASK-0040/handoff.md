# Handoff — TASK-0040 (Issue #50: Đại tu toàn diện Đảo Di Sản theo thiết kế mẫu 9 màn hình)

## 1. Tóm tắt Kết quả Thực thi
Đã hoàn thành đại tu toàn diện giao diện, bộ tài nguyên đồ họa 2.5D và luồng tương tác của tính năng **Đảo Di Sản (`/island`)** theo đúng thiết kế mẫu 9 màn hình (`plans/261030-issue-50-heritage-island-overhaul/island-mockup.png`), đồng thời mở rộng diện tích mặt đảo & lưới ô cân đối trên màn hình di động (`6×6` / `8×8` / `10×10`):

1. **Backend (`dau-viet-backend`):**
   - **Migration `V60__overhaul_heritage_island_9_screens.sql`**:
     - Mở rộng `chk_island_slot_count` (`island_tier_policies`) và `chk_island_slot_idx` (`island_slots`) lên `1..256`.
     - Cập nhật `island_tier_policies` (`config_version = 5`):
       - **Tier 1 (`Đảo Nhỏ`)**: `36` ô (`6×6`), `required_level = 1`.
       - **Tier 2 (`Đảo Vừa`)**: `64` ô (`8×8`), `required_level = 2`.
       - **Tier 3 (`Đảo Lớn`)**: `100` ô (`10×10`), `required_level = 3`.
     - Publish Layout Version 4 (`v4_id = '22200000-2222-4000-8000-000000000004'`) với bàn cờ `10×10 = 100` ô đồng tâm (`6×6` / `8×8` / `10×10`).
     - Chuẩn hóa đầy đủ 8 vật phẩm mẫu trong `item_catalog` & `island_shop_items` (*Nhà rông, Đình làng, Chùa cổ, Tháp Chăm, Cây đa cổ thụ, Tre trúc, Cột cờ, Bức tượng*) kèm metadata `footprintWidth`, `footprintHeight` (`2×2` / `1×1`) và `islandCategory`.
   - **`IslandLayoutService.java`**: Mở rộng giới hạn kiểm tra `slotIndex` lên `1..256`.

2. **Mobile (`dau-viet-mobile`):**
   - **Bộ tài nguyên 2.5D Illustrated Isometric (`assets/island/`)**:
     - Bổ sung 11 sprite RGBA sắc nét: `nha_rong.png`, `chua_co.png`, `thap_cham.png`, `cot_co.png`, `buc_tuong.png`, `tre_truc.png`, `cay_da_co_thu.png`, `turtle_hat_avatar.png`, `island_tier_1.png`, `island_tier_2.png`, `island_tier_3.png`.
   - **Khối Đảo 2.5D Diorama & Quy hoạch Lưới Ô (`island_scene.dart`, `island_isometric_renderer.dart`)**:
     - Phóng to tỷ lệ hiển thị đảo (`widthFill = 0.96`) cân đối trên màn hình di động.
     - Mặt phẳng đảo thảo nguyên xanh vàng ấm áp liền mạch, đường kẻ lưới isometric màu kem sáng rõ nét, cổ thụ tỏa bóng ở đỉnh Bắc, rặng tre/đá rêu hai bên, thác nước đổ xuống biển và bậc thang đá dẫn xuống cầu tàu gỗ kèm thuyền gỗ truyền thống neo đậu.
   - **5 Màn hình Chính & 4 Modal / Sheet (`island_screen.dart`, `island_tier_tabs.dart`, `island_inventory_tray.dart`, `island_inventory_sheet.dart`, `island_upgrade_panel.dart`)**:
     - **Màn 1:** Thanh Segmented Pill Tab 3 cấp (`Đảo Nhỏ` · `Đảo Vừa` · `Đảo Lớn`), gỡ bỏ `IslandSummaryCard`, đặt **Khung thoại Rùa đội nón lá** ngay phía trên bên trái (dưới thanh tab), nút nổi **`Bản đồ`** ở góc dưới bên phải và **Khay `🧰 Kho vật phẩm`** rút gọn ở đáy.
     - **Màn 2:** Chế độ **Placement Preview** hiển thị trực tiếp vật phẩm trên lưới với vùng đế xanh lá (`2×2` hoặc `1×1`) + cụm 3 nút tròn **`✕` / `↻` / `✓`** dưới chân vật phẩm + **Thẻ Đặt Vật Phẩm** (`Nhà rông`, `⊞ 2x2`, nút **`Đặt`**) ở đáy màn hình.
     - **Màn 3 & Màn 5:** Cụm 3 nút công cụ nổi dọc bên phải (**`Lưu`**, **`Thu hồi`**, **`Xoay`**) và giao diện **`Đảo Vừa` / `Đảo Lớn`** mở rộng.
     - **Màn 4:** **Bản đồ Toàn cảnh 3 Cấp Đảo** xếp dọc trên biển mây (`✅ Đảo Nhỏ — Đang sử dụng`, `🔒 Đảo Vừa — Hoàn thành 15 bài học để mở khóa`, `🔒 Đảo Lớn — Hoàn thành 30 bài học để mở khóa`).
     - **Modal 1 (`KHO VẬT PHẨM`):** 4 tab lọc pill (`Tất cả`, `Công trình`, `Cây cối`, `Trang trí`) + lưới 4 cột.
     - **Modal 2 (`CHI TIẾT VẬT PHẨM`):** Hình minh họa lớn bên trái + Tên, mô tả, `Kích thước: 2x2`, `⭐ 50` + nút **`Đặt lên đảo`**.
     - **Modal 3 (`NÂNG CẤP ĐẢO`):** Sơ đồ `Đảo Nhỏ → Đảo Vừa`, checklist 3 điều kiện tiến độ `X/Y` + nút **`Mở khóa Đảo Vừa`**.
     - **Modal 4 (`Chuyển đến Đảo Vừa?`):** Hình minh họa đảo vươn lên ở đỉnh hộp thoại + 2 nút **`Để sau`** / **`Chuyển ngay`**.

3. **Web Admin (`dau-viet-admin`):**
   - Đồng bộ `island-builder-fixture.ts` và `island-builder-workspace.tsx` theo lưới `10×10` đồng tâm (`Đảo Nhỏ` `6×6`, `Đảo Vừa` `8×8`, `Đảo Lớn` `10×10`).

## 2. Bằng chứng Kiểm chứng (Verification Evidence)
- **Backend (`dau-viet-backend`):**
  - `mvnw.cmd test -Dtest=IslandV51IT` -> **BUILD SUCCESS** (3/3 integration tests pass trên PostgreSQL 16 Testcontainers + Flyway V1–V60).
- **Mobile (`dau-viet-mobile`):**
  - `flutter analyze --no-pub` -> **No issues found!** trên toàn bộ dự án.
  - `flutter test test/island/island_dto_test.dart test/island/island_screen_test.dart` -> **18/18 tests passed!** (bao gồm kiểm thử toàn bộ 9 màn hình/modal và kiểm thử responsive `360×800` & `390×844` không overflow).
- **Admin (`dau-viet-admin`):**
  - `tsc --noEmit` -> **0 errors**.

## 3. Hành động Tiếp theo (Next Action)
- Chờ người dùng review và ủy quyền commit/push trên nhánh `feat/issue-50-heritage-island-overhaul`.
