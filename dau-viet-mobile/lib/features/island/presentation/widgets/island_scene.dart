import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';
import 'island_slot_widget.dart';

/// Trạng thái chuyển tiếp khi người học mở rộng Đảo Di Sản từ `fromTier` sang `toTier`
/// (ISLAND-07 Part B).
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

  /// Phase 2 (0.00 -> 0.38): Camera di chuyển mượt tới bao quát vùng đất mới.
  double get cameraProgress =>
      Curves.easeInOutCubic.transform((progress / 0.38).clamp(0.0, 1.0));

  /// Phase 3 (0.24 -> 0.74): Vùng đất mới (`fromTier < unlockTier <= toTier`) hiện rõ dần.
  double get landRevealProgress => Curves.easeOutCubic.transform(
    ((progress - 0.24) / 0.50).clamp(0.0, 1.0),
  );

  /// Phase 4 (0.64 -> 1.00): Các slot mới mở xuất hiện lần lượt nhẹ nhàng.
  double get slotRevealProgress =>
      ((progress - 0.64) / 0.36).clamp(0.0, 1.0);
}

/// Canvas 2.5D Vietnamese Heritage Illustrated Diorama hiển thị Đảo Di Sản.
/// Tối ưu (ISLAND-07):
/// - A1: Auto-fit camera dựa trên kích thước thực tế của viewport và vùng đất đã mở,
///   cho phép thu nhỏ tới `minScale = 0.28` để không cắt đảo trên màn hình nhỏ.
/// - A4: Chỉ dùng fallback layers khi `sceneLayers.isEmpty` (legacy); tôn trọng tuyệt đối
///   danh sách và thứ tự layer đã publish của Admin.
/// - A5: Chỉ nối hai vùng đất khi chúng thực sự chồng lấn hoặc kề sát nhau và không có
///   vùng khóa chắn giữa.
/// - B3: Hỗ trợ chuỗi animation mở rộng vùng đất mới + mở slot mới.
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

class _CachedLandGeometry {
  final String key;
  final List<IslandSlotDto> sortedSlots;
  final List<(IslandLayoutRegionDto, Rect)> lockedRegions;
  final Path baseLandPath;
  final Path fullUnlockedLandPath;
  final Path? newlyExpandedLandPath;

  const _CachedLandGeometry({
    required this.key,
    required this.sortedSlots,
    required this.lockedRegions,
    required this.baseLandPath,
    required this.fullUnlockedLandPath,
    required this.newlyExpandedLandPath,
  });
}

