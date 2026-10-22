import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../historical_animation_definition.dart';

/// ANIM-01 — Painter sông + bãi cọc schematic dùng chung cho scene dạng
/// "thủy triều / vật cản ngầm" (Bạch Đằng 938 là scene đầu tiên). Vẽ
/// vector bằng CustomPainter, tọa độ chuẩn hóa 0..1 — không phụ thuộc
/// asset ngoài, không pixel art, không ảnh khảo cổ.
///
/// waterLevel 0..1: 0 = nước rút (cọc lộ), 1 = nước dâng (cọc chìm).
/// boatProgress 0..1: thuyền đi từ ngoài khơi vào vùng bãi cọc.
/// boatsObstructed: thuyền bị cản — nghiêng nhẹ + dừng, không nổ/vỡ.
class RiverScenePainter extends HistoricalScenePainter {
  /// 9 cọc schematic rải đều khu vực giữa sông — KHÔNG phải bố trí
  /// khảo cổ thật (disclaimer hiển thị ở caption).
  static const List<Offset> _stakeField = [
    Offset(0.42, 0.62),
    Offset(0.50, 0.58),
    Offset(0.58, 0.63),
    Offset(0.46, 0.70),
    Offset(0.54, 0.72),
    Offset(0.62, 0.69),
    Offset(0.48, 0.79),
    Offset(0.57, 0.80),
    Offset(0.66, 0.76),
  ];

  /// Cao độ đỉnh cọc (chuẩn hóa theo chiều cao canvas): cọc ngắn nhô
  /// lên ~0.10 phía trên đáy sông; ngọn ở y = base - height.
  static const double _stakeHeight = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // --- Đáy sông (riverbed) ---
    paint.color = const Color(0xFF7A5A3E);
    final bedTop = h * 0.80;
    canvas.drawRect(Rect.fromLTRB(0, bedTop, w, h), paint);
    // Vân đất nhẹ.
    paint.color = const Color(0x22613B28);
    canvas.drawRect(Rect.fromLTRB(0, bedTop, w, h * 0.02), paint);

    // --- Mực nước schematic: waterLevel 0→đáy (0.80h), 1→gần nóc (0.20h) ---
    final waterSurfaceY = h * (0.80 - 0.60 * waterLevel.clamp(0.0, 1.0));

