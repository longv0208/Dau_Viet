import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Eyebrow chip kiểu Landing Page:
/// `CHƯƠNG 01 · HÀNH TRÌNH` — uppercase, mono-bold, viền 2px, pixel-shadow-sm.
///
/// Dùng để đánh dấu section/chapter/clue trên mọi màn.
class SectionEyebrow extends StatelessWidget {
  final String text;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool showShadow;

  const SectionEyebrow(
    this.text, {
    super.key,
    this.color = DauVietColors.cinnabarRed,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(4),
        boxShadow: showShadow ? DauVietColors.pixelShadowSm : null,
      ),
      child: Text(
        text.toUpperCase(),
        style: DauVietTypography.sectionEyebrow.copyWith(color: color),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
