import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';

/// Renderer mô hình công trình kiến trúc di sản Việt Nam 3D Isometric.
/// Căn chỉnh chân vật thể chuẩn xác trên mặt đất hình thoi của tile,
/// đổ bóng mềm 2.5D xuống mặt đảo và hòa hợp tuyệt đối với bảng màu Cozy Heritage.
class IslandHeritageBuilding extends StatelessWidget {
  final IslandPlacementDto placement;
  final bool isSelected;
  final double tileWidth;
  final double tileHeight;
  final bool flipHorizontally;
  final bool useProportionalScale;
  final VoidCallback? onTap;

  const IslandHeritageBuilding({
    super.key,
    required this.placement,
    this.isSelected = false,
    this.tileWidth = 72.0,
    this.tileHeight = 36.0,
    this.flipHorizontally = false,
    this.useProportionalScale = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = placement.assetPath;
    final remoteUrl = placement.remoteAssetUrl;
    final code = placement.code.toLowerCase();
    final renderKey = (placement.renderKey ?? '').toLowerCase();

    // Phân biệt tỷ lệ hiển thị giữa công trình lớn và vật phẩm nhỏ trên đảo (Issue #46 AC-2)
    final visualScale = useProportionalScale
        ? resolveIslandItemVisualScale(code, renderKey)
        : 1.15;
    final modelW = tileWidth * visualScale;
    final modelH = tileHeight * (visualScale * 1.95).clamp(1.85, 2.85);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: modelW,
        height: modelH,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Bóng đổ 2.5D trên mặt đất hình thoi
            Positioned(
              bottom: 2,
              child: _buildSoftShadow(modelW * 0.70, tileHeight * 0.52),
            ),

            // Viền chọn rực rỡ khi được tap
            if (isSelected)
              Positioned(
                bottom: 0,
                child: _buildSelectionAura(modelW * 0.78, tileHeight * 0.60),
              ),

            // Thân công trình: ưu tiên asset ảnh nếu có, fallback vẽ vector di sản tinh xảo
            Positioned(
              bottom: 4,
              child: Transform.flip(
                flipX: flipHorizontally,
                child: _buildBuildingArt(
                  context: context,
                  assetPath: assetPath,
                  remoteUrl: remoteUrl,
                  code: code,
                  renderKey: renderKey,
                  width: modelW,
                  height: modelH,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bóng đổ mềm mại hình elip trên mặt đất
  Widget _buildSoftShadow(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
        gradient: RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
    );
  }

  /// Hào quang viền sáng khi tile được chọn
  Widget _buildSelectionAura(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
        border: Border.all(
          color: DauVietColors.imperialGold,
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: DauVietColors.imperialGold.withValues(alpha: 0.45),
            blurRadius: 8.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingArt({
    required BuildContext context,
    required String? assetPath,
    required String? remoteUrl,
    required String code,
    required String renderKey,
    required double width,
    required double height,
  }) {
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        width: width,
        height: height * 0.92,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, _, _) => _buildProceduralBuilding(code, renderKey, width, height),
      );
    }

    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      final headers = islandAuthHeaders(remoteUrl);
      return Image.network(
        remoteUrl,
        headers: headers,
        width: width,
        height: height * 0.90,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, _, _) => _buildProceduralBuilding(code, renderKey, width, height),
      );
    }

    return _buildProceduralBuilding(code, renderKey, width, height);
  }

  /// Vẽ mô hình kiến trúc di sản thu nhỏ đặc trưng phong cách Việt Nam
  Widget _buildProceduralBuilding(String code, String renderKey, double width, double height) {
    final token = '$code $renderKey';

    if (token.contains('nha_tranh')) {
      return _VietnameseThatchedHouse(width: width, height: height * 0.88);
    } else if (token.contains('cau_kieu')) {
      return _VietnameseCoveredBridge(width: width, height: height * 0.82);
    } else if (token.contains('ho_sen')) {
      return _VietnameseLotusPond(width: width, height: height * 0.78);
    } else if (token.contains('cay_da')) {
      return _VietnameseBanyanTree(width: width, height: height * 0.94);
    } else if (token.contains('dinh_lang')) {
      return _VietnameseCommunalHall(width: width, height: height * 0.92);
    } else if (token.contains('cong_lang')) {
      return _VietnameseVillageGate(width: width, height: height * 0.88);
    } else if (token.contains('khue_van')) {
      return _VietnameseKhueVanCac(width: width, height: height * 0.95);
    } else if (token.contains('thap_but')) {
      return _VietnamesePenTower(width: width, height: height * 0.95);
    } else if (token.contains('gieng_co')) {
      return _VietnameseAncientWell(width: width, height: height * 0.75);
    } else if (token.contains('bui_tre')) {
      return _VietnameseBambooGrove(width: width, height: height * 0.85);
    } else if (token.contains('cot_co')) {
      return _VietnameseFlagpole(width: width, height: height * 0.92);
    } else if (token.contains('tuong_ly_thai_to') || token.contains('tuong')) {
      return _VietnameseLyThaiToStatue(width: width, height: height * 0.92);
    } else if (token.contains('cay_dao')) {
      return _VietnamesePeachBlossomTree(width: width, height: height * 0.92);
    } else if (token.contains('thuyen')) {
      return _VietnameseTraditionalBoat(width: width, height: height * 0.78);
    } else if (token.contains('den_long') || token.contains('den_da')) {
      return _VietnameseRedLanternPost(width: width, height: height * 0.86);
    }

    // Default: Nhà Tranh Mái Lá truyền thống
    return _VietnameseThatchedHouse(width: width, height: height * 0.88);
  }
}

/// Nhà Tranh Vách Đất: Mái tranh vàng rơm, vách đất nung ấm, hiên tre mộc mạc
class _VietnameseThatchedHouse extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseThatchedHouse({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ThatchedHousePainter(),
    );
  }
}

