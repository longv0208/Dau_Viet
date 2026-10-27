import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../data/island_dto.dart';

/// Modal / Bottom sheet hiển thị tiến độ và thao tác mở rộng Đảo Di Sản.
class IslandUpgradePanel extends StatelessWidget {
  final IslandDto island;
  final VoidCallback onUpgrade;
  final bool isUpgrading;

  const IslandUpgradePanel({
    super.key,
    required this.island,
    required this.onUpgrade,
    this.isUpgrading = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = island.progress;
    final currentTier = island.tier;
    final nextTier = (currentTier + 1).clamp(1, island.maxTier);
    final isMax = island.isMaxTier;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: DauVietColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: DauVietColors.parchmentContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.landscape_rounded,
                  color: DauVietColors.cinnabarRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MỞ RỘNG ĐẢO DI SẢN',
                      style: DauVietTypography.headlineSmall.copyWith(
                        color: DauVietColors.cinnabarRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isMax
                          ? 'Đảo đã đạt quy mô cực đại'
                          : 'Khai khẩn thêm lãnh thổ từ Cấp $currentTier lên Cấp $nextTier',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: DauVietColors.inkMuted,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Badge so sánh Tier hiện tại -> Tier tiếp theo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DauVietColors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTierBadge(
                  title: 'Hiện Tại',
                  tier: currentTier,
                  color: DauVietColors.heritageGreen,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: DauVietColors.imperialGold,
                  size: 28,
                ),
                _buildTierBadge(
                  title: 'Mục Tiêu',
                  tier: isMax ? currentTier : nextTier,
                  color: isMax
                      ? DauVietColors.inkMuted
                      : DauVietColors.cinnabarRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Thanh tiến độ sự kiện
          if (!isMax) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Sự kiện lịch sử hoàn thành',
                    style: DauVietTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
                Text(
                  '${progress.completedEvents} / ${progress.nextTierRequiredEvents}',
                  style: DauVietTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DauVietColors.cinnabarRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.progressFraction,
                minHeight: 12,
                backgroundColor: DauVietColors.outlineVariant.withValues(
                  alpha: 0.4,
                ),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  DauVietColors.imperialGold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Mô tả / Lời nhắc
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isMax
                  ? 'Tuyệt vời! Đảo của bạn đã khai mở toàn bộ các phân khu di sản.'
                  : progress.canUpgrade
                  ? 'Chúc mừng! Bạn đã tích lũy đủ thành tựu lịch sử để mở rộng đảo sang Cấp $nextTier. Hãy nhấn nút để khai mở các vị trí mới!'
                  : 'Cần hoàn thành thêm ${progress.nextTierRequiredEvents - progress.completedEvents} sự kiện lịch sử trên Hành trình để đủ điều kiện mở rộng đảo.',
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: DauVietColors.inkText,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Nút hành động
          if (progress.canUpgrade && !isMax)
            Tactile3DButton(
              label: 'MỞ RỘNG ĐẢO NGAY',
              icon: Icons.auto_awesome_rounded,
              variant: Tactile3DVariant.imperialGold,
              isLoading: isUpgrading,
              onPressed: onUpgrade,
            )
          else if (!isMax)
            Tactile3DButton(
              label: 'TIẾP TỤC HÀNH TRÌNH KHẢO CỔ',
              icon: Icons.map_rounded,
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/dashboard');
              },
            )
          else
            Tactile3DButton(
              label: 'ĐÃ ĐẠT QUY MÔ TỐI ĐA',
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: null,
            ),
        ],
      ),
    );
  }

  Widget _buildTierBadge({
    required String title,
    required int tier,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.inkMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            'CẤP $tier',
            style: DauVietTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
