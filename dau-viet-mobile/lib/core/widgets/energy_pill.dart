import 'package:flutter/material.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Huy hiệu hiển thị Sinh lực (Năng lượng) và Điểm Sử Ký
class EnergyPill extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thẻ Sinh lực (Energy)
        GestureDetector(
          onTap: onEnergyTap,
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
                const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: DauVietColors.imperialGold,
                ),
                const SizedBox(width: 4),
                Text(
                  '$energy/$maxEnergy',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showHistoryPoints) ...[
          const SizedBox(width: 8),

          // Thẻ Điểm Sử Ký
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
}
