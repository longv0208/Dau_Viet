import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/island_dto.dart';
import 'island_illustrated_layout.dart';
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
/// Bao gồm InteractiveViewer hỗ trợ Pan, Pinch-to-zoom, 4 góc nhìn xoay Isometric (10A),
/// Camera Auto-Fit thông minh, chuyển cảnh xoay mượt mà tôn trọng Reduced Motion,
/// và đường gạch làng Việt Autotile liền mạch (10B).
class IslandScene extends StatefulWidget {
  final IslandDto island;
  final String? selectedSlotId;
  final ValueChanged<IslandSlotDto?> onSelectSlot;
  final TransformationController? transformationController;
  final IslandCameraDirection cameraDirection;
  final int resetCameraVersion;
  final IslandExpansionTransition? expansionTransition;
  final String? activeEffectSlotId;
  final int placementEffectToken;
  final int removalEffectToken;
  final bool isEditMode;
  final Set<String> flippedSlotIds;
  final int previewTier;
  final ValueChanged<int>? onSelectTier;
  final IslandPlacementDto? previewPlacement;
  final bool previewFlipHorizontally;
  final VoidCallback? onCancelPreviewPlacement;
  final VoidCallback? onRotatePreviewPlacement;
  final VoidCallback? onConfirmPreviewPlacement;

  const IslandScene({
    super.key,
    required this.island,
    required this.selectedSlotId,
    required this.onSelectSlot,
    this.transformationController,
    this.cameraDirection = IslandCameraDirection.northEast,
    this.resetCameraVersion = 0,
    this.expansionTransition,
    this.activeEffectSlotId,
    this.placementEffectToken = 0,
    this.removalEffectToken = 0,
    this.isEditMode = false,
    this.flippedSlotIds = const {},
    this.previewTier = 1,
    this.onSelectTier,
    this.previewPlacement,
    this.previewFlipHorizontally = false,
    this.onCancelPreviewPlacement,
    this.onRotatePreviewPlacement,
    this.onConfirmPreviewPlacement,
  });
  @override
  State<IslandScene> createState() => _IslandSceneState();
}

