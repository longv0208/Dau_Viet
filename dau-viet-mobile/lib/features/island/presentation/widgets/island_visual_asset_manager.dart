import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';

/// Quản lý tập trung toàn bộ Visual Assets và Scenery Renderers của Đảo Di Sản.
/// Hỗ trợ tra cứu theo:
/// - terrainType (Cỏ, Đất, Đá, Cát, Đường, Tiểu Cảnh, Nước)
/// - visualKey / decorKey (bamboo, lotus, lantern, well, flower, rock, tree, rice...)
/// - renderKey / assetId (công trình kiến trúc di sản)
class IslandVisualAssetManager {
  IslandVisualAssetManager._();

  /// Tra cứu đường dẫn asset cục bộ hoặc URL backend
  static String? resolveBuildingAssetPath(String? renderKey, String? code, [String? assetId]) {
    return resolveIslandAsset(renderKey, code, assetId);
  }

  /// Tra cứu URL từ xa backend an toàn
  static String? resolveBuildingRemoteUrl(String? renderKey, String? assetId) {
    return resolveIslandRemoteAssetUrl(assetId) ?? resolveIslandRemoteAssetUrl(renderKey);
  }

  /// Kiểm tra xem tile có phải là tiểu cảnh môi trường tự nhiên mặc định không
  static bool hasSceneryVisual(IslandTileDto tile) {
    if (tile.decorKey != null && tile.decorKey!.isNotEmpty) return true;
    if (tile.terrainType == IslandTerrainType.decorative) return true;
    return false;
  }

  /// Trả về màu sắc và chất liệu đặc trưng cho từng loại Terrain
  static ({
    Color base,
    Color highlight,
    Color shadow,
    Color rimLight,
  }) getTerrainPalette(IslandTerrainType terrain, {int row = 0, int col = 0, bool isLocked = false}) {
    if (isLocked) {
      return (
        base: const Color(0xFF7A8D8B),
        highlight: const Color(0xFF96A6A4),
        shadow: const Color(0xFF5A6B69),
        rimLight: const Color(0xFFB0BFBD),
      );
    }

    // Biến thiên sắc độ rất nhẹ theo tọa độ (row, col) để mặt cỏ và đất không bị đơn điệu
    final seed = math.sin(row * 12.9898 + col * 78.233) * 43758.5453;
    final jitter = (seed - seed.floor()) - 0.5; // -0.5 .. +0.5

    switch (terrain) {
      case IslandTerrainType.grass:
        // Cỏ xanh tự nhiên: có ô đậm vị lá tre, có ô sáng màu nắng mai
        final r = (0x8F + (jitter * 6).round()).clamp(0x80, 0x9A);
        final g = (0xBA + (jitter * 8).round()).clamp(0xB0, 0xC4);
        final b = (0x63 + (jitter * 4).round()).clamp(0x58, 0x6E);
        return (
          base: Color.fromARGB(255, r, g, b),
          highlight: const Color(0xFFA6D176),
          shadow: const Color(0xFF749E4B),
          rimLight: const Color(0xFFBFE58D),
        );

      case IslandTerrainType.dirt:
        // Đất vàng phù sa ấm áp
        final r = (0x9B + (jitter * 8).round()).clamp(0x90, 0xA8);
        final g = (0x74 + (jitter * 6).round()).clamp(0x6A, 0x80);
        final b = (0x4B + (jitter * 4).round()).clamp(0x42, 0x55);
        return (
          base: Color.fromARGB(255, r, g, b),
          highlight: const Color(0xFFB89267),
          shadow: const Color(0xFF7E5C37),
          rimLight: const Color(0xFFCCAA80),
        );

      case IslandTerrainType.path:
        // Lối đi gạch đất nung hoặc đường làng đất nện
        return (
          base: const Color(0xFFB86644),
          highlight: const Color(0xFFD27B55),
          shadow: const Color(0xFF964C2E),
          rimLight: const Color(0xFFE4936E),
        );

      case IslandTerrainType.stone:
        // Phiến đá tảng xám rêu
        return (
          base: const Color(0xFF74857F),
          highlight: const Color(0xFF90A19B),
          shadow: const Color(0xFF5A6A64),
          rimLight: const Color(0xFFA8B8B2),
        );

      case IslandTerrainType.sand:
        // Bãi cát ven đảo
        return (
          base: const Color(0xFFD9C07A),
          highlight: const Color(0xFFEED792),
          shadow: const Color(0xFFBBA35F),
          rimLight: const Color(0xFFF9E7AC),
        );

      case IslandTerrainType.decorative:
        return (
          base: const Color(0xFF82AC5A),
          highlight: const Color(0xFF9CC870),
          shadow: const Color(0xFF668E3E),
          rimLight: const Color(0xFFB5E087),
        );

      case IslandTerrainType.water:
        return (
          base: const Color(0xFF5CAFB9),
          highlight: const Color(0xFF7AC9D2),
          shadow: const Color(0xFF3D8C9F),
          rimLight: const Color(0xFF9CE0E8),
        );
    }
  }

