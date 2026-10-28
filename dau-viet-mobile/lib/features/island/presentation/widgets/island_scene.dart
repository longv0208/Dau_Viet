import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_isometric_renderer.dart';

/// Trạng thái chuyển tiếp khi người học mở rộng Đảo Di Sản từ `fromTier` sang `toTier`.
@immutable
class IslandExpansionTransition {
  final int fromTier;
  final int toTier;
  /// Tiến độ chung của chuỗi animation (0.0 -> 1.0).
  final double progress;

  const IslandExpansionTransition({
    required this.fromTier,
    required this.toTier,
    required this.progress,
  });

  /// Phase 1 (0.00 -> 0.25): Camera lùi nhẹ.
  double get cameraProgress =>
      Curves.easeInOutCubic.transform((progress / 0.25).clamp(0.0, 1.0));

  /// Phase 2 & 3 (0.20 -> 0.70): Sương mù tan & mặt đất/bờ mở rộng.
  double get landRevealProgress => Curves.easeOutCubic.transform(
    ((progress - 0.20) / 0.50).clamp(0.0, 1.0),
  );

  /// Phase 4 (0.65 -> 1.00): Các slot mới mở xuất hiện sáng lên lần lượt.
  double get slotRevealProgress =>
      ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
}

/// Canvas 2:1 Isometric Heritage Island Scene cho Mobile.
/// Bao gồm InteractiveViewer hỗ trợ Pan, Pinch-to-zoom, Camera Auto-Fit,
/// hiệu ứng mặt nước nhẹ nhàng và tương tác chạm chọn tile hình thoi chính xác.
class IslandScene extends StatefulWidget {
  final IslandDto island;
  final String? selectedSlotId;
  final ValueChanged<IslandSlotDto?> onSelectSlot;
  final TransformationController? transformationController;
  final int resetCameraVersion;
  final IslandExpansionTransition? expansionTransition;
  final String? activeEffectSlotId;
  final int placementEffectToken;
  final int removalEffectToken;

  const IslandScene({
    super.key,
    required this.island,
    required this.selectedSlotId,
    required this.onSelectSlot,
    this.transformationController,
    this.resetCameraVersion = 0,
    this.expansionTransition,
    this.activeEffectSlotId,
    this.placementEffectToken = 0,
    this.removalEffectToken = 0,
  });

  @override
  State<IslandScene> createState() => _IslandSceneState();
}

