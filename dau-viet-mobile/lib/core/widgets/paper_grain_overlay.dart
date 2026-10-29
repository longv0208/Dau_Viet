import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Phủ texture hạt giấy dó lên trên cùng — noise mảnh opacity ~0.05.
/// Dùng như `Stack(children: [Content(), PaperGrainOverlay()])`.
///
/// `RepaintBoundary` + `CustomPainter` với seed cố định → không repaint.
class PaperGrainOverlay extends StatelessWidget {
  final double opacity;
  final int density; // hạt trên mỗi 1000 px²
  final bool ignorePointer;

  const PaperGrainOverlay({
    super.key,
    this.opacity = 0.05,
    this.density = 60,
    this.ignorePointer = true,
  });

  @override
  Widget build(BuildContext context) {
    final painter = _PaperGrainPainter(opacity: opacity, density: density);
    final child = RepaintBoundary(
      child: CustomPaint(painter: painter, child: const SizedBox.expand()),
    );
    return ignorePointer ? IgnorePointer(child: child) : child;
  }
}

class _PaperGrainPainter extends CustomPainter {
  final double opacity;
  final int density;

  _PaperGrainPainter({required this.opacity, required this.density});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(0xD40C0FFEE);
    final paint = Paint()
      ..color = const Color(0xFF4A3828).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final area = size.width * size.height;
    final count = (area / 1000 * density).clamp(0, 4000).toInt();
    for (var i = 0; i < count; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final r = random.nextDouble() * 0.9 + 0.3;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.density != density;
}
