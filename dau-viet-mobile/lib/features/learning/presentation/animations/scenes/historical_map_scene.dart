import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../historical_animation_definition.dart';

/// ANIM-02 — Model typed cho bản đồ lịch sử schematic. Tọa độ chuẩn hóa
/// 0..1 theo khung vẽ — không phụ thuộc pixel thiết bị, không phải tọa
/// độ địa lý thật. Bản đồ là SƠ ĐỒ minh họa, không phải bản đồ hành
/// chính hay khảo cổ.
class MapLocation {
  /// ID ổn định — route/step tham chiếu qua id này, không qua index.
  final String id;

  /// Tên hiển thị tiếng Việt.
  final String name;

  /// Vị trí chuẩn hóa (0..1) trong khung bản đồ.
  final Offset position;

  /// Mô tả ngắn ý nghĩa lịch sử — hiện trong panel khi learner chạm.
  final String description;

  /// Nhãn bối cảnh thời kỳ tuỳ chọn (vd: "Kinh đô cũ", "Trung tâm Hán").
  final String? contextLabel;

  const MapLocation({
    required this.id,
    required this.name,
    required this.position,
    required this.description,
    this.contextLabel,
  });
}

/// Tuyến kết nối schematic giữa hai địa điểm — minh họa quan hệ/hướng
/// diễn biến, KHÔNG khẳng định đường hành quân hay đường thủy thật.
class MapRoute {
  final String id;
  final String fromId; // MapLocation.id
  final String toId; // MapLocation.id

  /// Điểm cong trung gian chuẩn hóa (0..1) — đường đi cong nhẹ cho dễ
  /// nhìn; để trống = đường thẳng.
  final List<Offset> via;

  /// Giải thích ngắn của tuyến (hiện trong narration, không vẽ chữ nhỏ
  /// trên map).
  final String explanation;

  const MapRoute({
    required this.id,
    required this.fromId,
    required this.toId,
    this.via = const [],
    required this.explanation,
  });
}

/// Trạng thái đích typed của một bước trên map scene — điểm mở rộng của
/// ANIM-02 thay cho việc lạm dụng waterLevel/boatProgress.
class MapSceneState extends SceneTransition {
  /// Marker id → độ hiện rõ 0..1 (fade-in). Marker vắng mặt = ẩn.
  final Map<String, double> markerVisibility;

  /// Route id → tiến độ vẽ 0..1 (draw-gradually).
  final Map<String, double> routeProgress;

  /// Địa điểm được tô sáng (vòng vàng) ở cuối bước.
  final Set<String> highlighted;

  /// Địa điểm trung tâm câu chuyện của bước (vành đỏ nhẹ).
  final String? focusedId;

  const MapSceneState({
    this.markerVisibility = const {},
    this.routeProgress = const {},
    this.highlighted = const {},
    this.focusedId,
  });

  @override
  void applyFrom(
    HistoricalScenePainter painter,
    SceneTransition from,
    double t,
  ) {
    if (painter is! MapScenePainter) return;
    // Lerp từ snapshot ĐÓNG BĂNG [from]; key vắng ở from mặc định 0,
    // key vắng ở target lerp về 0 (fade-out có chủ đích).
    final f = from is MapSceneState ? from : null;
    painter
      ..markerVisibility = _lerpIdMap(
        f?.markerVisibility ?? const {},
        markerVisibility,
        t,
      )
      ..routeProgress = _lerpIdMap(
        f?.routeProgress ?? const {},
        routeProgress,
        t,
      )
      ..highlightedIds = Set.of(highlighted)
      ..focusedId = focusedId;
  }

  @override
  SceneTransition captured(HistoricalScenePainter painter) {
    if (painter is! MapScenePainter) return this;
    return MapSceneState(
      markerVisibility: Map.of(painter.markerVisibility),
      routeProgress: Map.of(painter.routeProgress),
      highlighted: Set.of(painter.highlightedIds),
      focusedId: painter.focusedId,
    );
  }