  /// Render tiểu cảnh tự nhiên theo visualKey
  static Widget renderSceneryItem({
    required String? visualKey,
    required double width,
    required double height,
  }) {
    final key = (visualKey ?? '').toLowerCase().trim();

    if (key.contains('bamboo') || key.contains('tre')) {
      return _BambooScenery(width: width, height: height);
    } else if (key.contains('lotus') || key.contains('sen')) {
      return _LotusPondScenery(width: width, height: height);
    } else if (key.contains('lantern') || key.contains('lamp') || key.contains('den')) {
      return _StoneLanternScenery(width: width, height: height);
    } else if (key.contains('well') || key.contains('gieng')) {
      return _VillageWellScenery(width: width, height: height);
    } else if (key.contains('rice') || key.contains('lua')) {
      return _RicePatchScenery(width: width, height: height);
    } else if (key.contains('flower') || key.contains('grass_flowers') || key.contains('hoa')) {
      return _FloweringBushScenery(width: width, height: height);
    } else if (key.contains('rock') || key.contains('stone') || key.contains('da')) {
      return _MossyRockScenery(width: width, height: height);
    } else if (key.contains('tree') || key.contains('cay') || key.contains('banyan') || key.contains('shrub') || key.contains('sapling')) {
      return _SmallShadeTreeScenery(width: width, height: height);
    }

    // Default: Khóm hoa rực rỡ hoặc bụi cỏ xinh
    return _FloweringBushScenery(width: width, height: height);
  }
}

// ---------------------------------------------------------------------------
// TIỂU CẢNH TỰ NHIÊN LÀNG VIỆT (Cozy Miniature Scenery)
// ---------------------------------------------------------------------------

/// Bụi Tre Làng Cổ: Thân tre vàng xanh thanh thoát, tán lá tre đu đưa
class _BambooScenery extends StatelessWidget {
  final double width;
  final double height;

  const _BambooScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BambooSceneryPainter(),
    );
  }
}

