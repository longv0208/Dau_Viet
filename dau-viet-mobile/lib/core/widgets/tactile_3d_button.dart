import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

enum Tactile3DVariant {
  primaryCinnabar,   // Đỏ chu sa
  secondaryParchment,// Giấy dó viền gỗ
  imperialGold,      // Vàng ngự xưởng
  natureGreen,       // Xanh di sản
  dangerRed,         // Đỏ cảnh báo
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
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final depth = isEnabled ? widget.depth : 0.0;

    Color topColor;
    Color bottomColor;
    Color textColor;
    Border? border;

    switch (widget.variant) {
      case Tactile3DVariant.primaryCinnabar:
        topColor = DauVietColors.cinnabarRed;
        bottomColor = DauVietColors.cinnabarRedDark;
        textColor = Colors.white;
        border = Border.all(color: DauVietColors.cinnabarRedDark, width: 1.2);
        break;
      case Tactile3DVariant.secondaryParchment:
        topColor = widget.isSelected ? const Color(0xFFFBF4E4) : DauVietColors.parchmentContainer;
        bottomColor = widget.isSelected ? DauVietColors.imperialGold : const Color(0xFFC7B596);
        textColor = DauVietColors.inkText;
        border = Border.all(
          color: widget.isSelected ? DauVietColors.imperialGold : DauVietColors.outline,
          width: widget.isSelected ? 2.0 : 1.2,
        );
        break;
      case Tactile3DVariant.imperialGold:
        topColor = DauVietColors.imperialGold;
        bottomColor = const Color(0xFFB88726);
        textColor = DauVietColors.inkText;
        border = Border.all(color: const Color(0xFFB88726), width: 1.2);
        break;
      case Tactile3DVariant.natureGreen:
        topColor = DauVietColors.natureGreen;
        bottomColor = const Color(0xFF1E5633);
        textColor = Colors.white;
        border = Border.all(color: const Color(0xFF1E5633), width: 1.2);
        break;
      case Tactile3DVariant.dangerRed:
        topColor = const Color(0xFFD32F2F);
        bottomColor = const Color(0xFF8A1C1C);
        textColor = Colors.white;
        border = Border.all(color: const Color(0xFF8A1C1C), width: 1.2);
        break;
    }

    if (!isEnabled) {
      topColor = const Color(0xFFD6CFC7);
      bottomColor = const Color(0xFFB5ADA4);
      textColor = const Color(0xFF7E766D);
      border = Border.all(color: const Color(0xFFB5ADA4), width: 1.0);
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
        onTapCancel: isEnabled && _isPressed ? () => setState(() => _isPressed = false) : null,
        child: Container(
          decoration: BoxDecoration(
            color: bottomColor,
            borderRadius: radius,
          ),
          padding: EdgeInsets.only(bottom: bottomOffset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(top: topOffset),
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: radius,
              border: border,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : widget.child ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 20, color: textColor),
                          const SizedBox(width: 8),
                        ],
                        if (widget.label != null)
                          Flexible(
                            child: Text(
                              widget.label!,
                              style: DauVietTypography.labelLarge.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
