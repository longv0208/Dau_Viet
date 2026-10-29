# Phase 02 — Backend Runtime API, Admin Settings API & Đồng bộ Ví (`dau-viet-backend`)

## 1. Mục tiêu
1. Tạo domain entities & repositories cho `energy_policy_settings` và `energy_remedies`.
2. Cập nhật `EnergyService` để:
   - Đọc quy tắc Thể lực từ `energy_policy_settings` (fallback sang `EnergyProperties` khi unit test không dùng repository).
   - Trả về `pointsBalance` và danh sách `remedies` trong `GET /api/v1/me/energy`.
   - Thực thi `POST /api/v1/me/energy/refills` nguyên tử, idempotent, cho phép mua mọi gói khi `currentEnergy < maxEnergy`.
3. Tạo `AdminEnergyController` & `AdminEnergyService` (`/api/v1/admin/energy/settings` & `/api/v1/admin/energy/remedies`).
4. Cập nhật `RewardService.summary()` trừ số Điểm Sử Ký đã tiêu trong `wallet_transactions` (`QA-19`).

## 2. Danh sách File Tạo mới / Chỉnh sửa

### Tạo mới:
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyPolicySetting.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyRemedy.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyRefillExceptions.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyPolicySettingRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyRemedyRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRemedyDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRefillRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRefillResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/AdminEnergyDtos.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/application/AdminEnergyService.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/AdminEnergyController.java`

### Chỉnh sửa:
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyTransactionRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyStateResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/application/EnergyService.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/EnergyController.java`
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java`
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java`
- `dau-viet-backend/src/main/java/com/dauviet/reward/application/RewardService.java`

## 3. Chi tiết Nghiệp vụ & Contract API

### 3.1. Truy vấn Cooldown theo từng `remedyCode`
Trong `EnergyTransactionRepository`:
```java
@Query(value = """
        SELECT reference_json->>'remedyCode' AS remedy_code,
               MAX(created_at) AS last_used_at
        FROM energy_transactions
        WHERE user_id = :userId
          AND reason = 'REFILL_PURCHASE'
          AND created_at >= :since
        GROUP BY reference_json->>'remedyCode'
        """, nativeQuery = true)
List<RemedyUsageProjection> findRecentRemedyUsages(
        @Param("userId") UUID userId,
        @Param("since") Instant since);
```
- Với mỗi `EnergyRemedy`:
  - Nếu `cooldownSeconds > 0` và `lastUsedAt != null`:
    - `cooldownEndsAt = lastUsedAt.plusSeconds(cooldownSeconds)`
    - Nếu `cooldownEndsAt.isAfter(now)` -> đang hồi chiêu (`REFILL_RATE_LIMITED`).

### 3.2. Điều kiện `eligible` của từng Vật phẩm trong `GET /api/v1/me/energy`
Với mỗi `EnergyRemedy` đang `active = true`:
- `blockReasons` (danh sách chuỗi):
  1. Nếu `currentEnergy >= maxEnergy` -> thêm `"ENERGY_FULL"`.
  2. Nếu `cooldownEndsAt != null && cooldownEndsAt.isAfter(now)` -> thêm `"REFILL_RATE_LIMITED"`.
  3. Nếu `pointsCost > 0 && pointsBalance < pointsCost` -> thêm `"INSUFFICIENT_FUNDS"`.
- `eligible = blockReasons.isEmpty()`.
- `effectiveEnergyGain = Math.max(0, Math.min(remedy.getEnergyGain(), maxEnergy - currentEnergy))`.

### 3.3. Luồng `POST /api/v1/me/energy/refills`
- Header bắt buộc: `Idempotency-Key` (thiếu hoặc trắng -> `400 VALIDATION_ERROR`).
- Body: `EnergyRefillRequest { @NotBlank String remedyCode }`.
- Bọc trong `idempotencyService.execute(userId, "ENERGY_REFILL", idempotencyKey, "REFILL:" + normalizedCode, EnergyRefillResponse.class, () -> ...)`.
- Thứ tự thực thi trong `@Transactional`:
  1. Đọc policy hiện hành (`maxEnergy`, `recoveryAmount`, `recoveryInterval`).
  2. `UserEnergy e = recoverLocked(userId, now, policy);` (Khóa `user_energy` **trước**).
  3. Tìm `EnergyRemedy` theo `code` (`active == true`). Không thấy -> ném `RemedyNotFoundException` (`404 REMEDY_NOT_FOUND`).
  4. Nếu `e.getCurrentEnergy() >= policy.maxEnergy()` -> ném `RefillNotEligibleException` (`422 REFILL_NOT_ELIGIBLE`, `reason = "ENERGY_FULL"`).
  5. Kiểm tra cooldown của `remedy.getCode()`. Nếu còn trong thời gian chờ -> ném `RefillRateLimitedException` (`409 REFILL_RATE_LIMITED` kèm `lastRefillAt`, `nextEligibleAt`, `serverTime`).
  6. `String causeKey = "REFILL:" + idempotencyKey;`
  7. Nếu `remedy.getPointsCost() > 0`:
     - Gọi `walletService.debit(userId, remedy.getPointsCost(), WalletTransaction.REASON_REFILL_PURCHASE, causeKey, remedy.getCode())` (Khóa `wallet_accounts` **sau** `user_energy`; nếu thiếu điểm ném `409 INSUFFICIENT_FUNDS`).
  8. Tính `int credited = Math.min(remedy.getEnergyGain(), policy.maxEnergy() - e.getCurrentEnergy())`.
  9. Ghi `energy_transactions` (`DIR_CREDIT`, `credited`, `REASON_REFILL_PURCHASE`, `causeKey`, `projected`, `referenceJson`) và cập nhật `e.credit(credited, projected >= policy.maxEnergy() ? now : null)`.
  10. Trả về `EnergyRefillResponse`.

### 3.4. Admin Endpoints (`AdminEnergyController`)
- `GET /api/v1/admin/energy/settings` -> `AdminEnergySettingsResponse`
- `PUT /api/v1/admin/energy/settings` -> `AdminEnergySettingsResponse`
- `GET /api/v1/admin/energy/remedies` -> `List<AdminEnergyRemedyResponse>`
- `POST /api/v1/admin/energy/remedies` -> `201 Created` `AdminEnergyRemedyResponse`
- `PUT /api/v1/admin/energy/remedies/{id}` -> `AdminEnergyRemedyResponse`
- `PATCH /api/v1/admin/energy/remedies/{id}` -> `AdminEnergyRemedyResponse`
- `DELETE /api/v1/admin/energy/remedies/{id}` -> `204 No Content`

### 3.5. Sửa `RewardService.summary(UUID userId)` (`QA-19`)
- Inject `WalletTransactionRepository` vào `RewardService`.
- Tính:
  ```java
  long earned = rewards.sumAmount(userId, RewardTransaction.TYPE_HISTORY_POINTS);
  long spent = walletLedger.sumDebits(userId);
  long availablePoints = Math.max(0L, earned - spent);
  ```
- Trả `availablePoints` trong `RewardSummaryResponse.historyPoints()`.
