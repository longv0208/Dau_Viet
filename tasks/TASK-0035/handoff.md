# Handoff — TASK-0035: Issue #46 — Thiết kế lại Đảo Di Sản theo phong cách Isometric 2.5D mới

## 1. Tóm tắt thay đổi

1. **Backend & Database (`dau-viet-backend`):**
   - Tạo migration `V59__redesign_heritage_island_3_tiers.sql`:
     - Cập nhật `island_tier_policies` (`config_version = 4`, vô hiệu hóa `config_version = 3`):
       - Cấp 1: **Đảo An Lạc** (`tier.an_lac`, `16` ô — lưới `4×4`)
       - Cấp 2: **Đảo Phồn Thịnh** (`tier.phon_thinh`, `36` ô — lưới `6×6`)
       - Cấp 3: **Đảo Trường Tồn** (`tier.truong_ton`, `64` ô — lưới `8×8`)
     - Xuất bản Layout Version 3 (`22200000-2222-4000-8000-000000000003`) trên board `8×8` đồng tâm vuông vắn (`TIER_1` `4×4` giữa có bậc thềm đá `elevation = 1`, `TIER_2` `6×6`, `TIER_3` `8×8`), chuyển v2 sang `ARCHIVED` để `IslandService.ensureIsland()` tự động nâng cấp layout an toàn và bảo toàn vật phẩm trong `user_inventory`.
     - Bổ sung các vật phẩm mẫu theo thiết kế (`DECOR_COT_CO`, `DECOR_TUONG_LY_THAI_TO`, `DECOR_CAY_DAO`) vào `item_catalog` & `island_shop_items`.
   - Cập nhật `IslandV51IT.java` kiểm chứng đầy đủ 3 cấp đảo `16 / 36 / 64` ô và nhãn `Đảo An Lạc` / `Đảo Phồn Thịnh` / `Đảo Trường Tồn`.

2. **Mobile (`dau-viet-mobile`):**
   - `island_dto.dart`, `island_fixture.dart`, `mock_island_repository.dart`, `mock_reward_repository.dart`:
     - Chuẩn hóa tên 3 cấp đảo (`Đảo An Lạc`, `Đảo Phồn Thịnh`, `Đảo Trường Tồn`), diện tích lưới (`tierAreaDimensionLabel`), lời thoại ngữ cảnh của Rùa Kabi (`kabiGuideTextForTier`).
     - Thêm enum `IslandInventoryCategory` (`Tất cả`, `Công trình`, `Cây cối`, `Trang trí`, `Khác`), hàm phân loại `resolveIslandItemCategory`, hàm rút gọn tên thẻ `shortIslandItemDisplayName` và tỷ lệ kích thước hiển thị `resolveIslandItemVisualScale` (Công trình lớn `1.46×` > Cây cối `1.22×` > Trang trí nhỏ `0.96×`).
   - `island_scene.dart`, `island_isometric_renderer.dart`, `island_heritage_building.dart`:
     - Bổ sung `_IslandPanoramicBackdrop` vẽ bầu trời, biển vịnh Hạ Long, núi đá vôi, mây trôi và 2 đảo phụ phía xa (có khóa `🔒` khi chưa mở).
     - Nâng cấp khối đảo nổi 2.5D: vách đá cao (`tileH * 1.18`), 2 dòng thác nước đổ xuống biển, bậc thang đá và cầu tàu gỗ.
     - Ẩn đường kẻ lưới & cọc `+` khi ở **Chế độ Tham quan**; hiển thị rõ lưới ô cỏ/đá sáng khi ở **Chế độ Bài trí**.
     - Bổ sung hình minh họa cho *Cột cờ, Tượng Lý Thái Tổ, Cây đào, Thuyền, Đèn lồng* và áp dụng tỷ lệ kích thước theo loại công trình/vật phẩm.
   - `island_screen.dart`, `island_tier_tabs.dart`, `island_inventory_tray.dart`:
     - Thiết kế lại Top Bar (`<`, `ĐẢO DI SẢN`, `?`, `⭐ Điểm Sử Ký`), thanh 3 tab cấp đảo có thumbnail isometric (`IslandTierTabs`), thẻ thông tin đảo (`_buildIslandSummaryCard`), 2 nút `<` `>` chuyển đảo và khung thoại trợ lý **Rùa Kabi đội nón lá**.
     - Tách rõ **Chế độ Tham quan** và **Chế độ Bài trí** với cụm 3 nút nổi bên phải (**Lưu đảo**, **Xoay**, **Xóa**) và Khay vật phẩm 5 tab dạng lưới 4 cột có badge số lượng.

3. **Admin (`dau-viet-admin`):**
   - Đồng bộ `island-builder-fixture.ts` và `island-builder-workspace.tsx` sang lưới đồng tâm `8×8` và nhãn 3 cấp đảo (`Đảo An Lạc`, `Đảo Phồn Thịnh`, `Đảo Trường Tồn`).

## 2. Kết quả Kiểm chứng (Verification Evidence)

- **Backend Integration Test (PostgreSQL Testcontainers + Flyway V59):**
  - Command: `mvn test -Dtest=IslandV51IT` (cwd: `dau-viet-backend`)
  - Result: `Tests run: 3, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS`
- **Mobile Static Analysis:**
  - Command: `flutter analyze` (cwd: `dau-viet-mobile`)
  - Result: `No issues found! (0 errors, 0 warnings, 0 info)`
- **Mobile Unit & Widget Tests (AC-1 → AC-5, gồm kiểm tra responsive 360x800 & 390x844):**
  - Command: `flutter test test/island/island_dto_test.dart test/island/island_screen_test.dart` (cwd: `dau-viet-mobile`)
  - Result: `18/18 tests passed`
- **Whitespace / Formatting Check:**
  - Command: `git diff --check`
  - Result: Clean (`0` errors)

## 3. Hành động Tiếp theo

- Chờ người dùng review giao diện và ủy quyền commit/push trên nhánh `feat/issue-46-island-redesign`.
