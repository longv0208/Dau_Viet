import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';
import 'island_slot_widget.dart';

/// Canvas 2.5D Vietnamese Heritage Illustrated Diorama hiển thị Đảo Di Sản,
/// hỗ trợ pan & zoom qua [InteractiveViewer] và tự động mở rộng diện tích đất
/// thực tế theo các vùng (regions) đã mở khóa ở Tier 1 (Đảo nhỏ), Tier 2 (Đảo vừa),
/// Tier 3 (Đảo lớn).
class IslandScene extends StatefulWidget {
  final IslandDto island;
  final String? selectedSlotId;
  final ValueChanged<IslandSlotDto?> onSelectSlot;
  final TransformationController? transformationController;
  final int resetCameraVersion;

  const IslandScene({
    super.key,
    required this.island,
    required this.selectedSlotId,
    required this.onSelectSlot,
    this.transformationController,
    this.resetCameraVersion = 0,
  });

  @override
  State<IslandScene> createState() => _IslandSceneState();
}

class _IslandSceneState extends State<IslandScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waterController;
  late final Animation<double> _waterRipple;

  static const double _defaultCanvasWidth = 960.0;
  static const double _defaultCanvasHeight = 720.0;

  Size? _lastViewportSize;
  int? _lastFittedTier;
  String? _lastFittedVersionId;
  int _lastResetCameraVersion = 0;

  @override
  void initState() {
    super.initState();
    _lastResetCameraVersion = widget.resetCameraVersion;
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _waterRipple = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waterController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(covariant IslandScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tierChanged = widget.island.tier != oldWidget.island.tier;
    final layoutChanged =
        widget.island.layoutVersionId != oldWidget.island.layoutVersionId;
    final resetRequested =
        widget.resetCameraVersion != _lastResetCameraVersion;

    if ((tierChanged || layoutChanged || resetRequested) &&
        _lastViewportSize != null) {
      _lastResetCameraVersion = widget.resetCameraVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastViewportSize == null) return;
        _applyAutoFitCamera(_lastViewportSize!);
      });
    }
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  double get _canvasWidth => widget.island.canvasWidth > 0
      ? widget.island.canvasWidth
      : _defaultCanvasWidth;

  double get _canvasHeight => widget.island.canvasHeight > 0
      ? widget.island.canvasHeight
      : _defaultCanvasHeight;

  /// Giải mã danh sách vùng đã mở và vùng chưa mở từ `island.regions` (hoặc suy
  /// từ toạ độ slot theo `unlockTier` nếu layout chưa khai báo regions).
  ({
    List<Rect> unlockedRects,
    List<(IslandLayoutRegionDto, Rect)> lockedRegions,
  }) _resolveRegions(double canvasWidth, double canvasHeight) {
    final unlockedRects = <Rect>[];
    final lockedRegions = <(IslandLayoutRegionDto, Rect)>[];

    if (widget.island.regions.isNotEmpty) {
      for (final r in widget.island.regions) {
        final norm = r.parseNormalizedBounds();
        if (norm == null) continue;
        final pixelRect = Rect.fromLTWH(
          norm.left * canvasWidth,
          norm.top * canvasHeight,
          norm.width * canvasWidth,
          norm.height * canvasHeight,
        );
        if (r.unlocked || r.unlockTier <= widget.island.tier) {
          unlockedRects.add(pixelRect);
        } else {
          lockedRegions.add((r, pixelRect));
        }
      }
    }

    // Bảo đảm mọi slot đã mở đều nằm gọn trong phần đất hiển thị
    final unlockedSlotRects = <Rect>[];
    for (final s in widget.island.slots) {
      if (s.unlocked || s.unlockTier <= widget.island.tier) {
        final sw = (s.widthNorm * canvasWidth).clamp(72.0, 150.0);
        final sh = (s.heightNorm * canvasHeight).clamp(76.0, 160.0);
        final cx = s.x * canvasWidth;
        final cy = s.y * canvasHeight;
        unlockedSlotRects.add(
          Rect.fromCenter(
            center: Offset(cx, cy - sh * 0.15),
            width: sw * 1.45,
            height: sh * 1.25,
          ),
        );
      }
    }

    if (unlockedRects.isEmpty && unlockedSlotRects.isNotEmpty) {
      Rect combined = unlockedSlotRects.first;
      for (final r in unlockedSlotRects.skip(1)) {
        combined = combined.expandToInclude(r);
      }
      unlockedRects.add(combined.inflate(28));
    }

    return (unlockedRects: unlockedRects, lockedRegions: lockedRegions);
  }

  /// Xây dựng đường bao địa hình (Path) liên tục cho các vùng đất đã mở.
  /// Khi mở từ Tier 1 -> Tier 2 -> Tier 3, các vùng đất liền kề được nối mượt
  /// thành một hòn đảo thống nhất, không bị tách rời thành 3 hình chữ nhật cứng.
  static Path _buildConnectedLandmassPath(
    List<Rect> unlockedRects,
    double canvasWidth,
    double canvasHeight,
  ) {
    if (unlockedRects.isEmpty) {
      final fallback = Rect.fromCenter(
        center: Offset(canvasWidth * 0.5, canvasHeight * 0.32),
        width: canvasWidth * 0.72,
        height: canvasHeight * 0.38,
      );
      return Path()
        ..addRRect(RRect.fromRectAndRadius(fallback, const Radius.circular(90)));
    }

    final sorted = List<Rect>.from(unlockedRects)
      ..sort((a, b) => a.top.compareTo(b.top));

    Path combined = Path();
    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      // Bo tròn tự nhiên để tạo dáng đảo hữu cơ
      final radius = math.min(r.width, r.height) * 0.42;
      final part = Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
      combined = i == 0
          ? part
          : Path.combine(PathOperation.union, combined, part);

      // Nếu có vùng liền kề phía trên, tạo dải đất nối liền hai vùng
      if (i > 0) {
        final prev = sorted[i - 1];
        final bridgeLeft = math.max(prev.left, r.left) + 28.0;
        final bridgeRight = math.min(prev.right, r.right) - 28.0;
        if (bridgeRight > bridgeLeft) {
          final bridgeTop = math.min(prev.bottom - 36.0, r.top);
          final bridgeBottom = math.max(r.top + 36.0, prev.bottom);
          final bridgeRect = Rect.fromLTRB(
            bridgeLeft,
            bridgeTop,
            bridgeRight,
            bridgeBottom,
          );
          final bridgePath = Path()
            ..addRRect(
              RRect.fromRectAndRadius(bridgeRect, const Radius.circular(48)),
            );
          combined = Path.combine(PathOperation.union, combined, bridgePath);
        }
      }
    }
    return combined;
  }

  /// Tự động căn chỉnh camera (scale + translate) theo quy mô đảo hiện tại
  /// để Tier 1 không bị quá nhỏ, Tier 2 & 3 nhìn rõ phần đất mở rộng.
  void _applyAutoFitCamera(Size viewportSize) {
    final controller = widget.transformationController;
    if (controller == null ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      return;
    }

    final cw = _canvasWidth;
    final ch = _canvasHeight;
    final regionInfo = _resolveRegions(cw, ch);

    Rect focusBounds;
    if (regionInfo.unlockedRects.isNotEmpty) {
      focusBounds = regionInfo.unlockedRects.first;
      for (final r in regionInfo.unlockedRects.skip(1)) {
        focusBounds = focusBounds.expandToInclude(r);
      }
      // Mở rộng nhẹ xuống phía dưới để người học thấy gợi ý bờ nước / vùng kế tiếp
      focusBounds = Rect.fromLTRB(
        (focusBounds.left - 36).clamp(0.0, cw),
        (focusBounds.top - 42).clamp(0.0, ch),
        (focusBounds.right + 36).clamp(0.0, cw),
        (focusBounds.bottom + (widget.island.isMaxTier ? 48 : 96)).clamp(
          0.0,
          ch,
        ),
      );
    } else {
      focusBounds = Rect.fromLTWH(0, 0, cw, ch);
    }

    final scaleX = viewportSize.width / focusBounds.width;
    final scaleY = viewportSize.height / focusBounds.height;
    final minScaleForTier = widget.island.tier == 1
        ? 0.82
        : (widget.island.tier == 2 ? 0.72 : 0.65);
    final maxScaleForTier = widget.island.tier == 1 ? 1.22 : 1.08;
    final targetScale = (math.min(scaleX, scaleY) * 0.92).clamp(
      minScaleForTier,
      maxScaleForTier,
    );

    final focusCenter = focusBounds.center;
    final tx = (viewportSize.width / 2.0) - (focusCenter.dx * targetScale);
    final ty = (viewportSize.height / 2.0) - (focusCenter.dy * targetScale);

    controller.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);

    _lastFittedTier = widget.island.tier;
    _lastFittedVersionId = widget.island.layoutVersionId;
  }

  List<IslandSceneLayerDto> _effectiveLayers() {
    final raw = widget.island.sceneLayers
        .where((l) => l.isVisibleForTier(widget.island.tier))
        .toList();
    if (raw.isEmpty) {
      return const [
        IslandSceneLayerDto(
          layerKey: 'water_bg',
          layerType: 'ANIMATED_WATER',
          renderOrder: 0,
        ),
        IslandSceneLayerDto(
          layerKey: 'island_base',
          layerType: 'STATIC_IMAGE',
          renderOrder: 10,
          assetRef: 'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
        ),
        IslandSceneLayerDto(
          layerKey: 'water_ambient',
          layerType: 'AMBIENT_OVERLAY',
          renderOrder: 20,
        ),
        IslandSceneLayerDto(
          layerKey: 'region_fog',
          layerType: 'REGION_OVERLAY',
          renderOrder: 25,
        ),
        IslandSceneLayerDto(
          layerKey: 'item_layer',
          layerType: 'ITEM_LAYER',
          renderOrder: 30,
        ),
      ];
    }
    raw.sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
    final hasRegionOverlay = raw.any((l) => l.layerType == 'REGION_OVERLAY');
    final hasItemLayer = raw.any((l) => l.layerType == 'ITEM_LAYER');
    if (!hasRegionOverlay) {
      raw.add(
        const IslandSceneLayerDto(
          layerKey: 'auto_region_overlay',
          layerType: 'REGION_OVERLAY',
          renderOrder: 25,
        ),
      );
    }
    if (!hasItemLayer) {
      raw.add(
        const IslandSceneLayerDto(
          layerKey: 'auto_item_layer',
          layerType: 'ITEM_LAYER',
          renderOrder: 30,
        ),
      );
    }
    raw.sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _canvasWidth;
    final canvasHeight = _canvasHeight;

    final sortedSlots = List<IslandSlotDto>.from(widget.island.slots)
      ..sort((a, b) {
        if (a.zIndex != b.zIndex) return a.zIndex.compareTo(b.zIndex);
        return a.y.compareTo(b.y);
      });

    final layers = _effectiveLayers();
    final regionInfo = _resolveRegions(canvasWidth, canvasHeight);
    final unlockedLandPath = _buildConnectedLandmassPath(
      regionInfo.unlockedRects,
      canvasWidth,
      canvasHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final needsInitialFit =
            _lastViewportSize == null ||
            _lastFittedTier != widget.island.tier ||
            _lastFittedVersionId != widget.island.layoutVersionId;
        _lastViewportSize = viewportSize;

        if (needsInitialFit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyAutoFitCamera(viewportSize);
          });
        }

        return ClipRect(
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.58,
            maxScale: 2.2,
            boundaryMargin: const EdgeInsets.all(140),
            constrained: false,
            child: GestureDetector(
              onTap: () => widget.onSelectSlot(null),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final layer in layers)
                      ..._buildLayerWidgets(
                        layer: layer,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        sortedSlots: sortedSlots,
                        unlockedRects: regionInfo.unlockedRects,
                        lockedRegions: regionInfo.lockedRegions,
                        unlockedLandPath: unlockedLandPath,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildLayerWidgets({
    required IslandSceneLayerDto layer,
    required double canvasWidth,
    required double canvasHeight,
    required List<IslandSlotDto> sortedSlots,
    required List<Rect> unlockedRects,
    required List<(IslandLayoutRegionDto, Rect)> lockedRegions,
    required Path unlockedLandPath,
  }) {
    switch (layer.layerType) {
      case 'ANIMATED_WATER':
        return [
          Positioned.fill(
            key: ValueKey('layer_${layer.layerKey}'),
            child: RepaintBoundary(child: _buildWaterBackground()),
          ),
        ];
      case 'STATIC_IMAGE':
        return [
          Positioned.fill(
            key: ValueKey('layer_${layer.layerKey}'),
            child: RepaintBoundary(
              child: _buildClippedIslandTerrain(
                assetRef: layer.assetRef,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                unlockedLandPath: unlockedLandPath,
                sortedSlots: sortedSlots,
              ),
            ),
          ),
        ];
      case 'FALLBACK_GRAPHICS':
        return [
          Positioned.fill(
            key: ValueKey('layer_${layer.layerKey}'),
            child: RepaintBoundary(
              child: _buildClippedIslandTerrain(
                assetRef: null,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                unlockedLandPath: unlockedLandPath,
                sortedSlots: sortedSlots,
              ),
            ),
          ),
        ];
      case 'AMBIENT_OVERLAY':
        return [
          Positioned.fill(
            key: ValueKey('layer_${layer.layerKey}'),
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _waterRipple,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _WaterAmbientPainter(
                        progress: _waterRipple.value,
                        unlockedLandPath: unlockedLandPath,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ];
      case 'REGION_OVERLAY':
        return _buildRegionOverlayWidgets(
          layerKey: layer.layerKey,
          unlockedLandPath: unlockedLandPath,
          lockedRegions: lockedRegions,
        );
      case 'ITEM_LAYER':
        return _buildSlotWidgets(
          layerKey: layer.layerKey,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          sortedSlots: sortedSlots,
        );
      default:
        return const [];
    }
  }

  /// Vẽ khối đất Đảo Di Sản giới hạn đúng theo các Region đã mở khóa:
  /// 1. Bờ đất nổi 2.5D (vách đất nâu ấm + viền cát vàng + bọt sóng ven bờ).
  /// 2. Mặt đảo được clip theo `unlockedLandPath` (không lộ vùng đất chưa mở).
  /// 3. Đường làng lát gạch nối nhẹ giữa các ô đã mở.
  Widget _buildClippedIslandTerrain({
    required String? assetRef,
    required double canvasWidth,
    required double canvasHeight,
    required Path unlockedLandPath,
    required List<IslandSlotDto> sortedSlots,
  }) {
    final unlockedSlotCenters = sortedSlots
        .where((s) => s.unlocked || s.unlockTier <= widget.island.tier)
        .map((s) => Offset(s.x * canvasWidth, s.y * canvasHeight))
        .toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Lớp vách đá/bờ đất 2.5D phía dưới mặt đảo
        CustomPaint(
          painter: _IslandCliffAndShorePainter(landPath: unlockedLandPath),
        ),
        // Lớp mặt đất được cắt theo đúng diện tích đã mở của Tier hiện tại
        ClipPath(
          clipper: _LandmassPathClipper(unlockedLandPath),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildRawStaticImageOrFallback(assetRef),
              CustomPaint(
                painter: _VillageTerrainAccentPainter(
                  landPath: unlockedLandPath,
                  unlockedSlotCenters: unlockedSlotCenters,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRawStaticImageOrFallback(String? assetRef) {
    final ref = assetRef?.trim();
    if (ref == null || ref.isEmpty) {
      return _buildFallbackIslandSurface();
    }
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return Image.network(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIslandSurface(),
      );
    }
    if (ref.startsWith('/api/')) {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      return Image.network(
        '$base$ref',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIslandSurface(),
      );
    }
    return Image.asset(
      ref,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackIslandSurface(),
    );
  }

  /// Vẽ silhouette bãi bồi mờ cho các vùng đất tương lai chưa mở khóa,
  /// dùng `PathOperation.difference` để tuyệt đối không đè lên đất đã mở.
  List<Widget> _buildRegionOverlayWidgets({
    required String layerKey,
    required Path unlockedLandPath,
    required List<(IslandLayoutRegionDto, Rect)> lockedRegions,
  }) {
    if (lockedRegions.isEmpty) return const [];

    return [
      Positioned.fill(
        key: ValueKey('layer_$layerKey'),
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _LockedRegionSilhouettePainter(
                lockedRegions: lockedRegions,
                unlockedLandPath: unlockedLandPath,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSlotWidgets({
    required String layerKey,
    required double canvasWidth,
    required double canvasHeight,
    required List<IslandSlotDto> sortedSlots,
  }) {
    return [
      Positioned.fill(
        key: ValueKey('layer_$layerKey'),
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final slot in sortedSlots)
                _buildPositionedSlot(slot, canvasWidth, canvasHeight),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildPositionedSlot(
    IslandSlotDto slot,
    double canvasWidth,
    double canvasHeight,
  ) {
    final slotWidth = (slot.widthNorm * canvasWidth).clamp(74.0, 156.0);
    final slotHeight = (slot.heightNorm * canvasHeight).clamp(82.0, 168.0);
    final rawLeft = (slot.x * canvasWidth) - (slotWidth * slot.anchorX);
    final rawTop = (slot.y * canvasHeight) - (slotHeight * slot.anchorY);
    // Giữ vật phẩm không bị cắt khi sát mép canvas
    final left = rawLeft.clamp(8.0, canvasWidth - slotWidth - 8.0);
    final top = rawTop.clamp(8.0, canvasHeight - slotHeight - 8.0);
    final isSelected = slot.slotId == widget.selectedSlotId;

    return Positioned(
      key: ValueKey('slot_${slot.slotId}'),
      left: left,
      top: top,
      child: IslandSlotWidget(
        slot: slot,
        width: slotWidth,
        height: slotHeight,
        isSelected: isSelected,
        onTap: () => widget.onSelectSlot(slot),
      ),
    );
  }

  /// Nền sông nước làng quê Việt Nam ấm áp, có chiều sâu
  Widget _buildWaterBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.1),
          radius: 0.95,
          colors: [
            Color(0xFF8CC5D6), // Xanh ngọc nước nông quanh đảo
            Color(0xFF5A9AB3), // Xanh sông sâu vừa
            Color(0xFF39728C), // Xanh lam rìa ngoài
          ],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
    );
  }

  /// Bề mặt thảo nguyên xanh ấm khi không có ảnh nền
  Widget _buildFallbackIslandSurface() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC8DC9B),
            Color(0xFFA6C473),
            Color(0xFF89AE58),
          ],
        ),
      ),
    );
  }
}

class _LandmassPathClipper extends CustomClipper<Path> {
  final Path landPath;

  const _LandmassPathClipper(this.landPath);

  @override
  Path getClip(Size size) => landPath;

  @override
  bool shouldReclip(covariant _LandmassPathClipper oldClipper) {
    return oldClipper.landPath != landPath;
  }
}

/// Vẽ bờ đất 2.5D (vách đất nâu trầm + bờ cỏ/cát vàng + sóng nước ven bờ)
/// bao quanh đúng phần diện tích đảo đã mở khóa.
class _IslandCliffAndShorePainter extends CustomPainter {
  final Path landPath;

  const _IslandCliffAndShorePainter({required this.landPath});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Bóng đổ mềm dưới nước
    canvas.drawPath(
      landPath.shift(const Offset(0, 22)),
      Paint()
        ..color = const Color(0x40163242)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 2. Bọt nước / sóng nông bao quanh bờ đảo
    canvas.drawPath(
      landPath.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x55E0F7FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeJoin = StrokeJoin.round,
    );

    // 3. Vách đất 2.5D phía nam tạo độ dày khối diorama
    canvas.drawPath(
      landPath.shift(const Offset(0, 14)),
      Paint()
        ..color = const Color(0xFF6E4B2A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      landPath.shift(const Offset(0, 7)),
      Paint()
        ..color = const Color(0xFF8C6239)
        ..style = PaintingStyle.fill,
    );

    // 4. Viền bờ cát / đất phù sa ấm quanh mép đảo
    canvas.drawPath(
      landPath,
      Paint()
        ..color = const Color(0xFFD8B878)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _IslandCliffAndShorePainter oldDelegate) {
    return oldDelegate.landPath != landPath;
  }
}

/// Vẽ đường làng uốn lượn nhẹ và viền cỏ xanh bên trong vùng đất đã mở.
class _VillageTerrainAccentPainter extends CustomPainter {
  final Path landPath;
  final List<Offset> unlockedSlotCenters;

  const _VillageTerrainAccentPainter({
    required this.landPath,
    required this.unlockedSlotCenters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Viền cỏ xanh tự nhiên dọc bờ đảo
    canvas.drawPath(
      landPath,
      Paint()
        ..color = const Color(0x885C8D40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

    // Đường đất làng quê nối nhẹ giữa các ô đã mở
    if (unlockedSlotCenters.length >= 2) {
      final pathPaint = Paint()
        ..color = const Color(0x55D9B982)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final road = Path()
        ..moveTo(unlockedSlotCenters.first.dx, unlockedSlotCenters.first.dy);
      for (int i = 1; i < unlockedSlotCenters.length; i++) {
        final prev = unlockedSlotCenters[i - 1];
        final curr = unlockedSlotCenters[i];
        final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        road.quadraticBezierTo(prev.dx, mid.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(road, pathPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VillageTerrainAccentPainter oldDelegate) {
    return oldDelegate.landPath != landPath ||
        oldDelegate.unlockedSlotCenters.length != unlockedSlotCenters.length;
  }
}

/// Painter vẽ hình bóng (silhouette) bãi bồi xa trong sương cho các vùng đất
/// thuộc Tier chưa mở, dùng `PathOperation.difference` để không bao giờ chạm
/// vào diện tích đất đã mở.
class _LockedRegionSilhouettePainter extends CustomPainter {
  final List<(IslandLayoutRegionDto, Rect)> lockedRegions;
  final Path unlockedLandPath;

  const _LockedRegionSilhouettePainter({
    required this.lockedRegions,
    required this.unlockedLandPath,
  });

  static String _tierScaleLabel(int tier) {
    switch (tier) {
      case 2:
        return 'Đảo vừa';
      case 3:
        return 'Đảo lớn';
      default:
        return 'Đảo cấp $tier';
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Mở rộng nhẹ vùng loại trừ để phần gợi ý vùng khóa luôn cách bờ đảo đã mở một khoảng nước nhỏ
    final exclusionBounds = unlockedLandPath.shift(const Offset(0, 12));

    final silhouetteFill = Paint()
      ..color = const Color(0x38284B5A)
      ..style = PaintingStyle.fill;

    final silhouetteStroke = Paint()
      ..color = DauVietColors.imperialGoldLight.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final (region, rect) in lockedRegions) {
      final deflated = rect.deflate(10);
      if (deflated.width <= 0 || deflated.height <= 0) continue;

      final radius = math.min(deflated.width, deflated.height) * 0.40;
      final rawLocked = Path()
        ..addRRect(
          RRect.fromRectAndRadius(deflated, Radius.circular(radius)),
        );
      final visibleLockedPath = Path.combine(
        PathOperation.difference,
        rawLocked,
        exclusionBounds,
      );

      canvas.drawPath(visibleLockedPath, silhouetteFill);
      canvas.drawPath(visibleLockedPath, silhouetteStroke);

      final bounds = visibleLockedPath.getBounds();
      if (bounds.width > 120 && bounds.height > 34) {
        final label =
            '🔒 ${region.label ?? region.regionCode} • Mở ở ${_tierScaleLabel(region.unlockTier)}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: DauVietTypography.bodySmall.copyWith(
              color: const Color(0xFFFDF8EE),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width - 24);

        final badgeWidth = textPainter.width + 22;
        final badgeHeight = textPainter.height + 10;
        final badgeCenter = Offset(
          bounds.center.dx,
          bounds.center.dy.clamp(bounds.top + 20.0, bounds.bottom - 20.0),
        );
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: badgeCenter,
            width: badgeWidth,
            height: badgeHeight,
          ),
          const Radius.circular(14),
        );

        canvas.drawRRect(
          badgeRect,
          Paint()..color = const Color(0xB8263844),
        );
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = DauVietColors.imperialGoldLight.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        textPainter.paint(
          canvas,
          Offset(
            badgeCenter.dx - textPainter.width / 2,
            badgeCenter.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LockedRegionSilhouettePainter oldDelegate) {
    return oldDelegate.lockedRegions != lockedRegions ||
        oldDelegate.unlockedLandPath != unlockedLandPath;
  }
}

/// Painter vẽ các đường gợn sóng nước lấp lánh trên mặt sông ngoài đảo.
class _WaterAmbientPainter extends CustomPainter {
  final double progress;
  final Path unlockedLandPath;

  const _WaterAmbientPainter({
    required this.progress,
    required this.unlockedLandPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10 + (progress * 0.07))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final rippleCenters = <Offset>[
      Offset(size.width * 0.14, size.height * 0.18),
      Offset(size.width * 0.86, size.height * 0.22),
      Offset(size.width * 0.16, size.height * 0.68),
      Offset(size.width * 0.84, size.height * 0.74),
    ];

    for (int i = 0; i < rippleCenters.length; i++) {
      final c = rippleCenters[i];
      if (unlockedLandPath.contains(c)) continue;
      final phase = (progress + (i * 0.25)) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: 90 + (phase * 36),
          height: 24 + (phase * 10),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