  static Map<String, double> _lerpIdMap(
    Map<String, double> from,
    Map<String, double> to,
    double t,
  ) {
    final keys = {...from.keys, ...to.keys};
    return {
      for (final k in keys)
        k: (from[k] ?? 0) + (((to[k] ?? 0) - (from[k] ?? 0)) * t),
    };
  }
}

/// Painter bản đồ schematic — nền giấy dó, đất liền xanh-nâu nhẹ, sông
/// cong stylized, marker tròn + tuyến đứt nét có mũi tên. Marker TẤP được
/// qua overlay widget (không hit-test canvas); painter chỉ vẽ.
class MapScenePainter extends HistoricalScenePainter {
  MapScenePainter({required this.locations, required this.routes});

  final List<MapLocation> locations;
  final List<MapRoute> routes;

  Map<String, double> _markerVisibility = const {};
  Map<String, double> _routeProgress = const {};
  Set<String> _highlightedIds = const {};
  String? _focusedId;

  Map<String, double> get markerVisibility => _markerVisibility;
  set markerVisibility(Map<String, double> v) {
    _markerVisibility = v;
    notifyListeners();
  }

  Map<String, double> get routeProgress => _routeProgress;
  set routeProgress(Map<String, double> v) {
    _routeProgress = v;
    notifyListeners();
  }

  Set<String> get highlightedIds => _highlightedIds;
  set highlightedIds(Set<String> v) {
    _highlightedIds = v;
    notifyListeners();
  }

  String? get focusedId => _focusedId;
  set focusedId(String? v) {
    if (v == _focusedId) return;
    _focusedId = v;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Static helpers — test kiểm hình học chuẩn hóa mà không cần pixel.
  // ------------------------------------------------------------------

  /// Vị trí px của marker theo id trên canvas size cho trước.
  static Offset? positionOf(List<MapLocation> locations, String id, Size size) {
    for (final loc in locations) {
      if (loc.id == id) {
        return Offset(
          loc.position.dx * size.width,
          loc.position.dy * size.height,
        );
      }
    }
    return null;
  }

  /// Điểm trên tuyến route ở tiến độ t (0..1) — đường thẳng nếu không
  /// có via; polyline qua via nếu có. Dùng cho mũi tên đầu tuyến +
  /// chấm "di chuyển" minh họa.
  static Offset routePointAt(
    MapRoute route,
    List<MapLocation> locations,
    double t,
  ) {
    final from = _locById(locations, route.fromId)?.position ?? Offset.zero;
    final to = _locById(locations, route.toId)?.position ?? Offset.zero;
    final pts = <Offset>[from, ...route.via, to];
    if (pts.length < 2) return from;
    // Polyline: chia t đều các đoạn.
    final seg = (pts.length - 1);
    final scaled = (t.clamp(0.0, 1.0)) * seg;
    final i = scaled.floor().clamp(0, seg - 1);
    final local = scaled - i;
    return Offset.lerp(pts[i], pts[i + 1], local) ?? to;
  }

  /// Kiểm tra nhất quán model: mọi route endpoint phải tồn tại trong
  /// locations; vị trí chuẩn hóa trong [0,1]. Chạy trong test/dev.
  static List<String> validateModel(
    List<MapLocation> locations,
    List<MapRoute> routes,
  ) {
    final errors = <String>[];
    final ids = locations.map((l) => l.id).toSet();
    for (final loc in locations) {
      if (loc.position.dx < 0 ||
          loc.position.dx > 1 ||
          loc.position.dy < 0 ||
          loc.position.dy > 1) {
        errors.add('location ${loc.id} position out of bounds');
      }
    }
    for (final r in routes) {
      if (!ids.contains(r.fromId)) {
        errors.add('route ${r.id} fromId ${r.fromId} missing');
      }
      if (!ids.contains(r.toId)) {
        errors.add('route ${r.id} toId ${r.toId} missing');
      }
      for (final v in r.via) {
        if (v.dx < 0 || v.dx > 1 || v.dy < 0 || v.dy > 1) {
          errors.add('route ${r.id} via point out of bounds');
        }
      }
    }
    return errors;
  }

  static MapLocation? _locById(List<MapLocation> locations, String id) {
    for (final l in locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  // ------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- Nền giấy dó + đất liền schematic ---
    // P0 §3: manifest có background asset → player set
    // suppressBaseBackground → bỏ nền opaque để ảnh lộ ra; các lớp
    // trên (đất liền/sông/routes/markers) vẫn vẽ bình thường vì đều
    // translucent, không che ảnh.
    if (!suppressBaseBackground) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = DauVietColors.parchmentDim,
      );
    }
    _paintLand(canvas, size);
    _paintRivers(canvas, size);
    _paintRoutes(canvas, size);
    _paintMarkers(canvas, size);
  }

