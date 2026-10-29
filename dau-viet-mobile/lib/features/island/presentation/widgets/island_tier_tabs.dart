import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';

/// Thanh chuyển 3 cấp đảo (🌱 Đảo Nhỏ / 🏡 Đảo Vừa / 🏰 Đảo Lớn).
/// Chọn tab thấp hơn/equal tier để xem đảo hiện tại ở quy mô đó;
/// tab cao hơn mở card preview + điều kiện mở khoá.
class IslandTierTabs extends StatelessWidget {
  final IslandDto island;
  final int previewTier;
  final ValueChanged<int> onSelectTier;

  const IslandTierTabs({
    super.key,
    required this.island,
    required this.previewTier,
    required this.onSelectTier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xE6FFF8EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9C098), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in island.tiers) _tab(t),
          if (island.tiers.isEmpty) ...[
            _legacyTab(1),
            _legacyTab(2),
            _legacyTab(3),
          ],
        ],
      ),
    );
  }

  Widget _tab(IslandTierInfoDto info) {
    final isActive = previewTier == info.tier;
    final isUnlocked = info.unlocked;
    final icon = switch (info.tier) {
      1 => '🌱',
      2 => '🏡',
      3 => '🏰',
      _ => '🏝',
    };
    final label = switch (info.nameKey) {
      'tier.small' => 'Đảo Nhỏ',
      'tier.medium' => 'Đảo Vừa',
      'tier.grand' => 'Đảo Lớn',
      _ => 'Cấp ${info.tier}',
    };

    return GestureDetector(
      onTap: () => onSelectTier(info.tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? DauVietColors.heritageGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : isUnlocked
                          ? DauVietColors.inkText
                          : DauVietColors.inkMuted,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (!isUnlocked) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.lock_rounded,
                size: 11,
                color: DauVietColors.inkMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legacyTab(int tier) {
    final isActive = previewTier == tier;
    final isUnlocked = island.tier >= tier;
    final icon = switch (tier) { 1 => '🌱', 2 => '🏡', _ => '🏰' };
    final label = switch (tier) {
      1 => 'Đảo Nhỏ',
      2 => 'Đảo Vừa',
      _ => 'Đảo Lớn',
    };
    return GestureDetector(
      onTap: () => onSelectTier(tier),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? DauVietColors.heritageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '$icon $label',
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive
                ? Colors.white
                : isUnlocked
                    ? DauVietColors.inkText
                    : DauVietColors.inkMuted,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
