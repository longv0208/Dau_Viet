import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'kabi_mascot_widget.dart';
import 'tactile_card.dart';

/// Trạng thái trống chuẩn — linh vật Tê Giác Dấu Việt + tiêu đề + mô tả + CTA tùy chọn.
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
      usePixelShadow: false,
      backgroundColor: const Color(0xFFFAF3E4),
      borderColor: const Color(0xFFE3D2B4),
      borderWidth: 1.1,
      borderRadius: 18,
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
                        color: DauVietColors.heritageGreenSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DauVietColors.heritageGreenLight.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: DauVietColors.heritageGreen,
                        size: 30,
                      ),
                    )
                  : KabiMascotWidget(mood: mood, width: 84, height: 84)),
          const SizedBox(height: 16),
          Text(
            title,
            style: DauVietTypography.headlineSmall.copyWith(
              color: DauVietColors.inkHeading,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A4B38),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFDEC69A).withValues(alpha: 0.55),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24163A2B),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel!,
                    style: DauVietTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
