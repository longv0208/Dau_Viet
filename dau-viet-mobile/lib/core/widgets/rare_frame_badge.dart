import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Khung độ hiếm cho bảo vật/dấu vết — COMMON/UNCOMMON/RARE/EPIC.
/// Màu khung + gradient ánh kim theo độ hiếm.
enum ItemRarity { common, uncommon, rare, epic }

extension ItemRarityX on ItemRarity {
  Color get border => switch (this) {
    ItemRarity.common => DauVietColors.outlineVariant,
    ItemRarity.uncommon => DauVietColors.natureGreen,
    ItemRarity.rare => DauVietColors.riverBlue,
    ItemRarity.epic => DauVietColors.imperialGold,
  };

  Color get glow => switch (this) {
    ItemRarity.common => Colors.transparent,
    ItemRarity.uncommon => DauVietColors.natureGreen.withValues(alpha: 0.18),
    ItemRarity.rare => DauVietColors.riverBlue.withValues(alpha: 0.22),
    ItemRarity.epic => DauVietColors.imperialGold.withValues(alpha: 0.30),
  };

  String get label => switch (this) {
    ItemRarity.common => 'Thường',
    ItemRarity.uncommon => 'Hiếm',
    ItemRarity.rare => 'Quý',
    ItemRarity.epic => 'Sử thi',
  };
}

/// Badge khung độ hiếm — wrap quanh card/avatar bảo vật.
class RareFrameBadge extends StatelessWidget {
  final ItemRarity rarity;
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final bool showLabel;
  final bool showGlow;
  final EdgeInsetsGeometry padding;

  const RareFrameBadge({
    super.key,
    required this.rarity,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 2.4,
    this.showLabel = false,
    this.showGlow = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = rarity.border;
    final radius = BorderRadius.circular(borderRadius);

    final framed = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: showGlow && rarity != ItemRarity.common
            ? [
                BoxShadow(
                  color: rarity.glow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
                ...DauVietColors.pixelShadowSm,
              ]
            : DauVietColors.pixelShadowSm,
      ),
      child: child,
    );

    if (!showLabel) return framed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        framed,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            rarity.label.toUpperCase(),
            style: DauVietTypography.labelSmall.copyWith(
              color: DauVietColors.paperBackground,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