class _ThatchedHousePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Nền móng đất nung
    final foundationPath = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.50, h * 0.98)
      ..lineTo(w * 0.85, h * 0.85)
      ..lineTo(w * 0.50, h * 0.72)
      ..close();
    canvas.drawPath(
      foundationPath,
      Paint()..color = const Color(0xFF8B5E3C),
    );

    // Vách đất nhà tranh
    final wallFront = Path()
      ..moveTo(w * 0.22, h * 0.65)
      ..lineTo(w * 0.50, h * 0.78)
      ..lineTo(w * 0.50, h * 0.92)
      ..lineTo(w * 0.22, h * 0.80)
      ..close();
    canvas.drawPath(
      wallFront,
      Paint()..color = const Color(0xFFD2A679),
    );

    final wallSide = Path()
      ..moveTo(w * 0.50, h * 0.78)
      ..lineTo(w * 0.78, h * 0.65)
      ..lineTo(w * 0.78, h * 0.80)
      ..lineTo(w * 0.50, h * 0.92)
      ..close();
    canvas.drawPath(
      wallSide,
      Paint()..color = const Color(0xFFB8865B),
    );

    // Cửa liếp tre mở nhẹ
    final doorPath = Path()
      ..moveTo(w * 0.32, h * 0.72)
      ..lineTo(w * 0.42, h * 0.77)
      ..lineTo(w * 0.42, h * 0.89)
      ..lineTo(w * 0.32, h * 0.83)
      ..close();
    canvas.drawPath(
      doorPath,
      Paint()..color = const Color(0xFF5A3825),
    );

    // Mái tranh rơm vàng ấm (2 mái dốc hình kim tự tháp truyền thống)
    final roofPeak = Offset(w * 0.50, h * 0.22);

    final roofFront = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(w * 0.10, h * 0.62)
      ..lineTo(w * 0.50, h * 0.76)
      ..close();
    canvas.drawPath(
      roofFront,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8C374), Color(0xFFC99742)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final roofSide = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(w * 0.50, h * 0.76)
      ..lineTo(w * 0.90, h * 0.62)
      ..close();
    canvas.drawPath(
      roofSide,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC99742), Color(0xFFA67428)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Chum nước sành bên hiên
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.20, h * 0.82), width: w * 0.09, height: h * 0.12),
      Paint()..color = const Color(0xFF7A4A28),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Đình Làng Mái Đao: Mái ngói đỏ mũi hài uốn cong vút, cột gỗ lim trầm mặc
