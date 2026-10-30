import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

enum Tactile3DVariant {
  primaryCinnabar, // Đỏ chu sa
  secondaryParchment, // Giấy dó viền gỗ
  imperialGold, // Vàng ngự xưởng
  natureGreen, // Xanh di sản
  dangerRed, // Đỏ cảnh báo
  heritageGreen, // Xanh rêu di sản UI Pro Max
}

/// Nút bấm xúc giác 3D chuẩn phong cách Duolingo kết hợp mỹ thuật Dấu Việt
/// Sử dụng cơ chế nén lò xo (Spring physics) qua margin/padding thuần túy,
/// đảm bảo tương thích 100% với hệ thống layout của Flutter và kiểm thử tự động
class Tactile3DButton extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Tactile3DVariant variant;
  final double height;
  final double? width;
  final double depth;
  final BorderRadius? borderRadius;
  final bool isSelected;
  final bool isLoading;

  const Tactile3DButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.icon,
    this.variant = Tactile3DVariant.primaryCinnabar,
    this.height = 50.0,
    this.width,
    this.depth = 4.0,
    this.borderRadius,
    this.isSelected = false,
    this.isLoading = false,
    this.enableSound = true,
  });

  final bool enableSound;

  @override
  State<Tactile3DButton> createState() => _Tactile3DButtonState();
}

class _Tactile3DButtonState extends State<Tactile3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final radius = widget.borderRadius ?? BorderRadius.circular(24);
    final depth = isEnabled ? widget.depth : 0.0;

    Color topColor;
    Color bottomGradientColor;
    Color bottomColor;
    Color textColor;
    Border? border;
    bool showWaveOrnament = false;

    switch (widget.variant) {
      case Tactile3DVariant.primaryCinnabar:
        topColor = const Color(0xFFB92B22);
        bottomGradientColor = const Color(0xFF8E1A13);
        bottomColor = const Color(0xFF66100B);
        textColor = const Color(0xFFFFFBF2);
        border = Border.all(color: const Color(0xFFDDA958), width: 1.3);
        showWaveOrnament = true;
        break;
      case Tactile3DVariant.secondaryParchment:
        topColor = widget.isSelected
            ? const Color(0xFFFBF4E4)
            : const Color(0xFFFAF3E4);
        bottomGradientColor = widget.isSelected
            ? const Color(0xFFF3E2C3)
            : const Color(0xFFF2E4CA);
        bottomColor = widget.isSelected
            ? DauVietColors.imperialGold
            : const Color(0xFFC7B596);
        textColor = DauVietColors.inkText;
        border = Border.all(
          color: widget.isSelected
              ? DauVietColors.imperialGold
              : const Color(0xFFD5BF98),
          width: widget.isSelected ? 2.0 : 1.3,
        );
        break;
      case Tactile3DVariant.imperialGold:
        topColor = const Color(0xFFE6B64E);
        bottomGradientColor = const Color(0xFFCA9632);
        bottomColor = const Color(0xFF9E701C);
        textColor = const Color(0xFF2B1F17);
        border = Border.all(color: const Color(0xFFF7DC97), width: 1.3);
        showWaveOrnament = true;
        break;
      case Tactile3DVariant.natureGreen:
        topColor = const Color(0xFF3B7A4A);
        bottomGradientColor = const Color(0xFF285934);
        bottomColor = const Color(0xFF1B3F24);
        textColor = Colors.white;
        border = Border.all(color: const Color(0xFF8CC096), width: 1.2);
        showWaveOrnament = true;
        break;
      case Tactile3DVariant.dangerRed:
        topColor = const Color(0xFFD32F2F);
        bottomGradientColor = const Color(0xFFA82020);
        bottomColor = const Color(0xFF7A1515);
        textColor = Colors.white;
        border = Border.all(color: const Color(0xFFE59866), width: 1.2);
        showWaveOrnament = true;
        break;
      case Tactile3DVariant.heritageGreen:
        topColor = const Color(0xFF235843);
        bottomGradientColor = const Color(0xFF173E2E);
        bottomColor = const Color(0xFF0E291E);
        textColor = Colors.white;
        border = Border.all(color: const Color(0xFF88B39E), width: 1.2);
        showWaveOrnament = true;
        break;
    }

    if (!isEnabled) {
      topColor = const Color(0xFFD6CFC7);
      bottomGradientColor = const Color(0xFFC8C0B7);
      bottomColor = const Color(0xFFB5ADA4);
      textColor = const Color(0xFF7E766D);
      border = Border.all(color: const Color(0xFFB5ADA4), width: 1.0);
      showWaveOrnament = false;
    }

    final topOffset = _isPressed ? depth : 0.0;
    final bottomOffset = _isPressed ? 0.0 : depth;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        onTapDown: isEnabled
            ? (_) {
                setState(() => _isPressed = true);
                if (widget.enableSound) {
                  DauVietAudioService.instance.playTap();
                }
              }
            : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: isEnabled && _isPressed
            ? () => setState(() => _isPressed = false)
            : null,
        child: Container(
          decoration: BoxDecoration(color: bottomColor, borderRadius: radius),
          padding: EdgeInsets.only(bottom: bottomOffset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(top: topOffset),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, bottomGradientColor],
              ),
              borderRadius: radius,
              border: border,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showWaveOrnament)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _ButtonWaveOrnamentPainter()),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              textColor,
                            ),
                          ),
                        )
                      : widget.child ??
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(widget.icon, size: 19, color: textColor),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.label != null)
                                  Flexible(
                                    child: Text(
                                      widget.label!,
                                      style: DauVietTypography.labelLarge
                                          .copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                            letterSpacing: 0.4,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonWaveOrnamentPainter extends CustomPainter {
  const _ButtonWaveOrnamentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE5A3).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Vân sóng đồng tâm hai góc dưới nút (khớp ảnh mẫu #2, #3, #4, #5, #6)
    final leftCenter = Offset(18, size.height + 4);
    final rightCenter = Offset(size.width - 18, size.height + 4);
    for (final r in const [10.0, 16.0, 22.0, 28.0]) {
      canvas.drawCircle(leftCenter, r, paint);
      canvas.drawCircle(rightCenter, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
