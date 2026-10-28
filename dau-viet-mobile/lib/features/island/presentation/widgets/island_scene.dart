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

    final sceneW = (board.rows + board.cols) * (board.tileWidth * 0.5) + board.tileWidth * 2.0;
    final sceneH = (board.rows + board.cols) * (board.tileHeight * 0.5) + board.tileHeight * 4.0;

    // Tính tỷ lệ zoom tối ưu vừa khít màn hình
    final scaleX = (viewportSize.width * 0.92) / (sceneW * 0.75);
    final scaleY = (viewportSize.height * 0.85) / (sceneH * 0.75);
    final fitScale = math.min(scaleX, scaleY).clamp(0.48, 1.15);

    final targetX = (viewportSize.width - (sceneW * fitScale)) * 0.5;
    final targetY = (viewportSize.height - (sceneH * fitScale)) * 0.42;

    final matrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(fitScale, fitScale);

    _controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.island.board ??
        IslandBoardDto.buildDefaultBoard(
          slots: widget.island.slots,
          regions: widget.island.regions,
        );

    final sceneW = (board.rows + board.cols) * (board.tileWidth * 0.5) + board.tileWidth * 2.0;
    final sceneH = (board.rows + board.cols) * (board.tileHeight * 0.5) + board.tileHeight * 4.0;

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
                return IslandIsometricRenderer(
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
                    // Kiểm tra xem tile này có gắn với slot nào không
                    final slot = board.tileAt(coord.$1, coord.$2)?.slotId != null
                        ? widget.island.slots.firstWhere(
                            (s) => s.slotId == board.tileAt(coord.$1, coord.$2)!.slotId,
                            orElse: () => widget.island.slots.first,
                          )
                        : null;
                    widget.onSelectSlot(slot);
                  },
                  onSlotTap: (slot) {
                    setState(() {
                      if (slot.tileRow != null && slot.tileCol != null) {
                        _selectedTileCoord = (slot.tileRow!, slot.tileCol!);
                      }
                    });
                    widget.onSelectSlot(slot);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
