import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import 'parchment_card.dart';

/// `TactileCard` — thẻ giấy dó có press-animation + pixel-shadow.
/// Phiên bản nâng cấp của [ParchmentCard]: thêm hiệu ứng nén khi chạm
/// và `pixelShadowSm` cho cảm giác "đóng dấu".
///
/// Dùng cho mọi card tương tác (chọn thời kỳ, thẻ dấu vết, option trả lời).
class TactileCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool enabled;
  final bool usePixelShadow;
  final List<BoxShadow>? boxShadow;

  const TactileCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.backgroundColor = DauVietColors.paperCard,
    this.borderColor = DauVietColors.outlineVariant,
    this.borderWidth = 1.4,
    this.borderRadius = 16,
    this.enabled = true,
    this.usePixelShadow = true,
    this.boxShadow,
  });

  @override
  State<TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<TactileCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final interactive = widget.enabled && widget.onTap != null;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _pressed ? 1.5 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor, width: widget.borderWidth),
        boxShadow:
            widget.boxShadow ??
            (widget.usePixelShadow
                ? DauVietColors.pixelShadowSm
                : DauVietColors.softCardShadow),
      ),
      child: widget.child,
    );

    Widget result = card;
    if (widget.margin != null) {
      result = Padding(padding: widget.margin!, child: result);
    }

    if (!interactive) return result;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: result,
      ),
    );
  }
}
