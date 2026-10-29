import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../../core/widgets/tactile_3d_button.dart';
import '../../energy/data/energy_dto.dart';
import '../../energy/data/energy_providers.dart';

/// Màn hình M-28: Quản Lý Năng Lượng & Viện Thái Y (Energy Management)
/// GAME-07 (Issue #28): 4 vật phẩm Phương án B — server quyết eligible/
/// cooldown/price; client chỉ render + gửi intent với Idempotency-Key.
///
/// UI/UX Pro Max — đồng bộ `IslandShopScreen` + `LearnerDashboardScreen`:
/// - Top Bar có `_buildWalletPill` (ví Điểm Sử Ký từ `dto.pointsBalance`).
/// - Hero Card Nhật Quang với thanh Thể lực 10 vạch + Badge trạng thái
///   sinh lực (SUNG MÃN / ĐIỀU HÒA / CẦN BỒI BỔ).
/// - 4 thẻ phương thang với `Tactile3DButton`, countdown cooldown thực tế.
/// - Dialog xác nhận trước + Dialog chúc mừng sau khi bồi bổ.
class EnergyManagementScreen extends ConsumerStatefulWidget {
  const EnergyManagementScreen({super.key});

  @override
  ConsumerState<EnergyManagementScreen> createState() =>
      _EnergyManagementScreenState();
}

