import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';
import 'island_visual_asset_manager.dart';

/// Renderer 2:1 Isometric Diorama Cao Cấp cho Đảo Di Sản (ISLAND-12).
/// Kết hợp hệ thống Sprite 2.5D minh họa thủ công (mặt đất, tiểu cảnh làng Việt,
/// nền móng đá cổ, công trình di sản) với vách bờ địa hình hữu cơ nhiều tầng,
/// mặt nước chuyển sắc từ nông ra sâu và hiệu ứng sương mờ vùng chưa mở khóa.
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
    final slotById = <String, IslandSlotDto>{
      for (final s in slots) s.slotId: s,
    };

    final slotByTileKey = <String, IslandSlotDto>{};
    for (final s in slots) {
      if (s.tileKey != null && s.tileKey!.isNotEmpty) {
        slotByTileKey[s.tileKey!] = s;
      }
    }

    final slotByCoord = <(int, int), IslandSlotDto>{};
    for (final s in slots) {
      if (s.tileRow != null && s.tileCol != null) {
        slotByCoord[(s.tileRow!, s.tileCol!)] = s;
      }
    }

    final tileW = board.tileWidth;
    final tileH = board.tileHeight;

    // Tính bounding-box thực tế của tập tile bao gồm cả chiều cao cây cối/công trình và bờ biển
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
      maxX = board.cols * (tileW * 0.5);
      maxY = (board.rows + board.cols) * (tileH * 0.5);
    }

    // Lề bao quanh cho tán cây cao ở đỉnh đảo, vách đá ngầm phía Nam và sóng vỗ ven bờ
    final padX = tileW * 1.45;
    final padTop = tileH * 2.85;
    final padBottom = tileH * 2.25;
    minX -= padX;
    maxX += padX;
    minY -= padTop;
    maxY += padBottom;

    final sceneWidth = maxX - minX;
    final sceneHeight = maxY - minY;
    final originX = sceneWidth * 0.5 - ((maxX + minX) * 0.5);
    final originY = -minY;

    // Depth sorting chuẩn isometric painter's algorithm: (row + col)
    final sortedTiles = List<IslandTileDto>.from(board.tiles)
      ..sort((a, b) {
        final depthA = a.row + a.col;
        final depthB = b.row + b.col;
        if (depthA != depthB) return depthA.compareTo(depthB);
        return a.row.compareTo(b.row);
      });

    final existingCoords = <(int, int)>{
      for (final t in board.tiles) (t.row, t.col),
    };

    return SizedBox(
      width: sceneWidth,
      height: sceneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // LỚP 1: Vùng nước nông ngọc bích quanh đảo, bóng đổ đại dương và bọt sóng vỗ bờ
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

          // LỚP 2: Vách bờ địa hình hữu cơ 2.5D + Mặt đất Sprite 2:1 (RepaintBoundary cố định)
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 2A: Vách đá/đất hữu cơ dưới rìa đảo và nền lót chống hở mạch
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HeritageIslandCliffAndUnderlayPainter(
                        board: board,
                        sortedTiles: sortedTiles,
                        existingCoords: existingCoords,
                        currentTier: currentTier,
                        originX: originX,
                        originY: originY,
                        expansionProgress: expansionRevealProgress,
                        expandingFromTier: expandingFromTier,
                        expandingToTier: expandingToTier,
                      ),
                    ),
                  ),

                  // 2B: Các Sprite mặt đất hình thoi 2:1 vẽ tay (Cỏ 3 biến thể, Sân gạch, Đường làng, Nền đá)
                  for (final tile in sortedTiles)
                    _buildTerrainTileSpriteWidget(
                      tile: tile,
                      originX: originX,
                      originY: originY,
                      tileW: tileW,
                      tileH: tileH,
                    ),

                  // 2C: Rìa cỏ rủ hữu cơ chờm qua mép vách đất & hiệu ứng viền chọn tile
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OrganicShoreOverhangAndSelectionPainter(
                        board: board,
                        sortedTiles: sortedTiles,
                        existingCoords: existingCoords,
                        currentTier: currentTier,
                        originX: originX,
                        originY: originY,
                        selectedCoord: selectedTileCoord,
                        selectedSlotId: selectedSlotId,
                        slotById: slotById,
                        slotByTileKey: slotByTileKey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LỚP 3: Tiểu cảnh làng Việt 2.5D, nền móng xây dựng, công trình di sản và sương mù vùng khóa
          for (final tile in sortedTiles)
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

  /// Tính độ mở (alpha) và trạng thái khóa của tile khi đang chạy animation mở rộng đảo.
  ({bool isLocked, double revealAlpha}) _resolveTileLockState(IslandTileDto tile) {
    final bool normallyLocked = tile.unlockTier > currentTier;
    final bool isBeingRevealed = expandingFromTier != null &&
        expandingToTier != null &&
        tile.unlockTier > expandingFromTier! &&
        tile.unlockTier <= expandingToTier!;

    if (isBeingRevealed) {
      return (
        isLocked: expansionRevealProgress < 0.45,
        revealAlpha: (0.45 + 0.55 * expansionRevealProgress).clamp(0.0, 1.0),
      );
    }
    return (isLocked: normallyLocked, revealAlpha: 1.0);
  }

  /// Render sprite mặt đất hình thoi 2:1 cho từng ô tile.
  Widget _buildTerrainTileSpriteWidget({
    required IslandTileDto tile,
    required double originX,
    required double originY,
    required double tileW,
    required double tileH,
  }) {
    final state = _resolveTileLockState(tile);
    final elevOffset = tile.elevation * 6.0;
    final rawCenter = board.toScreenOffset(
      tile.row,
      tile.col,
      originX: originX,
      originY: originY,
    );
    final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

    // Mở rộng nhẹ 6% để các cạnh hình thoi gối lên nhau mượt mà, triệt tiêu hoàn toàn khe hở
    final spriteW = tileW * 1.06;
    final spriteH = tileH * 1.06;
    final spritePath = IslandVisualAssetManager.resolveTerrainTileSprite(tile);

    Widget tileImage = Image.asset(
      spritePath,
      width: spriteW,
      height: spriteH,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );

    if (state.isLocked) {
      // Vùng đất chưa khám phá: phủ sắc xanh lam sương sớm dịu nhẹ, giữ nguyên chi tiết mặt đất
      tileImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.44, 0.26, 0.16, 0, 32,
          0.22, 0.48, 0.20, 0, 42,
          0.22, 0.30, 0.48, 0, 52,
          0,    0,    0,    0.88, 0,
        ]),
        child: tileImage,
      );
    }

    return Positioned(
      left: center.dx - spriteW * 0.5,
      top: center.dy - spriteH * 0.5,
      width: spriteW,
      height: spriteH,
      child: IgnorePointer(
        child: tileImage,
      ),
    );
  }

  /// Render đối tượng 2.5D trên từng tile theo thứ tự chiều sâu.
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
    final elevOffset = tile.elevation * 6.0;
    final rawPos = board.toScreenOffset(
      tile.row,
      tile.col,
      originX: originX,
      originY: originY,
    );
    final isoPos = Offset(rawPos.dx, rawPos.dy - elevOffset);

    final slot = slotByTileKey[tile.key] ??
        (tile.slotId != null ? slotById[tile.slotId] : null) ??
        slotByCoord[(tile.row, tile.col)];

    final isSelected = (slot != null && slot.slotId == selectedSlotId) ||
        (selectedTileCoord != null &&
            selectedTileCoord!.$1 == tile.row &&
            selectedTileCoord!.$2 == tile.col);

    final lockState = _resolveTileLockState(tile);
    final isLocked = lockState.isLocked;

    final objW = tileW * 1.38;
    final objH = tileH * 2.95;

    return Positioned(
      left: isoPos.dx - (objW * 0.5),
      top: isoPos.dy + (tileH * 0.5) - objH,
      width: objW,
      height: objH,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 1. Công trình di sản người học đã đặt trên đảo
          if (slot != null && slot.placement != null && !isLocked)
            IslandHeritageBuilding(
              placement: slot.placement!,
              isSelected: isSelected,
              tileWidth: tileW,
              tileHeight: tileH,
              onTap: () => onSlotTap(slot),
            )

          // 2. Ô đất xây dựng trống đã mở khóa: Nền móng đá & gỗ cổ tự nhiên
          else if (slot != null && !isLocked && tile.buildable)
            _buildSubtleBuildableSlotPlinth(
              slot: slot,
              tile: tile,
              isSelected: isSelected,
              tileW: tileW,
              tileH: tileH,
            )

          // 3. Tiểu cảnh làng Việt 2.5D (hiển thị cả khi mở khóa lẫn trong làn sương vùng khóa)
          else if (IslandVisualAssetManager.hasSceneryVisual(tile))
            GestureDetector(
              onTap: () => slot != null ? onSlotTap(slot) : onTileTap((tile.row, tile.col)),
              behavior: HitTestBehavior.translucent,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  IslandVisualAssetManager.renderSceneryItem(
                    visualKey: tile.decorKey,
                    tileWidth: tileW,
                    tileHeight: tileH,
                    row: tile.row,
                    col: tile.col,
                    isLocked: isLocked,
                  ),
                  if (isLocked)
                    Positioned(
                      bottom: 0,
                      child: _buildMistyFogVeil(tileW: tileW, tileH: tileH),
                    ),
                ],
              ),
            )

          // 4. Vùng đất chưa mở khóa (chỉ hiện biểu tượng khóa nhỏ trên ô có slot xây dựng)
          else if (isLocked)
            _buildAtmosphericLockedCue(
              tile: tile,
              isSelected: isSelected,
              tileW: tileW,
              tileH: tileH,
              slot: slot,
            )

          // 5. Ô mặt đất mở khóa bình thường (cỏ, đường gạch, sân đình)
          else
            GestureDetector(
              onTap: () => onTileTap((tile.row, tile.col)),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: tileW * 0.92,
                height: tileH * 0.92,
              ),
            ),
        ],
      ),
    );
  }

  /// Nền móng xây dựng bằng đá xanh & gỗ lim vẽ tay hòa vào mặt cỏ (thay nút cộng cam/trắng lặp lại).
  Widget _buildSubtleBuildableSlotPlinth({
    required IslandSlotDto slot,
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
  }) {
    final plinthW = tileW * 0.88;
    final plinthH = tileH * 0.96;

    return GestureDetector(
      onTap: () => onSlotTap(slot),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: tileW,
        height: tileH * 1.35,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Hào quang vàng kim dịu nhẹ khi người chơi chạm chọn
            if (isSelected)
              Positioned(
                bottom: tileH * 0.04,
                child: Container(
                  width: tileW * 0.86,
                  height: tileH * 0.68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(tileW * 0.86, tileH * 0.68),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(alpha: 0.65),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

            // Sprite nền móng đá chạm hoa sen nằm êm trên mặt đất
            Positioned(
              bottom: tileH * 0.03,
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.92,
                child: Image.asset(
                  IslandVisualAssetManager.buildableParcelPlinth,
                  width: plinthW,
                  height: plinthH,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),

            // Điểm đánh dấu vị trí đặt công trình siêu nhỏ gọn và trang nhã
            Positioned(
              bottom: tileH * 0.36,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 20 : 15,
                height: isSelected ? 20 : 15,
                decoration: BoxDecoration(
                  color: isSelected
                      ? DauVietColors.imperialGold
                      : const Color(0xCCFFF8EC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF5D3A1A)
                        : const Color(0xAA8D6E4C),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: isSelected ? 13 : 10,
                  color: const Color(0xFF4E3622),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lớp sương mù mờ ảo phủ nhẹ lên tiểu cảnh vùng chưa khám phá
  Widget _buildMistyFogVeil({required double tileW, required double tileH}) {
    return IgnorePointer(
      child: Container(
        width: tileW * 0.95,
        height: tileH * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.elliptical(tileW * 0.95, tileH * 0.85),
          ),
          gradient: RadialGradient(
            colors: [
              const Color(0xFFE4F0F2).withValues(alpha: 0.36),
              const Color(0xFFB5CDD1).withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// Vùng đất chưa mở khóa: Sương mù mờ ảo, chỉ hiện khóa nhỏ trên các ô có slot xây dựng.
  Widget _buildAtmosphericLockedCue({
    required IslandTileDto tile,
    required bool isSelected,
    required double tileW,
    required double tileH,
    IslandSlotDto? slot,
  }) {
    final bool hasBuildableSlot = slot != null;

    return GestureDetector(
      onTap: () {
        if (slot != null) {
          onSlotTap(slot);
        } else {
          onTileTap((tile.row, tile.col));
        }
      },
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: tileW,
        height: tileH * 1.15,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Lớp sương mù bồng bềnh nhẹ
            Positioned(
              bottom: tileH * 0.06,
              child: _buildMistyFogVeil(tileW: tileW, tileH: tileH),
            ),

            // Chỉ hiển thị biểu tượng ổ khóa nhỏ gọn trên ô thực sự là vị trí xây dựng hoặc đang được chạm
            if (hasBuildableSlot || isSelected)
              Positioned(
                bottom: tileH * 0.28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xB82A3B3E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? DauVietColors.imperialGold
                          : const Color(0x88CFD8DC),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 10,
                        color: isSelected
                            ? DauVietColors.imperialGold
                            : const Color(0xFFECEFF1),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Cấp ${tile.unlockTier}',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? DauVietColors.imperialGold
                              : const Color(0xFFECEFF1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LỚP 1: PAINTER NƯỚC BIỂN NÔNG - SÂU, BÓNG ĐẢO VÀ SÓNG VỖ BỜ HỮU CƠ
// =============================================================================
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
    final tileW = board.tileWidth;
    final tileH = board.tileHeight;
    final halfW = tileW * 0.5;
    final halfH = tileH * 0.5;
    final phase = animationValue * 2 * math.pi;

    // 1. Vùng nước nông xanh ngọc bích tỏa ra quanh chân đảo (Shallow-to-deep lagoon transition)
    final shallowLagoonPaint = Paint()
      ..color = const Color(0xFF8BE2E8).withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    final midLagoonPaint = Paint()
      ..color = const Color(0xFF6AD0DA).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    // 2. Bóng đổ mềm mại của khối đảo xuống mặt biển phía Nam
    final deepShadowPaint = Paint()
      ..color = const Color(0xFF103B45).withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    for (final tile in board.tiles) {
      final center = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + tileH * 0.15),
          width: tileW * 1.95,
          height: tileH * 1.75,
        ),
        shallowLagoonPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + tileH * 0.20),
          width: tileW * 1.35,
          height: tileH * 1.15,
        ),
        midLagoonPaint,
      );
    }

    for (final tile in board.tiles) {
      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));
      if (!hasSW || !hasSE) {
        final center = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + tileH * 0.82),
            width: tileW * 1.18,
            height: tileH * 0.85,
          ),
          deepShadowPaint,
        );
      }
    }

    // 3. Bọt sóng trắng mềm mại ôm sát chân vách đá và gợn sóng lan nhẹ
    for (final tile in board.tiles) {
      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));
      final hasNW = existingCoords.contains((tile.row - 1, tile.col));
      final hasNE = existingCoords.contains((tile.row, tile.col - 1));

      if (hasSW && hasSE && hasNW && hasNE) continue;

      final center = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      final localWave = math.sin(phase + (tile.row * 0.8 + tile.col * 1.1));
      final rippleShift = 2.5 + localWave * 2.2;

      final foamRibbonPaint = Paint()
        ..color = Colors.white.withValues(alpha: (0.48 - localWave * 0.12).clamp(0.22, 0.62))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      final outerRipplePaint = Paint()
        ..color = const Color(0xFFD8FAFC).withValues(alpha: (0.28 + localWave * 0.10).clamp(0.12, 0.42))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      final cliffBaseDrop = tileH * 0.46;

      if (!hasSW) {
        final p1 = Offset(center.dx - halfW * 0.92, center.dy + cliffBaseDrop * 0.88 + rippleShift);
        final p2 = Offset(center.dx - halfW * 0.05, center.dy + halfH + cliffBaseDrop + rippleShift);
        final ctrl = Offset(
          (p1.dx + p2.dx) * 0.5 - 4.0,
          (p1.dy + p2.dy) * 0.5 + 3.5,
        );
        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
        canvas.drawPath(path, foamRibbonPaint);

        final outerPath = Path()
          ..moveTo(p1.dx - 5, p1.dy + 6)
          ..quadraticBezierTo(ctrl.dx - 6, ctrl.dy + 7, p2.dx - 4, p2.dy + 6);
        canvas.drawPath(outerPath, outerRipplePaint);
      }

      if (!hasSE) {
        final p1 = Offset(center.dx + halfW * 0.05, center.dy + halfH + cliffBaseDrop + rippleShift);
        final p2 = Offset(center.dx + halfW * 0.92, center.dy + cliffBaseDrop * 0.88 + rippleShift);
        final ctrl = Offset(
          (p1.dx + p2.dx) * 0.5 + 4.0,
          (p1.dy + p2.dy) * 0.5 + 3.5,
        );
        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
        canvas.drawPath(path, foamRibbonPaint);

        final outerPath = Path()
          ..moveTo(p1.dx + 4, p1.dy + 6)
          ..quadraticBezierTo(ctrl.dx + 6, ctrl.dy + 7, p2.dx + 5, p2.dy + 6);
        canvas.drawPath(outerPath, outerRipplePaint);
      }

      if (!hasNW) {
        final p1 = Offset(center.dx - halfW * 0.85, center.dy - rippleShift * 0.5);
        final p2 = Offset(center.dx - halfW * 0.10, center.dy - halfH - rippleShift * 0.5);
        canvas.drawLine(p1, p2, outerRipplePaint);
      }

      if (!hasNE) {
        final p1 = Offset(center.dx + halfW * 0.10, center.dy - halfH - rippleShift * 0.5);
        final p2 = Offset(center.dx + halfW * 0.85, center.dy - rippleShift * 0.5);
        canvas.drawLine(p1, p2, outerRipplePaint);
      }
    }

    // 4. Ánh nắng lấp lánh rất nhẹ trên mặt biển (Sunlit water caustics)
    final sparklePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 14; i++) {
      final angle = i * 1.65 + 0.4;
      final dist = tileW * (2.6 + (i % 3) * 0.85);
      final sx = size.width * 0.5 + math.cos(angle) * dist * 1.15;
      final sy = size.height * 0.52 + math.sin(angle) * dist * 0.58;
      final twinkle = (math.sin(phase + i * 1.4) + 1.0) * 0.5;

      if (twinkle > 0.35) {
        sparklePaint.color = const Color(0xFFFFF9D2).withValues(alpha: (twinkle - 0.35) * 0.55);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(sx, sy), width: 6.0 * twinkle, height: 2.2 * twinkle),
          sparklePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrganicWaterAndShorelinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentTier != currentTier ||
        oldDelegate.board != board;
  }
}

// =============================================================================
// LỚP 2A: PAINTER VÁCH ĐẤT ĐÁ HỮU CƠ 2.5D & NỀN LÓT ĐỊA HÌNH
// =============================================================================
class _HeritageIslandCliffAndUnderlayPainter extends CustomPainter {
  final IslandBoardDto board;
  final List<IslandTileDto> sortedTiles;
  final Set<(int, int)> existingCoords;
  final int currentTier;
  final double originX;
  final double originY;
  final double expansionProgress;
  final int? expandingFromTier;
  final int? expandingToTier;

  _HeritageIslandCliffAndUnderlayPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingCoords,
    required this.currentTier,
    required this.originX,
    required this.originY,
    required this.expansionProgress,
    this.expandingFromTier,
    this.expandingToTier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = board.tileWidth;
    final tileH = board.tileHeight;
    final halfW = tileW * 0.5;
    final halfH = tileH * 0.5;
    final baseCliffDepth = tileH * 0.44;

    for (final tile in sortedTiles) {
      final bool isLocked = tile.unlockTier > currentTier;
      final elevOffset = tile.elevation * 6.0;
      final rawCenter = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));

      final cliffH = baseCliffDepth + elevOffset;

      // Vách bờ Tây-Nam (Đón nắng chiều ấm áp, phân tầng đất phù sa + đá tảng + bãi cát)
      if (!hasSW) {
        _drawOrganicCliffEdge(
          canvas: canvas,
          pStart: leftPt,
          pEnd: bottomPt,
          cliffDepth: cliffH,
          seed: tile.row * 17 + tile.col * 31,
          isSunlit: true,
          isLocked: isLocked,
        );
      }

      // Vách bờ Đông-Nam (Khuất bóng râm mát, đất nâu trầm + đá rêu ven nước)
      if (!hasSE) {
        _drawOrganicCliffEdge(
          canvas: canvas,
          pStart: bottomPt,
          pEnd: rightPt,
          cliffDepth: cliffH,
          seed: tile.row * 23 + tile.col * 41,
          isSunlit: false,
          isLocked: isLocked,
        );
      }

      // Mặt lót hình thoi dưới cùng để triệt tiêu mọi khe sáng giữa các tile
      final palette = IslandVisualAssetManager.getTerrainPalette(
        tile.terrainType,
        row: tile.row,
        col: tile.col,
        isLocked: isLocked,
      );
      final underlayDiamond = Path()
        ..moveTo(topPt.dx, topPt.dy - 1.0)
        ..lineTo(rightPt.dx + 1.5, rightPt.dy)
        ..lineTo(bottomPt.dx, bottomPt.dy + 1.0)
        ..lineTo(leftPt.dx - 1.5, leftPt.dy)
        ..close();
      canvas.drawPath(underlayDiamond, Paint()..color = palette.base);
    }
  }

  /// Vẽ vách đất bờ đảo có đường viền lồi lõm tự nhiên, phân tầng địa chất và đá cuội ven bờ.
  void _drawOrganicCliffEdge({
    required Canvas canvas,
    required Offset pStart,
    required Offset pEnd,
    required double cliffDepth,
    required int seed,
    required bool isSunlit,
    required bool isLocked,
  }) {
    final s1 = math.sin(seed * 1.3) * 3.2;
    final s2 = math.cos(seed * 2.1) * 3.8;
    final s3 = math.sin(seed * 3.7) * 2.8;

    final p25 = Offset.lerp(pStart, pEnd, 0.25)!;
    final p50 = Offset.lerp(pStart, pEnd, 0.50)!;
    final p75 = Offset.lerp(pStart, pEnd, 0.75)!;

    final bStart = Offset(pStart.dx, pStart.dy + cliffDepth * 0.92);
    final b25 = Offset(p25.dx + (isSunlit ? -2.0 : 2.0), p25.dy + cliffDepth + s1);
    final b50 = Offset(p50.dx, p50.dy + cliffDepth * 1.06 + s2);
    final b75 = Offset(p75.dx + (isSunlit ? -1.5 : 1.5), p75.dy + cliffDepth + s3);
    final bEnd = Offset(pEnd.dx, pEnd.dy + cliffDepth * 0.96);

    // 1. Dải cát & đá cuội ngầm sát mặt nước (Shoreline Sand & Pebble Shelf)
    final sandPath = Path()
      ..moveTo(bStart.dx, bStart.dy - 3)
      ..lineTo(b25.dx, b25.dy + 3.5)
      ..lineTo(b50.dx, b50.dy + 4.5)
      ..lineTo(b75.dx, b75.dy + 3.5)
      ..lineTo(bEnd.dx, bEnd.dy + 2.0)
      ..lineTo(bEnd.dx, bEnd.dy - 4)
      ..lineTo(bStart.dx, bStart.dy - 4)
      ..close();

    final sandColor = isLocked
        ? (isSunlit ? const Color(0xFF637574) : const Color(0xFF4F605F))
        : (isSunlit ? const Color(0xFFD9C082) : const Color(0xFFB59B62));
    canvas.drawPath(sandPath, Paint()..color = sandColor);

    // 2. Thân vách đất/đá chính (Multi-toned Stratified Earth Wall)
    final wallPath = Path()
      ..moveTo(pStart.dx, pStart.dy)
      ..lineTo(pEnd.dx, pEnd.dy)
      ..lineTo(bEnd.dx, bEnd.dy)
      ..lineTo(b75.dx, b75.dy)
      ..lineTo(b50.dx, b50.dy)
      ..lineTo(b25.dx, b25.dy)
      ..lineTo(bStart.dx, bStart.dy)
      ..close();

    final topEarth = isLocked
        ? (isSunlit ? const Color(0xFF5D706E) : const Color(0xFF4B5C5A))
        : (isSunlit ? const Color(0xFF9C6C43) : const Color(0xFF754E2E));
    final midEarth = isLocked
        ? (isSunlit ? const Color(0xFF4E605E) : const Color(0xFF3E4D4B))
        : (isSunlit ? const Color(0xFF815633) : const Color(0xFF5C3C22));
    final deepRock = isLocked
        ? const Color(0xFF344241)
        : (isSunlit ? const Color(0xFF5D3E25) : const Color(0xFF422B18));

    final wallRect = wallPath.getBounds();
    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topEarth, midEarth, deepRock],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(wallRect);
    canvas.drawPath(wallPath, wallPaint);

    // 3. Đường vân địa chất & tảng đá ven bờ tạo cảm giác mô hình thủ công
    final creasePaint = Paint()
      ..color = const Color(0xFF3A2414).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset.lerp(p25, b25, 0.18)!,
      Offset.lerp(p50, b50, 0.72)!,
      creasePaint,
    );

    if (seed % 2 == 0) {
      final rockCenter = Offset.lerp(b50, b75, 0.45)!;
      final rockW = 10.0 + (seed % 4) * 2.0;
      final rockH = 5.5 + (seed % 3) * 1.2;
      canvas.drawOval(
        Rect.fromCenter(center: rockCenter, width: rockW, height: rockH),
        Paint()
          ..color = isLocked
              ? const Color(0xFF546664)
              : (isSunlit ? const Color(0xFF7B857D) : const Color(0xFF5C665E)),
      );
    }

    // Viền tối mảnh khép dáng vách bờ
    canvas.drawPath(
      wallPath,
      Paint()
        ..color = const Color(0xFF3B2818).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HeritageIslandCliffAndUnderlayPainter oldDelegate) {
    return oldDelegate.currentTier != currentTier ||
        oldDelegate.expansionProgress != expansionProgress ||
        oldDelegate.board != board;
  }
}

