import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Widget biểu tượng Ngọn Lửa Hào Khí (Combo Streak Badge) chuẩn Duolingo
/// Hiển thị chuỗi câu đúng liên tiếp kèm hệ số nhân điểm Sử Ký (x1.5, x2.0).
/// Tích hợp hiệu ứng thở phập phồng (subtle flame pulse) và âm thanh tương tác.
class ComboStreakBadgeWidget extends StatefulWidget {
  final int streakCount;
  final double multiplier;
  final bool isActive;
  final VoidCallback? onTap;

  const ComboStreakBadgeWidget({
    super.key,
    required this.streakCount,
    this.multiplier = 1.0,
    this.isActive = true,
    this.onTap,
  });

  @override
  State<ComboStreakBadgeWidget> createState() => _ComboStreakBadgeWidgetState();
}

class _ComboStreakBadgeWidgetState extends State<ComboStreakBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    if (widget.isActive &&
        widget.streakCount >= 2 &&
        !DauVietAudioService.isTestEnvironment) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ComboStreakBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        widget.streakCount >= 2 &&
        !DauVietAudioService.isTestEnvironment) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    DauVietAudioService.instance.playTap();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    // Mặc định hiển thị thông điệp hào khí
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.parchmentSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DauVietColors.imperialGold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFE65100),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Ngọn Lửa Hào Khí',
              style: DauVietTypography.headlineSmall.copyWith(
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chuỗi trả lời đúng liên tiếp: ${widget.streakCount} câu.',
              style: DauVietTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.multiplier > 1.0
                  ? 'Tuyệt đỉnh! Hệ số nhân thưởng hiện tại là x${widget.multiplier.toStringAsFixed(1)} cho tất cả Dấu Vết và Điểm Sử Ký.'
                  : 'Hãy trả lời đúng từ 3 câu liên tiếp để kích hoạt hệ số nhân thưởng hào khí x1.5 và x2.0!',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'ĐÃ HIỂU',
              style: DauVietTypography.labelLarge.copyWith(
                color: DauVietColors.cinnabarRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFlame = widget.isActive && widget.streakCount > 0;
    final bool isHighCombo = widget.streakCount >= 3;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: (hasFlame && isHighCombo) ? _scaleAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hasFlame
                ? const Color(0xFFFFF3E0)
                : DauVietColors.parchmentContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighCombo
                  ? const Color(0xFFFF9800)
                  : (hasFlame
                        ? DauVietColors.imperialGold
                        : DauVietColors.outlineVariant),
              width: isHighCombo ? 1.6 : 1.2,
            ),
            boxShadow: isHighCombo
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon ngọn lửa hào khí
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFB300),
                    Color(0xFFF4511E),
                    Color(0xFFD84315),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: hasFlame ? Colors.white : DauVietColors.inkLight,
                ),
              ),
              const SizedBox(width: 4),

              // Số chuỗi (streak count)
              Text(
                '${widget.streakCount}',
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isHighCombo
                      ? const Color(0xFFBF360C)
                      : DauVietColors.inkText,
                ),
              ),

              // Huy hiệu nhân điểm (nếu có combo multiplier)
              if (widget.multiplier > 1.0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DauVietColors.imperialGold, Color(0xFFE65100)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'x${widget.multiplier.toStringAsFixed(1)}',
                    style: DauVietTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
