import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'kabi_mascot_widget.dart';
import 'tactile_card.dart';

/// Trạng thái trống chuẩn — mascot + tiêu đề + mô tả + CTA tùy chọn.
///
/// Thay thế mọi `Center(Text('Chưa có dữ liệu'))` thô.
class EmptyStateCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Widget? illustration;
  final KabiMood mood;

  const EmptyStateCard({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.illustration,
    this.mood = KabiMood.thinking,
  });

  @override
  Widget build(BuildContext context) {
    return TactileCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          illustration ??
              (icon != null
                  ? Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: DauVietColors.jade.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DauVietColors.jade,
                          width: 1.6,
                        ),
                      ),
                      child: Icon(icon, color: DauVietColors.jade, size: 30),
                    )
                  : KabiMascotWidget(mood: mood, width: 84, height: 84)),
          const SizedBox(height: 16),
          Text(
            title,
            style: DauVietTypography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: DauVietColors.cinnabarRed,
                foregroundColor: DauVietColors.paperBackground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel!, style: DauVietTypography.labelLarge),
            ),
          ],
        ],
      ),
    );
  }
}
