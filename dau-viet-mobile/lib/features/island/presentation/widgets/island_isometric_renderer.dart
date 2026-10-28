import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';

/// Renderer 2:1 Isometric Diorama cho Đảo Di Sản.
/// Từng tile là một hình thoi thật ăn khớp, có bờ đất dày 2.5D,
/// mặt nước gợn sóng nhẹ, bóng đổ tự nhiên và hit-testing chính xác.
class IslandIsometricRenderer extends StatelessWidget {
  final IslandBoardDto board;
  final List<IslandSlotDto> slots;
  final int currentTier;
  final String? selectedSlotId;
  final (int row, int col)? selectedTileCoord;
  final ValueChanged<(int row, int col)> onTileTap;
  final ValueChanged<IslandSlotDto> onSlotTap;
  final double waterAnimationValue;
  final double expansionRevealProgress;
  final int? expandingFromTier;
  final int? expandingToTier;

  const IslandIsometricRenderer({
    super.key,
    required this.board,
    required this.slots,
    required this.currentTier,
    required this.onTileTap,
    required this.onSlotTap,
    this.selectedSlotId,
    this.selectedTileCoord,
    this.waterAnimationValue = 0.0,
    this.expansionRevealProgress = 1.0,
    this.expandingFromTier,
    this.expandingToTier,
  });

