import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/gamification/gamification_widgets.dart';

/// Thẻ Tổng quan Nổi ở chân màn hình (`BottomFloatingSummaryCard`),
/// đồng bộ hoàn toàn với theme Heritage Cream & Crimson Gamification mới:
/// - Trái: ảnh đại diện bo góc mềm (ưu tiên tải từ DB `assets` qua [assetId],
///   fallback về [imageAsset]).
/// - Giữa: tên thời kỳ đậm + niên đại, thanh tiến độ ngọc bích [GamifiedProgressBar],
///   dòng chỉ số `X/Y sự kiện` + `Z%`.
/// - Phải: nút tròn đỏ chu sa `#C92525` với mũi tên trắng `>`.
class BottomFloatingSummaryCard extends StatelessWidget {
  final String title;
  final String? yearLabel;
  final String statsText;
  final int percent;
  final String? assetId;
  final String? imageAsset;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const BottomFloatingSummaryCard({
    super.key,
    required this.title,
    this.yearLabel,
    required this.statsText,
    required this.percent,
    this.assetId,
    this.imageAsset,
    this.ctaLabel,
    this.onTap,
  });

  static const String defaultAvatarAsset =
      'assets/images/journey_period_avatar_default.jpg';

  @override
  Widget build(BuildContext context) {
    final int clampedPercent = percent.clamp(0, 100);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFCF8EE),
            Color(0xFFF6ECDA),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0CAA0), width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E2B1B12),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                // Ảnh đại diện bo góc mềm (ưu tiên lấy từ DB assets).
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD9BE8A),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.5),
                    child: DbOrBundledImage(
                      assetId: assetId,
                      bundledPath: imageAsset ?? defaultAvatarAsset,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tên thời kỳ + niên đại + thanh tiến độ ngọc bích.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$title\u200B',
                              style: DauVietTypography.labelLarge.copyWith(
                                fontSize: 13.2,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2B1B12),
                                height: 1.18,
                              ),
                            ),
                            if (yearLabel != null &&
                                yearLabel!.trim().isNotEmpty)
                              TextSpan(
                                text: ' $yearLabel',
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 11.0,
                                  color: const Color(0xFF5A4A3B),
                                ),
                              ),
                          ],
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 5),
                      GamifiedProgressBar(
                        value: clampedPercent / 100.0,
                        height: 7.0,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                statsText,
                                maxLines: 1,
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF5A4A3B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$clampedPercent%',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2B9364),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Nút tròn đỏ chu sa `>` đồng bộ theme.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFDA322A),
                            Color(0xFFB51B16),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFF4DC),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x38B51B16),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    if (ctaLabel != null && ctaLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        ctaLabel!,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: DauVietColors.cinnabarRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
