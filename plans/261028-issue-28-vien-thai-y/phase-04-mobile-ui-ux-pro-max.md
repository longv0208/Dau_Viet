# Phase 04 — Mobile UI/UX Pro Max (`EnergyManagementScreen` — `M-28`)

## 1. Mục tiêu
Nâng cấp toàn diện tầng dữ liệu và giao diện màn hình **Viện Thái Y (`EnergyManagementScreen` — route `/energy`)** trong `dau-viet-mobile` theo chuẩn **`ui-ux-pro-max`**, đồng bộ 100% với `LearnerDashboardScreen`, `IslandShopScreen`, `InventoryScreen` và `LearningStreakScreen`.

## 2. Danh sách File Chỉnh sửa
- `dau-viet-mobile/lib/features/energy/data/energy_dto.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_api_client.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/api_energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/mock_energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_providers.dart`
- `dau-viet-mobile/lib/features/meta/presentation/energy_management_screen.dart`

## 3. Chi tiết Tầng Data & State (`lib/features/energy/data/`)

### 3.1. `energy_dto.dart`
- Thêm `EnergyRemedyDto`:
  - Trường: `id`, `code`, `title`, `description`, `rarity`, `iconKey`, `assetId`, `energyGain`, `pointsCost`, `cooldownSeconds`, `eligible`, `effectiveEnergyGain`, `cooldownEndsAt`, `blockReasons`.
  - Helper:
    - `bool get isFree => pointsCost <= 0;`
    - `bool get isRateLimited => blockReasons.contains('REFILL_RATE_LIMITED');`
    - `bool get isEnergyFull => blockReasons.contains('ENERGY_FULL');`
    - `bool get isInsufficientFunds => blockReasons.contains('INSUFFICIENT_FUNDS');`
    - `String get assetImagePath => 'assets/items/$iconKey.png';`
    - `Duration? timeUntilAvailable(DateTime currentServerNow)`: tính thời gian chờ còn lại theo `serverNow` đã bù clock skew.
- Mở rộng `EnergyStateDto`:
  - Thêm `final int pointsBalance;` (mặc định `0` nếu JSON cũ chưa gửi).
  - Thêm `final List<EnergyRemedyDto> remedies;` (mặc định `const []` nếu JSON cũ chưa gửi).
  - Thêm helper `Duration? timeUntilRemedyAvailable(EnergyRemedyDto remedy)`.
- Thêm `EnergyRefillResultDto`:
  - Trường: `energy` (`EnergyStateDto`), `remedyCode`, `energyCredited`, `pointsSpent`, `walletBalance`, `refillAt`, `nextEligibleAt`, `serverTime`.

### 3.2. `energy_providers.dart` (`EnergyController`)
- Thêm phương thức `Future<EnergyRefillResultDto> refillEnergy({required String remedyCode, String? idempotencyKey})`:
  - Sinh `Idempotency-Key` (UUID v4) nếu chưa truyền.
  - Gọi `repo.refillEnergy(remedyCode: remedyCode, idempotencyKey: key)`.
  - Cập nhật `applySnapshot(result.energy)` ngay lập tức.
  - Gọi `ref.invalidate(rewardSummaryProvider)` và `ref.invalidate(islandWalletProvider)` để đồng bộ số dư Điểm Sử Ký trên toàn bộ các màn hình (`ProfileScreen`, `EnergyPill`, `IslandShopScreen`).

## 4. Chi tiết Giao diện `EnergyManagementScreen` (`UI/UX Pro Max`)

### 4.1. Cấu trúc Bố cục & Đồng bộ Thiết kế
1. **Nền & Kéo làm mới (`RefreshIndicator`):**
   - Nền `LinearGradient` giấy dó 3 tầng (`#FFFBF4` -> `#F7F2E7` -> `#F2EADC`).
   - Bọc `SingleChildScrollView` (`AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`) trong `RefreshIndicator` màu `DauVietColors.cinnabarRed`.
2. **Top Bar (`_buildTopBar`) — Đồng bộ với `IslandShopScreen`:**
   - Nút Back `Icons.arrow_back_ios_new_rounded` (`44x44dp`).
   - Cụm tiêu đề: Badge `VIỆN THÁI Y` (`DauVietColors.heritageGreen`) + `QUẢN LÝ THỂ LỰC` (`DauVietTypography.headlineSmall`) + phụ đề `Dưỡng Tâm • Phục Hồi Sinh Lực Sĩ Tử`.
   - Góc phải: **Huy hiệu Ví Điểm Sử Ký (`_buildWalletPill`)** đồng bộ với `IslandShopScreen` (`parchmentContainer`, viền `imperialGold` `1.5px`, icon `Icons.stars_rounded` + `AnimatedSwitcher` hiển thị `dto.pointsBalance`).
