import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../data/map_location_dto.dart';

/// Nền minh họa + đường hành trình cho Bản Đồ Dấu Ấn.
///
/// Lớp nền: giấy dó, đồi xa, sông uốn, mây truyền thống, bóng đất.
/// Lớp đường: đoạn nối các node theo thứ tự chặng — vàng đặc cho đoạn
/// đã mở (UNLOCKED), nét đứt nâu nhạt cho đoạn chưa tới. Đường uốn
/// bezier giữa hai lane trái/phải — KHÔNG gợi tuyến đường địa lý thật.
class JourneyPathPainter extends CustomPainter {
  /// Tâm node đã resolve (cùng thứ tự `states`). Null → tự tính từ count.
  final List<Offset> centers;
  final List<MapUnlockState> states;
  final int? selectedIndex;

  JourneyPathPainter({
    required this.centers,
    required this.states,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintParchment(canvas, size);
    _paintLandscape(canvas, size);
    _paintPath(canvas, size);
    _paintOrnaments(canvas, size);
  }

  // ── Nền giấy dó + vệt mờ ────────────────────────────────────────────
  void _paintParchment(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = DauVietColors.parchmentHigh,
    );
    final rng = math.Random(11);
    final stain = Paint()
      ..color = DauVietColors.outlineVariant.withValues(alpha: 0.16);
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        34 + rng.nextDouble() * 74,
        stain,
      );
    }
  }

  // ── Đồi xa, sông, mây ───────────────────────────────────────────────
  void _paintLandscape(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dải đồi xa phía trên — 2 lớp xanh nhạt chồng nhau.
    _hill(
      canvas,
      Offset(0, h * 0.14),
      w * 0.55,
      h * 0.05,
      DauVietColors.natureGreen.withValues(alpha: 0.16),
    );
    _hill(
      canvas,
      Offset(w * 0.5, h * 0.12),
      w * 0.65,
      h * 0.06,
      DauVietColors.natureGreen.withValues(alpha: 0.20),
    );
    _hill(
      canvas,
      Offset(w * 0.1, h * 0.42),
      w * 0.4,
      h * 0.035,
      DauVietColors.natureGreen.withValues(alpha: 0.10),
    );
    _hill(
      canvas,
      Offset(w * 0.62, h * 0.62),
      w * 0.5,
      h * 0.045,
      DauVietColors.natureGreen.withValues(alpha: 0.12),
    );

    // Dải sông uốn dọc mép trái — trang trí thủy văn, không địa danh thật.
    final river = Path()
      ..moveTo(w * 0.06, h * 0.06)
      ..cubicTo(w * 0.02, h * 0.20, w * 0.14, h * 0.34, w * 0.07, h * 0.52)
      ..cubicTo(w * 0.01, h * 0.68, w * 0.12, h * 0.84, w * 0.05, h * 0.98)
      ..lineTo(w * 0.0, h)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      river,
      Paint()..color = DauVietColors.riverBlue.withValues(alpha: 0.10),
    );
    // Nét sóng trên sông.
    final wave = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final (dx, dy) in const [
      (0.10, 0.24),
      (0.07, 0.46),
      (0.11, 0.68),
      (0.06, 0.88),
    ]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * dx, h * dy), width: 26, height: 10),
        math.pi,
        math.pi,
        false,
        wave,
      );
    }

    // Mây truyền thống — vòng cung đồng tâm, 3 cụm dọc canvas.
    final cloud = Paint()
      ..color = DauVietColors.outline.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final (dx, dy, s) in const [
      (0.80, 0.09, 1.0),
      (0.18, 0.38, 0.8),
      (0.84, 0.55, 0.9),
      (0.15, 0.80, 1.0),
      (0.78, 0.92, 0.75),
    ]) {
      final c = Offset(w * dx, h * dy);
      for (int k = 1; k <= 3; k++) {
        canvas.drawArc(
          Rect.fromCenter(center: c, width: 14.0 * k * s, height: 10.0 * k * s),
          math.pi,
          math.pi,
          false,
          cloud,
        );
      }
    }

    // Silhouette mái đình nhỏ — nét kiến trúc gợi ý, không phục dựng.
    final roof = Paint()
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final (dx, dy, s) in const [(0.78, 0.30, 1.0), (0.20, 0.60, 0.85)]) {
      final c = Offset(w * dx, h * dy);
      final p = Path()
        ..moveTo(c.dx - 16 * s, c.dy)
        ..quadraticBezierTo(c.dx - 8 * s, c.dy - 8 * s, c.dx, c.dy - 9 * s)
        ..quadraticBezierTo(c.dx + 8 * s, c.dy - 8 * s, c.dx + 16 * s, c.dy)
        ..moveTo(c.dx - 10 * s, c.dy)
        ..lineTo(c.dx - 10 * s, c.dy + 7 * s)
        ..moveTo(c.dx + 10 * s, c.dy)
        ..lineTo(c.dx + 10 * s, c.dy + 7 * s)
        ..moveTo(c.dx - 12 * s, c.dy + 7 * s)
        ..lineTo(c.dx + 12 * s, c.dy + 7 * s);
      canvas.drawPath(p, roof);
    }
  }

  void _hill(
    Canvas canvas,
    Offset base,
    double width,
    double height,
    Color color,
  ) {
    final p = Path()
      ..moveTo(base.dx - width / 2, base.dy)
      ..quadraticBezierTo(
        base.dx - width / 4,
        base.dy - height * 2.4,
        base.dx,
        base.dy - height,
      )
      ..quadraticBezierTo(
        base.dx + width / 4,
        base.dy + height * 0.8,
        base.dx + width / 2,
        base.dy,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  // ── Đường hành trình ────────────────────────────────────────────────
  void _paintPath(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final gold = Paint()
      ..color = DauVietColors.imperialGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final goldGlow = Paint()
      ..color = DauVietColors.imperialGoldLight.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round;
    final dashed = Paint()
      ..color = DauVietColors.inkLight.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < centers.length - 1; i++) {
      final seg = _segment(centers[i], centers[i + 1]);
      final done =
          states[i] == MapUnlockState.unlocked &&
          states[i + 1] == MapUnlockState.unlocked;
      if (done) {
        canvas.drawPath(seg, goldGlow);
        canvas.drawPath(seg, gold);
      } else {
        _drawDashed(canvas, seg, dashed);
      }
    }
  }

  /// Đoạn uốn giữa 2 tâm kề nhau — cubic với điểm điều khiển đẩy về
  /// phía ngoài lane, tạo đường cong nhẹ không quá gấp khúc.
  Path _segment(Offset a, Offset b) {
    final mid = (a + b) / 2;
    final bend = Offset(mid.dx + (a.dx < b.dx ? 34 : -34), mid.dy);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx + (bend.dx - a.dx) * 0.7,
        a.dy + (b.dy - a.dy) * 0.38,
        b.dx + (bend.dx - b.dx) * 0.7,
        b.dy - (b.dy - a.dy) * 0.38,
        b.dx,
        b.dy,
      );
  }

  /// Nét đứt 8-4 theo chiều dài đường cong (xấp xỉ đa giác 16 đoạn).
  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 9.0, gap = 6.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final from = metric.getTangentForOffset(dist)!.position;
        final to = metric
            .getTangentForOffset(math.min(dist + dash, metric.length))!
            .position;
        canvas.drawLine(from, to, paint);
        dist += dash + gap;
      }
    }
  }

  // ── Chi tiết trang trí Đông Sơn ─────────────────────────────────────
  void _paintOrnaments(Canvas canvas, Size size) {
    // Khung viền đồng mỏng 2 lớp — bo cục bộ không quá nặng.
    canvas.drawRect(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      Paint()
        ..color = DauVietColors.outline.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRect(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      Paint()
        ..color = DauVietColors.outline.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    // Hoa văn góc: 3 vòng cung lồng nhau.
    final corner = Paint()
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final c in const [Offset(20, 20)]) {
      for (int k = 1; k <= 3; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 8.0 * k),
          math.pi,
          math.pi / 2,
          false,
          corner,
        );
      }
    }
  }

  @override
  bool shouldRepaint(JourneyPathPainter old) =>
      old.centers != centers ||
      old.states != states ||
      old.selectedIndex != selectedIndex;
}
