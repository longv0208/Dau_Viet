import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../energy/data/energy_dto.dart';
import '../../energy/data/energy_providers.dart';

/// Màn hình M-28: Quản Lý Năng Lượng & Viện Thái Y (Energy Management)
/// GAME-03: toàn bộ số liệu đến từ GET /me/energy — không còn state giả;
/// countdown tính theo serverTime (bù clock skew), chỉ refresh khi chạm 0.
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
  /// hồi để đếm (đầy/lỗi/loading → không timer → pumpAndSettle/test OK,
  /// không tốn CPU vô ích). Mỗi tick chỉ rebuild phần hiển thị — không
  /// gọi API.
  void _syncTicker(EnergyStateDto? dto) {
    final bool needTick = dto?.timeUntilNextRecovery() != null;
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
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF2F8F4), // Xanh lá thảo dược viện thái y
              DauVietColors.parchmentSurface,
              Color(0xFFFAF2E4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
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
                  data: (dto) => _buildContent(context, dto),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildEnergyGaugeHero(dto),
          const SizedBox(height: 16),
          _buildRemediesList(),
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
            variant: DongSonButtonVariant.secondaryParchment,
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

  // Header đỉnh trang
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.natureGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'VIỆN THÁI Y',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
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
        ],
      ),
    );
  }

  // Khung thước đo năng lượng Hero — số liệu thật từ server.
  Widget _buildEnergyGaugeHero(EnergyStateDto dto) {
    final double percent = dto.fraction;
    final Color barColor = dto.isDepleted
        ? DauVietColors.cinnabarRed
        : (percent < 0.3 ? const Color(0xFFC05621) : DauVietColors.natureGreen);
    final Duration? remain = dto.timeUntilNextRecovery();

    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: dto.isDepleted
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.imperialGold,
                size: 24,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'THỂ LỰC HIỆN TẠI',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${dto.current} / ${dto.max}',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: dto.isDepleted
                      ? DauVietColors.cinnabarRed
                      : DauVietColors.inkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 14,
              backgroundColor: DauVietColors.outlineVariant.withValues(
                alpha: 0.4,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 12),

          // Trạng thái hồi phục: đầy / cạn / đang đếm ngược — số liệu
          // server, không tự suy quy tắc.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.timelapse_rounded,
                size: 16,
                color: DauVietColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(child: _recoveryLine(dto, remain)),
            ],
          ),
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

  Widget _recoveryLine(EnergyStateDto dto, Duration? remain) {
    final String rate = dto.recoveryIntervalMinutes > 0
        ? '+${dto.recoveryAmount} Thể lực mỗi ${dto.recoveryIntervalMinutes} phút'
        : 'Hồi phục theo cấu hình máy chủ';
    if (dto.isFull) {
      return Text(
        '$rate — Thể lực đã đầy',
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: 11,
          color: DauVietColors.natureGreen,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (remain == null) {
      return Text(
        rate,
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: 11,
          color: DauVietColors.inkMuted,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rate,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            color: DauVietColors.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Hồi tiếp sau ${_formatCountdown(remain)}',
          style: DauVietTypography.labelSmall.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: DauVietColors.riverBlue,
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

  // Danh sách liệu pháp — GAME-03: giữ thiết kế nhưng KHÔNG cho tương
  // tác/cộng năng lượng giả. Wallet/chi tiêu chưa có backend (GAME-07)
  // nên mọi item hiển thị trạng thái "Sắp mở".
  Widget _buildRemediesList() {
    final remedies = [
      {
        'title': 'Nước Vối Tĩnh Tâm',
        'desc': 'Bát nước vối ấm lành tính giúp sĩ tử thư giãn gân cốt.',
        'assetImage': 'assets/items/energy_nuoc_voi.png',
        'icon': Icons.psychology_rounded,
        'color': DauVietColors.natureGreen,
      },
      {
        'title': 'Trà Sen Tây Hồ',
        'desc': 'Trà sen ướp hương thơm ngát giúp tinh thần minh mẫn.',
        'assetImage': 'assets/items/energy_tra_sen.png',
        'icon': Icons.local_cafe_rounded,
        'color': DauVietColors.imperialGold,
      },
      {
        'title': 'Nấm Linh Chi Ngự Dược',
        'desc': 'Thảo dược đại bổ triều đình bồi bổ nguyên khí.',
        'assetImage': 'assets/items/energy_linh_chi.png',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFFC05621),
      },
      {
        'title': 'Sâm Ngọc Linh Hoàng Gia',
        'desc': 'Bảo vật sâm rừng nghìn năm phục hồi sinh lực tức thì.',
        'assetImage': 'assets/items/energy_sam_ngoc_linh.png',
        'icon': Icons.stars_rounded,
        'color': DauVietColors.cinnabarRed,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medical_services_outlined,
              color: DauVietColors.natureGreen,
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

        ...remedies.map((rem) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (rem['color'] as Color).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (rem['color'] as Color).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Image.asset(
                    rem['assetImage'] as String,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        color: (rem['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        rem['icon'] as IconData,
                        color: rem['color'] as Color,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rem['title'] as String,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: DauVietColors.inkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rem['desc'] as String,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 10.5,
                          color: DauVietColors.inkMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Sắp mở',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // GAME-03: chưa có Wallet Service — liệu pháp bằng Điểm Sử Ký
        // chỉ công bố, không CTA mua.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F1E2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: DauVietColors.imperialGold.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            'Liệu pháp hồi phục bằng Điểm Sử Ký sẽ được mở ở bản cập '
            'nhật tiếp theo.',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: DauVietColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }

  // Khung lời dặn của Ngự Y
  Widget _buildPhysicianAdviceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F1E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.spa_rounded,
                color: DauVietColors.cinnabarRed,
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
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              fontStyle: FontStyle.italic,
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
