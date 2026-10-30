import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';

/// Thẻ Tổng quan Nổi ở chân màn hình (`BottomFloatingSummaryCard` — Issue #48).
///
/// Theo mockup: thẻ giấy kem `#FBF7EF` bo góc 22, đổ bóng mềm, nổi ngay phía
/// trên Bottom Navigation Bar:
/// - Trái: ảnh đại diện tròn 56x56 của thời kỳ (fallback
///   `assets/images/journey_period_avatar_default.jpg`).
/// - Giữa: tên thời kỳ đậm + niên đại `(startYear – endYear)`, thanh tiến độ
///   xanh `#2E7D47` trên nền `#E4DDD0`, dòng chỉ số `X/Y sự kiện` + `Z%`.
/// - Phải: nút tròn chevron `>` để vào `/journey/:periodCode` hoặc tiếp tục học.
class BottomFloatingSummaryCard extends StatelessWidget {
  /// Tên thời kỳ (hiển thị đậm, tối đa 1 dòng).
  final String title;

  /// Niên đại hiển thị sau tên, ví dụ `(938 – 1009)` — có thể null.
  final String? yearLabel;

  /// Dòng chỉ số tiến độ, ví dụ `1/4 sự kiện` hoặc
  /// `Tiến độ thời kỳ: 0/2 sự kiện • 1/3 bài học`.
  final String statsText;

  /// Phần trăm hoàn thành `0..100` — hiển thị dạng `Z%` bên phải thanh tiến độ.
  final int percent;

  /// Asset ảnh đại diện đã resolve (coverImageKey → bundled path); null dùng
  /// ảnh mặc định `journey_period_avatar_default.jpg`.
  final String? imageAsset;

  /// Nhãn CTA ngắn hiển thị dưới nút `>` (ví dụ `Học tiếp`) — null thì chỉ
  /// hiển thị nút chevron tròn.
  final String? ctaLabel;

  /// Chạm vào thẻ hoặc nút `>` — thường điều hướng sang `/journey/:periodCode`.
  final VoidCallback? onTap;

  const BottomFloatingSummaryCard({
    super.key,
    required this.title,
    this.yearLabel,
    required this.statsText,
    required this.percent,
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
        color: const Color(0xFFFBF7EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DFD1), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33261E19),
            offset: Offset(0, 6),
            blurRadius: 18,
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
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Ảnh đại diện tròn 56x56.
                ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      imageAsset ?? defaultAvatarAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        defaultAvatarAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: DauVietColors.paperDim,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.account_balance_rounded,
                            size: 26,
                            color: DauVietColors.inkLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tên thời kỳ + niên đại + tiến độ.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: title,
                              style: DauVietTypography.labelLarge.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF261E19),
                              ),
                            ),
                            if (yearLabel != null &&
                                yearLabel!.trim().isNotEmpty)
                              TextSpan(
                                text: ' $yearLabel',
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 11.5,
                                  color: DauVietColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: clampedPercent / 100.0,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE4DDD0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D47),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              statsText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 11.5,
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$clampedPercent%',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2E7D47),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Nút tròn chevron `>` (kèm nhãn CTA nhỏ nếu có).
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EDE0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE0D4BF),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: Color(0xFF4A3F37),
                      ),
                    ),
                    if (ctaLabel != null && ctaLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        ctaLabel!,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
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