3. **Hero Card — Đồng Hồ Nhật Quang Đông Sơn & Thanh Sinh Lực 10 Vạch (`_buildEnergyGaugeHero`):**
   - Dùng `ParchmentCard` viền kép `imperialGold`.
   - **Vòng Huy hiệu Nhật Quang** bên trái + Chỉ số lớn `${dto.current} / ${dto.max} ⚡` + **Badge Trạng thái Sinh lực**:
     - `80..100 ⚡`: **SUNG MÃN** (`DauVietColors.heritageGreen`)
     - `30..79 ⚡`: **ĐIỀU HÒA** (`DauVietColors.imperialGold`)
     - `0..29 ⚡`: **CẦN BỒI BỔ** (`DauVietColors.cinnabarRed`)
   - **Thanh Sinh Lực 10 Vạch (`_buildSegmentedEnergyBar`):**
     - Dùng `TweenAnimationBuilder<double>` (`duration: 400ms`, `Curves.easeOutCubic`) để thanh tiến trình trượt tăng mượt mà khi nạp.
     - Vẽ 10 vạch phân cách (mỗi vạch tương ứng `10 ⚡` = 1 lượt chịu sai câu chấm điểm).
   - **Dải Hồi phục Tự nhiên & Countdown:**
     - Hiển thị `Hồi tự nhiên: +${dto.recoveryAmount} Thể lực / ${dto.recoveryIntervalMinutes} phút` và Pill đếm ngược `Hồi tiếp: MM:SS` (`FontFeature.tabularFigures()`).
4. **Danh sách Thẻ Phương Thang (`_buildRemediesList` & `_buildRemedyCard`) — Đồng bộ với `IslandShopScreen`:**
   - Mỗi vật phẩm trong `dto.remedies` hiển thị trong thẻ bo góc `20px`, nền `parchmentContainer`, viền theo `rarity`, bóng đổ `DauVietColors.heritageShadow`.
   - **Khung tranh `76x76dp` bên trái:** Hiển thị `Image.asset(remedy.assetImagePath)` kèm **Badge nổi `+${remedy.energyGain} ⚡`** ở cạnh dưới.
   - **Cột thông tin:** Tag Phẩm cấp (`Phổ thông`, `Thanh tao`, `Quý hiếm`, `Bảo vật`) + Tag Hồi chiêu (`4h`, `12h`, `24h`), Tên vật phẩm (`Noto Serif Bold`), Mô tả công dụng (`Be Vietnam Pro`).
   - **Hàng Giá & Nút hành động (`Tactile3DButton`):**
     - **Khi `eligible == true`:**
       - Gói miễn phí (`pointsCost == 0`): Nhãn `"Miễn phí (1 lần/ngày)"` màu `heritageGreen` + `Tactile3DButton` (`Tactile3DVariant.heritageGreen`, label: `'NHẬN NGAY'`).
       - Gói Điểm Sử Ký (`pointsCost > 0`): Nhãn `★ ${remedy.pointsCost} Điểm Sử Ký` + `Tactile3DButton` (`Tactile3DVariant.primaryCinnabar`, label: `'BỒI BỔ'`).
     - **Khi đang hồi chiêu (`isRateLimited`):**
       - Pill đếm ngược thời gian thực: `Hồi sau ${_formatCountdown(remainCooldown)}` (màu `riverBlue`, tự động mở khóa ngay khi chạm `00:00`).
     - **Khi Thể lực đã đầy (`isEnergyFull`):**
       - Pill trạng thái: `'ĐÃ ĐẦY SINH LỰC'` (màu `natureGreen`).
     - **Khi thiếu Điểm Sử Ký (`isInsufficientFunds`):**
       - Nhãn giá màu `errorRed` + `Tactile3DButton` (`Tactile3DVariant.secondaryParchment`, label: `'THIẾU ${remedy.pointsCost - dto.pointsBalance} ĐIỂM'`, `onPressed: null`).
5. **Hộp thoại Xác nhận Bồi bổ & Chúc mừng (`_confirmUseRemedy` & `_showRefillSuccessDialog`):**
   - Với gói có phí (`pointsCost > 0`), hiển thị `AlertDialog` xác nhận giống `IslandShopScreen`:
     - So sánh trực quan **Sinh lực trước -> sau**: `${dto.current}/${dto.max} ⚡ ➔ ${projected}/${dto.max} ⚡ (+${remedy.effectiveEnergyGain}⚡)`.
     - Bảng đối chiếu: **Điểm hiện có** / **Chi phí phương thang** / **Số dư còn lại**.
   - Sau khi nạp thành công: hiển thị Dialog chúc mừng hồi phục kèm nút **"TIẾP TỤC"** (hoặc **"QUAY LẠI BÀI HỌC"** nếu `context.canPop()`).