class _IslandSceneState extends State<IslandScene>
    with TickerProviderStateMixin {
  late final AnimationController _waterController;
  late final AnimationController _rotationTransitionController;
  late final TransformationController _controller;
  bool _internalController = false;

  (int row, int col)? _selectedTileCoord;
  Size? _lastViewportSize;
  int _lastResetVersion = -1;
  bool _hasInitialCameraFit = false;
  int _lastRotationTurnDelta = 1;

  /// Kích thước scene isometric tính theo bounding-box thị giác thực tế của đảo ở góc nhìn hiện tại.
  ({double width, double height, double minX, double maxX, double minY, double maxY})
      _sceneMetrics(IslandBoardDto board, IslandCameraDirection direction) {
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
      final (vRow, vCol) = direction.toViewCoord(
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

    final pad = IslandIllustratedLayout.paddingForTier(
      tier: widget.previewTier,
      tileW: tileW,
      tileH: tileH,
    );
    final padX = pad.padX;
    final padTop = pad.padTop;
    final padBottom = pad.padBottom;
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

    _rotationTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );

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
    if (widget.cameraDirection != oldWidget.cameraDirection) {
      final diff = (widget.cameraDirection.quarterTurns -
              oldWidget.cameraDirection.quarterTurns) %
          4;
      _lastRotationTurnDelta = diff == 3 ? -1 : 1;
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduceMotion) {
        _rotationTransitionController.forward(from: 0.0);
      } else {
        _rotationTransitionController.value = 1.0;
      }
    }

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
    _rotationTransitionController.dispose();
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
    final m = _sceneMetrics(board, widget.cameraDirection);

    final bool isPortraitMobile = viewportSize.width < 600 &&
        viewportSize.height > viewportSize.width;

    final widthFill = isPortraitMobile ? 0.98 : 0.90;
    final heightFill = isPortraitMobile ? 0.86 : 0.84;

    final scaleX = (viewportSize.width * widthFill) / m.width;
    final scaleY = (viewportSize.height * heightFill) / m.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.70, 2.20);

    final targetX = (viewportSize.width - m.width * fitScale) * 0.5;
    final targetY = (viewportSize.height - m.height * fitScale) * 0.42;

    _controller.value = Matrix4.identity()
      ..translateByDouble(targetX, targetY, 0.0, 1.0)
      ..scaleByDouble(fitScale, fitScale, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.island.board ??
        IslandBoardDto.buildDefaultBoard(
          slots: widget.island.slots,
          regions: widget.island.regions,
        );
    final m = _sceneMetrics(board, widget.cameraDirection);

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

        return Stack(
          fit: StackFit.expand,
          children: [
            // Lớp nền toàn cảnh vịnh núi đá vôi Hạ Long, mây trôi & đảo phụ phía xa (Issue #46 AC-1)
            Positioned.fill(
              child: _IslandPanoramicBackdrop(
                island: widget.island,
                previewTier: widget.previewTier,
                isEditMode: widget.isEditMode,
                onSelectTier: widget.onSelectTier,
              ),
            ),
            InteractiveViewer(
              transformationController: _controller,
              minScale: 0.70,
              maxScale: 2.40,
              boundaryMargin: const EdgeInsets.all(56),
              constrained: false,
              panEnabled: true,
              scaleEnabled: true,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _waterController,
                  _rotationTransitionController,
                ]),
                builder: (context, _) {
                  final rotT = Curves.easeOutCubic.transform(
                    _rotationTransitionController.value,
                  );
                  final slideDx = (1.0 - rotT) * 22.0 * _lastRotationTurnDelta;
                  final scale = 0.965 + 0.035 * rotT;
                  final opacity = (0.72 + 0.28 * rotT).clamp(0.0, 1.0);

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(slideDx, 0),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: SizedBox(
                          key: ValueKey<int>(widget.previewTier),
                          width: m.width,
                          height: m.height,
                          child: IslandIsometricRenderer(
                            board: board,
                            slots: widget.island.slots,
                            currentTier: widget.island.tier,
                            previewTier: widget.previewTier,
                            selectedSlotId: widget.selectedSlotId,
                            selectedTileCoord: _selectedTileCoord,
                            cameraDirection: widget.cameraDirection,
                            waterAnimationValue: _waterController.value,
                            expansionRevealProgress:
                                widget.expansionTransition?.landRevealProgress ??
                                1.0,
                            expandingFromTier:
                                widget.expansionTransition?.fromTier,
                            expandingToTier: widget.expansionTransition?.toTier,
                            isEditMode: widget.isEditMode,
                            flippedSlotIds: widget.flippedSlotIds,
                            previewPlacement: widget.previewPlacement,
                            previewFlipHorizontally:
                                widget.previewFlipHorizontally,
                            onCancelPreviewPlacement:
                                widget.onCancelPreviewPlacement,
                            onRotatePreviewPlacement:
                                widget.onRotatePreviewPlacement,
                            onConfirmPreviewPlacement:
                                widget.onConfirmPreviewPlacement,
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
                                } else if (slot.tileRow != null &&
                                    slot.tileCol != null) {
                                  _selectedTileCoord = (
                                    slot.tileRow!,
                                    slot.tileCol!,
                                  );
                                } else {
                                  _selectedTileCoord = null;
                                }
                              });
                              widget.onSelectSlot(slot);
                            },
                          ),
                        ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!widget.isEditMode && widget.previewPlacement == null)
              Positioned(
                right: 10,
                bottom: 92,
                child: _IslandZoomControls(
                  onZoomIn: () => _zoomBy(1.28),
                  onZoomOut: () => _zoomBy(1 / 1.28),
                  onReset: () {
                    if (_lastViewportSize != null) {
                      _autoFitCamera(_lastViewportSize!);
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _zoomBy(double factor) {
    final current = _controller.value.clone();
    final scale = current.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(0.70, 2.40);
    final actual = next / scale;
    if ((actual - 1.0).abs() < 0.01) return;
    final viewport = _lastViewportSize ?? Size.zero;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final nextMatrix = current.clone()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(actual, actual, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _controller.value = nextMatrix;
  }
}

class _IslandZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _IslandZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF6FFF8EC),
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(Icons.add_rounded, 'Phóng to', onZoomIn),
          _zoomBtn(Icons.center_focus_strong_rounded, 'Vừa khung', onReset),
          _zoomBtn(Icons.remove_rounded, 'Thu nhỏ', onZoomOut),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: const Color(0xFF2B1F17)),
    );
  }
}