class _VietnameseCommunalHall extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseCommunalHall({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CommunalHallPainter(),
    );
  }
}

class _CommunalHallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Nền tam cấp đá xanh
    final base = Path()
      ..moveTo(w * 0.12, h * 0.86)
      ..lineTo(w * 0.50, h * 0.98)
      ..lineTo(w * 0.88, h * 0.86)
      ..lineTo(w * 0.50, h * 0.74)
      ..close();
    canvas.drawPath(base, Paint()..color = const Color(0xFF6B7280));

    // Cột gỗ lim trầm mặc
    final columnPaint = Paint()..color = const Color(0xFF4A2511)..strokeWidth = 3.5;
    canvas.drawLine(Offset(w * 0.26, h * 0.80), Offset(w * 0.26, h * 0.58), columnPaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.85), Offset(w * 0.42, h * 0.63), columnPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.85), Offset(w * 0.58, h * 0.63), columnPaint);
    canvas.drawLine(Offset(w * 0.74, h * 0.80), Offset(w * 0.74, h * 0.58), columnPaint);

    // Mái ngói đỏ rực rỡ với đầu đao cong vút đặc trưng đình làng Việt Nam
    final roofLeft = Path()
      ..moveTo(w * 0.04, h * 0.46) // Đầu đao cong vút bên trái
      ..quadraticBezierTo(w * 0.18, h * 0.58, w * 0.50, h * 0.66)
      ..lineTo(w * 0.50, h * 0.28) // Đỉnh nóc
      ..quadraticBezierTo(w * 0.22, h * 0.26, w * 0.04, h * 0.46)
      ..close();
    canvas.drawPath(
      roofLeft,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD34836), Color(0xFFB03322)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final roofRight = Path()
      ..moveTo(w * 0.96, h * 0.46) // Đầu đao cong vút bên phải
      ..quadraticBezierTo(w * 0.82, h * 0.58, w * 0.50, h * 0.66)
      ..lineTo(w * 0.50, h * 0.28)
      ..quadraticBezierTo(w * 0.78, h * 0.26, w * 0.96, h * 0.46)
      ..close();
    canvas.drawPath(
      roofRight,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB03322), Color(0xFF8A2417)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Lưỡng long chầu nguyệt hoặc hoa văn đỉnh nóc
    canvas.drawCircle(Offset(w * 0.50, h * 0.24), 3.5, Paint()..color = const Color(0xFFF5CD6A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cây Đa Cổ Thụ: Vòm lá xum xuê nhiều tầng xanh ngọc, rễ phụ buông mềm
class _VietnameseBanyanTree extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseBanyanTree({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BanyanTreePainter(),
    );
  }
}

class _BanyanTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gốc & Rễ cây đa cổ thụ
    final trunkPath = Path()
      ..moveTo(w * 0.44, h * 0.92)
      ..quadraticBezierTo(w * 0.48, h * 0.65, w * 0.40, h * 0.48)
      ..lineTo(w * 0.60, h * 0.48)
      ..quadraticBezierTo(w * 0.54, h * 0.68, w * 0.62, h * 0.92)
      ..close();
    canvas.drawPath(trunkPath, Paint()..color = const Color(0xFF5D4037));

    // Rễ phụ buông rủ
    final rootPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w * 0.36, h * 0.55), Offset(w * 0.38, h * 0.90), rootPaint);
    canvas.drawLine(Offset(w * 0.64, h * 0.56), Offset(w * 0.62, h * 0.90), rootPaint);

    // Các tầng tán lá xanh biếc xum xuê (deep forest -> lush emerald)
    void drawFoliageCluster(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    drawFoliageCluster(Offset(w * 0.32, h * 0.42), w * 0.22, const Color(0xFF2E7D32));
    drawFoliageCluster(Offset(w * 0.68, h * 0.44), w * 0.24, const Color(0xFF1B5E20));
    drawFoliageCluster(Offset(w * 0.50, h * 0.32), w * 0.26, const Color(0xFF388E3C));
    drawFoliageCluster(Offset(w * 0.46, h * 0.20), w * 0.22, const Color(0xFF4CAF50));
    drawFoliageCluster(Offset(w * 0.60, h * 0.24), w * 0.20, const Color(0xFF66BB6A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thủy Tạ Hồ Sen: Mặt nước ngọc bích, lá sen dập dềnh và hoa sen hồng thắm
class _VietnameseLotusPond extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseLotusPond({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _LotusPondPainter(),
    );
  }
}

class _LotusPondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mặt nước hồ sen trong xanh
    final pondWater = Path()
      ..moveTo(w * 0.10, h * 0.70)
      ..lineTo(w * 0.50, h * 0.88)
      ..lineTo(w * 0.90, h * 0.70)
      ..lineTo(w * 0.50, h * 0.52)
      ..close();
    canvas.drawPath(
      pondWater,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF81D4FA), Color(0xFF29B6F6), Color(0xFF0288D1)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Lá sen tròn nổi trên mặt nước
    final leafPaint = Paint()..color = const Color(0xFF43A047);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.34, h * 0.68), width: w * 0.18, height: h * 0.12), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.65, h * 0.74), width: w * 0.22, height: h * 0.14), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.48, h * 0.60), width: w * 0.16, height: h * 0.10), leafPaint);

    // Hoa sen hồng thắm nở rộ
    final lotusPaint = Paint()..color = const Color(0xFFE91E63);
    canvas.drawCircle(Offset(w * 0.44, h * 0.56), 4.5, lotusPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.70), 5.5, lotusPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.70), 2.5, Paint()..color = const Color(0xFFFFF176));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cầu Kiều Mái Cong: Nhịp cầu gỗ cong thanh thoát, mái che ngói đỏ
