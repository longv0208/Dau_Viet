import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';

/// POLISH-BD-01 — Bước tổng kết của `bach_dang_938_tide_v1`: sơ đồ chuỗi
/// 5 giai đoạn (Chuẩn bị → Nước dâng → Dụ địch → Mắc cọc → Phản công)
/// vẽ THAY cho cảnh sông. Nhấn thứ tự giai đoạn là một lược chiến thuật
/// chủ động, không phải chuỗi ngẫu nhiên.
///
/// Vẽ tĩnh, deterministic, tọa độ chuẩn hóa theo canvas — không phụ
/// thuộc asset ngoài; biểu tượng schematic (buồm xanh lục = phòng thủ,
/// buồm đỏ = địch, vàng ngự xưởng = giai đoạn trật tự) thống nhất với
/// RiverScenePainter để learner nhận ra ngay mà không cần legend riêng.
class RiverSequenceSummary {
  RiverSequenceSummary._();

  /// Giai đoạn → (nhãn, biểu tượng sơ đồ). Nhãn tiếng Việt có dấu, ≤2
  /// từ để đọc được ở 320px (font 11px trong ô ~60px rộng).
  static const _stages = <(String, _StageIcon)>[
    ('Chuẩn bị', _StageIcon.stakes),
    ('Nước dâng', _StageIcon.highWater),
    ('Dụ địch', _StageIcon.decoy),
    ('Mắc cọc', _StageIcon.obstructed),
    ('Phản công', _StageIcon.counterattack),
  ];

