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

    final widthFill = isPortraitMobile ? 0.96 : 0.88;
    final heightFill = isPortraitMobile ? 0.80 : 0.86;

    final scaleX = (viewportSize.width * widthFill) / m.width;
    final scaleY = (viewportSize.height * heightFill) / m.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.32, 1.85);

    final targetX = (viewportSize.width - m.width * fitScale) * 0.5;
    final targetY = (viewportSize.height - m.height * fitScale) * 0.45;

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
              minScale: 0.30,
              maxScale: 2.6,
              boundaryMargin: const EdgeInsets.all(520),
              constrained: false,
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
                        child: SizedBox(
                          width: m.width,
                          height: m.height,
                          child: IslandIsometricRenderer(
                            board: board,
                            slots: widget.island.slots,
                            currentTier: widget.island.tier,
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
                  );
                },
              ),
            ),
          ],
        );
      },
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
    final leftPreviewTier = previewTier == 1 ? 3 : 1;
    final rightPreviewTier = previewTier == 2 ? 3 : 2;
    final leftLocked = leftPreviewTier > island.tier;
    final rightLocked = rightPreviewTier > island.tier;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Nền biển trời chuyển sắc kèm núi đá vôi và mây mờ
        CustomPaint(
          painter: _HaLongBayHorizonPainter(),
        ),

        // 2. Hai đảo phụ lơ lửng phía xa trên biển mây khi ở Chế độ Tham quan
        if (!isEditMode) ...[
          Positioned(
            top: 175,
            left: 16,
            child: _DistantFloatingIslandBadge(
              tier: leftPreviewTier,
              isLocked: leftLocked,
              isGreySilhouette: true,
              onTap: onSelectTier != null
                  ? () => onSelectTier!(leftPreviewTier)
                  : null,
            ),
          ),
          Positioned(
            top: 168,
            right: 16,
            child: _DistantFloatingIslandBadge(
              tier: rightPreviewTier,
              isLocked: rightLocked,
              isGreySilhouette: false,
              onTap: onSelectTier != null
                  ? () => onSelectTier!(rightPreviewTier)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _HaLongBayHorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF9AD8E4),
            Color(0xFF66B8CE),
            Color(0xFF3E94AE),
            Color(0xFF28738A),
          ],
          stops: [0.0, 0.32, 0.72, 1.0],
        ).createShader(rect),
    );

    // Dãy núi đá vôi vịnh Hạ Long bên trái & bên phải chân trời
    final leftKarst = Path()
      ..moveTo(0, size.height * 0.34)
      ..lineTo(size.width * 0.06, size.height * 0.21)
      ..lineTo(size.width * 0.13, size.height * 0.26)
      ..lineTo(size.width * 0.19, size.height * 0.19)
      ..lineTo(size.width * 0.28, size.height * 0.34)
      ..close();
    canvas.drawPath(
      leftKarst,
      Paint()..color = const Color(0xFF4B8E9B).withValues(alpha: 0.55),
    );

    final rightKarst = Path()
      ..moveTo(size.width * 0.72, size.height * 0.35)
      ..lineTo(size.width * 0.80, size.height * 0.20)
      ..lineTo(size.width * 0.87, size.height * 0.25)
      ..lineTo(size.width * 0.94, size.height * 0.17)
      ..lineTo(size.width, size.height * 0.35)
      ..close();
    canvas.drawPath(
      rightKarst,
      Paint()..color = const Color(0xFF448390).withValues(alpha: 0.52),
    );

    // Lớp mây bồng bềnh quanh đảo
    final cloudPaint = Paint()
      ..color = const Color(0xFFFFFBF2).withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.20, size.height * 0.36),
        width: size.width * 0.42,
        height: 44,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.34),
        width: size.width * 0.40,
        height: 42,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.86),
        width: size.width * 0.85,
        height: 64,
      ),
      cloudPaint,
    );
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
