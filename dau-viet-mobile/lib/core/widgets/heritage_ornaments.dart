import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/dau_viet_colors.dart';

/// Họa tiết mây truyền thống Việt Nam (vân mây cổ) dùng tiết chế ở chân vùng Hero
/// hoặc nền giấy cổ. Vẽ bằng CustomPainter nhẹ, không dùng hiệu ứng GPU nặng.
class TraditionalCloudOrnament extends StatelessWidget {
  final double height;
  final Color color;
  final double opacity;

  const TraditionalCloudOrnament({
    super.key,
    this.height = 36,
    this.color = DauVietColors.imperialGold,
    this.opacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _TraditionalCloudPainter(
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _TraditionalCloudPainter extends CustomPainter {
  final Color color;

  const _TraditionalCloudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: (color.a * 1.35).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.72);
    path.cubicTo(w * 0.12, h * 0.32, w * 0.24, h * 0.88, w * 0.36, h * 0.56);
    path.cubicTo(w * 0.48, h * 0.24, w * 0.62, h * 0.82, w * 0.76, h * 0.46);
    path.cubicTo(w * 0.86, h * 0.22, w * 0.94, h * 0.64, w, h * 0.48);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, fillPaint);

    // Đường viền vân mây xoắn nhẹ phía trên
    final crest = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.12, h * 0.32, w * 0.24, h * 0.88, w * 0.36, h * 0.56)
      ..cubicTo(w * 0.48, h * 0.24, w * 0.62, h * 0.82, w * 0.76, h * 0.46)
      ..cubicTo(w * 0.86, h * 0.22, w * 0.94, h * 0.64, w, h * 0.48);
    canvas.drawPath(crest, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TraditionalCloudPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Hoa văn trống đồng Đông Sơn nhẹ làm nền chìm trên giấy cổ khi không có ảnh
/// hoặc tăng chiều sâu văn hóa cho vùng Hero.
class DongSonWatermark extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const DongSonWatermark({
    super.key,
    this.size = 160,
    this.color = DauVietColors.imperialGoldDark,
    this.opacity = 0.09,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DongSonPatternPainter(
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _DongSonPatternPainter extends CustomPainter {
  final Color color;

  const _DongSonPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Các vòng đồng tâm kỷ hà Đông Sơn
    for (final factor in const [0.22, 0.42, 0.64, 0.84, 0.96]) {
      canvas.drawCircle(center, maxR * factor, paint);
    }

    // Ngôi sao 12 cánh trung tâm trống đồng
    const int rays = 12;
    final starPath = Path();
    final innerR = maxR * 0.09;
    final outerR = maxR * 0.21;
    for (int i = 0; i < rays * 2; i++) {
      final angle = (i * math.pi) / rays;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        starPath.moveTo(pt.dx, pt.dy);
      } else {
        starPath.lineTo(pt.dx, pt.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, paint);

    // Các vạch kỷ hà giữa vòng 0.64 và 0.84
    const int ticks = 24;
    for (int i = 0; i < ticks; i++) {
      final a = (i * 2 * math.pi) / ticks;
      final p1 = Offset(
        center.dx + maxR * 0.66 * math.cos(a),
        center.dy + maxR * 0.66 * math.sin(a),
      );
      final p2 = Offset(
        center.dx + maxR * 0.82 * math.cos(a + 0.06),
        center.dy + maxR * 0.82 * math.sin(a + 0.06),
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DongSonPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Họa tiết góc dưới card (triện kỷ hà & vân mây nhỏ) — dùng tiết chế,
/// không cản trở nội dung và thao tác.
class HeritageCornerMotif extends StatelessWidget {
  final double size;
  final Color color;

  const HeritageCornerMotif({
    super.key,
    this.size = 26,
    this.color = DauVietColors.imperialGoldDark,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HeritageCornerPainter(
            color: color.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _HeritageCornerPainter extends CustomPainter {
  final Color color;

  const _HeritageCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Đường góc kỷ hà hồi văn
    final path = Path()
      ..moveTo(w * 0.18, h)
      ..lineTo(w, h)
      ..lineTo(w, h * 0.18)
      ..moveTo(w * 0.45, h * 0.82)
      ..lineTo(w * 0.82, h * 0.82)
      ..lineTo(w * 0.82, h * 0.45)
      ..lineTo(w * 0.62, h * 0.45)
      ..lineTo(w * 0.62, h * 0.64);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeritageCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
