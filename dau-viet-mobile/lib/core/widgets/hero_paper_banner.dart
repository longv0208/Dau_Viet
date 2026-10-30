import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'paper_grain_overlay.dart';

/// Hero banner 16:9 kiểu Landing Page — nền giấy dó ấm, viền 2px đậm,
/// pixel-shadow mạnh, optional `PaperGrainOverlay` texture.
///
/// Dùng cho `CampaignDetailScreen`, `LessonEntryScreen`, hero dashboard.
class HeroPaperBanner extends StatelessWidget {
  final Widget? child;
  final ImageProvider? image;
  final String? title;
  final String? subtitle;
  final String? eyebrow;
  final double height;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final bool showGrain;
  final VoidCallback? onTap;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool usePixelShadow;
  final List<BoxShadow>? boxShadow;

  const HeroPaperBanner({
    super.key,
    this.child,
    this.image,
    this.title,
    this.subtitle,
    this.eyebrow,
    this.height = 200,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.showGrain = true,
    this.onTap,
    this.borderColor = DauVietColors.inkHeading,
    this.borderWidth = 2.4,
    this.borderRadius = 20,
    this.usePixelShadow = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DauVietColors.paperCard,
        DauVietColors.paperCardHi,
      ],
    );

    final box = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow:
            boxShadow ??
            (usePixelShadow
                ? DauVietColors.pixelShadow
                : DauVietColors.heritageShadow),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image(image: image!, fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: gradient ?? defaultGradient),
            ),
          // overlay sương mờ nhẹ để chữ nổi
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  DauVietColors.paperBackground.withValues(alpha: 0.55),
                  DauVietColors.paperBackground.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          if (showGrain) const PaperGrainOverlay(opacity: 0.05),
          Padding(
            padding: padding,
            child:
                child ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (eyebrow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DauVietColors.cinnabarRed.withValues(
                            alpha: 0.12,
                          ),
                          border: Border.all(
                            color: DauVietColors.cinnabarRed,
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          eyebrow!.toUpperCase(),
                          style: DauVietTypography.sectionEyebrow,
                        ),
                      ),
                    if (title != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        title!,
                        style: DauVietTypography.headlineLarge.copyWith(
                          color: DauVietColors.inkHeading,
                          fontSize: 24,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: box,
      ),
    );
  }
}