  /// Vẽ toàn bộ bảng tổng kết — background giấy dó, hàng 5 ô biểu
  /// tượng nối bằng mũi tên, nhãn dưới mỗi ô.
  static void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Nền giấy dó + viền gỗ mảnh — cùng ngữ cảnh parchment của scene.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        const Radius.circular(8),
      ),
      Paint()..color = DauVietColors.parchmentDim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.012, h * 0.02, w * 0.976, h * 0.96),
        const Radius.circular(8),
      ),
      Paint()
        ..color = DauVietColors.outlineVariant.withValues(alpha: 0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Nhãn chuỗi phía trên.
    _label(
      canvas,
      'CHUỖI CHIẾN THUẬT',
      Offset(w * 0.5, h * 0.115),
      DauVietColors.inkMuted,
      fontSize: 11,
      bold: true,
      letterSpacing: 1.2,
    );

    // Bố cục hàng 5 ô: ô hình vuông cạnh ~0.128w, giãn đều.
    const n = 5;
    final box = w * 0.128;
    final gap = (w - box * n - w * 0.08) / (n - 1); // margin 4% mỗi bên
    final startX = w * 0.04;
    final centerY = h * 0.46;
    final labelsY = centerY + box * 0.72;

    for (var i = 0; i < n; i++) {
      final cx = startX + i * (box + gap) + box / 2;
      final center = Offset(cx, centerY);

      // Mũi tên nối sang ô kế.
      if (i < n - 1) {
        _joinArrow(
          canvas,
          Offset(cx + box / 2 + gap * 0.14, centerY),
          Offset(cx + box / 2 + gap * 0.86, centerY),
          size,
        );
      }

      _stageBadge(canvas, size, center, box, i);
      _stageIcon(canvas, size, center, box, _stages[i].$2);
      _label(
        canvas,
        _stages[i].$1,
        Offset(cx, labelsY),
        DauVietColors.inkText,
        fontSize: 11,
        bold: true,
      );
      // Số thứ tự nhỏ góc ô — thứ tự là thông điệp chính.
      _label(
        canvas,
        '${i + 1}',
        Offset(cx - box * 0.40, centerY - box * 0.40),
        DauVietColors.imperialGold,
        fontSize: 11,
        bold: true,
      );
    }

    // Dòng nhấn mạnh — chủ động kết hợp, không phải may mắn tự nhiên.
    _label(
      canvas,
      'Chủ động chuẩn bị + đúng nhịp triều + dụ địch + phản công phối hợp',
      Offset(w * 0.5, h * 0.86),
      DauVietColors.inkMuted,
      fontSize: 10.5,
    );
  }

  /// Ô vuông bo góc màu giai đoạn — vàng ngự xưởng viền ngoài, nền
  /// parchmentContainer; số thứ tự nằm ngoài, biểu tượng bên trong.
  static void _stageBadge(
    Canvas canvas,
    Size size,
    Offset c,
    double box,
    int index,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: box, height: box),
      Radius.circular(box * 0.18),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = DauVietColors.imperialGold.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = index == 4
            ? DauVietColors.cinnabarRed
            : DauVietColors.imperialGold
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  /// Mũi tên nối giữa hai ô — trục ngang + cánh, màu mực nhạt.
  static void _joinArrow(Canvas canvas, Offset a, Offset b, Size size) {
    final paint = Paint()
      ..color = DauVietColors.inkMuted.withValues(alpha: 0.7)
      ..strokeWidth = size.width * 0.006
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, paint);
    final dir = (b - a);
    if (dir.distance < 0.001) return;
    final unit = dir / dir.distance;
    final perp = Offset(-unit.dy, unit.dx);
    final len = size.width * 0.016;
    final wing = size.width * 0.010;
    canvas.drawLine(b, b - unit * len + perp * wing, paint);
    canvas.drawLine(b, b - unit * len - perp * wing, paint);
  }

  static void _stageIcon(
    Canvas canvas,
    Size size,
    Offset c,
    double box,
    _StageIcon icon,
  ) {
    switch (icon) {
      case _StageIcon.stakes:
        _iconStakes(canvas, size, c, box);
      case _StageIcon.highWater:
        _iconHighWater(canvas, size, c, box);
      case _StageIcon.decoy:
        _iconDecoy(canvas, size, c, box);
      case _StageIcon.obstructed:
        _iconObstructed(canvas, size, c, box);
      case _StageIcon.counterattack:
        _iconCounterattack(canvas, size, c, box);
    }
  }

  /// 3 cọc gỗ nhọn cắm đáy — giai đoạn chuẩn bị.
  static void _iconStakes(Canvas canvas, Size size, Offset c, double box) {
    final paint = Paint()
      ..color = DauVietColors.woodBrown
      ..style = PaintingStyle.fill;
    final baseY = c.dy + box * 0.28;
    for (var i = 0; i < 3; i++) {
      final x = c.dx + (i - 1) * box * 0.24;
      final topY = c.dy - box * 0.22;
      canvas.drawRect(
        Rect.fromLTRB(x - box * 0.028, topY, x + box * 0.028, baseY),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - box * 0.028, topY)
          ..lineTo(x, topY - box * 0.07)
          ..lineTo(x + box * 0.028, topY)
          ..close(),
        paint,
      );
    }
  }

  /// Mặt nước sóng cao che cọc — giai đoạn nước dâng.
  static void _iconHighWater(Canvas canvas, Size size, Offset c, double box) {
    final w = size.width;
    final wave = Path()..moveTo(c.dx - box * 0.38, c.dy - box * 0.05);
    final len = box * 0.76;
    for (var i = 0; i < 4; i++) {
      wave.quadraticBezierTo(
        c.dx - box * 0.38 + len * (i + 0.5) / 4,
        c.dy - box * 0.05 + (i.isEven ? -box * 0.08 : box * 0.08),
        c.dx - box * 0.38 + len * (i + 1) / 4,
        c.dy - box * 0.05,
      );
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = DauVietColors.riverBlue
        ..strokeWidth = w * 0.008
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Vệt chìm mờ dưới mặt nước = cọc bị che.
    final sub = Paint()
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.4)
      ..strokeWidth = w * 0.007
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(c.dx - box * 0.14, c.dy + box * 0.03),
      Offset(c.dx - box * 0.14, c.dy + box * 0.24),
      sub,
    );
    canvas.drawLine(
      Offset(c.dx + box * 0.10, c.dy + box * 0.03),
      Offset(c.dx + box * 0.10, c.dy + box * 0.20),
      sub,
    );
  }

  /// Thuyền xanh lục + đuôi vệt nét đứt — giai đoạn dụ địch.
  static void _iconDecoy(Canvas canvas, Size size, Offset c, double box) {
    _boatSymbol(
      canvas,
      c,
      box,
      sailColor: DauVietColors.natureGreen,
      trail: true,
    );
  }

  /// Thuyền đỏ nghiêng trên cọc lộ — giai đoạn mắc cọc.
  static void _iconObstructed(Canvas canvas, Size size, Offset c, double box) {
    // Cọc lộ ở đáy ô.
    final stake = Paint()
      ..color = DauVietColors.woodBrown
      ..style = PaintingStyle.fill;
    final baseY = c.dy + box * 0.30;
    for (var i = 0; i < 2; i++) {
      final x = c.dx + (i - 0.5) * box * 0.34;
      final topY = c.dy + box * 0.10;
      canvas.drawRect(
        Rect.fromLTRB(x - box * 0.024, topY, x + box * 0.024, baseY),
        stake,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - box * 0.024, topY)
          ..lineTo(x, topY - box * 0.06)
          ..lineTo(x + box * 0.024, topY)
          ..close(),
        stake,
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy - box * 0.02);
    canvas.rotate(-0.14);
    _boatHull(
      canvas,
      Offset.zero,
      box * 0.9,
      sailColor: DauVietColors.cinnabarRed,
    );
    canvas.restore();
  }

  /// Hai thuyền xanh lục + mũi tên hướng phải — giai đoạn phản công.
  static void _iconCounterattack(
    Canvas canvas,
    Size size,
    Offset c,
    double box,
  ) {
    _boatSymbol(
      canvas,
      c - Offset(box * 0.16, box * 0.10),
      box * 0.74,
      sailColor: DauVietColors.natureGreen,
    );
    _boatSymbol(
      canvas,
      c + Offset(box * 0.10, box * 0.14),
      box * 0.66,
      sailColor: DauVietColors.natureGreen,
    );
    // Mũi phối hợp về phía bãi (bên phải).
    final paint = Paint()
      ..color = DauVietColors.cinnabarRedDark
      ..strokeWidth = box * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final a = Offset(c.dx + box * 0.22, c.dy - box * 0.30);
    final b = Offset(c.dx + box * 0.40, c.dy - box * 0.30);
    canvas.drawLine(a, b, paint);
    canvas.drawLine(b, b - Offset(box * 0.06, box * 0.05), paint);
    canvas.drawLine(b, b - Offset(box * 0.06, -box * 0.05), paint);
  }

  /// Thuyền nhỏ stylized — thân đậm + buồm theo phe; `trail` thêm 2
  /// nét đứt phía sau đuôi thuyền (ký hiệu đường dẫn dụ địch).
  static void _boatSymbol(
    Canvas canvas,
    Offset c,
    double box, {
    required Color sailColor,
    bool trail = false,
  }) {
    _boatHull(canvas, c, box, sailColor: sailColor);
    if (trail) {
      final paint = Paint()
        ..color = sailColor.withValues(alpha: 0.6)
        ..strokeWidth = box * 0.045
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 2; i++) {
        final x = c.dx + box * (0.30 + i * 0.22);
        canvas.drawLine(
          Offset(x, c.dy + box * 0.10),
          Offset(x + box * 0.10, c.dy + box * 0.10),
          paint,
        );
      }
    }
  }

  /// Thân + buồm thuyền stylized tại tâm c — tương phản phe bằng màu
  /// buồm (đỏ = địch, xanh lục = phòng thủ).
  static void _boatHull(
    Canvas canvas,
    Offset c,
    double box, {
    required Color sailColor,
  }) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - box * 0.24, c.dy + box * 0.12)
        ..lineTo(c.dx + box * 0.24, c.dy + box * 0.12)
        ..lineTo(c.dx + box * 0.16, c.dy + box * 0.22)
        ..lineTo(c.dx - box * 0.16, c.dy + box * 0.22)
        ..close(),
      Paint()
        ..color = const Color(0xFF4A3226)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + box * 0.10)
        ..lineTo(c.dx, c.dy - box * 0.16)
        ..lineTo(c.dx + box * 0.16, c.dy + box * 0.08)
        ..close(),
      Paint()
        ..color = sailColor.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );
  }

  static void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    required double fontSize,
    bool bold = false,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 900);
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }
}

enum _StageIcon { stakes, highWater, decoy, obstructed, counterattack }