  /// Mảng đất liền mềm — không phải đường biên thật.
  void _paintLand(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final land = Paint()
      ..color = DauVietColors.natureGreen.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final blob = Path()
      ..moveTo(w * 0.05, h * 0.75)
      ..quadraticBezierTo(w * 0.20, h * 0.40, w * 0.45, h * 0.30)
      ..quadraticBezierTo(w * 0.75, h * 0.18, w * 0.92, h * 0.38)
      ..quadraticBezierTo(w * 0.98, h * 0.60, w * 0.80, h * 0.85)
      ..quadraticBezierTo(w * 0.45, h * 0.97, w * 0.05, h * 0.75)
      ..close();
    canvas.drawPath(blob, land);
    // Vân đồi nhẹ.
    final hill = Paint()
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final c in [
      Offset(w * 0.16, h * 0.30),
      Offset(w * 0.30, h * 0.22),
      Offset(w * 0.72, h * 0.70),
    ]) {
      canvas.drawArc(
        Rect.fromCenter(center: c, width: w * 0.10, height: h * 0.05),
        3.4,
        2.6,
        false,
        hill,
      );
    }
  }

  /// Vài đường sông cong stylized — gợi ý bối cảnh sông nước, không
  /// khẳng định hệ thống sông thật.
  void _paintRivers(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final river = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.5)
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final main = Path()
      ..moveTo(w * 0.10, h * 0.55)
      ..quadraticBezierTo(w * 0.35, h * 0.50, w * 0.55, h * 0.62)
      ..quadraticBezierTo(w * 0.78, h * 0.74, w * 0.95, h * 0.60);
    canvas.drawPath(main, river);
    final branch = Path()
      ..moveTo(w * 0.45, h * 0.18)
      ..quadraticBezierTo(w * 0.48, h * 0.38, w * 0.42, h * 0.52);
    canvas.drawPath(branch, river..strokeWidth = w * 0.008);
  }

  void _paintRoutes(Canvas canvas, Size size) {
    for (final route in routes) {
      final prog = (_routeProgress[route.id] ?? 0).clamp(0.0, 1.0);
      if (prog <= 0) continue;
      final paint = Paint()
        ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.8)
        ..strokeWidth = size.width * 0.008
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Vẽ polyline đứt nét tới điểm prog — "vẽ dần" không teleport.
      const dash = 0.035;
      var t = 0.0;
      while (t < prog) {
        final t2 = (t + dash).clamp(0.0, prog);
        final a = routePointAt(route, locations, t);
        final b = routePointAt(route, locations, t2);
        canvas.drawLine(
          Offset(a.dx * size.width, a.dy * size.height),
          Offset(b.dx * size.width, b.dy * size.height),
          paint,
        );
        t += dash * 1.8;
      }
      // Mũi tên nhỏ ở đầu tuyến đã vẽ tới.
      final tip = routePointAt(route, locations, prog);
      final before = routePointAt(
        route,
        locations,
        (prog - 0.04).clamp(0.0, 1.0),
      );
      _paintArrowTip(canvas, size, before, tip, paint.color);
    }
  }

  void _paintArrowTip(
    Canvas canvas,
    Size size,
    Offset fromN,
    Offset toN,
    Color color,
  ) {
    final from = Offset(fromN.dx * size.width, fromN.dy * size.height);
    final to = Offset(toN.dx * size.width, toN.dy * size.height);
    final dir = (to - from);
    if (dir.distance < 0.001) return;
    final unit = dir / dir.distance;
    final perp = Offset(-unit.dy, unit.dx);
    final len = size.width * 0.022;
    final wing = size.width * 0.011;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.007
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(to, to - unit * len + perp * wing, paint);
    canvas.drawLine(to, to - unit * len - perp * wing, paint);
  }

  void _paintMarkers(Canvas canvas, Size size) {
    for (final loc in locations) {
      final vis = (_markerVisibility[loc.id] ?? 0).clamp(0.0, 1.0);
      if (vis <= 0.02) continue;
      final p = Offset(
        loc.position.dx * size.width,
        loc.position.dy * size.height,
      );
      final highlighted = _highlightedIds.contains(loc.id);
      final focused = _focusedId == loc.id;
      final r = size.width * 0.022;

      // Vành highlight/focus — phân biệt bằng hình (vòng kép), không
      // chỉ màu.
      if (highlighted) {
        canvas.drawCircle(
          p,
          r * 2.3,
          Paint()
            ..color = DauVietColors.imperialGold.withValues(alpha: 0.45)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          p,
          r * 2.3,
          Paint()
            ..color = DauVietColors.imperialGold
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
        );
      }
      if (focused) {
        canvas.drawCircle(
          p,
          r * 1.7,
          Paint()
            ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.85)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
        );
      }
      // Thân marker.
      canvas.drawCircle(
        p,
        r * vis,
        Paint()
          ..color =
              (highlighted
                      ? DauVietColors.cinnabarRed
                      : DauVietColors.woodBrown)
                  .withValues(alpha: 0.25 + 0.75 * vis),
      );
      canvas.drawCircle(
        p,
        r * vis,
        Paint()
          ..color = DauVietColors.parchmentSurface
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
      // Nhãn tên — TextPainter thay vì chữ nhỏ canvas tự do; chữ vẫn
      // nằm trong painter vì nó là phần của hình, panel giải thích nằm
      // ở widget layer.
      _paintMarkerLabel(canvas, size, loc, p, vis);
    }
  }

  void _paintMarkerLabel(
    Canvas canvas,
    Size size,
    MapLocation loc,
    Offset p,
    double vis,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: loc.name,
        style: TextStyle(
          color: DauVietColors.inkText.withValues(alpha: vis),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.3);
    final dx = (p.dx - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
    final dy = (p.dy + size.width * 0.030).clamp(
      0.0,
      size.height - tp.height - 2,
    );
    // Nền parchment mờ sau chữ cho dễ đọc.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 3, dy - 1, tp.width + 6, tp.height + 2),
        const Radius.circular(3),
      ),
      Paint()
        ..color = DauVietColors.parchmentSurface.withValues(alpha: 0.8 * vis),
    );
    tp.paint(canvas, Offset(dx, dy));
  }

  /// Khôi phục toàn bộ trạng thái mutable từ painter đã-seed — replay
  /// đưa map về initialState (markers/routes/highlight/focus) thay vì
  /// giữ trạng thái cuối scene. Giữ [locations]/[routes] của instance
  /// này (cấu hình scene, không phải trạng thái mutable).
  @override
  void restoreFrom(HistoricalScenePainter seeded) {
    super.restoreFrom(seeded);
    if (seeded is! MapScenePainter) return;
    markerVisibility = Map.of(seeded.markerVisibility);
    routeProgress = Map.of(seeded.routeProgress);
    highlightedIds = Set.of(seeded.highlightedIds);
    focusedId = seeded.focusedId;
  }

  @override
  bool shouldRepaint(MapScenePainter old) => false; // ChangeNotifier.
}