class _VietnameseCoveredBridge extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseCoveredBridge({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CoveredBridgePainter(),
    );
  }
}

class _CoveredBridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Nhịp cầu gỗ uốn cong
    final arch = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..quadraticBezierTo(w * 0.50, h * 0.65, w * 0.85, h * 0.85)
      ..lineTo(w * 0.85, h * 0.78)
      ..quadraticBezierTo(w * 0.50, h * 0.58, w * 0.15, h * 0.78)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFF8D6E63));

    // Cột trụ cầu
    final postPaint = Paint()..color = const Color(0xFF5D4037)..strokeWidth = 2.5;
    canvas.drawLine(Offset(w * 0.32, h * 0.72), Offset(w * 0.32, h * 0.50), postPaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.72), Offset(w * 0.68, h * 0.50), postPaint);

    // Mái ngói che uốn lượn phong cách Cầu Chùa / Cầu Ngói Phát Diệm
    final roof = Path()
      ..moveTo(w * 0.10, h * 0.50)
      ..quadraticBezierTo(w * 0.50, h * 0.38, w * 0.90, h * 0.50)
      ..lineTo(w * 0.50, h * 0.28)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = const Color(0xFFC62828),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cổng Làng Đá Ong: Vòm cổng kiên cố rêu phong, mái ngói truyền thống
class _VietnameseVillageGate extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseVillageGate({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _VillageGatePainter(),
    );
  }
}

