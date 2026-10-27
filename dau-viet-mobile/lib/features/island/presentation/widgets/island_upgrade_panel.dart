import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../data/island_dto.dart';

/// Modal / Bottom sheet hiển thị tiến độ EXP / Level tài khoản và thao tác mở rộng
/// Đảo Di Sản. Eligibility hoàn toàn đến từ backend (`island.canUpgrade`).
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

  int _nextSlotCount(int nextTier) {
    if (island.nextTierSlotCount > 0) return island.nextTierSlotCount;
    final fromSlots = island.slots
        .where((s) => s.unlockTier <= nextTier)
        .length;
    if (fromSlots > 0) return fromSlots;
    return nextTier * 4;
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

    final currentSlots = island.unlockedSlotCount;
    final nextSlots = isMax ? currentSlots : _nextSlotCount(nextTier);

    final double progressFraction = (nextReqExp != null && nextReqExp > 0)
        ? (currentExp / nextReqExp).clamp(0.0, 1.0)
        : (canUpgrade ? 1.0 : 0.0);

    final int expRemaining =
        (nextReqExp != null && currentExp < nextReqExp)
            ? (nextReqExp - currentExp)
            : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                          ? 'Đảo Di Sản đã đạt quy mô lớn nhất ($currentSlots ô đất)'
                          : 'Từ Đảo ${_tierName(currentTier)} ($currentSlots ô) lên Đảo ${_tierName(nextTier)} ($nextSlots ô)',
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
          const SizedBox(height: 14),

          // So sánh Quy mô hiện tại -> Quy mô tiếp theo + Số slot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DauVietColors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTierBadge(
                  title: 'Quy mô hiện tại',
                  label: 'Đảo ${_tierName(currentTier)}',
                  subLabel: '$currentSlots vị trí đặt',
                  color: DauVietColors.heritageGreen,
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: DauVietColors.imperialGold,
                  size: 26,
                ),
                _buildTierBadge(
                  title: isMax ? 'Trạng thái' : 'Quy mô tiếp theo',
                  label: isMax ? 'Đảo Lớn (Tối đa)' : 'Đảo ${_tierName(nextTier)}',
                  subLabel: isMax
                      ? 'Toàn bộ $currentSlots vị trí'
                      : 'Mở lên $nextSlots vị trí',
                  color: isMax
                      ? DauVietColors.woodBrown
                      : DauVietColors.cinnabarRed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Thông tin Level tài khoản & điều kiện Level yêu cầu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level tài khoản hiện tại',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                    Text(
                      'Level $currentLevel  ·  $currentExp EXP',
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DauVietColors.inkText,
                      ),
                    ),
                  ],
                ),
                if (!isMax && nextReqLevel != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Điều kiện mở Đảo ${_tierName(nextTier)}',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                      Text(
                        'Level $nextReqLevel${nextReqExp != null ? ' ($nextReqExp EXP)' : ''}',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: canUpgrade
                              ? DauVietColors.heritageGreen
                              : DauVietColors.cinnabarRed,
                        ),
                      ),
                    ],
                  ),
                ],
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
                    'Tiến độ EXP tích lũy',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
                Text(
                  '$currentExp / $nextReqExp EXP',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: canUpgrade
                        ? DauVietColors.heritageGreen
                        : DauVietColors.cinnabarRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 10,
                backgroundColor: DauVietColors.outlineVariant.withValues(
                  alpha: 0.4,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  canUpgrade
                      ? DauVietColors.heritageGreen
                      : DauVietColors.imperialGold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Mô tả / Hướng dẫn tích lũy EXP
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
                nextSlots: nextSlots,
              ),
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: DauVietColors.inkText,
                height: 1.38,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Nút hành động: nếu đã max Tier thì chỉ hiện nút Đóng gọn gàng, không hiện nút nâng cấp vô nghĩa
          if (canUpgrade && !isMax)
            Tactile3DButton(
              label: 'MỞ RỘNG LÊN ĐẢO ${_tierName(nextTier).toUpperCase()}',
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
    required int nextSlots,
  }) {
    if (isMax) {
      return 'Đảo Di Sản của bạn đã mở khóa toàn bộ vùng đất và $nextSlots vị trí trang trí. Hãy ghé Cửa Hàng Di Sản để sưu tầm đủ công trình văn hóa Việt!';
    }
    if (canUpgrade) {
      return 'Bạn đã đạt đủ Level tài khoản để mở rộng sang Đảo ${_tierName(nextTier)} (nâng tổng số ô trang trí lên $nextSlots ô). Nhấn nút bên dưới để mở vùng đất mới!';
    }
    if (nextReqLevel != null && nextReqExp != null) {
      return 'Cần đạt Level tài khoản $nextReqLevel ($nextReqExp EXP) để mở Đảo ${_tierName(nextTier)} ($nextSlots ô đất). Bạn còn thiếu $expRemaining EXP — hoàn thành lần đầu mỗi bài học sẽ nhận +100 EXP.';
    }
    return 'Hoàn thành các bài học lịch sử để tích lũy EXP, nâng Level tài khoản và mở rộng Đảo Di Sản.';
  }

  Widget _buildTierBadge({
    required String title,
    required String label,
    required String subLabel,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label.toUpperCase(),
            style: DauVietTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subLabel,
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.woodBrown,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