  @override
  Widget build(BuildContext context) {
    // Map slotId -> IslandSlotDto
    final slotById = <String, IslandSlotDto>{
      for (final s in slots) s.slotId: s,
    };

    // Map (row, col) -> IslandSlotDto
    final slotByCoord = <(int, int), IslandSlotDto>{};
    for (final s in slots) {
      if (s.tileRow != null && s.tileCol != null) {
        slotByCoord[(s.tileRow!, s.tileCol!)] = s;
      }
    }

    final totalRows = board.rows;
    final totalCols = board.cols;
    final tileW = board.tileWidth;
    final tileH = board.tileHeight;

    // Chiều rộng & chiều cao tổng thể của scene isometric
    final sceneWidth = (totalRows + totalCols) * (tileW * 0.5) + tileW * 2.0;
    final sceneHeight = (totalRows + totalCols) * (tileH * 0.5) + tileH * 4.0;
    final originX = sceneWidth * 0.5;
    final originY = tileH * 2.0;

    // Phân loại tile theo thứ tự render (Depth sorting theo row + col)
    final sortedTiles = List<IslandTileDto>.from(board.tiles)
      ..sort((a, b) {
        final depthA = a.row + a.col;
        final depthB = b.row + b.col;
        if (depthA != depthB) return depthA.compareTo(depthB);
        return a.row.compareTo(b.row);
      });

    // Tập hợp các tọa độ tồn tại tile để xác định mép đảo (cliff edges)
    final existingCoords = <(int, int)>{
      for (final t in board.tiles) (t.row, t.col),
    };

    return SizedBox(
      width: sceneWidth,
      height: sceneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Lớp 1: Mặt nước xanh ngọc bích chuyển động êm dịu và bóng đảo
          Positioned.fill(
            child: CustomPaint(
              painter: _IslandWaterAndShadowPainter(
                board: board,
                originX: originX,
                originY: originY,
                existingCoords: existingCoords,
                currentTier: currentTier,
                animationValue: waterAnimationValue,
              ),
            ),
          ),

          // Lớp 2: Vẽ nền địa hình đảo (Tile thoi, bờ vách đá, chất liệu đất cỏ)
          Positioned.fill(
            child: CustomPaint(
              painter: _IslandTerrainPainter(
                board: board,
                sortedTiles: sortedTiles,
                existingCoords: existingCoords,
                currentTier: currentTier,
                originX: originX,
                originY: originY,
                expansionProgress: expansionRevealProgress,
                expandingFromTier: expandingFromTier,
                expandingToTier: expandingToTier,
                selectedCoord: selectedTileCoord,
                selectedSlotId: selectedSlotId,
                slotById: slotById,
              ),
            ),
          ),

          // Lớp 3: Các công trình di sản và widget tương tác căn theo chân tile
          for (final tile in sortedTiles)
            if (_isTileVisible(tile, currentTier, expansionRevealProgress, expandingFromTier, expandingToTier))
              _buildTileInteractiveObject(
                tile: tile,
                slotById: slotById,
                slotByCoord: slotByCoord,
                originX: originX,
                originY: originY,
                tileW: tileW,
                tileH: tileH,
              ),
        ],
      ),
    );
  }

  bool _isTileVisible(
    IslandTileDto tile,
    int tier,
    double expansionProgress,
    int? fromTier,
    int? toTier,
  ) {
    if (tile.unlockTier <= tier) return true;
    if (fromTier != null && toTier != null && tile.unlockTier <= toTier && expansionProgress > 0.05) {
      return true;
    }
    // Tile khóa vẫn hiển thị có chủ đích để người chơi thấy quy mô hòn đảo
    return true;
  }

  Widget _buildTileInteractiveObject({
    required IslandTileDto tile,
    required Map<String, IslandSlotDto> slotById,
    required Map<(int, int), IslandSlotDto> slotByCoord,
    required double originX,
    required double originY,
    required double tileW,
    required double tileH,
  }) {
    final isoPos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
    final slot = (tile.slotId != null ? slotById[tile.slotId] : null) ?? slotByCoord[(tile.row, tile.col)];

    final isSelected = (slot != null && slot.slotId == selectedSlotId) ||
        (selectedTileCoord != null &&
            selectedTileCoord!.$1 == tile.row &&
            selectedTileCoord!.$2 == tile.col);

    final isLocked = tile.unlockTier > currentTier;

    // Chiều rộng và chiều cao vùng chạm chuẩn
    final objW = tileW * 1.2;
    final objH = tileH * 2.8;

    return Positioned(
      left: isoPos.dx - (objW * 0.5),
      bottom: null,
      top: isoPos.dy + (tileH * 0.5) - objH,
      child: SizedBox(
        width: objW,
        height: objH,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Trường hợp 1: Có vật phẩm đã đặt
            if (slot != null && slot.placement != null && !isLocked)
              IslandHeritageBuilding(
                placement: slot.placement!,
                isSelected: isSelected,
                tileWidth: tileW,
                tileHeight: tileH,
                onTap: () {
                  onSlotTap(slot);
                  onTileTap((tile.row, tile.col));
                },
              )
            // Trường hợp 2: Ô xây dựng trống
            else if (slot != null && !isLocked)
              _buildEmptySlotCue(
                slot: slot,
                tile: tile,
                isSelected: isSelected,
                tileW: tileW,
                tileH: tileH,
              )
            // Trường hợp 3: Ô khóa có sương mờ
            else if (isLocked)
              _buildLockedTileCue(
                tile: tile,
                isSelected: isSelected,
                tileW: tileW,
                tileH: tileH,
                slot: slot,
              )
            // Trường hợp 4: Tile trang trí / tự nhiên
            else
              GestureDetector(
                onTap: () => onTileTap((tile.row, tile.col)),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: tileW,
                  height: tileH,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tín hiệu ô xây dựng trống mời gọi đặt vật phẩm
  Widget _buildEmptySlotCue({
    required IslandSlotDto slot,
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
  }) {
    return GestureDetector(
      onTap: () {
        onSlotTap(slot);
        onTileTap((tile.row, tile.col));
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: tileW,
        height: tileH * 1.6,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: tileH * 0.15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 30 : 26,
              height: isSelected ? 30 : 26,
              decoration: BoxDecoration(
                color: isSelected ? DauVietColors.imperialGold : const Color(0xFFD48B47),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? DauVietColors.imperialGold : Colors.black)
                        .withValues(alpha: 0.35),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tín hiệu ô đất bị khóa theo cấp độ đảo
  Widget _buildLockedTileCue({
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
    IslandSlotDto? slot,
  }) {
    return GestureDetector(
      onTap: () {
        if (slot != null) onSlotTap(slot);
        onTileTap((tile.row, tile.col));
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: tileW,
        height: tileH * 1.5,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: tileH * 0.20),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xCC334155),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? DauVietColors.imperialGold : const Color(0x9994A3B8),
              width: 1.2,
            ),
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 12,
            color: Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

/// Vẽ mặt nước turquoise hữu cơ và bóng đổ của hòn đảo xuống mặt nước
class _IslandWaterAndShadowPainter extends CustomPainter {
  final IslandBoardDto board;
  final double originX;
  final double originY;
  final Set<(int, int)> existingCoords;
  final int currentTier;
  final double animationValue;

  _IslandWaterAndShadowPainter({
    required this.board,
    required this.originX,
    required this.originY,
    required this.existingCoords,
    required this.currentTier,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nền nước chuyển sắc từ ngọc lam êm dịu (#6DB7BF) đến nước sâu (#3D8C9F)
    final waterRect = Offset.zero & size;
    final waterPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.1),
        radius: 1.1,
        colors: [
          Color(0xFF7AC9D2), // Soft turquoise water
          Color(0xFF5CAFB9),
          Color(0xFF3D8C9F), // Deep water
          Color(0xFF2E6E7C),
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(waterRect);
    canvas.drawRect(waterRect, waterPaint);

    // 2. Gợn sóng nước nhẹ nhàng quanh hòn đảo
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final wavePhase = animationValue * 2 * math.pi;

    for (int i = 0; i < 6; i++) {
      final wavePath = Path();
      final radiusW = size.width * (0.32 + i * 0.08);
      final radiusH = size.height * (0.24 + i * 0.06);
      final waveCenter = Offset(originX, originY + size.height * 0.28);

      for (double angle = 0; angle <= 2 * math.pi; angle += 0.2) {
        final ripple = math.sin(angle * 4 + wavePhase + i) * 4.0;
        final x = waveCenter.dx + math.cos(angle) * (radiusW + ripple);
        final y = waveCenter.dy + math.sin(angle) * (radiusH + ripple);
        if (angle == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      wavePath.close();
      canvas.drawPath(wavePath, wavePaint);
    }

    // 3. Bóng đổ 2.5D của đáy hòn đảo xuống mặt nước
    final shadowPaint = Paint()
      ..color = const Color(0xFF1E4E59).withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    for (final tile in board.tiles) {
      if (tile.unlockTier <= currentTier) {
        final pos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
        final shadowRect = Rect.fromCenter(
          center: Offset(pos.dx, pos.dy + board.tileHeight * 0.95),
          width: board.tileWidth * 1.05,
          height: board.tileHeight * 0.65,
        );
        canvas.drawOval(shadowRect, shadowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslandWaterAndShadowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentTier != currentTier;
  }
}

/// Vẽ toàn bộ mặt đất isometric: Hình thoi từng tile, vách đất dày 2.5D, texture cỏ đất đá
class _IslandTerrainPainter extends CustomPainter {
  final IslandBoardDto board;
  final List<IslandTileDto> sortedTiles;
  final Set<(int, int)> existingCoords;
  final int currentTier;
  final double originX;
  final double originY;
  final double expansionProgress;
  final int? expandingFromTier;
  final int? expandingToTier;
  final (int row, int col)? selectedCoord;
  final String? selectedSlotId;
  final Map<String, IslandSlotDto> slotById;

  _IslandTerrainPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingCoords,
    required this.currentTier,
    required this.originX,
    required this.originY,
    required this.expansionProgress,
    required this.expandingFromTier,
    required this.expandingToTier,
    required this.selectedCoord,
    required this.selectedSlotId,
    required this.slotById,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = board.tileWidth * 0.5;
    final halfH = board.tileHeight * 0.5;
    const cliffDepth = 18.0; // Độ dày 2.5D của bờ đất đảo vươn xuống nước

    for (final tile in sortedTiles) {
      final isLocked = tile.unlockTier > currentTier;
      final isNewlyExpanding = expandingFromTier != null &&
          expandingToTier != null &&
          tile.unlockTier > expandingFromTier! &&
          tile.unlockTier <= expandingToTier!;

      final double tileAlpha = isNewlyExpanding
          ? expansionProgress.clamp(0.0, 1.0)
          : (isLocked ? 0.65 : 1.0);

      final pos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      final center = Offset(pos.dx, pos.dy);

      // Điểm 4 đỉnh hình thoi (Top, Right, Bottom, Left)
      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      // 1. Vẽ bờ vách đất 2.5D (Cliff Face) ở mép phía Nam nếu ô liền kề không có đất
      final hasSouthEastNeighbor = existingCoords.contains((tile.row, tile.col + 1));
      final hasSouthWestNeighbor = existingCoords.contains((tile.row + 1, tile.col));

      // Vách đá Tây Nam (Left -> Bottom)
      if (!hasSouthWestNeighbor) {
        final leftCliff = Path()
          ..moveTo(leftPt.dx, leftPt.dy)
          ..lineTo(bottomPt.dx, bottomPt.dy)
          ..lineTo(bottomPt.dx, bottomPt.dy + cliffDepth)
          ..lineTo(leftPt.dx, leftPt.dy + cliffDepth)
          ..close();

        canvas.drawPath(
          leftCliff,
          Paint()
            ..color = const Color(0xFF8C6239).withValues(alpha: tileAlpha),
        );
        // Lớp đất tối dưới chân bờ
        final leftBase = Path()
          ..moveTo(leftPt.dx, leftPt.dy + cliffDepth * 0.65)
          ..lineTo(bottomPt.dx, bottomPt.dy + cliffDepth * 0.65)
          ..lineTo(bottomPt.dx, bottomPt.dy + cliffDepth)
          ..lineTo(leftPt.dx, leftPt.dy + cliffDepth)
          ..close();
        canvas.drawPath(
          leftBase,
          Paint()..color = const Color(0xFF5D3F22).withValues(alpha: tileAlpha),
        );
      }

      // Vách đá Đông Nam (Bottom -> Right)
      if (!hasSouthEastNeighbor) {
        final rightCliff = Path()
          ..moveTo(bottomPt.dx, bottomPt.dy)
          ..lineTo(rightPt.dx, rightPt.dy)
          ..lineTo(rightPt.dx, rightPt.dy + cliffDepth)
          ..lineTo(bottomPt.dx, bottomPt.dy + cliffDepth)
          ..close();

        canvas.drawPath(
          rightCliff,
          Paint()
            ..color = const Color(0xFF9E7244).withValues(alpha: tileAlpha),
        );
        // Lớp đất tối dưới chân bờ
        final rightBase = Path()
          ..moveTo(bottomPt.dx, bottomPt.dy + cliffDepth * 0.65)
          ..lineTo(rightPt.dx, rightPt.dy + cliffDepth * 0.65)
          ..lineTo(rightPt.dx, rightPt.dy + cliffDepth)
          ..lineTo(bottomPt.dx, bottomPt.dy + cliffDepth)
          ..close();
        canvas.drawPath(
          rightBase,
          Paint()..color = const Color(0xFF6B4725).withValues(alpha: tileAlpha),
        );
      }

      // 2. Mặt đất hình thoi (Diamond Top Face)
      final diamondPath = Path()
        ..moveTo(topPt.dx, topPt.dy)
        ..lineTo(rightPt.dx, rightPt.dy)
        ..lineTo(bottomPt.dx, bottomPt.dy)
        ..lineTo(leftPt.dx, leftPt.dy)
        ..close();

      // Màu sắc theo loại terrain
      final terrainColors = _getTerrainColors(tile.terrainType, isLocked);
      final diamondPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            terrainColors.highlight.withValues(alpha: tileAlpha),
            terrainColors.base.withValues(alpha: tileAlpha),
          ],
        ).createShader(Rect.fromLTWH(center.dx - halfW, center.dy - halfH, board.tileWidth, board.tileHeight));

      canvas.drawPath(diamondPath, diamondPaint);

      // Đường viền mềm tinh tế gắn kết các ô
      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = terrainColors.border.withValues(alpha: 0.35 * tileAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // 3. Texture nhẹ nhàng cho từng loại tile
      _drawTileTexture(canvas, tile, center, halfW, halfH, tileAlpha);

      // 4. Nếu tile đang được chọn: vẽ viền nổi bật màu vàng hoàng gia
      final isTileSelected = (selectedCoord != null &&
              selectedCoord!.$1 == tile.row &&
              selectedCoord!.$2 == tile.col) ||
          (selectedSlotId != null &&
              tile.slotId == selectedSlotId);

      if (isTileSelected) {
        canvas.drawPath(
          diamondPath,
          Paint()
            ..color = DauVietColors.imperialGold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
    }
  }

  ({Color base, Color highlight, Color border}) _getTerrainColors(
    IslandTerrainType terrain,
    bool isLocked,
  ) {
    if (isLocked) {
      return (
        base: const Color(0xFF7A8D8B),
        highlight: const Color(0xFF96A6A4),
        border: const Color(0xFF5A6B69),
      );
    }

    switch (terrain) {
      case IslandTerrainType.dirt:
        return (
          base: const Color(0xFF9B744B), // Warm soil
          highlight: const Color(0xFFB58C5E),
          border: const Color(0xFF7A5835),
        );
      case IslandTerrainType.stone:
        return (
          base: const Color(0xFF74857F), // Natural stone
          highlight: const Color(0xFF90A19B),
          border: const Color(0xFF596964),
        );
      case IslandTerrainType.path:
        return (
          base: const Color(0xFFB86644), // Terracotta path
          highlight: const Color(0xFFCF7F5D),
          border: const Color(0xFF944E31),
        );
      case IslandTerrainType.decorative:
        return (
          base: const Color(0xFF7EA858),
          highlight: const Color(0xFF98C46E),
          border: const Color(0xFF5E853C),
        );
      case IslandTerrainType.water:
        return (
          base: const Color(0xFF5CAFB9),
          highlight: const Color(0xFF7AC9D2),
          border: const Color(0xFF3D8C9F),
        );
      case IslandTerrainType.grass:
      default:
        return (
          base: const Color(0xFF8FBA63), // Grass green
          highlight: const Color(0xFFA5CF76),
          border: const Color(0xFF6F9845),
        );
    }
  }

  void _drawTileTexture(
    Canvas canvas,
    IslandTileDto tile,
    Offset center,
    double halfW,
    double halfH,
    double alpha,
  ) {
    if (tile.terrainType == IslandTerrainType.grass) {
      // Điểm xuyết khóm hoa dại / bụi cỏ nhỏ xinh xắn
      final detailPaint = Paint()..color = const Color(0xFFF5CD6A).withValues(alpha: 0.65 * alpha);
      if ((tile.row * 3 + tile.col * 7) % 3 == 0) {
        canvas.drawCircle(Offset(center.dx - halfW * 0.25, center.dy), 1.6, detailPaint);
        canvas.drawCircle(Offset(center.dx + halfW * 0.20, center.dy + halfH * 0.20), 1.4, detailPaint);
      }
    } else if (tile.terrainType == IslandTerrainType.path) {
      // Hoa văn mạch gạch lát đường làng
      final seamPaint = Paint()
        ..color = const Color(0xFF8B4728).withValues(alpha: 0.40 * alpha)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(center.dx - halfW * 0.4, center.dy),
        Offset(center.dx + halfW * 0.4, center.dy),
        seamPaint,
      );
    } else if (tile.terrainType == IslandTerrainType.stone) {
      // Mạch nứt vân đá tự nhiên
      final fissurePaint = Paint()
        ..color = const Color(0xFF4E5E58).withValues(alpha: 0.35 * alpha)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(center.dx - halfW * 0.3, center.dy - halfH * 0.2),
        Offset(center.dx + halfW * 0.1, center.dy + halfH * 0.3),
        fissurePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IslandTerrainPainter oldDelegate) {
    return oldDelegate.currentTier != currentTier ||
        oldDelegate.expansionProgress != expansionProgress ||
        oldDelegate.selectedSlotId != selectedSlotId ||
        oldDelegate.selectedCoord != selectedCoord;
  }
}
