import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';
import 'island_visual_asset_manager.dart';

/// Renderer 2:1 Isometric Diorama Cao Cấp cho Đảo Di Sản (ISLAND-12 / 10A / 10B).
/// Hỗ trợ:
/// - 4 góc nhìn Isometric cố định (`IslandCameraDirection`: Đông Bắc, Đông Nam, Tây Nam, Tây Bắc)
///   với thứ tự vẽ chiều sâu Painter's Algorithm, vách đá bờ biển và Hit Testing chính xác ở mọi góc.
/// - Hệ thống Autotiling Đường Gạch & Quảng Trường Làng Việt (`resolveAutotiledTerrainSprite`)
///   tự động nối liền mạch các đoạn thẳng, khúc cua, ngã ba, ngã tư, đầu đường và sân đình.
class IslandIsometricRenderer extends StatelessWidget {
  final IslandBoardDto board;
  final List<IslandSlotDto> slots;
  final int currentTier;
  final String? selectedSlotId;
  final (int row, int col)? selectedTileCoord;
  final ValueChanged<(int row, int col)> onTileTap;
  final ValueChanged<IslandSlotDto> onSlotTap;
  final IslandCameraDirection cameraDirection;
  final double waterAnimationValue;
  final double expansionRevealProgress;
  final int? expandingFromTier;
  final int? expandingToTier;
  final bool isEditMode;
  final Set<String> flippedSlotIds;
  final IslandPlacementDto? previewPlacement;
  final bool previewFlipHorizontally;
  final VoidCallback? onCancelPreviewPlacement;
  final VoidCallback? onRotatePreviewPlacement;
  final VoidCallback? onConfirmPreviewPlacement;

  const IslandIsometricRenderer({
    super.key,
    required this.board,
    required this.slots,
    required this.currentTier,
    required this.onTileTap,
    required this.onSlotTap,
    this.selectedSlotId,
    this.selectedTileCoord,
    this.cameraDirection = IslandCameraDirection.northEast,
    this.waterAnimationValue = 0.0,
    this.expansionRevealProgress = 1.0,
    this.expandingFromTier,
    this.expandingToTier,
    this.isEditMode = false,
    this.flippedSlotIds = const {},
    this.previewPlacement,
    this.previewFlipHorizontally = false,
    this.onCancelPreviewPlacement,
    this.onRotatePreviewPlacement,
    this.onConfirmPreviewPlacement,
  });
  /// Chuyển tọa độ logic (row, col) của tile sang tọa độ màn hình theo góc nhìn `cameraDirection`.
  Offset _tileToScreenOffset(
    int row,
    int col, {
    required double originX,
    required double originY,
  }) {
    final (vRow, vCol) = cameraDirection.toViewCoord(
      row,
      col,
      rows: board.rows,
      cols: board.cols,
    );
    return board.toScreenOffset(
      vRow,
      vCol,
      originX: originX,
      originY: originY,
    );
  }

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

    // Bản đồ tra cứu tile theo tọa độ logic (row, col) phục vụ Autotiling đường gạch
    final tileMap = <(int, int), IslandTileDto>{};
    for (final t in board.tiles) {
      final linkedSlot = slotByTileKey[t.key] ??
          (t.slotId != null ? slotById[t.slotId] : null) ??
          slotByCoord[(t.row, t.col)];
      tileMap[(t.row, t.col)] = (linkedSlot != null && (t.slotId == null || t.slotId!.isEmpty))
          ? t.copyWith(slotId: linkedSlot.slotId)
          : t;
    }

    final tileW = board.tileWidth;
    final tileH = board.tileHeight;

