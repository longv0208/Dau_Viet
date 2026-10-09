import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget bọc bất kỳ phần tử nào để tạo hiệu ứng rung lắc phản hồi (Shake Animation)
/// khi người học chọn sai đáp án hoặc thực hiện thao tác không hợp lệ chuẩn Duolingo
class ShakeAnimationWidget extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;
  final int shakeCount;

  const ShakeAnimationWidget({
    super.key,
    required this.child,
    this.amplitude = 8.0,
    this.duration = const Duration(milliseconds: 350),
    this.shakeCount = 3,
  });

  @override
  ShakeAnimationWidgetState createState() => ShakeAnimationWidgetState();
}

class ShakeAnimationWidgetState extends State<ShakeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Kích hoạt rung lắc ngang phản hồi
  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Hàm dao động hình sin tắt dần
        final progress = _controller.value;
        final damping = 1.0 - progress; // Giảm biên độ dần về 0
        final offset = math.sin(progress * math.pi * 2 * widget.shakeCount) *
            widget.amplitude *
            damping;

        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