    // --- Bãi cọc: vẽ TRƯỚC nước để nước che phần chìm ---
    final stakePaint = Paint()
      ..color = DauVietColors.woodBrown
      ..style = PaintingStyle.fill;
    final stakeHighlightPaint = Paint()
      ..color = DauVietColors.cinnabarRed
      ..style = PaintingStyle.fill;
    final stakeW = w * 0.016;
    for (final s in _stakeField) {
      final base = Offset(s.dx * w, s.dy * h);
      final top = Offset(base.dx, base.dy - h * _stakeHeight);
      final exposed = top.dy > waterSurfaceY;
      final p = (highlightStakes && exposed) ? stakeHighlightPaint : stakePaint;
      // Thân cọc.
      canvas.drawRect(
        Rect.fromLTWH(base.dx - stakeW / 2, top.dy, stakeW, h * _stakeHeight),
        p,
      );
      // Ngọn nhọn.
      final tip = Path()
        ..moveTo(base.dx - stakeW / 2, top.dy)
        ..lineTo(base.dx, top.dy - stakeW * 1.6)
        ..lineTo(base.dx + stakeW / 2, top.dy)
        ..close();
      canvas.drawPath(tip, p);
      // Nếu đỉnh cọc lộ trên mặt nước → vẽ vệt khô (không chỉ dùng màu).
      if (exposed) {
        final markPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(base.dx - stakeW * 0.6, top.dy - stakeW * 0.9),
          Offset(base.dx + stakeW * 0.6, top.dy - stakeW * 0.9),
          markPaint,
        );
      }
    }

    // --- Lớp nước ---
    final waterPaint = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, waterSurfaceY, w, bedTop), waterPaint);
    // Mặt nước — sóng nhẹ.
    final wavePaint = Paint()
      ..color = DauVietColors.riverBlue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final wave = Path()..moveTo(0, waterSurfaceY);
    final waveAmp = h * 0.008;
    final waveLen = w / 10;
    for (var i = 0; i <= 10; i++) {
      wave.quadraticBezierTo(
        waveLen * (i + 0.5),
        waterSurfaceY + (i.isEven ? -waveAmp : waveAmp),
        waveLen * (i + 1),
        waterSurfaceY,
      );
    }
    canvas.drawPath(wave, wavePaint);

    // --- Thuyền địch (stylized, KHÔNG phải mô hình lịch sử chính xác) ---
    _paintBoats(canvas, size, waterSurfaceY);

    // --- Nhãn vùng (a11y — không chỉ dựa vào màu) ---
    _paintLabel(
      canvas,
      'Bãi cọc',
      Offset(w * 0.54, h * 0.86),
      DauVietColors.inkText,
    );
    _paintLabel(
      canvas,
      waterLevel > 0.55 ? 'Nước dâng' : 'Nước rút',
      Offset(w * 0.10, waterSurfaceY - h * 0.03),
      DauVietColors.riverBlue,
    );
  }

  void _paintBoats(Canvas canvas, Size size, double surfaceY) {
    // Ba thuyền địch stylized tiến từ phải sang trái vào bãi cọc.
    // boatProgress 0 = ngoài khơi (x≈1.05), 1 = đã vào giữa bãi.
    final w = size.width;
    final h = size.height;
    final boatPaint = Paint()
      ..color = const Color(0xFF4A3226)
      ..style = PaintingStyle.fill;
    final sailPaint = Paint()
      ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    const lanes = [0.0, 0.18, 0.36];
    for (var i = 0; i < lanes.length; i++) {
      final prog = (boatProgress - lanes[i]).clamp(0.0, 1.0);
      if (prog <= 0) continue;
      // Đường đi: vào từ phải, chạm cọc quanh x≈0.62 → nếu nước rút +
      // obstructed → dừng/nghiêng; nước dâng → đi tiếp qua bãi.
      final x = boatsObstructed
          ? w *
                (1.05 - prog * 0.43) // dừng sớm ~x0.62
          : w * (1.05 - prog * 0.90); // đi sâu tới ~x0.15
      final y = surfaceY - h * 0.012;
      final tilt = boatsObstructed ? 0.10 : 0.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tilt);
      // Thân thuyền stylized.
      final hull = Path()
        ..moveTo(-w * 0.045, 0)
        ..lineTo(w * 0.045, 0)
        ..lineTo(w * 0.030, h * 0.022)
        ..lineTo(-w * 0.030, h * 0.022)
        ..close();
      canvas.drawPath(hull, boatPaint);
      // Buồm tam giác đơn giản.
      final sail = Path()
        ..moveTo(0, -h * 0.010)
        ..lineTo(0, -h * 0.055)
        ..lineTo(w * 0.028, -h * 0.010)
        ..close();
      canvas.drawPath(sail, sailPaint);
      canvas.restore();
    }

    // Mũi tên hướng tiến (educational, chỉ khi thuyền đang đi).
    if (boatProgress > 0 && boatProgress < 1 && !boatsObstructed) {
      final arrow = Paint()
        ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final ax = w * 0.80;
      final ay = surfaceY - h * 0.10;
      canvas.drawLine(Offset(ax + w * 0.08, ay), Offset(ax, ay), arrow);
      canvas.drawLine(
        Offset(ax + w * 0.02, ay - h * 0.015),
        Offset(ax, ay),
        arrow,
      );
      canvas.drawLine(
        Offset(ax + w * 0.02, ay + h * 0.015),
        Offset(ax, ay),
        arrow,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(RiverScenePainter old) =>
      old.waterLevel != waterLevel ||
      old.boatProgress != boatProgress ||
      old.boatsObstructed != boatsObstructed ||
      old.highlightStakes != highlightStakes;
}
