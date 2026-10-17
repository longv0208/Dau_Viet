import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

/// Thẻ lựa chọn 3D nén lò xo (Tactile 3D Option Card)
/// Dành cho các câu hỏi trắc nghiệm, ghép nối thẻ, và sắp xếp niên biểu chuẩn Duolingo
/// Sử dụng padding/margin thuần túy để bảo đảm kích thước tự nhiên và ổn định trong mọi Layout
class Tactile3DCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color bottomColor;
  final Color borderColor;
  final double borderWidth;
  final double depth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isEnabled;
  final bool enableSound;

  const Tactile3DCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = Colors.white,
    this.bottomColor = const Color(0xFFD6CFC7),
    this.borderColor = const Color(0xFFE2D6C5),
    this.borderWidth = 1.2,
    this.depth = 4.0,
    this.borderRadius,
    this.padding = const EdgeInsets.all(14),
    this.isSelected = false,
    this.isCorrect = false,
    this.isWrong = false,
    this.isEnabled = true,
    this.enableSound = true,
  });

  @override
  State<Tactile3DCard> createState() => _Tactile3DCardState();
}

class _Tactile3DCardState extends State<Tactile3DCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final depth = widget.isEnabled ? widget.depth : 0.0;

    Color bg = widget.backgroundColor;
    Color bottomBg = widget.bottomColor;
    Color borderC = widget.borderColor;
    double borderW = widget.borderWidth;

    if (widget.isCorrect) {
      bg = const Color(0xFFEAF5EE);
      bottomBg = const Color(0xFF1E5633);
      borderC = DauVietColors.natureGreen;
      borderW = 2.0;
    } else if (widget.isWrong) {
      bg = const Color(0xFFFDEEEC);
      bottomBg = const Color(0xFF8A1C1C);
      borderC = DauVietColors.cinnabarRed;
      borderW = 2.0;
    } else if (widget.isSelected) {
      bg = const Color(0xFFFBF4E4);
      bottomBg = const Color(0xFFB88726);
      borderC = DauVietColors.imperialGold;
      borderW = 2.0;
    }

    final topOffset = _isPressed ? depth : 0.0;
    final bottomOffset = _isPressed ? 0.0 : depth;

    return GestureDetector(
      onTapDown: widget.isEnabled && widget.onTap != null
          ? (_) {
              setState(() => _isPressed = true);
              if (widget.enableSound) {
                DauVietAudioService.instance.playTap();
              }
            }
          : null,
      onTapUp: widget.isEnabled && widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () {
        if (_isPressed) setState(() => _isPressed = false);
      },
      child: Container(
        decoration: BoxDecoration(color: bottomBg, borderRadius: radius),
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(top: topOffset),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: borderC, width: borderW),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: DauVietColors.imperialGold.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