class _IslandSceneState extends State<IslandScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waterController;
  late final TransformationController _controller;
  bool _internalController = false;

  (int row, int col)? _selectedTileCoord;
  Size? _lastViewportSize;
  int _lastResetVersion = -1;

  /// Kích thước scene isometric tính theo bounding-box thật của các tile tồn
  /// tại (không suy ra mọi ô trong grid — đảo hình thoi chỉ chiếm một phần).
  ({double width, double height, double minX, double maxX, double minY, double maxY})
      _sceneMetrics(IslandBoardDto board) {
    if (board.tiles.isEmpty) {
      final w = (board.rows + board.cols) * (board.tileWidth * 0.5) +
          board.tileWidth * 2.0;
      final h = (board.rows + board.cols) * (board.tileHeight * 0.5) +
          board.tileHeight * 4.0;
      return (width: w, height: h, minX: 0, maxX: w, minY: 0, maxY: h);
    }
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final t in board.tiles) {
      final x = (t.col - t.row) * (board.tileWidth * 0.5);
      final y = (t.col + t.row) * (board.tileHeight * 0.5);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    // Mở rộng thêm 1 tile mỗi phía cho viền đảo + bờ vách 2.5D.
    final padX = board.tileWidth;
    final padY = board.tileHeight * 2.0;
    minX -= padX; maxX += padX; minY -= padY; maxY += padY;
    return (
      width: maxX - minX,
      height: maxY - minY,
      minX: minX, maxX: maxX, minY: minY, maxY: maxY,
    );
  }

  @override
  void initState() {
    super.initState();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    if (widget.transformationController != null) {
      _controller = widget.transformationController!;
    } else {
      _controller = TransformationController();
      _internalController = true;
    }

    _lastResetVersion = widget.resetCameraVersion;
  }

  @override
  void didUpdateWidget(covariant IslandScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetCameraVersion != _lastResetVersion) {
      _lastResetVersion = widget.resetCameraVersion;
      if (_lastViewportSize != null) {
        _autoFitCamera(_lastViewportSize!);
      }
    }
  }

  @override
  void dispose() {
    _waterController.dispose();
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _autoFitCamera(Size viewportSize) {
    final board = widget.island.board ??
        IslandBoardDto.buildDefaultBoard(
          slots: widget.island.slots,
          regions: widget.island.regions,
        );
    final m = _sceneMetrics(board);

    // Fit đảo vào viewport (giữ lề nhỏ, không zoom quá mức)
    final scaleX = (viewportSize.width * 0.92) / m.width;
    final scaleY = (viewportSize.height * 0.85) / m.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.35, 1.4);

    // Căn giữa bounding box đảo trong viewport (hơi lệch lên trên cho HUD)
    final targetX =
        (viewportSize.width - m.width * fitScale) * 0.5 - m.minX * fitScale;
    final targetY =
        (viewportSize.height - m.height * fitScale) * 0.42 - m.minY * fitScale;

    _controller.value = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(fitScale, fitScale);
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.island.board ??
        IslandBoardDto.buildDefaultBoard(
          slots: widget.island.slots,
          regions: widget.island.regions,
        );
    final m = _sceneMetrics(board);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_lastViewportSize == null ||
            (_lastViewportSize!.width != viewportSize.width ||
                _lastViewportSize!.height != viewportSize.height)) {
          _lastViewportSize = viewportSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoFitCamera(viewportSize);
          });
        }

        return Container(
          color: const Color(0xFF5CAFB9), // Nền ngọc bích hòa nhập với nước
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 0.35,
            maxScale: 2.2,
            boundaryMargin: const EdgeInsets.all(400),
            constrained: false,
            child: AnimatedBuilder(
              animation: _waterController,
              builder: (context, _) {
                return SizedBox(
                  width: m.width,
                  height: m.height,
                  child: IslandIsometricRenderer(
                  board: board,
                  slots: widget.island.slots,
                  currentTier: widget.island.tier,
                  selectedSlotId: widget.selectedSlotId,
                  selectedTileCoord: _selectedTileCoord,
                  waterAnimationValue: _waterController.value,
                  expansionRevealProgress:
                      widget.expansionTransition?.landRevealProgress ?? 1.0,
                  expandingFromTier: widget.expansionTransition?.fromTier,
                  expandingToTier: widget.expansionTransition?.toTier,
                  onTileTap: (coord) {
                    setState(() {
                      _selectedTileCoord = coord;
                    });
                    // Chọn slot qua quan hệ tileKey→slotId đã link ở DTO;
                    // tile không có slot → bỏ chọn slot (không fallback .first).
                    final tile = board.tileAt(coord.$1, coord.$2);
                    final tileSlotId = tile?.slotId;
                    IslandSlotDto? slot;
                    if (tileSlotId != null && tileSlotId.isNotEmpty) {
                      for (final s in widget.island.slots) {
                        if (s.slotId == tileSlotId) {
                          slot = s;
                          break;
                        }
                      }
                    }
                    widget.onSelectSlot(slot);
                  },
                  onSlotTap: (slot) {
                    setState(() {
                      // Ưu tiên tile host đã link qua tileKey; fallback x/y
                      // chỉ cho dữ liệu legacy chưa gán tileKey/tileRow.
                      final host = slot.tileKey != null
                          ? board.tiles
                              .where((t) => t.key == slot.tileKey)
                              .firstOrNull
                          : null;
                      if (host != null) {
                        _selectedTileCoord = (host.row, host.col);
                      } else if (slot.tileRow != null && slot.tileCol != null) {
                        _selectedTileCoord = (slot.tileRow!, slot.tileCol!);
                      } else {
                        _selectedTileCoord = null;
                      }
                    });
                    widget.onSelectSlot(slot);
                  },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
