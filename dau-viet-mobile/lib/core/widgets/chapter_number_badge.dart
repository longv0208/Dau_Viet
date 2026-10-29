import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Huy hiệu số chương / số bước — "01", "02", "A", "B"…
/// Theo phong cách Landing Page: font pixel (Press Start 2P), chapter-green,
/// pixel-shadow-sm.
class ChapterNumberBadge extends StatelessWidget {
  final String label; // "01", "02", "A"…
  final double size;
  final Color color;
  final bool filled;

  const ChapterNumberBadge(
    this.label, {
    super.key,
    this.size = 40,
    this.color = DauVietColors.chapterGreen,
    this.filled = false,
  });

  /// Dạng tròn filled — dùng cho status completed.
  const ChapterNumberBadge.filled(
    this.label, {
    super.key,
    this.size = 40,
    this.color = DauVietColors.heritageGreen,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = DauVietTypography.chapterNumberSmall.copyWith(
      fontSize: size * 0.45,
      color: filled ? DauVietColors.paperBackground : color,
      height: 1.0,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : DauVietColors.paperCard,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: DauVietColors.pixelShadowSm,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: Text(label, style: textStyle, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