class _BambooSceneryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ nhẹ dưới gốc tre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.92), width: w * 0.45, height: h * 0.16),
      Paint()..color = Colors.black.withValues(alpha: 0.20),
    );

    final stalkPaint = Paint()
      ..color = const Color(0xFF88BD47)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final stalkShadow = Paint()
      ..color = const Color(0xFF64952D)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    // 3 thân tre uốn cong tự nhiên
    canvas.drawLine(Offset(w * 0.38, h * 0.90), Offset(w * 0.30, h * 0.25), stalkShadow);
    canvas.drawLine(Offset(w * 0.50, h * 0.92), Offset(w * 0.52, h * 0.18), stalkPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.90), Offset(w * 0.70, h * 0.28), stalkPaint);

    // Mắt tre đốt tre
    final nodePaint = Paint()..color = const Color(0xFF558223)..strokeWidth = 1.0;
    for (double f = 0.4; f <= 0.8; f += 0.18) {
      canvas.drawLine(Offset(w * 0.38 - 2, h * f), Offset(w * 0.38 + 2, h * f), nodePaint);
      canvas.drawLine(Offset(w * 0.50 - 2, h * f), Offset(w * 0.50 + 2, h * f), nodePaint);
      canvas.drawLine(Offset(w * 0.62 - 2, h * f), Offset(w * 0.62 + 2, h * f), nodePaint);
    }

    // Từng phiến lá tre nhọn mướt
    final leafPaint = Paint()..color = const Color(0xFF4CAF50);
    final leafLight = Paint()..color = const Color(0xFF7CB342);

    void drawLeaf(Offset pos, double angle, double length) {
      final p = Path();
      p.moveTo(pos.dx, pos.dy);
      final tipX = pos.dx + math.cos(angle) * length;
      final tipY = pos.dy + math.sin(angle) * length;
      final ctrlX = pos.dx + math.cos(angle + 0.3) * (length * 0.5);
      final ctrlY = pos.dy + math.sin(angle + 0.3) * (length * 0.5);
      p.quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);
      p.quadraticBezierTo(pos.dx, pos.dy + 3, pos.dx, pos.dy);
      canvas.drawPath(p, (length > 10) ? leafPaint : leafLight);
    }

    drawLeaf(Offset(w * 0.30, h * 0.28), -0.6, 12);
    drawLeaf(Offset(w * 0.30, h * 0.38), -1.2, 10);
    drawLeaf(Offset(w * 0.52, h * 0.20), -0.8, 14);
    drawLeaf(Offset(w * 0.52, h * 0.22), 0.5, 12);
    drawLeaf(Offset(w * 0.52, h * 0.35), 0.7, 11);
    drawLeaf(Offset(w * 0.70, h * 0.30), 0.4, 13);
    drawLeaf(Offset(w * 0.70, h * 0.42), -0.5, 10);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ao Sen Nhỏ: Nước trong xanh, lá sen tròn bập bềnh, búp sen hồng
class _LotusPondScenery extends StatelessWidget {
  final double width;
  final double height;

  const _LotusPondScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _LotusPondSceneryPainter(),
    );
  }
}

class _LotusPondSceneryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mặt nước ao nhỏ
    final waterPath = Path()
      ..moveTo(w * 0.15, h * 0.78)
      ..lineTo(w * 0.50, h * 0.94)
      ..lineTo(w * 0.85, h * 0.78)
      ..lineTo(w * 0.50, h * 0.62)
      ..close();
    canvas.drawPath(
      waterPath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF80DEEA), Color(0xFF26A69A), Color(0xFF00796B)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Lá sen tròn
    final leafPaint = Paint()..color = const Color(0xFF43A047);
    final leafLight = Paint()..color = const Color(0xFF66BB6A);

    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.76), width: w * 0.18, height: h * 0.11), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, h * 0.80), width: w * 0.20, height: h * 0.12), leafLight);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.50, h * 0.70), width: w * 0.15, height: h * 0.09), leafPaint);

    // Hoa sen hồng thắm nở rộ
    final lotusPaint = Paint()..color = const Color(0xFFE91E63);
    canvas.drawCircle(Offset(w * 0.44, h * 0.68), 3.8, lotusPaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.75), 4.4, lotusPaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.75), 1.8, Paint()..color = const Color(0xFFFFF59D));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Đèn Đá Sân Đình: Đèn đá cổ truyền thắp sáng không gian văn hóa
class _StoneLanternScenery extends StatelessWidget {
  final double width;
  final double height;

  const _StoneLanternScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _StoneLanternPainter(),
    );
  }
}

class _StoneLanternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.90), width: w * 0.32, height: h * 0.14),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Chân bệ đá
    final stone = Paint()..color = const Color(0xFF607D8B);
    final stoneLight = Paint()..color = const Color(0xFF78909C);

    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.50, h * 0.86), width: w * 0.22, height: h * 0.08), stone);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.50, h * 0.72), width: w * 0.10, height: h * 0.20), stoneLight);

    // Hốc đèn thắp nến ấm áp
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.50, h * 0.56), width: w * 0.18, height: h * 0.14), Paint()..color = const Color(0xFFF5CD6A));
    canvas.drawCircle(Offset(w * 0.50, h * 0.56), 3.0, Paint()..color = const Color(0xFFFFF9C4));

    // Mái đá che đèn
    final roof = Path()
      ..moveTo(w * 0.32, h * 0.52)
      ..lineTo(w * 0.50, h * 0.38)
      ..lineTo(w * 0.68, h * 0.52)
      ..close();
    canvas.drawPath(roof, stone);
    canvas.drawCircle(Offset(w * 0.50, h * 0.36), 2.2, stoneLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Giếng Làng Cổ: Thành đá xanh rêu phong, gàu sòng tre
class _VillageWellScenery extends StatelessWidget {
  final double width;
  final double height;

  const _VillageWellScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _VillageWellPainter(),
    );
  }
}

