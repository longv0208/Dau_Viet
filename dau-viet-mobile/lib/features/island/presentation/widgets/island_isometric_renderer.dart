import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';
import 'island_visual_asset_manager.dart';

/// Renderer 2:1 Isometric Diorama Cao Cấp cho Đảo Di Sản.
/// Từng tile là một hình thoi hòa hợp tự nhiên, bờ đất phân tầng 2.5D có cỏ rủ,
/// sóng biển nhẹ ven bờ, bóng đổ mềm mại, không có khung viền hộp tối,
/// và bệ đặt di sản tinh tế thay vì nút cam lặp lại.
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

    // Map tileKey -> IslandSlotDto (quan hệ chính V48)
    final slotByTileKey = <String, IslandSlotDto>{};
    for (final s in slots) {
      if (s.tileKey != null && s.tileKey!.isNotEmpty) {
        slotByTileKey[s.tileKey!] = s;
      }
    }

    // Map (row, col) -> IslandSlotDto (legacy fixture)
    final slotByCoord = <(int, int), IslandSlotDto>{};
    for (final s in slots) {
      if (s.tileRow != null && s.tileCol != null) {
        slotByCoord[(s.tileRow!, s.tileCol!)] = s;
      }
    }

    final tileW = board.tileWidth;
    final tileH = board.tileHeight;

    // Chiều rộng & chiều cao scene theo bounding-box thật của các tile
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    if (board.tiles.isNotEmpty) {
      minX = double.infinity;
      maxX = -double.infinity;
      minY = double.infinity;
      maxY = -double.infinity;
      for (final t in board.tiles) {
        final x = (t.col - t.row) * (tileW * 0.5);
        final y = (t.col + t.row) * (tileH * 0.5);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    } else {
      maxX = (board.cols) * (tileW * 0.5);
      maxY = (board.rows + board.cols) * (tileH * 0.5);
    }

    // Lề mở rộng cho vách đất bờ đảo và sóng vỗ ven bờ
    final padX = tileW * 1.5;
    final padY = tileH * 2.5;
    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    final sceneWidth = maxX - minX;
    final sceneHeight = maxY - minY;
    final originX = sceneWidth * 0.5 - ((maxX + minX) * 0.5);
    final originY = -minY + tileH * 0.5;

    // Depth sorting theo painter's algorithm: row + col
    final sortedTiles = List<IslandTileDto>.from(board.tiles)
      ..sort((a, b) {
        final depthA = a.row + a.col;
        final depthB = b.row + b.col;
        if (depthA != depthB) return depthA.compareTo(depthB);
        return a.row.compareTo(b.row);
      });

    // Tập hợp các tọa độ tồn tại tile để xác định mép đảo và liên kết đường đi
    final existingCoords = <(int, int)>{
      for (final t in board.tiles) (t.row, t.col),
    };

    // Tập hợp các tọa độ là đường đi / đất để vẽ mạng lưới đường làng liên tục
    final pathCoords = <(int, int)>{
      for (final t in board.tiles)
        if (t.terrainType == IslandTerrainType.path || t.terrainType == IslandTerrainType.dirt)
          (t.row, t.col),
    };

    return SizedBox(
      width: sceneWidth,
      height: sceneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // LỚP 1: Nước gợn sóng ven bờ & bóng đổ bờ đảo (Animated - không có hộp tối!)
          Positioned.fill(
            child: CustomPaint(
              painter: _OrganicWaterAndShorelinePainter(
                board: board,
                originX: originX,
                originY: originY,
                existingCoords: existingCoords,
                currentTier: currentTier,
                animationValue: waterAnimationValue,
              ),
            ),
          ),

          // LỚP 2: Mặt đất địa hình đảo (Tách riêng RepaintBoundary để tối ưu FPS)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HeritageIslandTerrainPainter(
                  board: board,
                  sortedTiles: sortedTiles,
                  existingCoords: existingCoords,
                  pathCoords: pathCoords,
                  currentTier: currentTier,
                  originX: originX,
                  originY: originY,
                  expansionProgress: expansionRevealProgress,
                  expandingFromTier: expandingFromTier,
                  expandingToTier: expandingToTier,
                  selectedCoord: selectedTileCoord,
                  selectedSlotId: selectedSlotId,
                  slotById: slotById,
                  slotByTileKey: slotByTileKey,
                ),
              ),
            ),
          ),

          // LỚP 3: Công trình di sản, tiểu cảnh tự nhiên và vị trí xây dựng
          for (final tile in sortedTiles)
            if (_isTileVisible(tile, currentTier, expansionRevealProgress, expandingFromTier, expandingToTier))
              _buildTileInteractiveObject(
                tile: tile,
                slotById: slotById,
                slotByTileKey: slotByTileKey,
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
    return true;
  }

  Widget _buildTileInteractiveObject({
    required IslandTileDto tile,
    required Map<String, IslandSlotDto> slotById,
    required Map<String, IslandSlotDto> slotByTileKey,
    required Map<(int, int), IslandSlotDto> slotByCoord,
    required double originX,
    required double originY,
    required double tileW,
    required double tileH,
  }) {
    final isoPos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
    final slot = slotByTileKey[tile.key] ??
        (tile.slotId != null ? slotById[tile.slotId] : null) ??
        slotByCoord[(tile.row, tile.col)];

    final isSelected = (slot != null && slot.slotId == selectedSlotId) ||
        (selectedTileCoord != null &&
            selectedTileCoord!.$1 == tile.row &&
            selectedTileCoord!.$2 == tile.col);

    final isLocked = tile.unlockTier > currentTier;

    // Kích thước chuẩn cho vùng đối tượng
    final objW = tileW * 1.25;
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
            // 1. Công trình di sản đã được người học đặt vào slot
            if (slot != null && slot.placement != null && !isLocked)
              IslandHeritageBuilding(
                placement: slot.placement!,
                isSelected: isSelected,
                tileWidth: tileW,
                tileHeight: tileH,
                onTap: () => onSlotTap(slot),
              )

            // 2. Ô xây dựng trống: Bệ đất tự nhiên với dấu cộng tinh tế (Không nút cam to!)
            else if (slot != null && !isLocked && tile.buildable)
              _buildSubtleBuildableSlotPlinth(
                slot: slot,
                tile: tile,
                isSelected: isSelected,
                tileW: tileW,
                tileH: tileH,
              )

            // 3. Tiểu cảnh tự nhiên mặc định (bụi tre, hồ sen, đèn đá, giếng cổ, hoa ban...)
            else if (!isLocked && IslandVisualAssetManager.hasSceneryVisual(tile))
              GestureDetector(
                onTap: () => onTileTap((tile.row, tile.col)),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: objW,
                  height: objH,
                  alignment: Alignment.bottomCenter,
                  padding: EdgeInsets.only(bottom: tileH * 0.15),
                  child: IslandVisualAssetManager.renderSceneryItem(
                    visualKey: tile.decorKey,
                    width: tileW * 0.95,
                    height: tileH * 2.0,
                  ),
                ),
              )

            // 4. Ô khóa: Phủ sương mỏng và icon khóa đồng nhỏ nhắn
            else if (isLocked)
              _buildAtmosphericLockedCue(
                tile: tile,
                isSelected: isSelected,
                tileW: tileW,
                tileH: tileH,
                slot: slot,
              )

            // 5. Tile đất/cỏ tự nhiên tương tác được
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

  /// Bệ đất xây dựng tinh tế hòa hợp với địa hình (Thay thế nút tròn cam thô)
  Widget _buildSubtleBuildableSlotPlinth({
    required IslandSlotDto slot,
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
  }) {
    return GestureDetector(
      onTap: () => onSlotTap(slot),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: tileW,
        height: tileH * 1.5,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: tileH * 0.12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Bệ đất mỏng có viền vàng đồng ấm
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: tileW * 0.65,
              height: tileH * 0.55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(tileW * 0.65, tileH * 0.55),
                ),
                gradient: RadialGradient(
                  colors: [
                    isSelected ? const Color(0xFFF5CD6A).withValues(alpha: 0.45) : const Color(0x33D4AF37),
                    isSelected ? const Color(0xFFD48B47).withValues(alpha: 0.25) : Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: isSelected ? DauVietColors.imperialGold : const Color(0x88D4AF37),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: DauVietColors.imperialGold.withValues(alpha: 0.50),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),

            // Dấu cộng thanh thoát nhỏ gọn ở giữa
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? DauVietColors.imperialGold : const Color(0xCCFFF8EC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFFB58C5E),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF6B4725),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tín hiệu ô khóa với sương mờ dịu và icon khóa đồng trang nhã
  Widget _buildAtmosphericLockedCue({
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
    IslandSlotDto? slot,
  }) {
    return GestureDetector(
      onTap: () {
        if (slot != null) {
          onSlotTap(slot);
        } else {
          onTileTap((tile.row, tile.col));
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: tileW,
        height: tileH * 1.4,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: tileH * 0.18),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xDD2D3748),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? DauVietColors.imperialGold : const Color(0x88CBD5E1),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 10,
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAINTER 1: NƯỚC XANH NGỌC & SÓNG VỖ BỜ ĐẢO HỮU CƠ (Không vẽ hộp tối)
// ---------------------------------------------------------------------------

class _OrganicWaterAndShorelinePainter extends CustomPainter {
  final IslandBoardDto board;
  final double originX;
  final double originY;
  final Set<(int, int)> existingCoords;
  final int currentTier;
  final double animationValue;

  _OrganicWaterAndShorelinePainter({
    required this.board,
    required this.originX,
    required this.originY,
    required this.existingCoords,
    required this.currentTier,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Bóng đổ tiếp xúc mềm mại (Ambient Contact Shadow) của đáy đảo lên nước
    final shadowPaint = Paint()
      ..color = const Color(0xFF1B4954).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (final tile in board.tiles) {
      if (tile.unlockTier <= currentTier) {
        final pos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
        final shadowRect = Rect.fromCenter(
          center: Offset(pos.dx, pos.dy + board.tileHeight * 0.95),
          width: board.tileWidth * 1.10,
          height: board.tileHeight * 0.65,
        );
        canvas.drawOval(shadowRect, shadowPaint);
      }
    }

    // 2. Sóng vỗ nhấp nhô ôm sát viền bờ đảo thật (Shoreline Foam Ripples)
    final waveCycle = animationValue * 2 * math.pi;
    final waveOffset = math.sin(waveCycle) * 2.2;
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.28 + math.sin(waveCycle) * 0.08).clamp(0.15, 0.40))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final halfW = board.tileWidth * 0.5;
    final halfH = board.tileHeight * 0.5;
    const cliffDepth = 20.0;

    for (final tile in board.tiles) {
      if (tile.unlockTier > currentTier) continue;

      final pos = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      final center = Offset(pos.dx, pos.dy);

      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));

      // Sóng chân bờ Tây Nam
      if (!hasSW) {
        final ripplePath = Path()
          ..moveTo(leftPt.dx - 2, leftPt.dy + cliffDepth + waveOffset)
          ..quadraticBezierTo(
            (leftPt.dx + bottomPt.dx) * 0.5,
            (leftPt.dy + bottomPt.dy) * 0.5 + cliffDepth + waveOffset + 1.5,
            bottomPt.dx,
            bottomPt.dy + cliffDepth + waveOffset,
          );
        canvas.drawPath(ripplePath, foamPaint);
      }

      // Sóng chân bờ Đông Nam
      if (!hasSE) {
        final ripplePath = Path()
          ..moveTo(bottomPt.dx, bottomPt.dy + cliffDepth + waveOffset)
          ..quadraticBezierTo(
            (bottomPt.dx + rightPt.dx) * 0.5,
            (bottomPt.dy + rightPt.dy) * 0.5 + cliffDepth + waveOffset + 1.5,
            rightPt.dx + 2,
            rightPt.dy + cliffDepth + waveOffset,
          );
        canvas.drawPath(ripplePath, foamPaint);
      }
    }

    // 3. Những điểm lấp lánh nhẹ nhàng của ánh nắng ban ngày trên mặt nước (Caustic Sparkles)
    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (int i = 0; i < 12; i++) {
      final sparklePhase = (waveCycle + i * 1.5) % (2 * math.pi);
      final alpha = (math.sin(sparklePhase) * 0.25).clamp(0.0, 0.35);
      if (alpha > 0.05) {
        final sparkX = originX + math.cos(i * 1.1) * (board.tileWidth * 3.5);
        final sparkY = originY + size.height * 0.38 + math.sin(i * 0.8) * (board.tileHeight * 2.5);
        canvas.drawCircle(Offset(sparkX, sparkY), 1.6, sparklePaint..color = Colors.white.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrganicWaterAndShorelinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentTier != currentTier;
  }
}

// ---------------------------------------------------------------------------
// PAINTER 2: MẶT ĐẤT ĐẢO DI SẢN, BỜ VÁCH ĐA TẦNG & ĐƯỜNG LÀNG LIỀN MẠCH
// ---------------------------------------------------------------------------

class _HeritageIslandTerrainPainter extends CustomPainter {
  final IslandBoardDto board;
  final List<IslandTileDto> sortedTiles;
  final Set<(int, int)> existingCoords;
  final Set<(int, int)> pathCoords;
  final int currentTier;
  final double originX;
  final double originY;
  final double expansionProgress;
  final int? expandingFromTier;
  final int? expandingToTier;
  final (int row, int col)? selectedCoord;
  final String? selectedSlotId;
  final Map<String, IslandSlotDto> slotById;
  final Map<String, IslandSlotDto> slotByTileKey;

  _HeritageIslandTerrainPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingCoords,
    required this.pathCoords,
    required this.currentTier,
    required this.originX,
    required this.originY,
    required this.expansionProgress,
    required this.expandingFromTier,
    required this.expandingToTier,
    required this.selectedCoord,
    required this.selectedSlotId,
    required this.slotById,
    required this.slotByTileKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = board.tileWidth * 0.5;
    final halfH = board.tileHeight * 0.5;
    const cliffDepth = 20.0; // Độ dày tự nhiên của bờ đảo

    // GIAI ĐOẠN 1: Vẽ các bờ vách 2.5D trước theo depth order
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

      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));

      // VÁCH TÂY NAM (Đón ánh sáng mặt trời từ hướng Tây Bắc): Màu đất ấm + cát chân bờ
      if (!hasSW) {
        _drawSouthWestCliff(canvas, leftPt, bottomPt, cliffDepth, tileAlpha, isLocked);
      }

      // VÁCH ĐÔNG NAM (Nằm ở góc khuất bóng): Màu đất sẫm hơn + phân tầng đá
      if (!hasSE) {
        _drawSouthEastCliff(canvas, bottomPt, rightPt, cliffDepth, tileAlpha, isLocked);
      }
    }

    // GIAI ĐOẠN 2: Vẽ mặt đất hình thoi của từng ô (Tự nhiên, không viền stroke thô)
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

      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final diamondPath = Path()
        ..moveTo(topPt.dx, topPt.dy)
        ..lineTo(rightPt.dx, rightPt.dy)
        ..lineTo(bottomPt.dx, bottomPt.dy)
        ..lineTo(leftPt.dx, leftPt.dy)
        ..close();

      // Lấy bảng màu sắc thái tự nhiên
      final palette = IslandVisualAssetManager.getTerrainPalette(
        tile.terrainType,
        row: tile.row,
        col: tile.col,
        isLocked: isLocked,
      );

      // Mặt đất chuyển sắc nhẹ từ ánh sáng rim phía trên xuống
      final diamondPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.highlight.withValues(alpha: tileAlpha),
            palette.base.withValues(alpha: tileAlpha),
          ],
        ).createShader(Rect.fromLTWH(center.dx - halfW, center.dy - halfH, board.tileWidth, board.tileHeight));

      canvas.drawPath(diamondPath, diamondPaint);

      // Đường viền mép trên đón sáng mềm (Rim lighting - không phải kẻ ô đen!)
      final rimLightPath = Path()
        ..moveTo(leftPt.dx, leftPt.dy)
        ..lineTo(topPt.dx, topPt.dy)
        ..lineTo(rightPt.dx, rightPt.dy);

      canvas.drawPath(
        rimLightPath,
        Paint()
          ..color = palette.rimLight.withValues(alpha: 0.35 * tileAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Texture tự nhiên đặc trưng (hoa dại, cỏ nhỏ, đá nứt, cát...)
      _drawMicroTexture(canvas, tile, center, halfW, halfH, tileAlpha);

      // Nối đường làng qua ô lân cận nếu đây là đường đi
      if (tile.terrainType == IslandTerrainType.path || tile.terrainType == IslandTerrainType.dirt) {
        _drawConnectedPath(canvas, tile, center, halfW, halfH, tileAlpha);
      }

      // Cỏ rủ nhẹ (Grass Frills) ở rìa bờ phía Nam
      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));
      if (!hasSW) {
        _drawOverhangingGrassTufts(canvas, leftPt, bottomPt, palette.highlight, tileAlpha);
      }
      if (!hasSE) {
        _drawOverhangingGrassTufts(canvas, bottomPt, rightPt, palette.highlight, tileAlpha);
      }

      // Viền sáng vàng hoàng gia khi tile được chọn
      final isTileSelected = (selectedCoord != null &&
              selectedCoord!.$1 == tile.row &&
              selectedCoord!.$2 == tile.col) ||
          (selectedSlotId != null &&
              (tile.slotId == selectedSlotId ||
                  slotByTileKey[tile.key]?.slotId == selectedSlotId));

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

  /// Vẽ vách bờ Tây Nam: 3 tầng tự nhiên (đất phù sa -> phiến đá cổ -> bãi cát chân bờ)
  void _drawSouthWestCliff(
    Canvas canvas,
    Offset leftPt,
    Offset bottomPt,
    double depth,
    double alpha,
    bool isLocked,
  ) {
    final soilColor = isLocked ? const Color(0xFF6B7A78) : const Color(0xFF9E754C);
    final stoneColor = isLocked ? const Color(0xFF556361) : const Color(0xFF755535);
    final sandBase = isLocked ? const Color(0xFF4A5553) : const Color(0xFFC7A76E);

    // Tầng 1: Đất phù sa mặt trên
    final topLayer = Path()
      ..moveTo(leftPt.dx, leftPt.dy)
      ..lineTo(bottomPt.dx, bottomPt.dy)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.45)
      ..lineTo(leftPt.dx, leftPt.dy + depth * 0.45)
      ..close();
    canvas.drawPath(topLayer, Paint()..color = soilColor.withValues(alpha: alpha));

    // Tầng 2: Vỉa đá trầm tích ở giữa
    final midLayer = Path()
      ..moveTo(leftPt.dx, leftPt.dy + depth * 0.45)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.45)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.80)
      ..lineTo(leftPt.dx, leftPt.dy + depth * 0.80)
      ..close();
    canvas.drawPath(midLayer, Paint()..color = stoneColor.withValues(alpha: alpha));

    // Tầng 3: Chân bờ cát tiếp giáp mặt nước
    final baseLayer = Path()
      ..moveTo(leftPt.dx, leftPt.dy + depth * 0.80)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.80)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth)
      ..lineTo(leftPt.dx, leftPt.dy + depth)
      ..close();
    canvas.drawPath(baseLayer, Paint()..color = sandBase.withValues(alpha: alpha));
  }

  /// Vẽ vách bờ Đông Nam: Khuất sáng, màu đất sẫm hơn, bóng đổ vách đá
  void _drawSouthEastCliff(
    Canvas canvas,
    Offset bottomPt,
    Offset rightPt,
    double depth,
    double alpha,
    bool isLocked,
  ) {
    final darkSoil = isLocked ? const Color(0xFF5A6664) : const Color(0xFF704D2E);
    final darkStone = isLocked ? const Color(0xFF475250) : const Color(0xFF53371E);
    final baseColor = isLocked ? const Color(0xFF384240) : const Color(0xFF3B2715);

    final topLayer = Path()
      ..moveTo(bottomPt.dx, bottomPt.dy)
      ..lineTo(rightPt.dx, rightPt.dy)
      ..lineTo(rightPt.dx, rightPt.dy + depth * 0.50)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.50)
      ..close();
    canvas.drawPath(topLayer, Paint()..color = darkSoil.withValues(alpha: alpha));

    final midLayer = Path()
      ..moveTo(bottomPt.dx, bottomPt.dy + depth * 0.50)
      ..lineTo(rightPt.dx, rightPt.dy + depth * 0.50)
      ..lineTo(rightPt.dx, rightPt.dy + depth * 0.85)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth * 0.85)
      ..close();
    canvas.drawPath(midLayer, Paint()..color = darkStone.withValues(alpha: alpha));

    final baseLayer = Path()
      ..moveTo(bottomPt.dx, bottomPt.dy + depth * 0.85)
      ..lineTo(rightPt.dx, rightPt.dy + depth * 0.85)
      ..lineTo(rightPt.dx, rightPt.dy + depth)
      ..lineTo(bottomPt.dx, bottomPt.dy + depth)
      ..close();
    canvas.drawPath(baseLayer, Paint()..color = baseColor.withValues(alpha: alpha));
  }

  /// Vẽ cỏ rủ nhẹ (Grass Frills) che phủ tự nhiên qua mép vách đá
  void _drawOverhangingGrassTufts(
    Canvas canvas,
    Offset startPt,
    Offset endPt,
    Color grassColor,
    double alpha,
  ) {
    final tuftPaint = Paint()..color = grassColor.withValues(alpha: 0.90 * alpha);
    const count = 4;
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final px = startPt.dx + (endPt.dx - startPt.dx) * t;
      final py = startPt.dy + (endPt.dy - startPt.dy) * t;
      canvas.drawCircle(Offset(px, py + 1.2), 1.8, tuftPaint);
    }
  }

  /// Texture vi mô: chấm hoa dại nhỏ, búi cỏ mềm, mạch đá rêu
  void _drawMicroTexture(
    Canvas canvas,
    IslandTileDto tile,
    Offset center,
    double halfW,
    double halfH,
    double alpha,
  ) {
    if (tile.terrainType == IslandTerrainType.grass) {
      final flowerPaint = Paint()..color = const Color(0xFFF7D173).withValues(alpha: 0.70 * alpha);
      final whiteFlower = Paint()..color = Colors.white.withValues(alpha: 0.65 * alpha);

      // Điểm xuyết hoa vàng/trắng nhỏ xinh tự nhiên rải thưa
      if ((tile.row * 5 + tile.col * 7) % 4 == 0) {
        canvas.drawCircle(Offset(center.dx - halfW * 0.22, center.dy - halfH * 0.10), 1.5, flowerPaint);
        canvas.drawCircle(Offset(center.dx + halfW * 0.28, center.dy + halfH * 0.15), 1.3, whiteFlower);
      }
      if ((tile.row * 3 + tile.col * 11) % 5 == 0) {
        canvas.drawCircle(Offset(center.dx + halfW * 0.05, center.dy - halfH * 0.25), 1.4, flowerPaint);
      }
    } else if (tile.terrainType == IslandTerrainType.dirt) {
      // Sỏi đá phù sa nhỏ
      final pebblePaint = Paint()..color = const Color(0xFF7E5C37).withValues(alpha: 0.45 * alpha);
      canvas.drawCircle(Offset(center.dx - halfW * 0.20, center.dy + halfH * 0.10), 1.2, pebblePaint);
      canvas.drawCircle(Offset(center.dx + halfW * 0.18, center.dy - halfH * 0.12), 1.0, pebblePaint);
    } else if (tile.terrainType == IslandTerrainType.stone) {
      // Rêu phong và mạch vân đá nứt tự nhiên
      final fissure = Paint()
        ..color = const Color(0xFF4A5852).withValues(alpha: 0.40 * alpha)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(center.dx - halfW * 0.28, center.dy - halfH * 0.15),
        Offset(center.dx + halfW * 0.15, center.dy + halfH * 0.20),
        fissure,
      );
    }
  }

  /// Nối đường làng qua ô lân cận để đường không bị đứt đoạn vô lý
  void _drawConnectedPath(
    Canvas canvas,
    IslandTileDto tile,
    Offset center,
    double halfW,
    double halfH,
    double alpha,
  ) {
    final pathPaint = Paint()
      ..color = const Color(0xFFC76F4B).withValues(alpha: 0.65 * alpha)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // Kiểm tra 4 hướng lân cận: (row-1, col), (row+1, col), (row, col-1), (row, col+1)
    if (pathCoords.contains((tile.row - 1, tile.col))) {
      canvas.drawLine(center, Offset(center.dx + halfW * 0.5, center.dy - halfH * 0.5), pathPaint);
    }
    if (pathCoords.contains((tile.row + 1, tile.col))) {
      canvas.drawLine(center, Offset(center.dx - halfW * 0.5, center.dy + halfH * 0.5), pathPaint);
    }
    if (pathCoords.contains((tile.row, tile.col - 1))) {
      canvas.drawLine(center, Offset(center.dx - halfW * 0.5, center.dy - halfH * 0.5), pathPaint);
    }
    if (pathCoords.contains((tile.row, tile.col + 1))) {
      canvas.drawLine(center, Offset(center.dx + halfW * 0.5, center.dy + halfH * 0.5), pathPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeritageIslandTerrainPainter oldDelegate) {
    return oldDelegate.currentTier != currentTier ||
        oldDelegate.expansionProgress != expansionProgress ||
        oldDelegate.selectedSlotId != selectedSlotId ||
        oldDelegate.selectedCoord != selectedCoord;
  }
}
