# TASK-0031 — [GAME-07] Hoàn thiện chức năng Viện Thái Y: 4 Vật phẩm Hồi Thể lực, Admin Settings & Mobile UI/UX Pro Max (Issue #28)

- **GitHub Issue:** https://github.com/longv0208/Dau_Viet/issues/28
- **Branch:** `feat/issue-28-vien-thai-y`
- **Worktree:** `E:/Telegram Desktop/Dau viet/Dau_Viet-issue-28`
- **Master Plan:** `plans/261028-issue-28-vien-thai-y/plan.md`

## 1. Mục tiêu
Hoàn thiện end-to-end chức năng **Viện Thái Y (`M-28` / `GAME-07`)** trên cả 3 phân hệ (`dau-viet-backend`, `dau-viet-admin`, `dau-viet-mobile`):
1. Lưu cấu hình quy tắc Thể lực toàn cục (`energy_policy_settings`) và danh mục 4 vật phẩm Viện Thái Y theo Phương án B (`energy_remedies`) trong Database (`V49`).
2. Cho phép người học bấm mua/dùng mọi vật phẩm đang mở bán miễn là Thể lực chưa đầy (`currentEnergy < maxEnergy`), thực thi nguyên tử & idempotent qua `POST /api/v1/me/energy/refills`, đồng bộ số dư Điểm Sử Ký trên toàn hệ thống (`QA-19`).
3. Cung cấp trang Quản trị Viện Thái Y (`/thai-y-vien`) trên `dau-viet-admin` để Admin chỉnh sửa quy tắc Thể lực và CRUD vật phẩm Viện Thái Y.
4. Nâng cấp giao diện Mobile `EnergyManagementScreen` theo chuẩn `UI/UX Pro Max`, đồng bộ 100% với `LearnerDashboardScreen` và `IslandShopScreen`.

## 2. Bảng 4 Vật phẩm Mặc định (Phương án B)
1. **`NUOC_VOI` (Nước Vối Tĩnh Tâm):** `+20 ⚡` • `0 Điểm Sử Ký (Miễn phí)` • Cooldown `24 giờ` (`86.400s`) • `COMMON`
2. **`TRA_SEN` (Trà Sen Tây Hồ):** `+30 ⚡` • `30 Điểm Sử Ký` • Cooldown `4 giờ` (`14.400s`) • `UNCOMMON`
3. **`NAM_LINH_CHI` (Nấm Linh Chi Ngự Dược):** `+50 ⚡` • `55 Điểm Sử Ký` • Cooldown `12 giờ` (`43.200s`) • `RARE`
4. **`SAM_NGOC_LINH` (Sâm Ngọc Linh Hoàng Gia):** `+100 ⚡ (Đầy bình)` • `90 Điểm Sử Ký` • Cooldown `24 giờ` (`86.400s`) • `EPIC`

## 3. Tiêu chí Nghiệm thu (Acceptance Criteria)
- **AC-1:** Migration `V49` tạo bảng `energy_policy_settings` và `energy_remedies`, seed đúng quy tắc Thể lực mặc định và 4 vật phẩm Phương án B.
- **AC-2:** `GET /api/v1/me/energy` trả `pointsBalance` và `remedies[]`; `POST /api/v1/me/energy/refills` cho phép dùng mọi gói `active` khi `currentEnergy < maxEnergy`, chặn khi `== maxEnergy` (`422 REFILL_NOT_ELIGIBLE`), kiểm tra cooldown từng gói (`409 REFILL_RATE_LIMITED`), trừ Điểm Sử Ký nguyên tử (`409 INSUFFICIENT_FUNDS`), clamp trần `maxEnergy`, neo `last_recovery_at = now` khi đạt `maxEnergy`, và idempotent theo `Idempotency-Key`.
- **AC-3:** Sau khi mua vật phẩm có phí tại Viện Thái Y, cả `GET /api/v1/me/wallet` và `GET /api/v1/me/rewards/summary` đều phản ánh đúng số dư Điểm Sử Ký đã trừ; EXP, số bài học và vật phẩm giữ nguyên (`QA-19`).
- **AC-4:** Admin xem và cập nhật được quy tắc Thể lực chung (`PUT /api/v1/admin/energy/settings`) và thêm/sửa/xóa/bật-tắt vật phẩm Viện Thái Y (`/api/v1/admin/energy/remedies`) trên giao diện Web Admin `/thai-y-vien`; thay đổi của Admin phản ánh ngay trên API người học.
- **AC-5:** Màn hình Viện Thái Y (`M-28`) hiển thị đồng bộ chuẩn Di Sản Dấu Việt v2.0 (Top Bar có `_buildWalletPill`, Hero Nhật Quang & thanh 10 vạch mượt mà, 4 thẻ phương thang với `Tactile3DButton`, Dialog xác nhận trước/sau khi nạp, đếm ngược cooldown thực tế) và vượt qua toàn bộ bộ test tự động.
