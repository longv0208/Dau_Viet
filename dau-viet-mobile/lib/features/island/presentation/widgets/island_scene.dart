import 'package:flutter/material.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';
import 'island_slot_widget.dart';

/// Canvas isometric 2.5D hiển thị đảo di sản, hỗ trợ pan & zoom qua [InteractiveViewer].
/// Đọc trực tiếp sceneLayers, regions và slots từ layout version (ISLAND-03/04).
class IslandScene extends StatefulWidget {
  final IslandDto island;
  final String? selectedSlotId;
  final ValueChanged<IslandSlotDto?> onSelectSlot;
  final TransformationController? transformationController;

  const IslandScene({
    super.key,
    required this.island,
    required this.selectedSlotId,
    required this.onSelectSlot,
    this.transformationController,
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

  @override
  void initState() {
    super.initState();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _waterRipple = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waterController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
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
    final canvasWidth = widget.island.canvasWidth > 0
        ? widget.island.canvasWidth
        : _defaultCanvasWidth;
    final canvasHeight = widget.island.canvasHeight > 0
        ? widget.island.canvasHeight
        : _defaultCanvasHeight;

    final sortedSlots = List<IslandSlotDto>.from(widget.island.slots)
      ..sort((a, b) {
        if (a.zIndex != b.zIndex) return a.zIndex.compareTo(b.zIndex);
        return a.y.compareTo(b.y);
      });

    final layers = _effectiveLayers();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.65,
            maxScale: 2.2,
            boundaryMargin: const EdgeInsets.all(120),
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
                        layer,
                        canvasWidth,
                        canvasHeight,
                        sortedSlots,
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

  List<Widget> _buildLayerWidgets(
    IslandSceneLayerDto layer,
    double canvasWidth,
    double canvasHeight,
    List<IslandSlotDto> sortedSlots,
  ) {
    switch (layer.layerType) {
      case 'ANIMATED_WATER':
        return [Positioned.fill(child: _buildWaterBackground())];
      case 'STATIC_IMAGE':
        return [
          Positioned.fill(child: _buildStaticImageLayer(layer.assetRef)),
        ];
      case 'FALLBACK_GRAPHICS':
        return [Positioned.fill(child: _buildFallbackIslandGraphics())];
      case 'AMBIENT_OVERLAY':
        return [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _waterRipple,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WaterAmbientPainter(progress: _waterRipple.value),
                  );
                },
              ),
            ),
          ),
        ];
      case 'REGION_OVERLAY':
        return _buildRegionOverlayWidgets(canvasWidth, canvasHeight);
      case 'ITEM_LAYER':
        return _buildSlotWidgets(canvasWidth, canvasHeight, sortedSlots);
      default:
        return const [];
    }
  }

  Widget _buildStaticImageLayer(String? assetRef) {
    final ref = assetRef?.trim();
    if (ref == null || ref.isEmpty) {
      return _buildFallbackIslandGraphics();
    }
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return Image.network(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIslandGraphics(),
      );
    }
    if (ref.startsWith('/api/')) {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      return Image.network(
        '$base$ref',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIslandGraphics(),
      );
    }
    return Image.asset(
      ref,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackIslandGraphics(),
    );
  }

  /// Vẽ lớp sương khóa cho các vùng đất chưa mở theo Tier,
  /// loại trừ (clip) hoàn toàn các vùng đã mở để không bao giờ che vùng đang chơi.
  List<Widget> _buildRegionOverlayWidgets(
    double canvasWidth,
    double canvasHeight,
  ) {
    final regions = widget.island.regions;
    if (regions.isEmpty) return const [];

    final unlockedRects = <Rect>[];
    final lockedRegions = <(IslandLayoutRegionDto, Rect)>[];

    for (final r in regions) {
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

    if (lockedRegions.isEmpty) return const [];

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _LockedRegionOverlayPainter(
              lockedRegions: lockedRegions,
              unlockedRects: unlockedRects,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSlotWidgets(
    double canvasWidth,
    double canvasHeight,
    List<IslandSlotDto> sortedSlots,
  ) {
    return sortedSlots.map((slot) {
      final slotWidth = (slot.widthNorm * canvasWidth).clamp(72.0, 160.0);
      final slotHeight = (slot.heightNorm * canvasHeight).clamp(80.0, 176.0);
      final left = (slot.x * canvasWidth) - (slotWidth * slot.anchorX);
      final top = (slot.y * canvasHeight) - (slotHeight * slot.anchorY);
      final isSelected = !slot.isLocked && slot.slotId == widget.selectedSlotId;

      return Positioned(
        left: left,
        top: top,
        child: IslandSlotWidget(
          slot: slot,
          width: slotWidth,
          height: slotHeight,
          isSelected: isSelected,
          onTap: slot.isLocked ? null : () => widget.onSelectSlot(slot),
        ),
      );
    }).toList();
  }

  /// Nền nước biển chuyển sắc xanh lam giang
  Widget _buildWaterBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Color(0xFF86B9CF), // Xanh biển tươi ở tâm
            Color(0xFF4A89A6), // Xanh sẫm ngoài rìa
          ],
        ),
      ),
    );
  }

  /// Nền đảo dự phòng khi asset ảnh chưa nạp xong
  Widget _buildFallbackIslandGraphics() {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F4F8), Color(0xFFC7E2E6)],
        ),
      ),
      child: Container(
        width: 600,
        height: 380,
        decoration: BoxDecoration(
          color: const Color(0xFFD6C29E),
          borderRadius: const BorderRadius.all(Radius.elliptical(600, 380)),
          border: Border.all(color: DauVietColors.woodBrown, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 16),
              blurRadius: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter vẽ lớp sương mù nhẹ trên các vùng đất chưa mở khóa,
/// dùng PathOperation.difference để không bao giờ che vùng đất đã mở.
class _LockedRegionOverlayPainter extends CustomPainter {
  final List<(IslandLayoutRegionDto, Rect)> lockedRegions;
  final List<Rect> unlockedRects;

  _LockedRegionOverlayPainter({
    required this.lockedRegions,
    required this.unlockedRects,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Path unlockedPath = Path();
    for (final rect in unlockedRects) {
      unlockedPath.addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      );
    }

    final fillPaint = Paint()
      ..color = const Color(0x521E293B)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = DauVietColors.imperialGoldLight.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final (region, rect) in lockedRegions) {
      Path lockedPath = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));
      final visibleLockedPath = Path.combine(
        PathOperation.difference,
        lockedPath,
        unlockedPath,
      );

      canvas.drawPath(visibleLockedPath, fillPaint);
      canvas.drawPath(visibleLockedPath, borderPaint);

      final bounds = visibleLockedPath.getBounds();
      if (bounds.width > 80 && bounds.height > 28) {
        final label =
            '${region.label ?? region.regionCode} • Mở ở Cấp đảo ${region.unlockTier}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: DauVietTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width - 16);

        final badgeWidth = textPainter.width + 20;
        final badgeHeight = textPainter.height + 8;
        final badgeCenter = Offset(
          bounds.center.dx,
          bounds.top + (bounds.height * 0.25).clamp(18.0, bounds.height - 18.0),
        );
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: badgeCenter,
            width: badgeWidth,
            height: badgeHeight,
          ),
          const Radius.circular(12),
        );

        canvas.drawRRect(
          badgeRect,
          Paint()..color = const Color(0xCC30251F),
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
  bool shouldRepaint(covariant _LockedRegionOverlayPainter oldDelegate) {
    return oldDelegate.lockedRegions != lockedRegions ||
        oldDelegate.unlockedRects != unlockedRects;
  }
}

/// Painter vẽ các đường gợn sóng nước phản chiếu ánh sáng nhẹ.
class _WaterAmbientPainter extends CustomPainter {
  final double progress;

  _WaterAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 + (progress * 0.06))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Vài đường gợn nước elip góc biển
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, size.height * 0.78),
        width: 140 + (progress * 20),
        height: 40 + (progress * 10),
      ),
      paint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.32),
        width: 180 + (progress * 25),
        height: 50 + (progress * 12),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
