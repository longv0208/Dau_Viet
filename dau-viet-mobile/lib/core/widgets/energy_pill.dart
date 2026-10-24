import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/energy/data/energy_providers.dart';
import '../../features/rewards/data/reward_providers.dart';
import '../api/api_config.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Huy hiệu hiển thị Thể lực (⚡) và Điểm Sử Ký — GAME-03.
///
/// Real mode đọc `energyProvider` + `rewardSummaryProvider` — KHÔNG hard-code
/// 100/150: loading → pill mờ, lỗi → pill có nút retry nhỏ thay vì số giả.
/// Mock mode (USE_MOCK) giữ giá trị demo truyền vào như trước.
///
/// Caller vẫn truyền `energy`/`historyPoints` cho mock mode + backward
/// compat với các call site cũ — real mode provider override.
class EnergyPill extends ConsumerWidget {
  final int energy;
  final int maxEnergy;
  final int historyPoints;
  final bool showHistoryPoints;
  final VoidCallback? onEnergyTap;

  const EnergyPill({
    super.key,
    this.energy = 100,
    this.maxEnergy = 100,
    this.historyPoints = 150,
    this.showHistoryPoints = true,
    this.onEnergyTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ApiConfig.useMock) {
      return _pillRow(
        current: energy,
        max: maxEnergy,
        historyPoints: historyPoints,
        showPoints: showHistoryPoints,
        state: _PillState.ready,
        onTap: onEnergyTap,
        onRetry: null,
      );
    }
    final energyAsync = ref.watch(energyProvider);
    final pointsAsync = ref.watch(rewardSummaryProvider);
    return energyAsync.when(
      loading: () => _pillRow(
        current: null,
        max: null,
        historyPoints: pointsAsync.value?.historyPoints,
        showPoints: showHistoryPoints,
        state: _PillState.loading,
        onTap: onEnergyTap,
        onRetry: null,
      ),
      error: (_, _) => _pillRow(
        current: null,
        max: null,
        historyPoints: null,
        showPoints: false,
        state: _PillState.error,
        onTap: null,
        onRetry: () => ref.read(energyProvider.notifier).refresh(),
      ),
      data: (dto) => _pillRow(
        current: dto.current,
        max: dto.max,
        historyPoints: pointsAsync.value?.historyPoints,
        showPoints: showHistoryPoints,
        state: _PillState.ready,
        onTap: onEnergyTap,
        onRetry: null,
      ),
    );
  }

  Widget _pillRow({
    required int? current,
    required int? max,
    required int? historyPoints,
    required bool showPoints,
    required _PillState state,
    required VoidCallback? onTap,
    required VoidCallback? onRetry,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DauVietColors.outlineVariant, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: _boltColor(current, max, state),
                ),
                const SizedBox(width: 4),
                _energyLabel(current, max, state, onRetry),
              ],
            ),
          ),
        ),
        if (showPoints && historyPoints != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DauVietColors.outlineVariant, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: DauVietColors.cinnabarRed,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$historyPoints',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DauVietColors.cinnabarRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _boltColor(int? current, int? max, _PillState state) {
    if (state != _PillState.ready || current == null || max == null) {
      return DauVietColors.imperialGold;
    }
    if (current <= 0) return DauVietColors.cinnabarRed;
    if (max > 0 && current / max < 0.3) return const Color(0xFFC05621);
    return DauVietColors.imperialGold;
  }

  Widget _energyLabel(
    int? current,
    int? max,
    _PillState state,
    VoidCallback? onRetry,
  ) {
    switch (state) {
      case _PillState.loading:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      case _PillState.error:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(
            Icons.refresh_rounded,
            size: 14,
            color: DauVietColors.cinnabarRed,
          ),
        );
      case _PillState.ready:
        return Text(
          '$current/$max',
          style: DauVietTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: current != null && current <= 0
                ? DauVietColors.cinnabarRed
                : DauVietColors.inkText,
          ),
        );
    }
  }
}

enum _PillState { loading, ready, error }
