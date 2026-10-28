import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/island_dto.dart';
import 'island_isometric_renderer.dart';
import 'island_visual_asset_manager.dart';

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

/// Canvas 2:1 Isometric Heritage Island Scene.
/// Bao gồm InteractiveViewer hỗ trợ Pan, Pinch-to-zoom, Camera Auto-Fit thông minh
/// theo đúng bounding-box thị giác (gồm cả cây cao, công trình và bờ đá),
/// nền biển nhiệt đới đa sắc độ và tương tác chạm chọn tile hình thoi chính xác.
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
  bool _hasInitialCameraFit = false;

  /// Kích thước scene isometric tính theo bounding-box thị giác thực tế của đảo
  /// (khớp hoàn toàn với phép tính trong `IslandIsometricRenderer`).
  ({double width, double height, double minX, double maxX, double minY, double maxY})
      _sceneMetrics(IslandBoardDto board) {
    final tileW = board.tileWidth;
    final tileH = board.tileHeight;

    if (board.tiles.isEmpty) {
      final w = (board.rows + board.cols) * (tileW * 0.5) + tileW * 2.0;
      final h = (board.rows + board.cols) * (tileH * 0.5) + tileH * 4.0;
      return (width: w, height: h, minX: 0, maxX: w, minY: 0, maxY: h);
    }

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final t in board.tiles) {
      final x = (t.col - t.row) * (tileW * 0.5);
      final y = (t.col + t.row) * (tileH * 0.5);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final padX = tileW * 1.45;
    final padTop = tileH * 2.85;
    final padBottom = tileH * 2.25;
    minX -= padX;
    maxX += padX;
    minY -= padTop;
    maxY += padBottom;

    return (
      width: maxX - minX,
      height: maxY - minY,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  @override
  void initState() {
    super.initState();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    IslandVisualAssetManager.precacheIslandSprites(context);
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

    final bool isPortraitMobile = viewportSize.width < 600 &&
        viewportSize.height > viewportSize.width;

    // Trên desktop/tablet: đảo nổi bật chiếm ~86% chiều cao khả dụng, giảm khoảng nước trống dư thừa.
    // Trên mobile dọc: ưu tiên vùng đất trung tâm đã mở khóa vừa vặn tầm tay chạm.
    final widthFill = isPortraitMobile ? 0.96 : 0.88;
    final heightFill = isPortraitMobile ? 0.80 : 0.86;

    final scaleX = (viewportSize.width * widthFill) / m.width;
    final scaleY = (viewportSize.height * heightFill) / m.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.32, 1.85);

    final targetX = (viewportSize.width - m.width * fitScale) * 0.5;
    final targetY = (viewportSize.height - m.height * fitScale) * 0.45;

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

        if (!_hasInitialCameraFit ||
            _lastViewportSize == null ||
            (_lastViewportSize!.width - viewportSize.width).abs() > 2.0 ||
            (_lastViewportSize!.height - viewportSize.height).abs() > 2.0) {
          _lastViewportSize = viewportSize;
          _hasInitialCameraFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoFitCamera(viewportSize);
          });
        }

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.15, -0.10),
              radius: 1.15,
              colors: [
                Color(0xFF7AD2DC),
                Color(0xFF5AB4C0),
                Color(0xFF3E94A4),
                Color(0xFF2D7686),
              ],
              stops: [0.0, 0.45, 0.80, 1.0],
            ),
          ),
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 0.30,
            maxScale: 2.6,
            boundaryMargin: const EdgeInsets.all(520),
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
