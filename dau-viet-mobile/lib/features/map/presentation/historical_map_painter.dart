import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../data/map_location_dto.dart';

/// Khung nhìn bao quanh các điểm dữ liệu (+ padding) và phép chiếu
/// lat/lng → offset. Screen và painter dùng CHUNG hàm này để marker và
/// nền khớp nhau tuyệt đối (cùng một projection).
///
/// Đây là bản đồ lược hoạ (schematic): không có base map thật, không
/// bờ biển/địa hình định vị theo tọa độ — vì vậy đường cong trang trí
/// KHÔNG được gợi hình địa lý thật, tránh hiểu nhầm là georeferenced.
Rect mapDataBounds(List<MapLocationDto> locations) {
  // Vùng mặc định quanh đồng bằng Bắc Bộ khi chưa có điểm — chỉ là khung
  // nhìn trống, KHÔNG sinh marker.
  if (locations.isEmpty) {
    return const Rect.fromLTRB(104.5, 20.0, 107.5, 22.5);
  }
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
  // Padding 15% mỗi phía; span tối thiểu 0.6° để 1 điểm / cụm điểm sát
  // nhau vẫn render rõ thay vì zoom vô hạn.
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

/// Project lat/lng → offset trong một canvas `size` với `bounds` cho
/// trước. Giá trị nằm ngoài khung vẫn project tuyến tính (marker ngoài
/// viewport bị InteractiveViewer che — đúng kỳ vọng khi pan/zoom).
Offset projectLngLat(MapLocationDto loc, Size size, Rect bounds) {
  final dx = (loc.longitude - bounds.left) / bounds.width;
  final dy = 1 - (loc.latitude - bounds.top) / bounds.height;
  return Offset(dx * size.width, dy * size.height);
}

/// Bản đồ giấy dó lược hoạ — KHÔNG dùng tile/base map thật (zero-dep).
/// Nền parchment + lưới kinh/vĩ tuyến mờ + la bàn + vài nét sóng trang
/// trí THUẦN hoạ tiết (không gợi hình địa lý thật). Vị trí marker tính
/// từ tọa độ thật qua [projectLngLat] — không bịa vị trí.
class HistoricalMapPainter extends CustomPainter {
  final List<MapLocationDto> locations;
  final int? selectedIndex;

  HistoricalMapPainter({required this.locations, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = mapDataBounds(locations);
    _paintParchment(canvas, size);
    _paintGrid(canvas, size, bounds);
    _paintDecorativeWaves(canvas, size);
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

  /// Nét sóng trang trí THUẦN hoạ tiết — đặt theo tỉ lệ canvas, cố tình
  /// KHÔNG gợi hình bờ biển hay địa danh thật (bản đồ lược hoạ, không
  /// georeferenced; tránh ngụy trang độ chính xác địa lý).
  void _paintDecorativeWaves(Canvas canvas, Size size) {
    final wave = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (dx, dy) in const [
      (0.14, 0.18),
      (0.86, 0.20),
      (0.18, 0.48),
      (0.84, 0.55),
      (0.12, 0.80),
      (0.88, 0.84),
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