// =============================================================================
// LỚP 2C: PAINTER RÌA CỎ RỦ HỮU CƠ QUA MÉP ĐẢO & VIỀN CHỌN TILE
// =============================================================================
class _OrganicShoreOverhangAndSelectionPainter extends CustomPainter {
  final IslandBoardDto board;
  final List<IslandTileDto> sortedTiles;
  final Set<(int, int)> existingCoords;
  final int currentTier;
  final double originX;
  final double originY;
  final (int row, int col)? selectedCoord;
  final String? selectedSlotId;
  final Map<String, IslandSlotDto> slotById;
  final Map<String, IslandSlotDto> slotByTileKey;

  _OrganicShoreOverhangAndSelectionPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingCoords,
    required this.currentTier,
    required this.originX,
    required this.originY,
    this.selectedCoord,
    this.selectedSlotId,
    required this.slotById,
    required this.slotByTileKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = board.tileWidth;
    final tileH = board.tileHeight;
    final halfW = tileW * 0.5;
    final halfH = tileH * 0.5;

    for (final tile in sortedTiles) {
      final isLocked = tile.unlockTier > currentTier;
      final elevOffset = tile.elevation * 6.0;
      final rawCenter = board.toScreenOffset(tile.row, tile.col, originX: originX, originY: originY);
      final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingCoords.contains((tile.row + 1, tile.col));
      final hasSE = existingCoords.contains((tile.row, tile.col + 1));

      final overhangLight = isLocked ? const Color(0xFF69807E) : const Color(0xFF83B153);
      final overhangDark = isLocked ? const Color(0xFF536967) : const Color(0xFF618B38);

      if (!hasSW) {
        _drawGrassOverhangFringe(canvas, leftPt, bottomPt, overhangLight, overhangDark);
      }
      if (!hasSE) {
        _drawGrassOverhangFringe(canvas, bottomPt, rightPt, overhangDark, overhangDark);
      }

      // Kiểm tra trạng thái đang được chạm chọn
      final linkedSlot = slotByTileKey[tile.key] ??
          (tile.slotId != null ? slotById[tile.slotId] : null);
      final isSelected = (selectedCoord != null &&
              selectedCoord!.$1 == tile.row &&
              selectedCoord!.$2 == tile.col) ||
          (selectedSlotId != null &&
              (tile.slotId == selectedSlotId || linkedSlot?.slotId == selectedSlotId));

      if (isSelected) {
        final diamond = Path()
          ..moveTo(topPt.dx, topPt.dy)
          ..lineTo(rightPt.dx, rightPt.dy)
          ..lineTo(bottomPt.dx, bottomPt.dy)
          ..lineTo(leftPt.dx, leftPt.dy)
          ..close();

        canvas.drawPath(
          diamond,
          Paint()
            ..color = DauVietColors.imperialGold.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xFFFFF3C4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  /// Vẽ dải cỏ rủ mềm mại uốn lượn qua mép vách đất để xóa bỏ cạnh thẳng cứng nhắc.
  void _drawGrassOverhangFringe(
    Canvas canvas,
    Offset start,
    Offset end,
    Color fillColor,
    Color strokeColor,
  ) {
    final path = Path()..moveTo(start.dx, start.dy - 1.0);
    const segments = 6;
    for (int i = 1; i <= segments; i++) {
      final tMid = (i - 0.5) / segments;
      final tEnd = i / segments;
      final mid = Offset.lerp(start, end, tMid)!;
      final pt = Offset.lerp(start, end, tEnd)!;
      final droop = 4.2 + (i % 2) * 2.2;
      path.quadraticBezierTo(mid.dx, mid.dy + droop, pt.dx, pt.dy + 1.0);
    }
    path.lineTo(start.dx, start.dy - 1.0);
    path.close();

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicShoreOverhangAndSelectionPainter oldDelegate) {
    return oldDelegate.selectedCoord != selectedCoord ||
        oldDelegate.selectedSlotId != selectedSlotId ||
        oldDelegate.currentTier != currentTier;
  }
}
