# Phase 05 — Kiểm thử Toàn diện & Cập nhật Tài liệu

## 1. Mục tiêu
Đảm bảo toàn bộ tính năng Viện Thái Y (Database `V49`, Backend Runtime & Admin API, Web Admin `/thai-y-vien`, Mobile `EnergyManagementScreen`) có bộ kiểm thử tự động chặt chẽ và tài liệu được cập nhật đồng bộ.

## 2. Kế hoạch Kiểm thử Chi tiết

### 2.1. Backend Unit Tests (`EnergyRecoveryTest.java`)
- Kiểm thử đọc danh sách 4 vật phẩm mặc định trong `stateOf(userId)`:
  - Trả đúng `pointsBalance` và 4 vật phẩm (`NUOC_VOI`, `TRA_SEN`, `NAM_LINH_CHI`, `SAM_NGOC_LINH`).
  - Khi `currentEnergy = 100`: cả 4 vật phẩm đều `eligible = false` với `blockReasons = ["ENERGY_FULL"]`.
  - Khi `currentEnergy = 85`, `pointsBalance = 40`:
    - `NUOC_VOI` (`0đ`, `+20⚡`): `eligible = true`, `effectiveEnergyGain = 15`.
    - `TRA_SEN` (`30đ`, `+30⚡`): `eligible = true`, `effectiveEnergyGain = 15`.
    - `NAM_LINH_CHI` (`55đ`, `+50⚡`): `eligible = false`, `blockReasons = ["INSUFFICIENT_FUNDS"]`.
- Kiểm thử `refill(userId, remedyCode, idempotencyKey)`:
  - Dùng `NUOC_VOI` miễn phí khi `energy = 60` -> `energy = 80`, `pointsSpent = 0`, giữ nguyên `last_recovery_at`.
  - Dùng lại `NUOC_VOI` ngay lập tức -> ném `RefillRateLimitedException` (`409 REFILL_RATE_LIMITED`), sau `24h + 1s` thì dùng lại được.
  - Dùng `TRA_SEN` (`30đ`, `+30⚡`) khi `energy = 80, balance = 50` -> `energy = 100` (chạm trần), `balance = 20`, neo lại `last_recovery_at = now` (`ENGY-08`).
  - Dùng bất kỳ gói nào khi `energy = 100` -> ném `RefillNotEligibleException` (`422 REFILL_NOT_ELIGIBLE`).

### 2.2. Backend Integration Tests (`EnergySystemIT.java`)
- Chạy trên PostgreSQL thật (Testcontainers, Flyway `V1`–`V49`):
  - **IT-1:** `GET /api/v1/me/energy` trả `pointsBalance` và 4 vật phẩm Phương án B.
  - **IT-2:** `POST /api/v1/me/energy/refills` với `NUOC_VOI` (`0 Điểm`) và `TRA_SEN` (`30 Điểm`); kiểm tra retry cùng `Idempotency-Key` không trừ tiền/cộng năng lượng lần 2.
  - **IT-3:** Kiểm tra đồng thời (concurrency race) 2 request mua khi chỉ đủ điểm cho 1 lần -> đúng 1 lần thành công, 1 lần `409 INSUFFICIENT_FUNDS`.
  - **IT-4 (`QA-19`):** Sau khi tiêu `30 Điểm Sử Ký` tại Viện Thái Y, gọi `GET /api/v1/me/rewards/summary` xác nhận `historyPoints` giảm đúng `30`, trong khi `exp` giữ nguyên.
  - **IT-5 (Admin API):** `GET/PUT /api/v1/admin/energy/settings` và `POST/PUT/DELETE /api/v1/admin/energy/remedies`; xác nhận chỉnh giá `TRA_SEN` từ `30` sang `25` trên Admin phản ánh ngay ở `GET /api/v1/me/energy` của learner.

### 2.3. Web Admin Verification (`dau-viet-admin`)
- Chạy `npm run typecheck` (`tsc --noEmit`) và `npm test` đảm bảo 0 lỗi TypeScript và test pass.

### 2.4. Mobile Widget & Unit Tests (`dau-viet-mobile`)
- Cập nhật `test/fakes/fake_energy_repository.dart` và `test/energy/energy_management_screen_test.dart`:
  - Hiển thị đúng Huy hiệu Ví Điểm Sử Ký (`_buildWalletPill`), Hero Card Nhật Quang, và 4 thẻ vật phẩm (`Nước Vối Tĩnh Tâm`, `Trà Sen Tây Hồ`, `Nấm Linh Chi Ngự Dược`, `Sâm Ngọc Linh Hoàng Gia`).
  - Bấm `NHẬN NGAY` trên `Nước Vối Tĩnh Tâm` (`0 Điểm`) -> cộng `+20 ⚡` ngay lập tức và chuyển thẻ sang đếm ngược `Hồi sau 23:59:59`.
  - Bấm `BỒI BỔ` trên `Trà Sen Tây Hồ` (`30 Điểm`) -> mở Dialog Xác nhận Bồi bổ Sinh lực -> bấm `XÁC NHẬN DÙNG` -> thanh Thể lực tăng thêm `+30 ⚡`, ví giảm `30 Điểm`.
  - Hiển thị đúng trạng thái `ĐÃ ĐẦY SINH LỰC` khi `100/100`, `THIẾU X ĐIỂM` khi không đủ điểm, và tự refetch khi countdown về `00:00`.
- Chạy `flutter analyze` và `flutter test test/energy/`.

## 3. Cập nhật Tài liệu (`docs/`)
- `docs/DATABASE_DESIGN.md`: Bổ sung bảng `energy_policy_settings` và `energy_remedies` (V49).
- `docs/API_SPEC.md`: Bổ sung `POST /api/v1/me/energy/refills`, mở rộng `GET /api/v1/me/energy`, và nhóm `/api/v1/admin/energy/*`.
- `docs/GAMIFICATION_BUSINESS_RULES.md`: Cập nhật bảng 4 vật phẩm Viện Thái Y (Phương án B) và cơ chế Admin cấu hình động.
- `docs/project-changelog.md`: Ghi nhận hoàn thành Issue #28 (`TASK-0028`).