class _VillageWellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.86), width: w * 0.44, height: h * 0.18),
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );

    // Miệng giếng đá xanh
    final outerWell = Rect.fromCenter(center: Offset(w * 0.50, h * 0.74), width: w * 0.42, height: h * 0.24);
    canvas.drawOval(outerWell, Paint()..color = const Color(0xFF546E7A));

    // Lòng giếng nước trong vắt
    final innerWater = Rect.fromCenter(center: Offset(w * 0.50, h * 0.73), width: w * 0.30, height: h * 0.16);
    canvas.drawOval(innerWater, Paint()..color = const Color(0xFF00ACC1));

    // Cột tre treo gàu múc nước
    final postPaint = Paint()..color = const Color(0xFF6D4C41)..strokeWidth = 2.2;
    canvas.drawLine(Offset(w * 0.34, h * 0.72), Offset(w * 0.34, h * 0.38), postPaint);
    canvas.drawLine(Offset(w * 0.66, h * 0.72), Offset(w * 0.66, h * 0.38), postPaint);
    canvas.drawLine(Offset(w * 0.32, h * 0.40), Offset(w * 0.68, h * 0.40), postPaint);

    // Gàu sòng tre nhỏ
    canvas.drawRect(Rect.fromLTWH(w * 0.47, h * 0.50, w * 0.07, h * 0.09), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawLine(Offset(w * 0.50, h * 0.40), Offset(w * 0.50, h * 0.50), Paint()..color = const Color(0xFFBCAAA4)..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Khóm Hoa Ban / Hoa Dại Nở Rộ: Chấm sắc vàng, cam, đỏ ấm cúng
class _FloweringBushScenery extends StatelessWidget {
  final double width;
  final double height;

  const _FloweringBushScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _FloweringBushPainter(),
    );
  }
}

class _FloweringBushPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.88), width: w * 0.40, height: h * 0.16),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Vòm lá xanh tròn
    final leafDark = Paint()..color = const Color(0xFF388E3C);
    final leafLight = Paint()..color = const Color(0xFF66BB6A);

    canvas.drawCircle(Offset(w * 0.42, h * 0.72), w * 0.16, leafDark);
    canvas.drawCircle(Offset(w * 0.58, h * 0.70), w * 0.15, leafLight);
    canvas.drawCircle(Offset(w * 0.50, h * 0.60), w * 0.18, leafLight);

    // Các bông hoa nhỏ sắc màu
    final yellowFlower = Paint()..color = const Color(0xFFFFD54F);
    final orangeFlower = Paint()..color = const Color(0xFFFF7043);
    final whiteFlower = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(w * 0.40, h * 0.60), 2.8, yellowFlower);
    canvas.drawCircle(Offset(w * 0.52, h * 0.54), 3.2, orangeFlower);
    canvas.drawCircle(Offset(w * 0.62, h * 0.64), 2.6, whiteFlower);
    canvas.drawCircle(Offset(w * 0.46, h * 0.74), 2.5, orangeFlower);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tảng Đá Rêu Phong Ven Đảo: Khối đá tự nhiên trầm mặc
class _MossyRockScenery extends StatelessWidget {
  final double width;
  final double height;

  const _MossyRockScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _MossyRockPainter(),
    );
  }
}