class _VillageGatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Trụ cổng đá ong
    final stoneGate = Path()
      ..moveTo(w * 0.20, h * 0.88)
      ..lineTo(w * 0.20, h * 0.42)
      ..lineTo(w * 0.80, h * 0.42)
      ..lineTo(w * 0.80, h * 0.88)
      ..lineTo(w * 0.62, h * 0.88)
      ..lineTo(w * 0.62, h * 0.60)
      ..arcToPoint(Offset(w * 0.38, h * 0.60), radius: Radius.circular(w * 0.12))
      ..lineTo(w * 0.38, h * 0.88)
      ..close();
    canvas.drawPath(stoneGate, Paint()..color = const Color(0xFF8D6E63));

    // Mái cổng ngói rêu phong
    final roof = Path()
      ..moveTo(w * 0.12, h * 0.42)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.88, h * 0.42)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB71C1C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Khuê Văn Các: Cửa sổ tròn sao Khuê, 4 cột đá vững chãi đỡ gác gỗ son đỏ
class _VietnameseKhueVanCac extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseKhueVanCac({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _KhueVanCacPainter(),
    );
  }
}

class _KhueVanCacPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bốn trụ đá nâng đỡ
    final stonePillar = Paint()..color = const Color(0xFF78909C)..strokeWidth = 3.2;
    canvas.drawLine(Offset(w * 0.30, h * 0.90), Offset(w * 0.30, h * 0.60), stonePillar);
    canvas.drawLine(Offset(w * 0.42, h * 0.92), Offset(w * 0.42, h * 0.62), stonePillar);
    canvas.drawLine(Offset(w * 0.58, h * 0.92), Offset(w * 0.58, h * 0.62), stonePillar);
    canvas.drawLine(Offset(w * 0.70, h * 0.90), Offset(w * 0.70, h * 0.60), stonePillar);

    // Gác gỗ đỏ son
    canvas.drawRect(
      Rect.fromLTWH(w * 0.24, h * 0.38, w * 0.52, h * 0.22),
      Paint()..color = const Color(0xFFC62828),
    );

    // Cửa sổ tròn sao Khuê tỏa tia sáng
    canvas.drawCircle(Offset(w * 0.50, h * 0.49), w * 0.085, Paint()..color = const Color(0xFFF5CD6A));
    canvas.drawCircle(Offset(w * 0.50, h * 0.49), w * 0.065, Paint()..color = const Color(0xFFC62828));

    // Mái chồng diêm hai tầng
    final roofLower = Path()
      ..moveTo(w * 0.16, h * 0.40)
      ..lineTo(w * 0.50, h * 0.28)
      ..lineTo(w * 0.84, h * 0.40)
      ..close();
    canvas.drawPath(roofLower, Paint()..color = const Color(0xFFB71C1C));

    final roofUpper = Path()
      ..moveTo(w * 0.25, h * 0.28)
      ..lineTo(w * 0.50, h * 0.16)
      ..lineTo(w * 0.75, h * 0.28)
      ..close();
    canvas.drawPath(roofUpper, Paint()..color = const Color(0xFFD32F2F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tháp Bút: Tháp đá cao vút ngút trời
class _VietnamesePenTower extends StatelessWidget {
  final double width;
  final double height;

  const _VietnamesePenTower({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PenTowerPainter(),
    );
  }
}

class _PenTowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final towerPath = Path()
      ..moveTo(w * 0.35, h * 0.90)
      ..lineTo(w * 0.44, h * 0.26)
      ..lineTo(w * 0.50, h * 0.10) // Ngọn bút lông
      ..lineTo(w * 0.56, h * 0.26)
      ..lineTo(w * 0.65, h * 0.90)
      ..close();
    canvas.drawPath(towerPath, Paint()..color = const Color(0xFF546E7A));

    // Đầu ngọn bút
    final tipPath = Path()
      ..moveTo(w * 0.45, h * 0.24)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.55, h * 0.24)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = const Color(0xFF263238));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Giếng Cổ Đá Xanh
class _VietnameseAncientWell extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseAncientWell({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _AncientWellPainter(),
    );
  }
}

class _AncientWellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Thành giếng hình bát giác đá xanh
    final wellOuter = Rect.fromCenter(center: Offset(w * 0.50, h * 0.70), width: w * 0.50, height: h * 0.35);
    canvas.drawOval(wellOuter, Paint()..color = const Color(0xFF78909C));

    // Lòng giếng nước trong xanh biếc
    final wellInner = Rect.fromCenter(center: Offset(w * 0.50, h * 0.68), width: w * 0.36, height: h * 0.24);
    canvas.drawOval(wellInner, Paint()..color = const Color(0xFF00ACC1));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bụi Tre Làng Cổ: Thân tre vàng óng, lá tre xanh tươi đu đưa
