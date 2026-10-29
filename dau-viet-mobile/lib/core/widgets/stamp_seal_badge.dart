import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Huy hiệu đóng dấu triện đỏ chu sa.
/// Vòng tròn viền kép, chữ ngắn ("DẤU", "✓", "1", "★") ở giữa.
///
/// Dùng cho:
/// - Trạng thái hoàn thành / mở khóa / đã chọn
/// - Phản hồi đúng (success stamp)
/// - Chip bảo vật (rarity stamp)
class StampSealBadge extends StatelessWidget {
  final String label;
  final double size;
  final Color color;
  final bool filled;
  final double rotationDeg;

  const StampSealBadge(
    this.label, {
    super.key,
    this.size = 44,
    this.color = DauVietColors.cinnabarRed,
    this.filled = true,
    this.rotationDeg = -8,
  });

  /// Phiên bản "đã hoàn thành" — xanh lá.
  const StampSealBadge.success(
    this.label, {
    super.key,
    this.size = 44,
    this.color = DauVietColors.natureGreen,
    this.filled = true,
    this.rotationDeg = -8,
  });

  /// Phiên bản "đã khóa/chưa mở" — outline.
  const StampSealBadge.outline(
    this.label, {
    super.key,
    this.size = 44,
    this.color = DauVietColors.outline,
    this.filled = false,
    this.rotationDeg = -8,
  });

  @override
  Widget build(BuildContext context) {
    final innerColor = filled ? color : Colors.transparent;
    final textColor = filled ? DauVietColors.paperBackground : color;
    final fontSize = size * (label.length > 2 ? 0.20 : 0.34);

    final seal = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: innerColor,
        border: Border.all(color: color, width: 2.4),
        boxShadow: DauVietColors.pixelShadowSm,
      ),
      child: Center(
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? DauVietColors.paperBackground : color,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DauVietTypography.sectionEyebrow.copyWith(
              color: textColor,
              fontSize: fontSize,
              height: 1.0,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );

    return Transform.rotate(
      angle: rotationDeg * 3.1415926535 / 180.0,
      child: seal,
    );
  }
}
