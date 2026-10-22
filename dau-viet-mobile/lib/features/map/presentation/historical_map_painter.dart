import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../data/map_location_dto.dart';

/// Bản đồ giấy dó stylized — KHÔNG dùng tile thật (zero-dep, đúng brief).
/// Tọa độ lat/lng được chuẩn hoá vào khung nhìn bao quanh các điểm dữ liệu
/// (+ padding), vẽ lên nền parchment với lưới kinh tuyến/vĩ tuyến mờ và
/// bờ biển Việt Nam lược hoạ bằng bezier. Vị trí marker tính từ tọa độ
/// thật — không bịa vị trí.
class HistoricalMapPainter extends CustomPainter {
  final List<MapLocationDto> locations;
  final int? selectedIndex;

  HistoricalMapPainter({required this.locations, this.selectedIndex});

  /// Vùng dữ liệu mặc định quanh đồng bằng Bắc Bộ khi chưa có điểm nào —
  /// dùng làm khung nhìn trống, KHÔNG sinh marker.
  static const Rect _fallbackBounds = Rect.fromLTRB(104.5, 20.0, 107.5, 22.5);

  Rect _dataBounds() {
    if (locations.isEmpty) return _fallbackBounds;
    double minLng = locations.first.longitude;
    double maxLng = minLng;
    double minLat = locations.first.latitude;
    double maxLat = minLat;
    for (final l in locations) {
      minLng = math.min(minLng, l.longitude);
      maxLng = math.max(maxLng, l.longitude);
      minLat = math.min(minLat, l.latitude);
      maxLat = math.max(maxLat, l.latitude);
    }
    // Padding 15% mỗi phía, tối thiểu 0.6° để cụm điểm sát nhau vẫn rõ.
    const pad = 0.15;
    final spanLng = math.max(maxLng - minLng, 0.6);
    final spanLat = math.max(maxLat - minLat, 0.6);
    return Rect.fromLTRB(
      minLng - spanLng * pad,
      minLat - spanLat * pad,
      maxLng + spanLng * pad,
      maxLat + spanLat * pad,
    );
  }

  /// Project lat/lng → offset trong `size`.
  Offset project(MapLocationDto loc, Size size, Rect bounds) {
    final dx = (loc.longitude - bounds.left) / bounds.width;
    final dy = 1 - (loc.latitude - bounds.top) / bounds.height;
    return Offset(dx * size.width, dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _dataBounds();
    _paintParchment(canvas, size);
    _paintGrid(canvas, size, bounds);
    _paintCoastline(canvas, size, bounds);
    _paintCompass(canvas, size);
  }

  void _paintParchment(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = DauVietColors.parchmentHigh,
    );
    // Vệt giấy dó nhẹ.
    final rng = math.Random(7);
    final stain = Paint()
      ..color = DauVietColors.outlineVariant.withValues(alpha: 0.18);
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        30 + rng.nextDouble() * 70,
        stain,
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size, Rect bounds) {
    final grid = Paint()
      ..color = DauVietColors.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    const lines = 6;
    for (int i = 1; i < lines; i++) {
      final x = size.width * i / lines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      final y = size.height * i / lines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Khung ngoài kiểu bản đồ cổ.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = DauVietColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
      Paint()
        ..color = DauVietColors.outline.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  /// Bờ biển lược hoạ — vùng biển phía Đông/Nam tô nhạt, đường cong gợi
  /// hình chữ S. Thuần trang trí; marker vẫn đặt theo tọa độ thật.
  void _paintCoastline(Canvas canvas, Size size, Rect bounds) {
    final sea = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.14);
    final seaPath = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.30,
        size.width * 0.62,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.75,
        size.width * 0.70,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(seaPath, sea);

    final coast = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final coastPath = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.30,
        size.width * 0.62,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.75,
        size.width * 0.70,
        size.height,
      );
    canvas.drawPath(coastPath, coast);

    // Vài nét sóng trang trí trong vùng biển.
    final wave = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (dx, dy) in const [
      (0.86, 0.18),
      (0.90, 0.42),
      (0.84, 0.66),
      (0.90, 0.85),
    ]) {
      final cx = size.width * dx;
      final cy = size.height * dy;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: 26, height: 10),
        math.pi,
        math.pi,
        false,
        wave,
      );
    }
  }

  void _paintCompass(Canvas canvas, Size size) {
    final c = Offset(size.width - 44, 48);
    final paint = Paint()
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.8);
    canvas.drawCircle(c, 18, Paint()..color = DauVietColors.parchmentDim);
    canvas.drawCircle(
      c,
      18,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final needle = Path()
      ..moveTo(c.dx, c.dy - 13)
      ..lineTo(c.dx + 4, c.dy)
      ..lineTo(c.dx, c.dy + 13)
      ..lineTo(c.dx - 4, c.dy)
      ..close();
    canvas.drawPath(
      needle,
      Paint()..color = DauVietColors.cinnabarRed.withValues(alpha: 0.85),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: DauVietColors.inkMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -30));
  }

  @override
  bool shouldRepaint(HistoricalMapPainter old) =>
      old.locations != locations || old.selectedIndex != selectedIndex;
}