class _IslandSceneState extends State<IslandScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waterController;
  late final Animation<double> _waterRipple;

  static const double _defaultCanvasWidth = 960.0;
  static const double _defaultCanvasHeight = 720.0;
  static const double _viewerMinScale = 0.28;
  static const double _viewerMaxScale = 2.40;

  Size? _lastViewportSize;
  int? _lastFittedTier;
  String? _lastFittedVersionId;
  int _lastResetCameraVersion = 0;
  Matrix4? _expansionCameraStartMatrix;
  _CachedLandGeometry? _cachedGeometry;

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

    // Khi bắt đầu chuỗi animation mở rộng đảo: chụp lại ma trận camera hiện tại
    // để nội suy mượt mà từ góc nhìn đang đứng tới vùng đất mới (Phase 2).
    if (widget.expansionTransition != null &&
        oldWidget.expansionTransition == null) {
      _expansionCameraStartMatrix =
          widget.transformationController?.value.clone();
    } else if (widget.expansionTransition == null &&
        oldWidget.expansionTransition != null) {
      _expansionCameraStartMatrix = null;
    }

    if (widget.expansionTransition != null && _lastViewportSize != null) {
      _applyInterpolatedExpansionCamera(
        _lastViewportSize!,
        widget.expansionTransition!,
      );
      return;
    }

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

  /// Phân tách các vùng đất theo Tier:
  /// - `baseUnlockedRects`: đã mở từ trước (`unlockTier <= baseTier`)
  /// - `expandingRects`: đang mở mới trong chuỗi animation (`fromTier < unlockTier <= toTier`)
  /// - `lockedRegions`: chưa mở (`unlockTier > toTier`)
  ({
    List<Rect> baseUnlockedRects,
    List<Rect> expandingRects,
    List<Rect> allUnlockedRects,
    List<(IslandLayoutRegionDto, Rect)> lockedRegions,
  }) _resolveRegions(
    double canvasWidth,
    double canvasHeight, {
    int? overrideTargetTier,
  }) {
    final transition = widget.expansionTransition;
    final baseTier = overrideTargetTier ??
        (transition != null ? transition.fromTier : widget.island.tier);
    final targetTier = overrideTargetTier ??
        (transition != null ? transition.toTier : widget.island.tier);

    final baseUnlockedRects = <Rect>[];
    final expandingRects = <Rect>[];
    final allUnlockedRects = <Rect>[];
    final lockedRegions = <(IslandLayoutRegionDto, Rect)>[];

    if (widget.island.regions.isNotEmpty) {
      for (final r in widget.island.regions) {
        final norm = r.parseNormalizedBounds();
        if (norm == null) continue;
        final rawLeft = (norm.left * canvasWidth).clamp(0.0, canvasWidth);
        final rawTop = (norm.top * canvasHeight).clamp(0.0, canvasHeight);
        final rawRight =
            ((norm.left + norm.width) * canvasWidth).clamp(0.0, canvasWidth);
        final rawBottom =
            ((norm.top + norm.height) * canvasHeight).clamp(0.0, canvasHeight);
        if (rawRight - rawLeft <= 4.0 || rawBottom - rawTop <= 4.0) continue;

        final pixelRect = Rect.fromLTRB(rawLeft, rawTop, rawRight, rawBottom);
        final isUnlockedInTarget = overrideTargetTier != null
            ? r.unlockTier <= targetTier
            : (r.unlocked && r.unlockTier <= targetTier) ||
                  r.unlockTier <= targetTier;
        if (!isUnlockedInTarget) {
          lockedRegions.add((r, pixelRect));
        } else {
          allUnlockedRects.add(pixelRect);
          if (overrideTargetTier == null &&
              transition != null &&
              r.unlockTier > baseTier) {
            expandingRects.add(pixelRect);
          } else {
            baseUnlockedRects.add(pixelRect);
          }
        }
      }
    } else {
      // Chỉ suy diễn vùng đất từ slot khi layout hoàn toàn không khai báo regions (legacy)
      final unlockedSlotRects = <Rect>[];
      for (final s in widget.island.slots) {
        if (s.unlocked && s.unlockTier <= targetTier) {
          final sw = (s.widthNorm * canvasWidth).clamp(72.0, 150.0);
          final sh = (s.heightNorm * canvasHeight).clamp(76.0, 160.0);
          final cx = (s.x * canvasWidth).clamp(0.0, canvasWidth);
          final cy = (s.y * canvasHeight).clamp(0.0, canvasHeight);
          unlockedSlotRects.add(
            Rect.fromCenter(
              center: Offset(cx, cy - sh * 0.15),
              width: sw * 1.45,
              height: sh * 1.25,
            ),
          );
        }
      }
      if (unlockedSlotRects.isNotEmpty) {
        Rect combined = unlockedSlotRects.first;
        for (final r in unlockedSlotRects.skip(1)) {
          combined = combined.expandToInclude(r);
        }
        final inflated = combined.inflate(28).intersect(
          Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        );
        if (inflated.width > 4 && inflated.height > 4) {
          baseUnlockedRects.add(inflated);
          allUnlockedRects.add(inflated);
        }
      }
    }

    return (
      baseUnlockedRects: baseUnlockedRects,
      expandingRects: expandingRects,
      allUnlockedRects: allUnlockedRects,
      lockedRegions: lockedRegions,
    );
  }

  /// Kiểm tra hai hình chữ nhật vùng đất có thực sự chồng lấn hoặc kề sát nhau
  /// và không bị một vùng khóa nào chắn ở giữa hay không (ISLAND-07 Part A5 / ISLAND-08 C2).
  static bool _areRegionsDirectlyAdjacent(
    Rect a,
    Rect b,
    List<(IslandLayoutRegionDto, Rect)> lockedRegions,
  ) {
    final overlapX = math.min(a.right, b.right) - math.max(a.left, b.left);
    final overlapY = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);

    final verticalGap = math.max(a.top, b.top) - math.min(a.bottom, b.bottom);
    final horizontalGap =
        math.max(a.left, b.left) - math.min(a.right, b.right);

    final directlyOverlapping = overlapX > 12.0 && overlapY > 12.0;
    final verticallyAdjacent = verticalGap <= 24.0 && overlapX >= 48.0;
    final horizontallyAdjacent = horizontalGap <= 24.0 && overlapY >= 48.0;

    if (!directlyOverlapping &&
        !verticallyAdjacent &&
        !horizontallyAdjacent) {
      return false;
    }

    // Kiểm tra có vùng khóa nào chắn giữa tâm hai vùng không
    final bridgeCheck = Rect.fromPoints(a.center, b.center).inflate(6);
    for (final (_, lockedRect) in lockedRegions) {
      final inter = bridgeCheck.intersect(lockedRect.deflate(8));
      if (inter.width > 6 && inter.height > 6) {
        return false;
      }
    }
    return true;
  }

  /// Xây dựng đường bao địa hình (Path) cho danh sách vùng đất:
  /// Chỉ nối cầu đất giữa những cặp vùng thực sự liền kề hoặc chồng lấn (A5)
  /// và trừ bỏ phần diện tích của vùng khóa không nằm trong vùng đã mở (C2).
  static Path _buildConnectedLandmassPath(
    List<Rect> rects,
    List<(IslandLayoutRegionDto, Rect)> lockedRegions,
    double canvasWidth,
    double canvasHeight, {
    bool allowFallbackWhenEmpty = true,
  }) {
    if (rects.isEmpty) {
      if (!allowFallbackWhenEmpty) return Path();
      final fallback = Rect.fromCenter(
        center: Offset(canvasWidth * 0.5, canvasHeight * 0.32),
        width: canvasWidth * 0.72,
        height: canvasHeight * 0.38,
      );
      return Path()
        ..addRRect(RRect.fromRectAndRadius(fallback, const Radius.circular(90)));
    }

    Path combined = Path();
    for (int i = 0; i < rects.length; i++) {
      final r = rects[i];
      final radius = math.min(r.width, r.height) * 0.40;
      final part = Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
      combined = i == 0
          ? part
          : Path.combine(PathOperation.union, combined, part);
    }

    // Chỉ tạo dải nối mềm giữa các cặp vùng thực sự liền kề/chồng lấn
    for (int i = 0; i < rects.length; i++) {
      for (int j = i + 1; j < rects.length; j++) {
        final a = rects[i];
        final b = rects[j];
        if (!_areRegionsDirectlyAdjacent(a, b, lockedRegions)) continue;

        final overlapLeft = math.max(a.left, b.left) + 24.0;
        final overlapRight = math.min(a.right, b.right) - 24.0;
        if (overlapRight > overlapLeft) {
          final top = math.min(a.bottom - 28.0, b.bottom - 28.0);
          final bottom = math.max(a.top + 28.0, b.top + 28.0);
          if (bottom > top) {
            final bridge = Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTRB(overlapLeft, top, overlapRight, bottom),
                  const Radius.circular(42),
                ),
              );
            combined = Path.combine(PathOperation.union, combined, bridge);
          }
        }

        final overlapTop = math.max(a.top, b.top) + 24.0;
        final overlapBottom = math.min(a.bottom, b.bottom) - 24.0;
        if (overlapBottom > overlapTop) {
          final left = math.min(a.right - 28.0, b.right - 28.0);
          final right = math.max(a.left + 28.0, b.left + 28.0);
          if (right > left) {
            final hBridge = Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTRB(left, overlapTop, right, overlapBottom),
                  const Radius.circular(42),
                ),
              );
            combined = Path.combine(PathOperation.union, combined, hBridge);
          }
        }
      }
    }

    // Loại trừ phần diện tích vùng đang khóa nằm ngoài các vùng đã mở để cầu đất không bao giờ đè qua vùng khóa
    if (lockedRegions.isNotEmpty) {
      Path rawUnlockedUnion = Path();
      for (int i = 0; i < rects.length; i++) {
        final r = rects[i];
        final radius = math.min(r.width, r.height) * 0.40;
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
        rawUnlockedUnion = i == 0
            ? p
            : Path.combine(PathOperation.union, rawUnlockedUnion, p);
      }

      for (final (_, lockedRect) in lockedRegions) {
        final lockedRadius =
            math.min(lockedRect.width, lockedRect.height) * 0.36;
        final lockedPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(lockedRect, Radius.circular(lockedRadius)),
          );
        final strictlyLocked = Path.combine(
          PathOperation.difference,
          lockedPath,
          rawUnlockedUnion,
        );
        combined = Path.combine(
          PathOperation.difference,
          combined,
          strictlyLocked,
        );
      }
    }

    return combined;
  }

  /// Tính ma trận camera căn vừa khít vùng đất đã mở với khoảng đệm hợp lý (Part A1 / C1).
  Matrix4 _computeTargetCameraMatrix(Size viewportSize, {int? forTier}) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Matrix4.identity();
    }
    final cw = _canvasWidth;
    final ch = _canvasHeight;
    final regionInfo = _resolveRegions(cw, ch, overrideTargetTier: forTier);

    Rect focusBounds;
    if (regionInfo.allUnlockedRects.isNotEmpty) {
      focusBounds = regionInfo.allUnlockedRects.first;
      for (final r in regionInfo.allUnlockedRects.skip(1)) {
        focusBounds = focusBounds.expandToInclude(r);
      }
      // Padding вокруг vùng đất đã mở để bờ đảo không chạm sát mép màn hình
      const padX = 44.0;
      const padTop = 44.0;
      final padBottom = widget.island.isMaxTier ? 52.0 : 84.0;
      focusBounds = Rect.fromLTRB(
        math.max(0.0, focusBounds.left - padX),
        math.max(0.0, focusBounds.top - padTop),
        math.min(cw, focusBounds.right + padX),
        math.min(ch, focusBounds.bottom + padBottom),
      );
    } else {
      focusBounds = Rect.fromLTWH(0, 0, cw, ch);
    }

    final safeWidth = math.max(120.0, focusBounds.width);
    final safeHeight = math.max(120.0, focusBounds.height);

    // Cho phép thu nhỏ theo đúng tỷ lệ thực tế của màn hình (tối thiểu _viewerMinScale = 0.28)
    final scaleX = (viewportSize.width * 0.94) / safeWidth;
    final scaleY = (viewportSize.height * 0.90) / safeHeight;
    final targetScale = math.min(scaleX, scaleY).clamp(
      _viewerMinScale,
      1.18,
    );

    final focusCenter = focusBounds.center;
    final tx = (viewportSize.width / 2.0) - (focusCenter.dx * targetScale);
    final ty = (viewportSize.height / 2.0) - (focusCenter.dy * targetScale);

    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
  }

  void _applyAutoFitCamera(Size viewportSize) {
    final controller = widget.transformationController;
    if (controller == null ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      return;
    }

    controller.value = _computeTargetCameraMatrix(viewportSize);
    _lastFittedTier = widget.island.tier;
    _lastFittedVersionId = widget.island.layoutVersionId;
  }

  void _applyInterpolatedExpansionCamera(
    Size viewportSize,
    IslandExpansionTransition transition,
  ) {
    final controller = widget.transformationController;
    if (controller == null ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      return;
    }
    final targetMatrix = _computeTargetCameraMatrix(
      viewportSize,
      forTier: transition.toTier,
    );
    final startMatrix = _expansionCameraStartMatrix ?? targetMatrix;
    final t = transition.cameraProgress;
    controller.value = Matrix4Tween(
      begin: startMatrix,
      end: targetMatrix,
    ).transform(t);
    _lastFittedTier = widget.island.tier;
    _lastFittedVersionId = widget.island.layoutVersionId;
  }

  /// Danh sách scene layers (Part A4):
  /// - Chỉ dùng fallback mặc định khi `widget.island.sceneLayers.isEmpty` (layout legacy).
  /// - Khi layout đã có `sceneLayers`, tôn trọng nguyên trạng cấu hình và `renderOrder`
  ///   của Admin, không tự ý chèn thêm layer.
  List<IslandSceneLayerDto> _effectiveLayers() {
    if (widget.island.sceneLayers.isEmpty) {
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

    final visible = widget.island.sceneLayers
        .where((l) => l.isVisibleForTier(widget.island.tier))
        .toList()
      ..sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
    return visible;
  }

  _CachedLandGeometry _ensureCachedGeometry(
    double canvasWidth,
    double canvasHeight,
  ) {
    final transition = widget.expansionTransition;
    final cacheKey = [
      widget.island.layoutVersionId ?? widget.island.layoutCode ?? 'default',
      widget.island.rowVersion,
      widget.island.tier,
      transition?.fromTier ?? -1,
      transition?.toTier ?? -1,
      canvasWidth.toStringAsFixed(1),
      canvasHeight.toStringAsFixed(1),
      widget.island.slots.length,
      widget.island.regions.length,
    ].join('|');

    final existing = _cachedGeometry;
    if (existing != null && existing.key == cacheKey) {
      return existing;
    }

    final regionUnlockByCode = <String, int>{
      for (final r in widget.island.regions) r.regionCode: r.unlockTier,
    };

    final effectiveTier = transition != null
        ? transition.toTier
        : widget.island.tier;

    final sortedSlots = widget.island.slots.map((s) {
      final regionLocked =
          s.regionCode != null &&
          regionUnlockByCode.containsKey(s.regionCode) &&
          regionUnlockByCode[s.regionCode]! > effectiveTier;
      final slotUnlocked =
          !regionLocked && s.unlocked && s.unlockTier <= effectiveTier;
      return s.unlocked == slotUnlocked ? s : s.copyWith(unlocked: slotUnlocked);
    }).toList()
      ..sort((a, b) {
        if (a.zIndex != b.zIndex) return a.zIndex.compareTo(b.zIndex);
        return a.y.compareTo(b.y);
      });

    final regionInfo = _resolveRegions(canvasWidth, canvasHeight);
    final allowFallback = widget.island.regions.isEmpty;

    final baseLandPath = _buildConnectedLandmassPath(
      regionInfo.baseUnlockedRects,
      regionInfo.lockedRegions,
      canvasWidth,
      canvasHeight,
      allowFallbackWhenEmpty: allowFallback,
    );
    final fullUnlockedLandPath = _buildConnectedLandmassPath(
      regionInfo.allUnlockedRects,
      regionInfo.lockedRegions,
      canvasWidth,
      canvasHeight,
      allowFallbackWhenEmpty: allowFallback,
    );
    final newlyExpandedLandPath = regionInfo.expandingRects.isEmpty
        ? null
        : Path.combine(
            PathOperation.difference,
            fullUnlockedLandPath,
            baseLandPath,
          );

    final built = _CachedLandGeometry(
      key: cacheKey,
      sortedSlots: sortedSlots,
      lockedRegions: regionInfo.lockedRegions,
      baseLandPath: baseLandPath,
      fullUnlockedLandPath: fullUnlockedLandPath,
      newlyExpandedLandPath: newlyExpandedLandPath,
    );
    _cachedGeometry = built;
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _canvasWidth;
    final canvasHeight = _canvasHeight;

    final layers = _effectiveLayers();
    final geom = _ensureCachedGeometry(canvasWidth, canvasHeight);
    final sortedSlots = geom.sortedSlots;
    final baseLandPath = geom.baseLandPath;
    final fullUnlockedLandPath = geom.fullUnlockedLandPath;
    final newlyExpandedLandPath = geom.newlyExpandedLandPath;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final sizeChanged =
            _lastViewportSize == null ||
            (viewportSize.width - _lastViewportSize!.width).abs() > 2.0 ||
            (viewportSize.height - _lastViewportSize!.height).abs() > 2.0;
        final needsInitialFit =
            sizeChanged ||
            _lastFittedTier != widget.island.tier ||
            _lastFittedVersionId != widget.island.layoutVersionId;
        _lastViewportSize = viewportSize;

        if (needsInitialFit && widget.expansionTransition == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyAutoFitCamera(viewportSize);
          });
        }

        return ClipRect(
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: _viewerMinScale,
            maxScale: _viewerMaxScale,
            boundaryMargin: const EdgeInsets.all(180),
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
                        lockedRegions: geom.lockedRegions,
                        baseLandPath: baseLandPath,
                        fullUnlockedLandPath: fullUnlockedLandPath,
                        newlyExpandedLandPath: newlyExpandedLandPath,
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
    required List<(IslandLayoutRegionDto, Rect)> lockedRegions,
    required Path baseLandPath,
    required Path fullUnlockedLandPath,
    required Path? newlyExpandedLandPath,
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
                baseLandPath: baseLandPath,
                fullUnlockedLandPath: fullUnlockedLandPath,
                newlyExpandedLandPath: newlyExpandedLandPath,
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
                baseLandPath: baseLandPath,
                fullUnlockedLandPath: fullUnlockedLandPath,
                newlyExpandedLandPath: newlyExpandedLandPath,
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
                        unlockedLandPath: fullUnlockedLandPath,
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
          unlockedLandPath: fullUnlockedLandPath,
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

  /// Vẽ khối đất Đảo Di Sản theo các Region đã mở khóa và hiệu ứng xuất hiện vùng đất mới (Phase 3).
  Widget _buildClippedIslandTerrain({
    required String? assetRef,
    required double canvasWidth,
    required double canvasHeight,
    required Path baseLandPath,
    required Path fullUnlockedLandPath,
    required Path? newlyExpandedLandPath,
    required List<IslandSlotDto> sortedSlots,
  }) {
    final transition = widget.expansionTransition;
    final unlockedSlotCenters = sortedSlots
        .where((s) => s.unlocked || s.unlockTier <= widget.island.tier)
        .map((s) => Offset(s.x * canvasWidth, s.y * canvasHeight))
        .toList();

    // Khi không có transition mở rộng: vẽ toàn bộ đất đã mở liền mạch
    if (transition == null || newlyExpandedLandPath == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _IslandCliffAndShorePainter(
              landPath: fullUnlockedLandPath,
            ),
          ),
          ClipPath(
            clipper: _LandmassPathClipper(fullUnlockedLandPath),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildRawStaticImageOrFallback(assetRef),
                CustomPaint(
                  painter: _VillageTerrainAccentPainter(
                    landPath: fullUnlockedLandPath,
                    unlockedSlotCenters: unlockedSlotCenters,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Khi đang chạy Phase 3 (mở rộng đảo):
    // - Phần đất cũ (`baseLandPath`) giữ nguyên 100%.
    // - Phần đất mới (`newlyExpandedLandPath`) dần hiện rõ từ lớp sương biển kèm ánh sáng ven bờ.
    final reveal = transition.landRevealProgress;
    final newBounds = newlyExpandedLandPath.getBounds();

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Phần đất cũ giữ nguyên
        CustomPaint(
          painter: _IslandCliffAndShorePainter(landPath: baseLandPath),
        ),
        ClipPath(
          clipper: _LandmassPathClipper(baseLandPath),
          child: _buildRawStaticImageOrFallback(assetRef),
        ),

        // 2. Phần đất mới nổi dần lên với sóng nước & viền sáng ấm
        if (reveal > 0.01)
          Opacity(
            opacity: reveal,
            child: Transform.scale(
              scale: 0.94 + (0.06 * reveal),
              alignment: Alignment(
                ((newBounds.center.dx / canvasWidth) * 2.0) - 1.0,
                ((newBounds.center.dy / canvasHeight) * 2.0) - 1.0,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _IslandCliffAndShorePainter(
                      landPath: fullUnlockedLandPath,
                      expansionGlowProgress: reveal,
                    ),
                  ),
                  ClipPath(
                    clipper: _LandmassPathClipper(fullUnlockedLandPath),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildRawStaticImageOrFallback(assetRef),
                        CustomPaint(
                          painter: _VillageTerrainAccentPainter(
                            landPath: fullUnlockedLandPath,
                            unlockedSlotCenters: unlockedSlotCenters,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final remoteUrl = resolveIslandRemoteAssetUrl(ref);
    if (remoteUrl != null) {
      return Image.network(
        remoteUrl,
        headers: islandAuthHeaders(),
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
    final transition = widget.expansionTransition;
    final newlyUnlockedSlots = transition == null
        ? const <IslandSlotDto>[]
        : sortedSlots
              .where(
                (s) =>
                    s.unlockTier > transition.fromTier &&
                    s.unlockTier <= transition.toTier,
              )
              .toList();

    return [
      Positioned.fill(
        key: ValueKey('layer_$layerKey'),
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final slot in sortedSlots)
                _buildPositionedSlot(
                  slot: slot,
                  canvasWidth: canvasWidth,
                  canvasHeight: canvasHeight,
                  transition: transition,
                  newlyUnlockedSlots: newlyUnlockedSlots,
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildPositionedSlot({
    required IslandSlotDto slot,
    required double canvasWidth,
    required double canvasHeight,
    required IslandExpansionTransition? transition,
    required List<IslandSlotDto> newlyUnlockedSlots,
  }) {
    final slotWidth = (slot.widthNorm * canvasWidth).clamp(74.0, 156.0);
    final slotHeight = (slot.heightNorm * canvasHeight).clamp(82.0, 168.0);
    final rawLeft = (slot.x * canvasWidth) - (slotWidth * slot.anchorX);
    final rawTop = (slot.y * canvasHeight) - (slotHeight * slot.anchorY);
    final left = rawLeft.clamp(8.0, canvasWidth - slotWidth - 8.0);
    final top = rawTop.clamp(8.0, canvasHeight - slotHeight - 8.0);
    final isSelected = slot.slotId == widget.selectedSlotId;

    // Tính tiến độ xuất hiện staggered cho các slot mới mở ở Phase 4
    double revealProgress = 1.0;
    if (transition != null &&
        slot.unlockTier > transition.fromTier &&
        slot.unlockTier <= transition.toTier) {
      final idx = newlyUnlockedSlots.indexWhere((s) => s.slotId == slot.slotId);
      final count = math.max(1, newlyUnlockedSlots.length);
      final staggerStart = (idx.clamp(0, count - 1) / count) * 0.45;
      final rawP = transition.slotRevealProgress;
      revealProgress = ((rawP - staggerStart) / (1.0 - staggerStart)).clamp(
        0.0,
        1.0,
      );
    }

    final isEffectTarget = widget.activeEffectSlotId == slot.slotId;

    return Positioned(
      key: ValueKey('slot_${slot.slotId}'),
      left: left,
      top: top,
      child: IslandSlotWidget(
        slot: slot,
        width: slotWidth,
        height: slotHeight,
        isSelected: isSelected,
        revealProgress: revealProgress,
        placementEffectToken: isEffectTarget ? widget.placementEffectToken : 0,
        removalEffectToken: isEffectTarget ? widget.removalEffectToken : 0,
        onTap: () => widget.onSelectSlot(slot),
      ),
    );
  }

  Widget _buildWaterBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.1),
          radius: 0.95,
          colors: [
            Color(0xFF8CC5D6),
            Color(0xFF5A9AB3),
            Color(0xFF39728C),
          ],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
    );
  }

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

class _IslandCliffAndShorePainter extends CustomPainter {
  final Path landPath;
  final double? expansionGlowProgress;

  const _IslandCliffAndShorePainter({
    required this.landPath,
    this.expansionGlowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      landPath.shift(const Offset(0, 22)),
      Paint()
        ..color = const Color(0x40163242)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawPath(
      landPath.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0x55E0F7FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeJoin = StrokeJoin.round,
    );

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

    canvas.drawPath(
      landPath,
      Paint()
        ..color = const Color(0xFFD8B878)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round,
    );

    // Ánh sáng vàng dịu và vòng gợn sóng quanh bờ đất mới mở (Phase 3)
    if (expansionGlowProgress != null) {
      final p = expansionGlowProgress!.clamp(0.0, 1.0);
      final glowAlpha = (1.0 - (p - 0.5).abs() * 1.6).clamp(0.0, 1.0) * 0.65;
      if (glowAlpha > 0.02) {
        canvas.drawPath(
          landPath,
          Paint()
            ..color = DauVietColors.imperialGold.withValues(alpha: glowAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16 + (p * 10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslandCliffAndShorePainter oldDelegate) {
    return oldDelegate.landPath != landPath ||
        oldDelegate.expansionGlowProgress != expansionGlowProgress;
  }
}

class _VillageTerrainAccentPainter extends CustomPainter {
  final Path landPath;
  final List<Offset> unlockedSlotCenters;

  const _VillageTerrainAccentPainter({
    required this.landPath,
    required this.unlockedSlotCenters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      landPath,
      Paint()
        ..color = const Color(0x885C8D40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );

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