    // Tính bounding-box thực tế của tập tile theo góc nhìn hiện tại
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    if (board.tiles.isNotEmpty) {
      minX = double.infinity;
      maxX = -double.infinity;
      minY = double.infinity;
      maxY = -double.infinity;
      for (final t in board.tiles) {
        final (vRow, vCol) = cameraDirection.toViewCoord(
          t.row,
          t.col,
          rows: board.rows,
          cols: board.cols,
        );
        final x = (vCol - vRow) * (tileW * 0.5);
        final y = (vCol + vRow) * (tileH * 0.5);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    } else {
      maxX = board.cols * (tileW * 0.5);
      maxY = (board.rows + board.cols) * (tileH * 0.5);
    }

    final padX = tileW * 1.05;
    final padTop = tileH * 2.35;
    final padBottom = tileH * 1.95;
    minX -= padX;
    maxX += padX;
    minY -= padTop;
    maxY += padBottom;
    final sceneWidth = maxX - minX;
    final sceneHeight = maxY - minY;
    final originX = sceneWidth * 0.5 - ((maxX + minX) * 0.5);
    final originY = -minY;

    // Depth sorting chuẩn isometric painter's algorithm theo tọa độ góc nhìn (vRow + vCol)
    final sortedTiles = List<IslandTileDto>.from(board.tiles)
      ..sort((a, b) {
        final (vRowA, vColA) = cameraDirection.toViewCoord(
          a.row,
          a.col,
          rows: board.rows,
          cols: board.cols,
        );
        final (vRowB, vColB) = cameraDirection.toViewCoord(
          b.row,
          b.col,
          rows: board.rows,
          cols: board.cols,
        );
        final depthA = vRowA + vColA;
        final depthB = vRowB + vColB;
        if (depthA != depthB) return depthA.compareTo(depthB);
        return vRowA.compareTo(vRowB);
      });

    // Tập tọa độ trong không gian góc nhìn (vRow, vCol) để xác định cạnh bờ đá hướng về camera
    final existingViewCoords = <(int, int)>{
      for (final t in board.tiles)
        cameraDirection.toViewCoord(
          t.row,
          t.col,
          rows: board.rows,
          cols: board.cols,
        ),
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
                existingViewCoords: existingViewCoords,
                cameraDirection: cameraDirection,
                currentTier: currentTier,
                animationValue: waterAnimationValue,
              ),
            ),
          ),

          // LỚP 2: Vách bờ địa hình hữu cơ 2.5D + Mặt đất & Đường gạch Autotile Sprite 2:1
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
                        existingViewCoords: existingViewCoords,
                        cameraDirection: cameraDirection,
                        currentTier: currentTier,
                        originX: originX,
                        originY: originY,
                        expansionProgress: expansionRevealProgress,
                        expandingFromTier: expandingFromTier,
                        expandingToTier: expandingToTier,
                      ),
                    ),
                  ),

                  // 2B: Các Sprite mặt đất & đường gạch hình thoi 2:1 được Autotile liền mạch
                  for (final tile in sortedTiles)
                    _buildTerrainTileSpriteWidget(
                      tile: tileMap[(tile.row, tile.col)] ?? tile,
                      tileMap: tileMap,
                      originX: originX,
                      originY: originY,
                      tileW: tileW,
                      tileH: tileH,
                    ),

                  // 2C: Rìa cỏ rủ hữu cơ chờm qua mép vách đất & hiệu ứng viền chọn tile
                  // 2C: Rìa cỏ rủ hữu cơ, lưới ô isometric sáng & đế xanh lá preview 2x2/1x1
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OrganicShoreOverhangAndSelectionPainter(
                        board: board,
                        sortedTiles: sortedTiles,
                        existingViewCoords: existingViewCoords,
                        cameraDirection: cameraDirection,
                        currentTier: currentTier,
                        originX: originX,
                        originY: originY,
                        selectedCoord: selectedTileCoord,
                        selectedSlotId: selectedSlotId,
                        slotById: slotById,
                        slotByTileKey: slotByTileKey,
                        isEditMode: isEditMode,
                        previewPlacement: previewPlacement,
                      ),
                    ),
                  ),

                  // 2D: Quần thể cổ thụ, rặng dừa/tre ở đỉnh đảo & thuyền gỗ neo đậu tại cầu tàu (Issue #50 AC-1)
                  ..._buildDioramaPerimeterLandmarks(
                    sortedTiles: sortedTiles,
                    originX: originX,
                    originY: originY,
                    tileW: tileW,
                    tileH: tileH,
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

  /// Render sprite mặt đất / đường gạch hình thoi 2:1 đã được Autotile cho từng ô tile.
  Widget _buildTerrainTileSpriteWidget({
    required IslandTileDto tile,
    required Map<(int, int), IslandTileDto> tileMap,
    required double originX,
    required double originY,
    required double tileW,
    required double tileH,
  }) {
    final state = _resolveTileLockState(tile);
    final elevOffset = tile.elevation * 6.0;
    final rawCenter = _tileToScreenOffset(
      tile.row,
      tile.col,
      originX: originX,
      originY: originY,
    );
    final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

    // Mặt phẳng đảo liền mạch theo phong cách 2.5D Illustrated Diorama (Issue #50 AC-1):
    // kết hợp nền thảo nguyên ấm áp với độ mờ nhẹ để không tạo đốm tối rời rạc giữa các ô
    final spriteW = tileW * 1.06;
    final spriteH = tileH * 1.06;
    final spritePath = IslandVisualAssetManager.resolveAutotiledTerrainSprite(
      tile: tile,
      tileMap: tileMap,
      cameraDirection: cameraDirection,
    );

    Widget tileImage = Opacity(
      opacity: tile.terrainType == IslandTerrainType.grass ? 0.42 : 0.78,
      child: Image.asset(
        spritePath,
        width: spriteW,
        height: spriteH,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );
    if (state.isLocked) {
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

  /// Render đối tượng 2.5D trên từng tile theo thứ tự chiều sâu của góc nhìn hiện tại.
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
    final rawPos = _tileToScreenOffset(
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

    final bool isPreviewAnchorSlot =
        previewPlacement != null &&
        slot != null &&
        slot.slotId == selectedSlotId &&
        !isLocked;

    final Widget tileStack = Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // 0. Preview đặt vật phẩm trực tiếp trên lưới kèm 3 nút tròn ✕ / ↻ / ✓ (Màn 2 — Issue #50 AC-3)
        if (isPreviewAnchorSlot)
          _buildPlacementPreviewWithInlineControls(
            slot: slot,
            placement: previewPlacement!,
            tileW: tileW,
            tileH: tileH,
          )

        // 1. Công trình di sản người học đã đặt trên đảo
        else if (slot != null && slot.placement != null && !isLocked)
          IslandHeritageBuilding(
            placement: slot.placement!,
            isSelected: isSelected,
            tileWidth: tileW,
            tileHeight: tileH,
            flipHorizontally: flippedSlotIds.contains(slot.slotId)
                ? !(cameraDirection == IslandCameraDirection.southEast ||
                    cameraDirection == IslandCameraDirection.southWest)
                : (cameraDirection == IslandCameraDirection.southEast ||
                    cameraDirection == IslandCameraDirection.southWest),
            onTap: () => onSlotTap(slot),
          )

        // 2. Ô đất xây dựng trống đã mở khóa
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
            onTap: () => slot != null
                ? onSlotTap(slot)
                : onTileTap((tile.row, tile.col)),
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
                  cameraDirection: cameraDirection,
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
            child: SizedBox(width: tileW * 0.92, height: tileH * 0.92),
          ),
      ],
    );

    final String? slotKeyLabel = slot == null
        ? null
        : (slot.stableSlotKey != null && slot.stableSlotKey!.isNotEmpty
              ? slot.stableSlotKey!
              : slot.slotId);

    return Positioned(
      left: isoPos.dx - (objW * 0.5),
      top: isoPos.dy + (tileH * 0.5) - objH,
      width: objW,
      height: objH,
      child: slot != null
          ? Semantics(
              button: true,
              container: true,
              label: slot.placement != null && !isLocked
                  ? 'Ô di sản $slotKeyLabel: ${slot.placement!.name}'
                  : (!isLocked
                        ? 'Ô trống $slotKeyLabel'
                        : 'Ô khóa $slotKeyLabel Cấp ${slot.unlockTier}'),
              onTap: () => onSlotTap(slot),
              child: tileStack,
            )
          : tileStack,
    );
  }
  /// Màn 2 (Issue #50 AC-3): Hiển thị vật phẩm đang preview trên lưới kèm cụm 3 nút tròn `✕` / `↻` / `✓` ngay dưới chân.
  Widget _buildPlacementPreviewWithInlineControls({
    required IslandSlotDto slot,
    required IslandPlacementDto placement,
    required double tileW,
    required double tileH,
  }) {
    final (footW, _) = resolveIslandItemFootprint(
      placement.code,
      placement.renderKey,
    );
    final is2x2 = footW >= 2;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: is2x2 ? -tileH * 0.28 : 0,
          child: IslandHeritageBuilding(
            placement: placement,
            isSelected: true,
            tileWidth: tileW,
            tileHeight: tileH,
            flipHorizontally: previewFlipHorizontally,
            onTap: () => onSlotTap(slot),
          ),
        ),
        Positioned(
          bottom: is2x2 ? -tileH * 0.88 : -tileH * 0.62,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInlinePreviewCircleButton(
                icon: Icons.close_rounded,
                bgColor: const Color(0xFFE04F44),
                iconColor: Colors.white,
                tooltip: 'Hủy đặt',
                onTap: onCancelPreviewPlacement,
              ),
              const SizedBox(width: 8),
              _buildInlinePreviewCircleButton(
                icon: Icons.rotate_right_rounded,
                bgColor: const Color(0xFFFBF3E4),
                iconColor: const Color(0xFF3E2D20),
                tooltip: 'Xoay hướng',
                onTap: onRotatePreviewPlacement,
              ),
              const SizedBox(width: 8),
              _buildInlinePreviewCircleButton(
                icon: Icons.check_rounded,
                bgColor: const Color(0xFF2B7A4B),
                iconColor: Colors.white,
                tooltip: 'Xác nhận đặt',
                onTap: onConfirmPreviewPlacement,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlinePreviewCircleButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFBF3E4), width: 2.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
      ),
    );
  }

  /// Quần thể cây đa cổ thụ ở đỉnh Bắc của đảo & rặng cây xanh hai bên rìa như ảnh mẫu (Issue #50 AC-1).
  List<Widget> _buildDioramaPerimeterLandmarks({
    required List<IslandTileDto> sortedTiles,
    required double originX,
    required double originY,
    required double tileW,
    required double tileH,
  }) {
    if (sortedTiles.isEmpty) return const [];
    final topTile = sortedTiles.first;
    final topCenter = _tileToScreenOffset(
      topTile.row,
      topTile.col,
      originX: originX,
      originY: originY,
    );

    int minCol = 999, maxCol = -999;
    IslandTileDto? westTile;
    IslandTileDto? eastTile;
    for (final t in sortedTiles) {
      if (t.col < minCol) {
        minCol = t.col;
        westTile = t;
      }
      if (t.col > maxCol) {
        maxCol = t.col;
        eastTile = t;
      }
    }
    final westCenter = westTile != null
        ? _tileToScreenOffset(
            westTile.row,
            westTile.col,
            originX: originX,
            originY: originY,
          )
        : topCenter;
    final eastCenter = eastTile != null
        ? _tileToScreenOffset(
            eastTile.row,
            eastTile.col,
            originX: originX,
            originY: originY,
          )
        : topCenter;

    return [
      // Đại cổ thụ tỏa bóng ở đỉnh Bắc của đảo
      Positioned(
        left: topCenter.dx - tileW * 0.95,
        top: topCenter.dy - tileH * 2.55,
        width: tileW * 1.90,
        height: tileH * 2.40,
        child: IgnorePointer(
          child: Image.asset(
            'assets/island/scenery/cay_da_co_thu.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      // Rặng tre / đá rêu phong bên cánh Tây
      Positioned(
        left: westCenter.dx - tileW * 0.90,
        top: westCenter.dy - tileH * 1.40,
        width: tileW * 1.05,
        height: tileH * 1.65,
        child: IgnorePointer(
          child: Image.asset(
            IslandVisualAssetManager.bambooGroveLarge,
            fit: BoxFit.contain,
          ),
        ),
      ),
      // Khóm tre / cây xanh bên cánh Đông
      Positioned(
        left: eastCenter.dx - tileW * 0.15,
        top: eastCenter.dy - tileH * 1.35,
        width: tileW * 1.00,
        height: tileH * 1.55,
        child: IgnorePointer(
          child: Image.asset(
            IslandVisualAssetManager.banyanSapling,
            fit: BoxFit.contain,
          ),
        ),
      ),
    ];
  }

  /// Nền móng xây dựng bằng đá xanh & gỗ lim vẽ tay hòa vào mặt cỏ.
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
        child: (!isEditMode && !isSelected)
            ? const SizedBox.expand()
            : Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
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
                              color: DauVietColors.imperialGold.withValues(
                                alpha: 0.65,
                              ),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: tileH * 0.03,
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.72,
                      child: Image.asset(
                        IslandVisualAssetManager.buildableParcelPlinth,
                        width: plinthW,
                        height: plinthH,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: tileH * 0.36,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: DauVietColors.imperialGold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF5D3A1A),
                            width: 1.1,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: Color(0xFF4E3622),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

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
            Positioned(
              bottom: tileH * 0.06,
              child: _buildMistyFogVeil(tileW: tileW, tileH: tileH),
            ),

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
  final Set<(int, int)> existingViewCoords;
  final IslandCameraDirection cameraDirection;
  final int currentTier;
  final double animationValue;

  _OrganicWaterAndShorelinePainter({
    required this.board,
    required this.originX,
    required this.originY,
    required this.existingViewCoords,
    required this.cameraDirection,
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

    final shallowLagoonPaint = Paint()
      ..color = const Color(0xFF8BE2E8).withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    final midLagoonPaint = Paint()
      ..color = const Color(0xFF6AD0DA).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    final deepShadowPaint = Paint()
      ..color = const Color(0xFF103B45).withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    for (final tile in board.tiles) {
      final (vRow, vCol) = cameraDirection.toViewCoord(
        tile.row,
        tile.col,
        rows: board.rows,
        cols: board.cols,
      );
      final center = board.toScreenOffset(vRow, vCol, originX: originX, originY: originY);
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
      final (vRow, vCol) = cameraDirection.toViewCoord(
        tile.row,
        tile.col,
        rows: board.rows,
        cols: board.cols,
      );
      final hasSW = existingViewCoords.contains((vRow + 1, vCol));
      final hasSE = existingViewCoords.contains((vRow, vCol + 1));
      if (!hasSW || !hasSE) {
        final center = board.toScreenOffset(vRow, vCol, originX: originX, originY: originY);
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

    for (final tile in board.tiles) {
      final (vRow, vCol) = cameraDirection.toViewCoord(
        tile.row,
        tile.col,
        rows: board.rows,
        cols: board.cols,
      );
      final hasSW = existingViewCoords.contains((vRow + 1, vCol));
      final hasSE = existingViewCoords.contains((vRow, vCol + 1));
      final hasNW = existingViewCoords.contains((vRow - 1, vCol));
      final hasNE = existingViewCoords.contains((vRow, vCol - 1));

      if (hasSW && hasSE && hasNW && hasNE) continue;

      final center = board.toScreenOffset(vRow, vCol, originX: originX, originY: originY);
      final localWave = math.sin(phase + (vRow * 0.8 + vCol * 1.1));
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
        oldDelegate.cameraDirection != cameraDirection ||
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
  final Set<(int, int)> existingViewCoords;
  final IslandCameraDirection cameraDirection;
  final int currentTier;
  final double originX;
  final double originY;
  final double expansionProgress;
  final int? expandingFromTier;
  final int? expandingToTier;

  _HeritageIslandCliffAndUnderlayPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingViewCoords,
    required this.cameraDirection,
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
    final baseCliffDepth = tileH * 1.18;
    int swEdgeCounter = 0;
    int seEdgeCounter = 0;

    for (final tile in sortedTiles) {
      final bool isLocked = tile.unlockTier > currentTier;
      final elevOffset = tile.elevation * 6.0;
      final (vRow, vCol) = cameraDirection.toViewCoord(
        tile.row,
        tile.col,
        rows: board.rows,
        cols: board.cols,
      );
      final rawCenter = board.toScreenOffset(
        vRow,
        vCol,
        originX: originX,
        originY: originY,
      );
      final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingViewCoords.contains((vRow + 1, vCol));
      final hasSE = existingViewCoords.contains((vRow, vCol + 1));

      final cliffH = baseCliffDepth + elevOffset;

      if (!hasSW) {
        swEdgeCounter++;
        _drawOrganicCliffEdge(
          canvas: canvas,
          pStart: leftPt,
          pEnd: bottomPt,
          cliffDepth: cliffH,
          seed: tile.row * 17 + tile.col * 31,
          isSunlit: true,
          isLocked: isLocked,
        );
        if (!isLocked && swEdgeCounter == 2) {
          _drawWaterfallCascade(
            canvas: canvas,
            pStart: leftPt,
            pEnd: bottomPt,
            cliffDepth: cliffH,
          );
        }
      }

      if (!hasSE) {
        seEdgeCounter++;
        _drawOrganicCliffEdge(
          canvas: canvas,
          pStart: bottomPt,
          pEnd: rightPt,
          cliffDepth: cliffH,
          seed: tile.row * 23 + tile.col * 41,
          isSunlit: false,
          isLocked: isLocked,
        );
        if (!isLocked && seEdgeCounter == 2) {
          _drawWaterfallCascade(
            canvas: canvas,
            pStart: bottomPt,
            pEnd: rightPt,
            cliffDepth: cliffH,
          );
        }
      }

      if (!isLocked && swEdgeCounter == 3 && !hasSW) {
        _drawWoodenDockAndSteps(
          canvas: canvas,
          pStart: leftPt,
          pEnd: bottomPt,
          cliffDepth: cliffH,
          isLeftShore: true,
        );
      } else if (!isLocked && seEdgeCounter == 4 && !hasSE) {
        _drawWoodenDockAndSteps(
          canvas: canvas,
          pStart: bottomPt,
          pEnd: rightPt,
          cliffDepth: cliffH,
          isLeftShore: false,
        );
      }

      final underlayColor = isLocked
          ? const Color(0xFF6B857E)
          : ((tile.row + tile.col).isEven
                ? const Color(0xFF9AC54F)
                : const Color(0xFF8EBA47));
      final underlayDiamond = Path()
        ..moveTo(topPt.dx, topPt.dy - 1.2)
        ..lineTo(rightPt.dx + 1.6, rightPt.dy)
        ..lineTo(bottomPt.dx, bottomPt.dy + 1.2)
        ..lineTo(leftPt.dx - 1.6, leftPt.dy)
        ..close();
      canvas.drawPath(underlayDiamond, Paint()..color = underlayColor);
    }
  }

  /// Vẽ dòng thác nước trắng xóa đổ từ mép vách đá 2.5D xuống mặt biển ngọc bích.
  void _drawWaterfallCascade({
    required Canvas canvas,
    required Offset pStart,
    required Offset pEnd,
    required double cliffDepth,
  }) {
    final topLeft = Offset.lerp(pStart, pEnd, 0.28)!;
    final topRight = Offset.lerp(pStart, pEnd, 0.72)!;
    final botLeft = Offset(topLeft.dx, topLeft.dy + cliffDepth * 0.98);
    final botRight = Offset(topRight.dx, topRight.dy + cliffDepth * 0.98);

    final cascadePath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..close();

    final cascadeRect = cascadePath.getBounds();
    canvas.drawPath(
      cascadePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F7FA),
            Color(0xFF80DEEA),
            Color(0xFFFFFFFF),
          ],
        ).createShader(cascadeRect),
    );

    // Bọt nước tung trắng xóa ở chân thác
    final splashCenter = Offset(
      (botLeft.dx + botRight.dx) * 0.5,
      (botLeft.dy + botRight.dy) * 0.5 + 2.0,
    );
    canvas.drawOval(
      Rect.fromCenter(center: splashCenter, width: 26, height: 10),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  /// Vẽ bậc thang đá dẫn xuống cầu tàu gỗ kèm thuyền gỗ truyền thống neo đậu (Issue #50 AC-1).
  void _drawWoodenDockAndSteps({
    required Canvas canvas,
    required Offset pStart,
    required Offset pEnd,
    required double cliffDepth,
    bool isLeftShore = true,
  }) {
    final mid = Offset.lerp(pStart, pEnd, 0.50)!;
    final dirX = isLeftShore ? -32.0 : 34.0;
    final dockStart = Offset(mid.dx, mid.dy + cliffDepth * 0.32);
    final dockEnd = Offset(mid.dx + dirX, mid.dy + cliffDepth * 0.96 + 18);

    // Bậc thang đá nối từ mặt đảo xuống cầu tàu
    for (int i = 0; i < 4; i++) {
      final t = i / 4.0;
      final stepCenter = Offset.lerp(mid, dockStart, t)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: stepCenter, width: 17, height: 5.5),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFC5B8A5),
      );
    }

    // Mặt cầu tàu gỗ lim
    final pierPath = Path()
      ..moveTo(dockStart.dx - 10, dockStart.dy)
      ..lineTo(dockStart.dx + 10, dockStart.dy - 5)
      ..lineTo(dockEnd.dx + 10, dockEnd.dy - 5)
      ..lineTo(dockEnd.dx - 10, dockEnd.dy)
      ..close();
    canvas.drawPath(pierPath, Paint()..color = const Color(0xFF9C6639));
    canvas.drawPath(
      pierPath,
      Paint()
        ..color = const Color(0xFF5D3A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Cọc gỗ đỡ cầu tàu dưới mặt nước
    for (final pt in [
      Offset(dockStart.dx - 6, dockStart.dy + 4),
      Offset(dockEnd.dx - 6, dockEnd.dy + 2),
      Offset(dockEnd.dx + 8, dockEnd.dy - 2),
    ]) {
      canvas.drawLine(
        pt,
        Offset(pt.dx, pt.dy + 13),
        Paint()
          ..color = const Color(0xFF4E342E)
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Thuyền gỗ truyền thống neo đậu cạnh cầu tàu
    final boatCenter = Offset(
      dockEnd.dx + (isLeftShore ? -12 : 14),
      dockEnd.dy + 12,
    );
    final hullPath = Path()
      ..moveTo(boatCenter.dx - 24, boatCenter.dy - 4)
      ..quadraticBezierTo(
        boatCenter.dx,
        boatCenter.dy + 12,
        boatCenter.dx + 24,
        boatCenter.dy - 4,
      )
      ..quadraticBezierTo(
        boatCenter.dx,
        boatCenter.dy + 2,
        boatCenter.dx - 24,
        boatCenter.dy - 4,
      )
      ..close();
    canvas.drawPath(hullPath, Paint()..color = const Color(0xFF7D4825));
    canvas.drawPath(
      hullPath,
      Paint()
        ..color = const Color(0xFF4A2811)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Mui thuyền đan tre ấm áp
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(boatCenter.dx, boatCenter.dy - 2),
        width: 20,
        height: 9,
      ),
      Paint()..color = const Color(0xFFC89654),
    );
  }

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
    return oldDelegate.cameraDirection != cameraDirection ||
        oldDelegate.currentTier != currentTier ||
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
  final Set<(int, int)> existingViewCoords;
  final IslandCameraDirection cameraDirection;
  final int currentTier;
  final double originX;
  final double originY;
  final (int row, int col)? selectedCoord;
  final String? selectedSlotId;
  final Map<String, IslandSlotDto> slotById;
  final Map<String, IslandSlotDto> slotByTileKey;
  final bool isEditMode;
  final IslandPlacementDto? previewPlacement;

  _OrganicShoreOverhangAndSelectionPainter({
    required this.board,
    required this.sortedTiles,
    required this.existingViewCoords,
    required this.cameraDirection,
    required this.currentTier,
    required this.originX,
    required this.originY,
    this.selectedCoord,
    this.selectedSlotId,
    required this.slotById,
    required this.slotByTileKey,
    this.isEditMode = false,
    this.previewPlacement,
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
      final (vRow, vCol) = cameraDirection.toViewCoord(
        tile.row,
        tile.col,
        rows: board.rows,
        cols: board.cols,
      );
      final rawCenter = board.toScreenOffset(vRow, vCol, originX: originX, originY: originY);
      final center = Offset(rawCenter.dx, rawCenter.dy - elevOffset);

      final topPt = Offset(center.dx, center.dy - halfH);
      final rightPt = Offset(center.dx + halfW, center.dy);
      final bottomPt = Offset(center.dx, center.dy + halfH);
      final leftPt = Offset(center.dx - halfW, center.dy);

      final hasSW = existingViewCoords.contains((vRow + 1, vCol));
      final hasSE = existingViewCoords.contains((vRow, vCol + 1));

      final overhangLight = isLocked ? const Color(0xFF69807E) : const Color(0xFF83B153);
      final overhangDark = isLocked ? const Color(0xFF536967) : const Color(0xFF618B38);

      if (!hasSW) {
        _drawGrassOverhangFringe(canvas, leftPt, bottomPt, overhangLight, overhangDark);
      }
      if (!hasSE) {
        _drawGrassOverhangFringe(canvas, bottomPt, rightPt, overhangDark, overhangDark);
      }

      final linkedSlot = slotByTileKey[tile.key] ??
          (tile.slotId != null ? slotById[tile.slotId] : null);
      // Xác định vùng ô thuộc footprint preview (2x2 hoặc 1x1) khi ở Màn 2
      // (chỉ neo vào selectedSlotId đã mở khóa để khớp 100% với vị trí thực đặt)
      int? anchorRow, anchorCol;
      if (selectedSlotId != null) {
        for (final t in sortedTiles) {
          final s = slotByTileKey[t.key] ??
              (t.slotId != null ? slotById[t.slotId] : null);
          if (t.slotId == selectedSlotId || s?.slotId == selectedSlotId) {
            anchorRow = t.row;
            anchorCol = t.col;
            break;
          }
        }
      } else if (previewPlacement == null && selectedCoord != null) {
        anchorRow = selectedCoord!.$1;
        anchorCol = selectedCoord!.$2;
      }

      final (footW, footH) = previewPlacement != null
          ? resolveIslandItemFootprint(
              previewPlacement!.code,
              previewPlacement!.renderKey,
            )
          : (1, 1);

      final bool isInPreviewFootprint = previewPlacement != null &&
          anchorRow != null &&
          anchorCol != null &&
          tile.row >= anchorRow &&
          tile.row < anchorRow + footH &&
          tile.col >= anchorCol &&
          tile.col < anchorCol + footW;
      final isSelected = (selectedCoord != null &&
              selectedCoord!.$1 == tile.row &&
              selectedCoord!.$2 == tile.col) ||
          (selectedSlotId != null &&
              (tile.slotId == selectedSlotId ||
                  linkedSlot?.slotId == selectedSlotId));
      final diamond = Path()
        ..moveTo(topPt.dx, topPt.dy)
        ..lineTo(rightPt.dx, rightPt.dy)
        ..lineTo(bottomPt.dx, bottomPt.dy)
        ..lineTo(leftPt.dx, leftPt.dy)
        ..close();

      // Kẻ đường lưới ô isometric màu kem sáng rõ nét trên vùng mặt phẳng xây dựng (Issue #50 AC-1 & AC-2)
      if (!isLocked && tile.buildable) {
        final isEven = (tile.row + tile.col) % 2 == 0;
        canvas.drawPath(
          diamond,
          Paint()
            ..color = isEven
                ? const Color(0x28F6F4C8)
                : const Color(0x16DCE775)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xB8F9F6D0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      }

      // Màn 2 (Issue #50 AC-3): Vùng ô dưới chân đế vật phẩm preview tô sáng màu xanh lá
      if (isInPreviewFootprint && !isLocked) {
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0x88388E3C)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xFFB9F6CA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      } else if (isSelected) {
        canvas.drawPath(
          diamond,
          Paint()
            ..color = DauVietColors.imperialGold.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawPath(
          diamond,
          Paint()
            ..color = const Color(0xFFFFF3C4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }
  }

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
  bool shouldRepaint(
    covariant _OrganicShoreOverhangAndSelectionPainter oldDelegate,
  ) {
    return oldDelegate.cameraDirection != cameraDirection ||
        oldDelegate.selectedCoord != selectedCoord ||
        oldDelegate.selectedSlotId != selectedSlotId ||
        oldDelegate.currentTier != currentTier ||
        oldDelegate.isEditMode != isEditMode ||
        oldDelegate.previewPlacement != previewPlacement;
  }
}
