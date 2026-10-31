import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../features/learning/presentation/renderers/asset_cover_image.dart';
import '../../theme/dau_viet_colors.dart';
import '../../theme/dau_viet_typography.dart';

/// Helper hiển thị ảnh bundle an toàn khi hot-reload trên Flutter Web
/// (tránh lỗi 404 do AssetManifest.bin cũ được cache từ phiên chạy đầu),
/// đồng thời ưu tiên tải ảnh từ DB (`GET /api/v1/assets/{id}/content`) khi có [assetId].
class DbOrBundledImage extends StatelessWidget {
  final String? assetId;
  final String bundledPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;

  const DbOrBundledImage({
    super.key,
    this.assetId,
    required this.bundledPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallbackWidget = _buildBundledOnly();
    final String? cleanAssetId =
        (assetId != null && assetId!.trim().isNotEmpty) ? assetId!.trim() : null;

    if (cleanAssetId != null) {
      return AssetCoverImage(
        assetId: cleanAssetId,
        bundledPath: null,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholder: fallbackWidget,
      );
    }
    return fallbackWidget;
  }

  Widget _buildBundledOnly() {
    final Widget defaultPlaceholder =
        placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFEFE4CE),
          alignment: Alignment.center,
          child: const Icon(
            Icons.history_edu_rounded,
            color: DauVietColors.heritageGreen,
            size: 24,
          ),
        );

    if (kIsWeb &&
        (bundledPath.startsWith('assets/images/home/') ||
            bundledPath.startsWith('assets/images/journey/'))) {
      return Image.network(
        'assets/$bundledPath?v=3',
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Image.asset(
          bundledPath,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          errorBuilder: (_, _, _) => defaultPlaceholder,
        ),
      );
    }

    return Image.asset(
      bundledPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => defaultPlaceholder,
    );
  }
}

/// Thanh tiến trình Gamification bo tròn màu xanh ngọc bích kèm hiệu ứng highlight.
class GamifiedProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const GamifiedProgressBar({
    super.key,
    required this.value,
    this.height = 9.0,
  });

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAE1D0),
        borderRadius: BorderRadius.circular(height),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double fillWidth =
              constraints.maxWidth * (clamped == 0 ? 0.0 : clamped.clamp(0.08, 1.0));
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: fillWidth,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF2B9364),
                    Color(0xFF42B883),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Painter vẽ nền thẻ dạng Folder-Tab cho khối "Tiếp tục hành trình":
/// Góc trái nhô cao tạo tab bo mềm S-curve, góc phải thấp hơn để chú Tê Giác đứng lên.
class FolderTabCardPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tabHeight;
  final double tabWidthRatio;

  const FolderTabCardPainter({
    this.fillColor = const Color(0xFFFBF6EC),
    this.borderColor = const Color(0xFFE6D8BF),
    this.tabHeight = 36.0,
    this.tabWidthRatio = 0.56,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double r = 22.0;
    final double tabW = (size.width * tabWidthRatio).clamp(165.0, size.width - 70.0);
    final double shoulderW = 30.0;
    final double topBodyY = tabHeight;

    final Path path = Path()
      // Bắt đầu từ góc trên-trái của tab
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      // Đỉnh tab sang phải
      ..lineTo(tabW - 12, 0)
      // Đường cong S-curve trượt từ đỉnh tab xuống mặt trên của thân thẻ
      ..cubicTo(
        tabW + 4,
        0,
        tabW + shoulderW - 14,
        topBodyY,
        tabW + shoulderW,
        topBodyY,
      )
      // Mặt trên bên phải của thân thẻ (nơi chân chú Tê Giác đứng)
      ..lineTo(size.width - r, topBodyY)
      ..quadraticBezierTo(size.width, topBodyY, size.width, topBodyY + r)
      // Cạnh phải xuống góc dưới phải
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      // Cạnh đáy sang góc dưới trái
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..close();

    // Đổ bóng mềm
    canvas.drawShadow(
      path.shift(const Offset(0, 3)),
      const Color(0x22382314),
      8.0,
      false,
    );

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRebuildSemantics(covariant FolderTabCardPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant FolderTabCardPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.tabHeight != tabHeight ||
        oldDelegate.tabWidthRatio != tabWidthRatio;
  }
}

/// Painter vẽ tấm nền trắng-kem có tai folder cong ở đáy mỗi thẻ "Bài học nổi bật".
class FeaturedCardBottomPanelPainter extends CustomPainter {
  final Color fillColor;

  const FeaturedCardBottomPanelPainter({
    this.fillColor = const Color(0xFFFBF6EC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double topShoulderDrop = 14.0;
    final double tabW = size.width * 0.72;
    const double r = 14.0;

    final Path path = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(tabW - 10, 0)
      ..cubicTo(
        tabW + 4,
        0,
        tabW + 10,
        topShoulderDrop,
        tabW + 22,
        topShoulderDrop,
      )
      ..lineTo(size.width - 10, topShoulderDrop)
      ..quadraticBezierTo(
        size.width,
        topShoulderDrop,
        size.width,
        topShoulderDrop + 10,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final Paint paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FeaturedCardBottomPanelPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor;
  }
}

/// Thẻ sự kiện / bài học trong carousel ngang "Bài học nổi bật".
/// Hỗ trợ lấy ảnh bìa từ DB ([assetId]) hoặc fallback sang [bundledImagePath].
class FeaturedLessonCarouselCard extends StatelessWidget {
  final String title;
  final String activitiesLabel;
  final String durationLabel;
  final String? badgeText;
  final String? assetId;
  final String bundledImagePath;
  final VoidCallback onTap;

  const FeaturedLessonCarouselCard({
    super.key,
    required this.title,
    required this.activitiesLabel,
    required this.durationLabel,
    this.badgeText,
    this.assetId,
    required this.bundledImagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 204,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE4D5BC),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14382314),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Lớp 1: Ảnh minh họa sự kiện (ưu tiên tải từ DB qua assetId)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 112,
              child: DbOrBundledImage(
                assetId: assetId,
                bundledPath: bundledImagePath,
                fit: BoxFit.cover,
              ),
            ),

            // Lớp 2: Badge "Mới" (hoặc tag từ DB) ở góc trên trái
            if (badgeText != null && badgeText!.trim().isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32525),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeText!,
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),

            // Lớp 3: Panel trắng-kem dạng folder-tab ở nửa dưới thẻ
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 94,
              child: CustomPaint(
                painter: const FeaturedCardBottomPanelPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$title\u200B',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.headlineSmall.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF23140D),
                          height: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color: Color(0xFFD68B28),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              activitiesLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B5B4D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time_filled_rounded,
                            size: 13,
                            color: Color(0xFFD68B28),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              durationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B5B4D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
