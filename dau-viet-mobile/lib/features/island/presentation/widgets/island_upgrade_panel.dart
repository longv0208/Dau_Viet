import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../data/island_dto.dart';

/// Modal / Bottom sheet hiển thị tiến độ EXP / Level và thao tác mở rộng
/// Đảo Di Sản. Eligibility hoàn toàn đến từ backend (island.canUpgrade).
/// ISLAND-02: thay thế hiển thị số sự kiện bằng EXP + Level.
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

  static String _tierName(int tier) {
    switch (tier) {
      case 1:
        return 'Nhỏ';
      case 2:
        return 'Vừa';
      case 3:
        return 'Lớn';
      default:
        return 'Cấp $tier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = island.tier;
    final nextTier = island.isMaxTier ? currentTier : (currentTier + 1);
    final isMax = island.isMaxTier;

    final currentExp = island.currentExp;
    final currentLevel = island.currentLevel;
    final nextReqLevel = island.nextTierRequiredLevel;
    final nextReqExp = island.nextTierRequiredExp;
    final canUpgrade = island.canUpgrade;

    // Tiến độ EXP tới ngưỡng yêu cầu (0.0–1.0)
    final double progressFraction = (nextReqExp != null && nextReqExp > 0)
        ? (currentExp / nextReqExp).clamp(0.0, 1.0)
        : (canUpgrade ? 1.0 : 0.0);

    // Số EXP còn thiếu
    final int expRemaining =
        (nextReqExp != null && currentExp < nextReqExp)
            ? (nextReqExp - currentExp)
            : 0;

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
                          ? 'Đảo Di Sản đã đạt quy mô lớn nhất'
                          : 'Từ Đảo ${_tierName(currentTier)} lên Đảo ${_tierName(nextTier)}',
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
                  label: 'Đảo ${_tierName(currentTier)}',
                  color: DauVietColors.heritageGreen,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: DauVietColors.imperialGold,
                  size: 28,
                ),
                _buildTierBadge(
                  title: 'Mục Tiêu',
                  label: isMax ? 'Tối Đa' : 'Đảo ${_tierName(nextTier)}',
                  color: isMax
                      ? DauVietColors.inkMuted
                      : DauVietColors.cinnabarRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // EXP / Level hiện tại
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cấp tài khoản',
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
                Text(
                  'Cấp $currentLevel  ·  $currentExp EXP',
                  style: DauVietTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Thanh tiến độ EXP (chỉ hiện khi chưa max và có ngưỡng)
          if (!isMax && nextReqExp != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'EXP để mở Đảo ${_tierName(nextTier)}',
                    style: DauVietTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
                Text(
                  '$currentExp / $nextReqExp',
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
                value: progressFraction,
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
              _buildHintText(
                isMax: isMax,
                canUpgrade: canUpgrade,
                nextTier: nextTier,
                nextReqLevel: nextReqLevel,
                nextReqExp: nextReqExp,
                expRemaining: expRemaining,
              ),
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: DauVietColors.inkText,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Nút hành động
          if (canUpgrade && !isMax)
            Tactile3DButton(
              label: 'MỞ RỘNG ĐẢO NGAY',
              icon: Icons.auto_awesome_rounded,
              variant: Tactile3DVariant.imperialGold,
              isLoading: isUpgrading,
              onPressed: onUpgrade,
            )
          else if (!isMax)
            Tactile3DButton(
              label: 'TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP',
              icon: Icons.school_rounded,
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/dashboard');
              },
            )
          else
            Tactile3DButton(
              label: 'ĐÃ ĐẠT QUY MÔ LỚN NHẤT',
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: null,
            ),
        ],
      ),
    );
  }

  String _buildHintText({
    required bool isMax,
    required bool canUpgrade,
    required int nextTier,
    required int? nextReqLevel,
    required int? nextReqExp,
    required int expRemaining,
  }) {
    if (isMax) {
      return 'Tuyệt vời! Đảo Di Sản của bạn đã đạt quy mô lớn nhất.';
    }
    if (canUpgrade) {
      return 'Chúc mừng! Bạn đã đủ điều kiện mở rộng sang Đảo ${_tierName(nextTier)}. '
          'Hãy nhấn nút để khai mở các vị trí mới!';
    }
    if (nextReqLevel != null && nextReqExp != null) {
      return 'Cần đạt Cấp $nextReqLevel (tối thiểu $nextReqExp EXP) để mở Đảo '
          '${_tierName(nextTier)}. Còn $expRemaining EXP nữa — tiếp tục hoàn '
          'thành các bài học để tích lũy.';
    }
    return 'Tiếp tục hoàn thành các bài học để tích lũy EXP và mở rộng Đảo Di Sản.';
  }

  Widget _buildTierBadge({
    required String title,
    required String label,
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
            label.toUpperCase(),
            style: DauVietTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