class _MossyRockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.88), width: w * 0.46, height: h * 0.18),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // Khối đá chính
    final rockPath = Path()
      ..moveTo(w * 0.32, h * 0.84)
      ..lineTo(w * 0.30, h * 0.60)
      ..lineTo(w * 0.48, h * 0.46)
      ..lineTo(w * 0.68, h * 0.58)
      ..lineTo(w * 0.72, h * 0.84)
      ..close();
    canvas.drawPath(rockPath, Paint()..color = const Color(0xFF607D8B));

    // Mặt sáng trên đỉnh đá
    final highlightPath = Path()
      ..moveTo(w * 0.48, h * 0.46)
      ..lineTo(w * 0.68, h * 0.58)
      ..lineTo(w * 0.58, h * 0.66)
      ..lineTo(w * 0.40, h * 0.55)
      ..close();
    canvas.drawPath(highlightPath, Paint()..color = const Color(0xFF90A4AE));

    // Vệt rêu xanh bám trên đá
    final mossPaint = Paint()..color = const Color(0xFF689F38);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.42, h * 0.70), width: w * 0.14, height: h * 0.08), mossPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, h * 0.76), width: w * 0.12, height: h * 0.06), mossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cây Nhỏ Bóng Mát: Thân gỗ ấm, vòm lá xanh mướt
class _SmallShadeTreeScenery extends StatelessWidget {
  final double width;
  final double height;

  const _SmallShadeTreeScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SmallShadeTreePainter(),
    );
  }
}

class _SmallShadeTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bóng đổ
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.90), width: w * 0.48, height: h * 0.18),
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );

    // Thân cây gỗ nâu ấm
    final trunk = Path()
      ..moveTo(w * 0.46, h * 0.88)
      ..lineTo(w * 0.48, h * 0.55)
      ..lineTo(w * 0.53, h * 0.55)
      ..lineTo(w * 0.55, h * 0.88)
      ..close();
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF5D4037));

    // Vòm lá xanh ngọc nhiều tầng
    final foliageDark = Paint()..color = const Color(0xFF2E7D32);
    final foliageMid = Paint()..color = const Color(0xFF388E3C);
    final foliageLight = Paint()..color = const Color(0xFF4CAF50);

    canvas.drawCircle(Offset(w * 0.40, h * 0.48), w * 0.18, foliageDark);
    canvas.drawCircle(Offset(w * 0.60, h * 0.46), w * 0.17, foliageMid);
    canvas.drawCircle(Offset(w * 0.50, h * 0.32), w * 0.20, foliageLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thửa Ruộng Lúa Vàng / Mạ Non: Các khóm lúa xanh ngả vàng óng ả
class _RicePatchScenery extends StatelessWidget {
  final double width;
  final double height;

  const _RicePatchScenery({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RicePatchPainter(),
    );
  }
}

class _RicePatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mặt nước xâm xấp phù sa ấm
    final mud = Path()
      ..moveTo(w * 0.20, h * 0.78)
      ..lineTo(w * 0.50, h * 0.92)
      ..lineTo(w * 0.80, h * 0.78)
      ..lineTo(w * 0.50, h * 0.64)
      ..close();
    canvas.drawPath(
      mud,
      Paint()..color = const Color(0xFF8D6E63).withValues(alpha: 0.35),
    );

    // Khóm lúa mạ và bông lúa vàng trĩu hạt
    final stalkGreen = Paint()
      ..color = const Color(0xFF7CB342)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final grainGold = Paint()
      ..color = const Color(0xFFF5CD6A)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    void drawRiceBunch(double cx, double cy, double scale) {
      // 3 tép lúa xòe cong
      canvas.drawLine(Offset(cx, cy), Offset(cx - 5 * scale, cy - 14 * scale), stalkGreen);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy - 17 * scale), stalkGreen);
      canvas.drawLine(Offset(cx, cy), Offset(cx + 5 * scale, cy - 13 * scale), stalkGreen);

      // Đầu bông lúa vàng
      canvas.drawCircle(Offset(cx - 5 * scale, cy - 14 * scale), 1.8 * scale, grainGold);
      canvas.drawCircle(Offset(cx, cy - 17 * scale), 2.0 * scale, grainGold);
      canvas.drawCircle(Offset(cx + 5 * scale, cy - 13 * scale), 1.8 * scale, grainGold);
    }

    drawRiceBunch(w * 0.38, h * 0.82, 0.9);
    drawRiceBunch(w * 0.54, h * 0.86, 1.0);
    drawRiceBunch(w * 0.62, h * 0.75, 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