class _EnergyManagementScreenState extends ConsumerState<EnergyManagementScreen>
    with WidgetsBindingObserver {
  /// Timer 1s CHỈ cập nhật phần hiển thị countdown — không gọi API.
  Timer? _ticker;

  /// Chống refresh chồng khi countdown chạm 0 (timer tick tiếp theo không
  /// lên lịch thêm request nữa cho tới khi fetch xong).
  bool _refreshingAtZero = false;

  /// Chặn double-tap refill cùng remedy — key = remedyCode.
  final Set<String> _inFlightRemedies = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mở màn → đảm bảo dữ liệu mới nhất (invalidateSelf nếu đã có cache).
    // refresh() đã swallow lỗi vào AsyncError — UI hiển thị error view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(energyProvider.notifier).refresh();
    });
  }

  /// Đồng bộ ticker với trạng thái hiện tại: chỉ tick khi THỰC SỰ có mốc
  /// hồi để đếm hoặc remedy nào đó còn cooldown (đầy/lỗi/loading → không
  /// timer → pumpAndSettle/test OK, không tốn CPU vô ích). Mỗi tick chỉ
  /// rebuild phần hiển thị — không gọi API.
  void _syncTicker(EnergyStateDto? dto) {
    final bool needRecoveryTick = dto?.timeUntilNextRecovery() != null;
    final bool needCooldownTick = dto?.remedies
            .any((r) => r.timeUntilAvailable(dto.serverNow) != null) ??
        false;
    final bool needTick = needRecoveryTick || needCooldownTick;
    if (needTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {}); // chỉ rebuild phần countdown
        _maybeRefreshAtZero();
      });
    } else if (!needTick) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App quay lại foreground → refetch trạng thái server (recovery có thể
  /// đã trôi qua nhiều chu kỳ khi app nằm nền).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(energyProvider.notifier).refresh();
    }
  }

  /// Countdown chạm 0 → gọi lại GET /me/energy MỘT lần để lấy trạng thái
  /// authoritative (có thể đã +5 hoặc đầy). Không tự cộng vào state.
  void _maybeRefreshAtZero() {
    if (_refreshingAtZero) return;
    final dto = ref.read(energyProvider).value;
    final remain = dto?.timeUntilNextRecovery();
    if (dto == null || remain == null || remain > Duration.zero) return;
    _refreshingAtZero = true;
    ref
        .read(energyProvider.notifier)
        .refresh()
        .whenComplete(() => _refreshingAtZero = false);
  }

  @override
  Widget build(BuildContext context) {
    final energyAsync = ref.watch(energyProvider);
    // Ticker chỉ tồn tại khi thật sự có mốc hồi để đếm — data lỗi /
    // đầy / chưa có nextRecoveryAt → huỷ timer (không tick vô ích,
    // không cản pumpAndSettle trong test).
    ref.listen(energyProvider, (_, next) => _syncTicker(next.value));

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBF4), // Giấy dó tầng sáng
              Color(0xFFF7F2E7),
              Color(0xFFF2EADC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, energyAsync.value),
              Expanded(
                child: energyAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AsyncStateView.error(
                        error: e,
                        onRetry: () =>
                            ref.read(energyProvider.notifier).refresh(),
                      ),
                    ),
                  ),
                  data: (dto) => RefreshIndicator(
                    color: DauVietColors.cinnabarRed,
                    onRefresh: () =>
                        ref.read(energyProvider.notifier).refresh(),
                    child: _buildContent(context, dto),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EnergyStateDto dto) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEnergyGaugeHero(dto),
          const SizedBox(height: 16),
          _buildRemediesList(dto),
          const SizedBox(height: 16),
          _buildPhysicianAdviceCard(),
          const SizedBox(height: 20),
          DongSonButton(
            label: context.canPop()
                ? 'QUAY LẠI BÀI HỌC'
                : 'VỀ BÀN HỌC TẬP (DASHBOARD)',
            icon: context.canPop()
                ? Icons.arrow_back_rounded
                : Icons.home_rounded,
            variant: DongSonButtonVariant.imperialGold,
            height: 48,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /* ==================== TOP BAR ==================== */

  // Header đỉnh trang — đồng bộ IslandShopScreen: back button 44dp +
  // badge "VIỆN THÁI Y" heritageGreen + tiêu đề + ví Điểm Sử Ký góc phải.
  Widget _buildTopBar(BuildContext context, EnergyStateDto? dto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.paperBackground,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: DauVietColors.inkText,
            tooltip: 'Quay lại',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SectionEyebrow(
                      'VIỆN THÁI Y',
                      color: DauVietColors.jade,
                      showShadow: false,
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'QUẢN LÝ THỂ LỰC',
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 16,
                          color: DauVietColors.inkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Dưỡng Tâm • Phục Hồi Sinh Lực Sĩ Tử',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _buildWalletPill(dto?.pointsBalance),
        ],
      ),
    );
  }

  /// Badge Ví Điểm Sử Ký — đồng bộ với `_buildWalletPill` của
  /// IslandShopScreen: parchmentContainer + viền imperialGold 1.5px +
  /// icon stars_rounded + AnimatedSwitcher hiển thị số.
  Widget _buildWalletPill(int? points) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            color: DauVietColors.imperialGold,
            size: 20,
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              points != null ? '$points' : '...',
              key: ValueKey<int?>(points),
              style: DauVietTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: DauVietColors.woodBrown,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ==================== HERO GAUGE ==================== */

  // Hero Card Nhật Quang — ParchmentCard viền kép imperialGold + vòng
  // huy hiệu Nhật Quang trái + số chỉ số + Badge trạng thái sinh lực +
  // thanh 10 vạch TweenAnimationBuilder.
  Widget _buildEnergyGaugeHero(EnergyStateDto dto) {

    final Duration? remain = dto.timeUntilNextRecovery();
    final _VitalStatus status = _vitalStatusOf(dto);

    return TactileCard(
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vòng huy hiệu Nhật Quang (Đông Sơn)
              _buildSunDiskBadge(dto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THỂ LỰC HIỆN TẠI',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DauVietColors.cinnabarRed,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${dto.current}',
                          style: DauVietTypography.headlineLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: dto.isDepleted
                                ? DauVietColors.cinnabarRed
                                : DauVietColors.inkText,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/ ${dto.max} ⚡',
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: DauVietColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildVitalBadge(status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Thanh Sinh Lực 10 vạch — TweenAnimationBuilder trượt mượt.
          _buildSegmentedEnergyBar(dto),
          const SizedBox(height: 12),

          // Dải hồi phục tự nhiên + countdown.
          _recoveryLine(dto, remain),

          if (dto.isDepleted) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: DauVietColors.cinnabarRed.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Thể lực đã cạn. Bạn vẫn có thể đọc tư liệu và ôn tập '
                'trong lúc chờ hồi phục.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.cinnabarRed,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Vòng huy hiệu Nhật Quang — icon bolt + viền đồng.
  Widget _buildSunDiskBadge(EnergyStateDto dto) {
    final bool depleted = dto.isDepleted;
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: depleted
              ? [
                  DauVietColors.cinnabarRed.withValues(alpha: 0.15),
                  DauVietColors.cinnabarRed.withValues(alpha: 0.05),
                ]
              : [
                  DauVietColors.imperialGold.withValues(alpha: 0.35),
                  DauVietColors.imperialGold.withValues(alpha: 0.12),
                ],
        ),
        border: Border.all(
          color: depleted
              ? DauVietColors.cinnabarRed
              : DauVietColors.imperialGold,
          width: 2.0,
        ),
      ),
      child: Icon(
        Icons.bolt_rounded,
        color: depleted
            ? DauVietColors.cinnabarRed
            : DauVietColors.imperialGold,
        size: 34,
      ),
    );
  }

  /// Badge trạng thái sinh lực — 3 ngưỡng theo spec.
  _VitalStatus _vitalStatusOf(EnergyStateDto dto) {
    if (dto.current >= 80) return _VitalStatus.sungMan;
    if (dto.current >= 30) return _VitalStatus.dieuHoa;
    return _VitalStatus.canBoiBo;
  }

  Widget _buildVitalBadge(_VitalStatus status) {
    final (label, color) = switch (status) {
      _VitalStatus.sungMan => ('SUNG MÃN', DauVietColors.heritageGreen),
      _VitalStatus.dieuHoa => ('ĐIỀU HÒA', DauVietColors.imperialGold),
      _VitalStatus.canBoiBo => ('CẦN BỒI BỔ', DauVietColors.cinnabarRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        label,
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Thanh Sinh Lực 10 vạch — TweenAnimationBuilder cho trượt mượt khi
  /// nạp; mỗi vạch 10⚡ tương ứng 1 lượt chịu sai câu chấm điểm.
  Widget _buildSegmentedEnergyBar(EnergyStateDto dto) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: dto.fraction),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                // Track nền
                Container(
                  color: DauVietColors.outlineVariant.withValues(alpha: 0.4),
                ),
                // Thanh fill
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: dto.isDepleted
                            ? const [Color(0xFFE85A4F), Color(0xFFC8402F)]
                            : const [Color(0xFF6AB04C), Color(0xFF3E8E5E)],
                      ),
                    ),
                  ),
                ),
                // 9 vạch phân cách trắng chia 10 ô
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return Stack(
                      children: [
                        for (int i = 1; i < 10; i++)
                          Positioned(
                            left: (w * i / 10) - 0.75,
                            top: 0,
                            bottom: 0,
                            width: 1.5,
                            child: Container(
                              color: Colors.white
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recoveryLine(EnergyStateDto dto, Duration? remain) {
    final String rate = dto.recoveryIntervalMinutes > 0
        ? 'Hồi tự nhiên: +${dto.recoveryAmount} Thể lực / '
            '${dto.recoveryIntervalMinutes} phút'
        : 'Hồi phục theo cấu hình máy chủ';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.timelapse_rounded,
          size: 16,
          color: DauVietColors.inkMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rate,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: dto.isFull
                      ? DauVietColors.natureGreen
                      : DauVietColors.inkMuted,
                  fontWeight:
                      dto.isFull ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (!dto.isFull && remain != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Hồi tiếp: ${_formatCountdown(remain)}',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.riverBlue,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatCountdown(Duration d) {
    final int total = d.inSeconds;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /* ==================== REMEDIES LIST ==================== */

  // Danh sách thẻ phương thang — server quyết eligible/blockReasons;
  // client chỉ render + mở dialog + gọi refill.
  Widget _buildRemediesList(EnergyStateDto dto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medical_services_outlined,
              color: DauVietColors.heritageGreen,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'LIỆU PHÁP VIỆN THÁI Y:',
              style: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkMuted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (dto.remedies.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DauVietColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              'Viện Thái Y đang soạn thang thuốc. Vui lòng quay lại sau.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: DauVietColors.inkMuted,
              ),
            ),
          )
        else
          ...dto.remedies.map((r) => _buildRemedyCard(dto, r)),
      ],
    );
  }

  /// Một thẻ phương thang — bo góc 20px + viền rarity + nút CTA trạng
  /// thái do server quyết.
  Widget _buildRemedyCard(EnergyStateDto dto, EnergyRemedyDto remedy) {
    final _RarityStyle rarityStyle = _rarityStyleOf(remedy.rarity);
    final Duration? cooldownRemain =
        remedy.timeUntilAvailable(dto.serverNow);
    final bool inFlight = _inFlightRemedies.contains(remedy.code);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rarityStyle.borderColor.withValues(alpha: 0.65),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: DauVietColors.inkMuted.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Khung tranh 76x76 + badge +N⚡
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: rarityStyle.borderColor
                            .withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      remedy.assetImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        color: rarityStyle.borderColor
                            .withValues(alpha: 0.12),
                        child: Icon(
                          _remedyIconOf(remedy.code),
                          color: rarityStyle.borderColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.heritageGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '+${remedy.energyGain} ⚡',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag Phẩm cấp + Tag Hồi chiêu
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _miniTag(
                          _rarityLabel(remedy.rarity),
                          rarityStyle.textColor,
                          rarityStyle.borderColor,
                        ),
                        if (remedy.cooldownSeconds > 0)
                          _miniTag(
                            _cooldownLabel(remedy.cooldownSeconds),
                            DauVietColors.riverBlue,
                            DauVietColors.riverBlue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      remedy.title,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remedy.description,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: DauVietColors.inkMuted,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hàng Giá & CTA
          _remedyCtaRow(dto, remedy, cooldownRemain, inFlight),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color fg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  /// Hàng giá + nút hành động — switch theo server-decided blockReasons.
  Widget _remedyCtaRow(EnergyStateDto dto, EnergyRemedyDto remedy,
      Duration? cooldownRemain, bool inFlight) {
    // Đầy sinh lực → pill trạng thái, không nút.
    if (remedy.isEnergyFull) {
      return _statusPill(
        'ĐÃ ĐẦY SINH LỰC',
        color: DauVietColors.natureGreen,
        icon: Icons.check_circle_rounded,
      );
    }
    // Cooldown → pill countdown thực tế.
    if (remedy.isRateLimited && cooldownRemain != null) {
      return _statusPill(
        'Hồi sau ${_formatCountdown(cooldownRemain)}',
        color: DauVietColors.riverBlue,
        icon: Icons.hourglass_bottom_rounded,
      );
    }
    // Thiếu điểm → nút disabled với lý do.
    if (remedy.isInsufficientFunds) {
      final int missing = remedy.pointsCost - dto.pointsBalance;
      return Row(
        children: [
          Expanded(
            child: Text(
              '★ ${remedy.pointsCost} Điểm Sử Ký',
              style: DauVietTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.errorRed,
              ),
            ),
          ),
          Tactile3DButton(
            label: 'THIẾU $missing ĐIỂM',
            variant: Tactile3DVariant.secondaryParchment,
            height: 40,
            onPressed: null,
          ),
        ],
      );
    }
    // Eligible → nút theo free/paid.
    final String cta = remedy.isFree ? 'NHẬN NGAY' : 'BỒI BỔ';
    final Tactile3DVariant variant = remedy.isFree
        ? Tactile3DVariant.heritageGreen
        : Tactile3DVariant.primaryCinnabar;
    final String priceLabel = remedy.isFree
        ? 'Miễn phí (1 lần/ngày)'
        : '★ ${remedy.pointsCost} Điểm Sử Ký';
    final Color priceColor = remedy.isFree
        ? DauVietColors.heritageGreen
        : DauVietColors.imperialGold;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                priceLabel,
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: priceColor,
                ),
              ),
              if (remedy.effectiveEnergyGain < remedy.energyGain)
                Text(
                  'Hồi thực +${remedy.effectiveEnergyGain}⚡ (gần đầy bình)',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        Tactile3DButton(
          label: inFlight ? 'ĐANG DÙNG...' : cta,
          variant: variant,
          height: 42,
          onPressed:
              inFlight || !remedy.eligible ? null : () => _useRemedy(dto, remedy),
        ),
      ],
    );
  }

  Widget _statusPill(String label,
      {required Color color, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /* ==================== REFILL FLOW ==================== */

  /// Tap nút trên thẻ — free → xác nhận nhẹ rồi execute; paid → dialog
  /// xác nhận so sánh trước/sau (giống IslandShopScreen).
  Future<void> _useRemedy(EnergyStateDto dto, EnergyRemedyDto remedy) async {
    if (!remedy.eligible || _inFlightRemedies.contains(remedy.code)) {
      return;
    }
    if (remedy.isFree) {
      // Gói free — xác nhận nhẹ qua SnackBar-style dialog ngắn.
      final ok = await _confirmUseRemedy(dto, remedy, isFree: true);
      if (ok == true) await _executeRefill(dto, remedy);
    } else {
      final ok = await _confirmUseRemedy(dto, remedy, isFree: false);
      if (ok == true) await _executeRefill(dto, remedy);
    }
  }

  /// Dialog xác nhận trước khi dùng — so sánh Sinh lực trước → sau +
  /// bảng đối chiếu ví cho gói có phí.
  Future<bool?> _confirmUseRemedy(EnergyStateDto dto, EnergyRemedyDto remedy,
      {required bool isFree}) async {
    final int projected =
        (dto.current + remedy.effectiveEnergyGain).clamp(0, dto.max);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.parchmentSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isFree ? 'XÁC NHẬN NHẬN LIỆU PHÁP' : 'XÁC NHẬN BỒI BỔ SINH LỰC',
          style: DauVietTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: DauVietColors.cinnabarRed,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn muốn dùng "${remedy.title}" để bồi bổ '
              '+${remedy.effectiveEnergyGain}⚡ Thể lực?',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DauVietColors.parchmentContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sinh lực hiện tại:'),
                      Text(
                        '${dto.current}/${dto.max} ⚡',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sau khi dùng:'),
                      Text(
                        '$projected/${dto.max} ⚡ '
                        '(+${remedy.effectiveEnergyGain}⚡)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DauVietColors.heritageGreen,
                        ),
                      ),
                    ],
                  ),
                  if (!isFree) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Điểm hiện có:'),
                        Text(
                          '${dto.pointsBalance}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Chi phí phương thang:'),
                        Text(
                          '-${remedy.pointsCost}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: DauVietColors.cinnabarRed,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số dư còn lại:'),
                        Text(
                          '${dto.pointsBalance - remedy.pointsCost}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: DauVietColors.heritageGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'HỦY',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFree
                  ? DauVietColors.heritageGreen
                  : DauVietColors.cinnabarRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isFree ? 'NHẬN NGAY' : 'XÁC NHẬN DÙNG'),
          ),
        ],
      ),
    );
  }

  /// Execute POST refills — server quyết mọi số liệu, client chỉ nhận
  /// snapshot mới. Idempotency-Key UUID v4 mỗi lần bấm.
  Future<void> _executeRefill(
      EnergyStateDto dto, EnergyRemedyDto remedy) async {
    if (_inFlightRemedies.contains(remedy.code)) return;
    setState(() {
      _inFlightRemedies.add(remedy.code);
    });
    final String idempotencyKey = const Uuid().v4();
    try {
      final result = await ref.read(energyProvider.notifier).refillEnergy(
            remedyCode: remedy.code,
            idempotencyKey: idempotencyKey,
          );
      if (!mounted) return;
      _showRefillSuccessDialog(dto, remedy, result);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Liệu pháp chưa hoàn tất, vui lòng thử lại.',
          ),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _inFlightRemedies.remove(remedy.code);
        });
      }
    }
  }

  /// Dialog chúc mừng sau khi refill thành công — icon check + số ⚡ cộng.
  void _showRefillSuccessDialog(EnergyStateDto old, EnergyRemedyDto remedy,
      EnergyRefillResultDto result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.parchmentSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: DauVietColors.natureGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BỒI BỔ THÀNH CÔNG!',
              style: DauVietTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: DauVietColors.heritageGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${remedy.title}" đã phục hồi '
              '+${result.energyCredited}⚡ Thể lực.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            if (result.pointsSpent > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Đã trừ ${result.pointsSpent} Điểm Sử Ký — '
                'còn ${result.walletBalance} Điểm.',
                textAlign: TextAlign.center,
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DauVietColors.heritageGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (context.canPop()) {
                context.pop();
              }
            },
            child: Text(
              context.canPop() ? 'QUAY LẠI BÀI HỌC' : 'TIẾP TỤC',
            ),
          ),
        ],
      ),
    );
  }

  /* ==================== PHYSICIAN ADVICE ==================== */

  // Khung lời dặn của Ngự Y — giữ nguyên bản GAME-03.
  Widget _buildPhysicianAdviceCard() {
    return TactileCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: DauVietColors.paperCardHi,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.spa_rounded,
                color: DauVietColors.jade,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LỜI DẶN DƯỠNG SINH VIỆN THÁI Y:',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '“Học sử cần tinh tấn nhưng dưỡng thần cần điều hòa. '
            'Nghỉ ngơi tĩnh tâm giữa các đợt khảo cứu để tâm trí luôn '
            'sáng suốt, hào khí luôn tràn đầy.”',
            style: DauVietTypography.ancientCitation.copyWith(
              color: DauVietColors.inkText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /* ==================== HELPERS ==================== */

  _RarityStyle _rarityStyleOf(String rarity) {
    return switch (rarity) {
      'COMMON' => _RarityStyle(
          borderColor: DauVietColors.inkMuted,
          textColor: DauVietColors.inkMuted,
        ),
      'UNCOMMON' => _RarityStyle(
          borderColor: DauVietColors.heritageGreen,
          textColor: DauVietColors.heritageGreen,
        ),
      'RARE' => _RarityStyle(
          borderColor: DauVietColors.riverBlue,
          textColor: DauVietColors.riverBlue,
        ),
      'EPIC' => _RarityStyle(
          borderColor: DauVietColors.cinnabarRed,
          textColor: DauVietColors.cinnabarRed,
        ),
      _ => _RarityStyle(
          borderColor: DauVietColors.inkMuted,
          textColor: DauVietColors.inkMuted,
        ),
    };
  }

  String _rarityLabel(String rarity) {
    return switch (rarity) {
      'COMMON' => 'Phổ thông',
      'UNCOMMON' => 'Thanh tao',
      'RARE' => 'Quý hiếm',
      'EPIC' => 'Bảo vật',
      _ => rarity,
    };
  }

  String _cooldownLabel(int seconds) {
    if (seconds % 3600 == 0) {
      final h = seconds ~/ 3600;
      return '${h}h';
    }
    if (seconds % 60 == 0) {
      return '${seconds ~/ 60}p';
    }
    return '${seconds}s';
  }

  IconData _remedyIconOf(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('nuoc') || lower.contains('voi')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('tra') || lower.contains('sen')) {
      return Icons.local_cafe_rounded;
    }
    if (lower.contains('linh') || lower.contains('nam')) {
      return Icons.spa_rounded;
    }
    if (lower.contains('sam') || lower.contains('ngoc')) {
      return Icons.stars_rounded;
    }
    return Icons.medication_rounded;
  }
}

/// Trạng thái sinh lực — 3 ngưỡng theo spec UI/UX Pro Max.
enum _VitalStatus { sungMan, dieuHoa, canBoiBo }

/// Style phẩm cấp remedy — border + text theo rarity.
class _RarityStyle {
  final Color borderColor;
  final Color textColor;
  const _RarityStyle({required this.borderColor, required this.textColor});
}