/// Khung cảnh biển trời vịnh núi đá vôi Hạ Long, mây trôi và các đảo phụ phía xa (Issue #46 AC-1).
class _IslandPanoramicBackdrop extends StatelessWidget {
  final IslandDto island;
  final int previewTier;
  final bool isEditMode;
  final ValueChanged<int>? onSelectTier;

  const _IslandPanoramicBackdrop({
    required this.island,
    required this.previewTier,
    required this.isEditMode,
    this.onSelectTier,
  });

  @override
  Widget build(BuildContext context) {
    final futureTiers = [
      for (var t = island.tier + 1; t <= island.maxTier; t++) t,
    ];
    final leftPreviewTier = futureTiers.isNotEmpty ? futureTiers.first : null;
    final rightPreviewTier = futureTiers.length > 1 ? futureTiers[1] : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Nền bầu trời mây trắng bồng bềnh, đại dương ngọc bích, rạn san hô & hòn non bộ xanh mát (Issue #50 AC-1)
        Positioned.fill(
          child: CustomPaint(
            painter: _HaLongBayHorizonPainter(),
          ),
        ),

        // 3. Đảo phụ phía xa — chỉ đảo chưa mở, không hiện đảo cũ.
        if (!isEditMode && leftPreviewTier != null)
          Positioned(
            top: 175,
            left: 16,
            child: _DistantFloatingIslandBadge(
              tier: leftPreviewTier,
              isLocked: leftPreviewTier > island.tier,
              isGreySilhouette: true,
              onTap: onSelectTier != null
                  ? () => onSelectTier!(leftPreviewTier)
                  : null,
            ),
          ),
        if (!isEditMode && rightPreviewTier != null)
          Positioned(
            top: 168,
            right: 16,
            child: _DistantFloatingIslandBadge(
              tier: rightPreviewTier,
              isLocked: rightPreviewTier > island.tier,
              isGreySilhouette: false,
              onTap: onSelectTier != null
                  ? () => onSelectTier!(rightPreviewTier)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _HaLongBayHorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 1. Bầu trời nắng ấm chuyển sắc mượt xuống mặt biển ngọc bích & đại dương sâu (giống hệt mẫu Image #2)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE7F6FB),
            Color(0xFFB9E8F3),
            Color(0xFF86D5E6),
            Color(0xFF5FCBDC),
            Color(0xFF3EB4C8),
            Color(0xFF2B96AC),
          ],
          stops: [0.0, 0.16, 0.34, 0.52, 0.76, 1.0],
        ).createShader(rect),
    );

    // 2. Ánh nắng vàng dịu tỏa từ góc trên bên trái
    final sunGlowRect = Rect.fromCircle(
      center: Offset(w * 0.18, h * 0.10),
      radius: w * 0.65,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8DF).withValues(alpha: 0.46),
            const Color(0xFFFFF3C8).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(sunGlowRect),
    );

    // 3. Các tầng mây cumulus trắng kem bồng bềnh phía chân trời trên & hai bên sườn đảo
    _drawFluffyCloudCluster(
      canvas,
      center: Offset(w * 0.16, h * 0.15),
      width: w * 0.52,
      height: 68,
      alpha: 0.92,
    );
    _drawFluffyCloudCluster(
      canvas,
      center: Offset(w * 0.84, h * 0.14),
      width: w * 0.50,
      height: 64,
      alpha: 0.90,
    );
    _drawFluffyCloudCluster(
      canvas,
      center: Offset(w * 0.50, h * 0.11),
      width: w * 0.62,
      height: 56,
      alpha: 0.78,
    );
    _drawFluffyCloudCluster(
      canvas,
      center: Offset(w * 0.08, h * 0.27),
      width: w * 0.38,
      height: 48,
      alpha: 0.72,
    );
    _drawFluffyCloudCluster(
      canvas,
      center: Offset(w * 0.92, h * 0.26),
      width: w * 0.38,
      height: 48,
      alpha: 0.72,
    );

    // 4. Quần đảo đá vôi tròn trịa xanh ngọc phía xa kèm tán cây & sương mù chân đảo
    _drawLushDistantIslet(
      canvas,
      baseCenter: Offset(w * 0.11, h * 0.25),
      width: 92,
      height: 44,
    );
    _drawLushDistantIslet(
      canvas,
      baseCenter: Offset(w * 0.89, h * 0.24),
      width: 96,
      height: 46,
    );

    // 5. Các mảng nước nông ngọc lam (lagoon), rạn đá ngầm & gợn sóng lăn tăn trên mặt biển
    final reefPaint = Paint()
      ..color = const Color(0xFF56CEDB).withValues(alpha: 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.14, h * 0.36),
        width: 118,
        height: 48,
      ),
      reefPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.86, h * 0.35),
        width: 124,
        height: 50,
      ),
      reefPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.16, h * 0.74),
        width: 132,
        height: 54,
      ),
      reefPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.84, h * 0.70),
        width: 120,
        height: 48,
      ),
      reefPaint,
    );

    // Gợn sóng bạc & lá súng/bèo xanh trôi nhẹ trên biển quanh đảo
    final waveLinePaint = Paint()
      ..color = const Color(0xFFB7F3F7).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (wx, wy, ww) in const [
      (0.18, 0.39, 34.0),
      (0.80, 0.38, 38.0),
      (0.12, 0.54, 28.0),
      (0.88, 0.52, 32.0),
      (0.24, 0.76, 40.0),
      (0.76, 0.74, 36.0),
      (0.50, 0.81, 44.0),
    ]) {
      final cx = w * wx;
      final cy = h * wy;
      final path = Path()
        ..moveTo(cx - ww * 0.5, cy)
        ..quadraticBezierTo(cx - ww * 0.2, cy - 3.5, cx, cy)
        ..quadraticBezierTo(cx + ww * 0.2, cy + 3.5, cx + ww * 0.5, cy);
      canvas.drawPath(path, waveLinePaint);
    }

    // Những cụm lá sen / hoa súng nhỏ điểm xuyết trên mặt biển ngọc bích
    final padPaint = Paint()..color = const Color(0xFF4CA858).withValues(alpha: 0.78);
    final blossomPaint = Paint()..color = const Color(0xFFFF8A9B).withValues(alpha: 0.90);
    for (final (lx, ly) in const [
      (0.22, 0.37),
      (0.77, 0.36),
      (0.20, 0.72),
      (0.79, 0.69),
    ]) {
      final c = Offset(w * lx, h * ly);
      canvas.drawOval(Rect.fromCenter(center: c, width: 13, height: 7), padPaint);
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(9, 4), width: 10, height: 5.5),
        padPaint,
      );
      canvas.drawCircle(c.translate(1, -1.5), 2.4, blossomPaint);
    }
  }

  void _drawFluffyCloudCluster(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double alpha,
  }) {
    final baseShadePaint = Paint()
      ..color = const Color(0xFFCDE7F2).withValues(alpha: alpha * 0.78);
    final mainCreamPaint = Paint()
      ..color = const Color(0xFFFFFDF6).withValues(alpha: alpha);
    final rimWarmPaint = Paint()
      ..color = const Color(0xFFFFF4D9).withValues(alpha: alpha * 0.85);

    // Đế mây xanh nhạt phía dưới
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, height * 0.16),
          width: width * 0.92,
          height: height * 0.46,
        ),
        Radius.circular(height * 0.25),
      ),
      baseShadePaint,
    );

    // Các vòm mây tròn bồng bềnh chồng lớp
    final puffs = [
      (-0.30, 0.06, 0.34, 0.58),
      (-0.14, -0.08, 0.42, 0.76),
      (0.06, -0.14, 0.46, 0.84),
      (0.24, -0.04, 0.36, 0.64),
      (0.36, 0.08, 0.26, 0.46),
    ];
    for (final (dx, dy, rw, rh) in puffs) {
      final puffRect = Rect.fromCenter(
        center: Offset(center.dx + width * dx, center.dy + height * dy),
        width: width * rw,
        height: height * rh,
      );
      canvas.drawOval(puffRect, mainCreamPaint);
      canvas.drawOval(
        puffRect.deflate(width * 0.02).translate(-2, -3),
        rimWarmPaint,
      );
    }
  }

  void _drawLushDistantIslet(
    Canvas canvas, {
    required Offset baseCenter,
    required double width,
    required double height,
  }) {
    // Bọt sóng trắng dưới chân đảo xa
    canvas.drawOval(
      Rect.fromCenter(
        center: baseCenter.translate(0, 3),
        width: width * 1.12,
        height: 11,
      ),
      Paint()..color = const Color(0xFFDDF9FC).withValues(alpha: 0.58),
    );

    // Vách đá nâu vàng ấm áp
    final rockPath = Path()
      ..moveTo(baseCenter.dx - width * 0.46, baseCenter.dy)
      ..quadraticBezierTo(
        baseCenter.dx - width * 0.28,
        baseCenter.dy - height * 0.85,
        baseCenter.dx - width * 0.04,
        baseCenter.dy - height * 0.68,
      )
      ..quadraticBezierTo(
        baseCenter.dx + width * 0.18,
        baseCenter.dy - height * 1.05,
        baseCenter.dx + width * 0.46,
        baseCenter.dy,
      )
      ..close();
    canvas.drawPath(
      rockPath,
      Paint()..color = const Color(0xFF7B684A).withValues(alpha: 0.72),
    );

    // Vòm cây xanh ngọc phủ đỉnh đảo xa
    for (final (ox, oy, r) in [
      (-width * 0.18, -height * 0.56, height * 0.36),
      (width * 0.08, -height * 0.68, height * 0.42),
      (width * 0.26, -height * 0.44, height * 0.30),
    ]) {
      canvas.drawCircle(
        baseCenter.translate(ox, oy),
        r,
        Paint()..color = const Color(0xFF4F9350).withValues(alpha: 0.78),
      );
      canvas.drawCircle(
        baseCenter.translate(ox - 2, oy - 3),
        r * 0.72,
        Paint()..color = const Color(0xFF7BB856).withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DistantFloatingIslandBadge extends StatelessWidget {
  final int tier;
  final bool isLocked;
  final bool isGreySilhouette;
  final VoidCallback? onTap;

  const _DistantFloatingIslandBadge({
    required this.tier,
    required this.isLocked,
    required this.isGreySilhouette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(92, 60),
              painter: _MiniatureFloatingIslandPainter(
                isGrey: isGreySilhouette && isLocked,
              ),
            ),
            if (isLocked)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF6E7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8C7355),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 13,
                  color: Color(0xFF5D4632),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniatureFloatingIslandPainter extends CustomPainter {
  final bool isGrey;

  const _MiniatureFloatingIslandPainter({required this.isGrey});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Đám mây đỡ chân đảo
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.80),
        width: w * 0.88,
        height: h * 0.30,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // Khối đá dưới đảo
    final cliff = Path()
      ..moveTo(w * 0.14, h * 0.50)
      ..lineTo(w * 0.50, h * 0.72)
      ..lineTo(w * 0.86, h * 0.50)
      ..lineTo(w * 0.76, h * 0.82)
      ..lineTo(w * 0.50, h * 0.92)
      ..lineTo(w * 0.24, h * 0.82)
      ..close();
    canvas.drawPath(
      cliff,
      Paint()
        ..color = isGrey ? const Color(0xFF6E7476) : const Color(0xFF7B5836),
    );

    // Mặt cỏ hình thoi
    final topDiamond = Path()
      ..moveTo(w * 0.50, h * 0.26)
      ..lineTo(w * 0.86, h * 0.50)
      ..lineTo(w * 0.50, h * 0.72)
      ..lineTo(w * 0.14, h * 0.50)
      ..close();
    canvas.drawPath(
      topDiamond,
      Paint()
        ..color = isGrey ? const Color(0xFF8C9294) : const Color(0xFF6AA24A),
    );

    // Mái đình nhỏ trên đảo phụ
    final roof = Path()
      ..moveTo(w * 0.34, h * 0.42)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.66, h * 0.42)
      ..close();
    canvas.drawPath(
      roof,
      Paint()
        ..color = isGrey ? const Color(0xFF595E60) : const Color(0xFFB93430),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniatureFloatingIslandPainter oldDelegate) =>
      oldDelegate.isGrey != isGrey;
}