class _VietnameseBambooGrove extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseBambooGrove({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BambooGrovePainter(),
    );
  }
}

class _BambooGrovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stalkPaint = Paint()
      ..color = const Color(0xFF8BC34A)
      ..strokeWidth = 3.0;

    canvas.drawLine(Offset(w * 0.38, h * 0.88), Offset(w * 0.32, h * 0.20), stalkPaint);
    canvas.drawLine(Offset(w * 0.50, h * 0.90), Offset(w * 0.50, h * 0.15), stalkPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.88), Offset(w * 0.68, h * 0.22), stalkPaint);

    final leafPaint = Paint()..color = const Color(0xFF4CAF50);
    for (int i = 0; i < 6; i++) {
      final y = h * (0.22 + i * 0.10);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.40, y), width: 12, height: 4), leafPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.60, y), width: 12, height: 4), leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cột Cờ Truyền Thống: Bệ đá xanh bậc tam cấp, cột gỗ sơn son và đại kỳ thêu hoa văn
class _VietnameseFlagpole extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseFlagpole({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _FlagpolePainter(),
    );
  }
}

class _FlagpolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bệ đá xanh hình thoi
    final basePath = Path()
      ..moveTo(w * 0.28, h * 0.86)
      ..lineTo(w * 0.50, h * 0.95)
      ..lineTo(w * 0.72, h * 0.86)
      ..lineTo(w * 0.50, h * 0.77)
      ..close();
    canvas.drawPath(basePath, Paint()..color = const Color(0xFF78909C));

    // Cột cờ gỗ sơn đỏ nâu
    canvas.drawLine(
      Offset(w * 0.48, h * 0.84),
      Offset(w * 0.48, h * 0.16),
      Paint()
        ..color = const Color(0xFF6D3B24)
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );

    // Đỉnh hồ lô vàng
    canvas.drawCircle(
      Offset(w * 0.48, h * 0.14),
      3.8,
      Paint()..color = const Color(0xFFFFCA28),
    );

    // Lá cờ hội ngũ sắc (viền vàng kim, nền đỏ chu sa, tâm xanh ngọc)
    final flagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.50, h * 0.18, w * 0.34, h * 0.26),
      const Radius.circular(3),
    );
    canvas.drawRRect(flagRect, Paint()..color = const Color(0xFFE0AE45));
    final innerRed = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.53, h * 0.21, w * 0.28, h * 0.20),
      const Radius.circular(2),
    );
    canvas.drawRRect(innerRed, Paint()..color = const Color(0xFFC62828));
    canvas.drawRect(
      Rect.fromLTWH(w * 0.61, h * 0.26, w * 0.12, h * 0.10),
      Paint()..color = const Color(0xFF247D78),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tượng Lý Thái Tổ: Đài đá chạm khắc và tượng đồng uy nghi cầm Chiếu dời đô
class _VietnameseLyThaiToStatue extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseLyThaiToStatue({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _LyThaiToStatuePainter(),
    );
  }
}

