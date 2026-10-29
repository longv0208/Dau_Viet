import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Tag phân loại dấu vết — "Hiện vật", "Địa hình", "Nhân vật", "Cổ thư"…
/// Chip nhỏ màu jade/outline, dùng trong `EVIDENCE_SELECT`, collection,
/// lesson header.
class ClueTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  final EdgeInsetsGeometry padding;

  const ClueTag(
    this.label, {
    super.key,
    this.icon,
    this.color = DauVietColors.jade,
    this.filled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  /// Preset theo loại dấu vết kinh điển (map bởi code/caller).
  factory ClueTag.category(
    String category, {
    Key? key,
    bool filled = false,
  }) {
    switch (category.toLowerCase()) {
      case 'hiện vật':
      case 'artifact':
        return ClueTag(
          'Hiện vật',
          key: key,
          icon: Icons.inventory_2_outlined,
          color: DauVietColors.imperialGoldDark,
          filled: filled,
        );
      case 'địa hình':
      case 'terrain':
        return ClueTag(
          'Địa hình',
          key: key,
          icon: Icons.terrain_outlined,
          color: DauVietColors.riverBlue,
          filled: filled,
        );
      case 'nhân vật':
      case 'person':
        return ClueTag(
          'Nhân vật',
          key: key,
          icon: Icons.person_outline,
          color: DauVietColors.heritageGreen,
          filled: filled,
        );
      case 'cổ thư':
      case 'document':
        return ClueTag(
          'Cổ thư',
          key: key,
          icon: Icons.menu_book_outlined,
          color: DauVietColors.cinnabarRed,
          filled: filled,
        );
      default:
        return ClueTag(category, key: key, filled: filled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : color.withValues(alpha: 0.10);
    final fg = filled ? DauVietColors.paperBackground : color;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: DauVietTypography.clueTag.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
