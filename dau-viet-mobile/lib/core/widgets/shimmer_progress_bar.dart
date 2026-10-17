import 'package:flutter/material.dart';
import '../theme/dau_viet_colors.dart';

/// Thanh tiến độ bài học lướt sáng (Shimmer Progress Bar) chuẩn phong cách Duolingo
/// Quét một vệt sáng hoàng kim khi người học đạt tiến độ mới
class ShimmerProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color fillColor;
  final Color trackColor;
  final BorderRadius? borderRadius;

  const ShimmerProgressBar({
    super.key,
    required this.progress,
    this.height = 14.0,
    this.fillColor = DauVietColors.cinnabarRed,
    this.trackColor = const Color(0xFFE8DEC8),
    this.borderRadius,
  });

  @override
  State<ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Quét vệt sáng 1 lần khi thanh tiến độ xuất hiện
    _shimmerController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant ShimmerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      // Quét vệt sáng mỗi khi tiến độ thay đổi
      _shimmerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(100);
    final clampedProgress = widget.progress.clamp(0.0, 1.0);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.trackColor,
        borderRadius: radius,
        border: Border.all(
          color: DauVietColors.outlineVariant.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: clampedProgress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) {
              final fillWidth = totalWidth * animatedProgress;

              return Stack(
                children: [
                  // 1. Dải màu tiến độ đã hoàn thành
                  Container(
                    width: fillWidth,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.fillColor,
                      borderRadius: radius,
                      boxShadow: fillWidth > 8
                          ? [
                              BoxShadow(
                                color: widget.fillColor.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),

                  // 2. Tia sáng hoàng kim lướt qua (Shimmer light sweep)
                  if (fillWidth > 16)
                    ClipRRect(
                      borderRadius: radius,
                      child: SizedBox(
                        width: fillWidth,
                        height: widget.height,
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            final shimmerX =
                                -1.0 + (_shimmerController.value * 3.0);

                            return FractionallySizedBox(
                              alignment: Alignment(shimmerX, 0),
                              widthFactor: 0.4,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.45),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
