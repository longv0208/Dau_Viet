# TASK-0035: Issue #46 — Thiết kế lại Đảo Di Sản theo phong cách Isometric 2.5D mới

## Goal

Thiết kế lại toàn diện giao diện và trải nghiệm tương tác của màn hình **Đảo Di Sản (`/island`)** theo mẫu thiết kế UI/UX mới ([Issue #46](https://github.com/longv0208/Dau_Viet/issues/46) & `plans/261030-issue-46-island-redesign/island-mockup.png`), bao gồm:
1. Hệ thống 3 cấp đảo (**Đảo An Lạc** · **Đảo Phồn Thịnh** · **Đảo Trường Tồn**) với thanh tab có thumbnail isometric, thẻ thông tin diện tích & trạng thái (`Đang sử dụng` / `🔒 Mở rộng đảo`), bối cảnh biển mây vịnh núi Hạ Long, đảo phụ phía xa, nút điều hướng `<` `>` và khung thoại hướng dẫn ngữ cảnh của trợ lý **Rùa Kabi đội nón lá**.
2. Quy hoạch lại diện tích & lưới ô đồng tâm cân đối trên màn hình di động (`4×4` ô cho Đảo An Lạc, `6×6` ô cho Đảo Phồn Thịnh, `8×8` ô cho Đảo Trường Tồn), khối đảo nổi 2.5D có vách đá, thác nước đổ xuống biển, bậc thang đá, cầu tàu gỗ, và phân biệt tỷ lệ hiển thị giữa công trình lớn với vật phẩm nhỏ.
3. Tách biệt **Chế độ Tham quan** (ẩn lưới ô để đảo như tranh phong cảnh) và **Chế độ Bài trí** (hiện lưới ô sáng rõ, cụm 3 nút công cụ nổi **Lưu đảo / Xoay / Xóa** bên phải, và **Khay vật phẩm phân loại 5 tab** `Tất cả`, `Công trình`, `Cây cối`, `Trang trí`, `Khác` dạng lưới 4 cột có badge số lượng).

## Requirements and acceptance criteria

- **AC-1:** Giao diện 3 Cấp Đảo & Bối cảnh Isometric 2.5D: Hiển thị đúng hệ thống 3 đảo (Đảo An Lạc, Đảo Phồn Thịnh, Đảo Trường Tồn) với thanh tab có thumbnail, thẻ thông tin diện tích/trạng thái (Đang sử dụng / Mở rộng đảo), nền biển mây vịnh núi, đảo phụ phía xa, nút chuyển `<` `>` và khung thoại hướng dẫn của Rùa Kabi.
- **AC-2:** Quy hoạch Diện tích & Lưới Ô Hợp lý: Kích thước lưới ô của từng cấp đảo được tinh chỉnh hợp lý (`4×4` / `6×6` / `8×8` đồng tâm), cân đối với kích thước màn hình điện thoại; phân biệt rõ tỷ lệ hiển thị giữa công trình lớn và vật phẩm trang trí nhỏ, đảm bảo chạm chọn chính xác và không bị rối mắt.
- **AC-3:** Chế độ Bài trí & Cụm Công cụ Lưu / Xoay / Xóa: Khi bài trí, hiển thị rõ lưới ô trên mặt đảo cùng 3 nút công cụ nổi bên phải (Lưu đảo, Xoay, Xóa) hoạt động mượt mà, đồng bộ với Backend.
- **AC-4:** Khay Vật phẩm Phân loại 5 Tab: Khay vật phẩm phía dưới có bộ lọc `Tất cả`, `Công trình`, `Cây cối`, `Trang trí`, `Khác`, hiển thị lưới thẻ vật phẩm 4 cột kèm hình minh họa, tên và badge số lượng đúng như thiết kế.
- **AC-5:** Responsive & Tests: Giao diện chạy mượt trên nhiều kích thước màn hình mobile, không bị lỗi overflow và pass bộ test liên quan.

## Scope

- **Modules:** `backend`, `mobile`, `admin`
- **Paths:**
  - `dau-viet-backend/src/main/resources/db/migration/V59__redesign_heritage_island_3_tiers.sql`
  - `dau-viet-backend/src/test/java/com/dauviet/island/IslandV51IT.java`
  - `dau-viet-mobile/lib/features/island/`
  - `dau-viet-mobile/test/island/`
  - `dau-viet-admin/src/features/island-builder/`
  - `plans/261030-issue-46-island-redesign/plan.md`

## Constraints and risk

- **Risk lane:** `high-risk` (có Flyway migration `V59` cập nhật tier policies & layout version 3).
- **Invariants:**
  - Backend vẫn là nguồn chân lý cho quyền sở hữu vật phẩm, điều kiện mở khóa cấp đảo theo Level/EXP và lưu vị trí đặt (`user_island_placements`).
  - Việc chuyển từ layout v2 sang v3 khi archive v2 phải giữ nguyên toàn bộ vật phẩm trong `user_inventory` của người học (không làm mất vật phẩm).
  - Tương thích ngược với các mã `nameKey` cũ (`tier.small`, `tier.medium`, `tier.grand`) và mới (`tier.an_lac`, `tier.phon_thinh`, `tier.truong_ton`).

## Plan

Xem kế hoạch chi tiết tại [`plans/261030-issue-46-island-redesign/plan.md`](../../plans/261030-issue-46-island-redesign/plan.md).

## Verification mapping

| AC | Check | Expected outcome | Evidence artifact |
|---|---|---|---|
| AC-1 | `flutter test test/island/island_screen_test.dart` + `IslandV51IT` | Hiển thị đúng 3 tab `Đảo An Lạc`, `Đảo Phồn Thịnh`, `Đảo Trường Tồn` kèm thumbnail, thẻ `Diện tích`, nút `<` `>`, nền vịnh núi và lời thoại Rùa Kabi đội nón lá | `tasks/TASK-0035/handoff.md` |
| AC-2 | `mvn test -Dtest=IslandV51IT` + `island_dto_test.dart` | Lưới đồng tâm `4×4` (16 ô), `6×6` (36 ô), `8×8` (64 ô); tỷ lệ hiển thị công trình lớn (`1.46×`) > cây cối (`1.22×`) > trang trí nhỏ (`0.96×`) | `tasks/TASK-0035/handoff.md` |
| AC-3 | `flutter test test/island/island_screen_test.dart` | Chế độ Bài trí hiện lưới ô + 3 nút `Lưu đảo`, `Xoay`, `Xóa` hoạt động và gọi API đặt/gỡ đồng bộ | `tasks/TASK-0035/handoff.md` |
| AC-4 | `flutter test test/island/island_screen_test.dart` | Khay vật phẩm có 5 tab lọc (`Tất cả`, `Công trình`, `Cây cối`, `Trang trí`, `Khác`) và lưới 4 cột kèm badge số lượng | `tasks/TASK-0035/handoff.md` |
| AC-5 | `flutter analyze`, `flutter test test/island/*`, `mvn test -Dtest=IslandV51IT` | `flutter analyze` 0 issues across `dau-viet-mobile`, 18/18 island tests pass, `IslandV51IT` 3/3 pass, 0 overflow trên `360×800` & `390×844` | `tasks/TASK-0035/handoff.md` |

Trạng thái thực thi lưu tại `tasks/TASK-0035/task.json`.