class _LyThaiToStatuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bệ đá bậc cấp
    final plinth = Path()
      ..moveTo(w * 0.24, h * 0.85)
      ..lineTo(w * 0.50, h * 0.95)
      ..lineTo(w * 0.76, h * 0.85)
      ..lineTo(w * 0.50, h * 0.75)
      ..close();
    canvas.drawPath(plinth, Paint()..color = const Color(0xFF8D8273));

    // Trụ đá đứng
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.62, w * 0.28, h * 0.24),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFA69B8C),
    );

    // Thân tượng đồng cổ
    final robePath = Path()
      ..moveTo(w * 0.38, h * 0.63)
      ..lineTo(w * 0.43, h * 0.32)
      ..lineTo(w * 0.57, h * 0.32)
      ..lineTo(w * 0.62, h * 0.63)
      ..close();
    canvas.drawPath(robePath, Paint()..color = const Color(0xFF8C6239));

    // Đầu và mũ bình thiên
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.25),
      w * 0.065,
      Paint()..color = const Color(0xFF9E7042),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.19),
        width: w * 0.18,
        height: h * 0.035,
      ),
      Paint()..color = const Color(0xFFD4A34A),
    );

    // Cuộn Chiếu dời đô bên tay phải
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.56, h * 0.38, w * 0.10, h * 0.06),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFE082),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cây Đào Cổ Thụ: Gốc gỗ nâu trầm, tán hoa đào hồng thắm mùa xuân
class _VietnamesePeachBlossomTree extends StatelessWidget {
  final double width;
  final double height;

  const _VietnamesePeachBlossomTree({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PeachBlossomTreePainter(),
    );
  }
}

class _PeachBlossomTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final trunk = Path()
      ..moveTo(w * 0.50, h * 0.90)
      ..quadraticBezierTo(w * 0.46, h * 0.68, w * 0.50, h * 0.48);
    canvas.drawPath(trunk, trunkPaint);

    // Tán hoa đào hồng nhiều lớp
    canvas.drawCircle(
      Offset(w * 0.36, h * 0.46),
      w * 0.19,
      Paint()..color = const Color(0xFFF48FB1),
    );
    canvas.drawCircle(
      Offset(w * 0.64, h * 0.46),
      w * 0.19,
      Paint()..color = const Color(0xFFF06292),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.32),
      w * 0.23,
      Paint()..color = const Color(0xFFF8BBD0),
    );
    canvas.drawCircle(
      Offset(w * 0.48, h * 0.28),
      w * 0.15,
      Paint()..color = const Color(0xFFFCE4EC),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thuyền Gỗ Truyền Thống: Thân thuyền gỗ mũi cong mộc mạc
class _VietnameseTraditionalBoat extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseTraditionalBoat({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TraditionalBoatPainter(),
    );
  }
}

class _TraditionalBoatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final hullPath = Path()
      ..moveTo(w * 0.14, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.92, w * 0.86, h * 0.56)
      ..quadraticBezierTo(w * 0.52, h * 0.72, w * 0.14, h * 0.62)
      ..close();
    canvas.drawPath(hullPath, Paint()..color = const Color(0xFF795548));

    final deckPath = Path()
      ..moveTo(w * 0.18, h * 0.60)
      ..quadraticBezierTo(w * 0.50, h * 0.46, w * 0.82, h * 0.54)
      ..quadraticBezierTo(w * 0.50, h * 0.72, w * 0.18, h * 0.60)
      ..close();
    canvas.drawPath(deckPath, Paint()..color = const Color(0xFFA1887F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Đèn Lồng Phố Cổ: Trụ gỗ treo đèn lồng lụa đỏ rực rỡ
class _VietnameseRedLanternPost extends StatelessWidget {
  final double width;
  final double height;

  const _VietnameseRedLanternPost({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RedLanternPostPainter(),
    );
  }
}

class _RedLanternPostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Chân trụ gỗ
    canvas.drawLine(
      Offset(w * 0.50, h * 0.90),
      Offset(w * 0.50, h * 0.24),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    // Bầu đèn lồng lụa đỏ
    final lanternRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.44),
      width: w * 0.38,
      height: h * 0.30,
    );
    canvas.drawOval(lanternRect, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.44),
        width: w * 0.20,
        height: h * 0.26,
      ),
      Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.65),
    );

    // Nắp và tua rua vàng
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.29),
        width: w * 0.20,
        height: h * 0.035,
      ),
      Paint()..color = const Color(0xFFFFCA28),
    );
    canvas.drawLine(
      Offset(w * 0.50, h * 0.59),
      Offset(w * 0.50, h * 0.70),
      Paint()
        ..color = const Color(0xFFE53935)
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
