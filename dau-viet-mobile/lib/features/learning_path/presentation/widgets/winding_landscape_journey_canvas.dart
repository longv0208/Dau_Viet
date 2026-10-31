import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/widgets/gamification/gamification_widgets.dart';
import '../../data/learning_path_dto.dart';

/// Một hàng trên canvas hành trình 2.5D.
///
/// - [JourneyCanvasEntry.milestone]: nút mốc trên đường đi — gồm huy hiệu tròn
///   ([badge]) nằm trên con đường và thẻ nội dung ([child]) nổi bên cạnh.
/// - [JourneyCanvasEntry.fullWidth]: hàng rộng toàn khung (tiêu đề ERA/PHASE,
///   nhãn sự kiện hoặc thẻ thời kỳ minh họa) — không có huy hiệu.
class JourneyCanvasEntry {
  final Widget? badge;
  final Widget child;
  final bool cardOnLeft;
  final double? focusX;
  final bool isUnlocked;

  const JourneyCanvasEntry.milestone({
    required Widget badge,
    required Widget child,
    bool cardOnLeft = false,
    double? focusX,
    bool isUnlocked = true,
  }) : this._(
         badge: badge,
         child: child,
         cardOnLeft: cardOnLeft,
         focusX: focusX,
         isUnlocked: isUnlocked,
       );

  const JourneyCanvasEntry.fullWidth({required Widget child})
      : this._(child: child);

  const JourneyCanvasEntry._({
    this.badge,
    required this.child,
    this.cardOnLeft = false,
    this.focusX,
    this.isUnlocked = true,
  });

  bool get isMilestone => badge != null;
}

/// Vòng tròn huy hiệu nằm trên đường hành trình:
/// - [isFeaturedStar] hoặc `mastered` → vòng tròn đỏ viền vàng + ngôi sao vàng (`★`).
/// - Đã hoàn thành (`completed`) → vòng tròn xanh lá `#2E8B57` + dấu kiểm trắng (`✓`).
/// - Đang học / Sẵn sàng học (`inProgress` / `available` / `isSelected`) → vòng tròn
///   đỏ cam phát sáng + icon cuốn sách mở (`Icons.menu_book_rounded`).
/// - Khóa tuần tự (`locked`) → vòng tròn xám `#9E9A90` + ổ khóa trắng (`🔒`).
class JourneyNodeBadge extends StatelessWidget {
  final LearnerPathStatus status;
  final bool isSelected;
  final bool isPeriodNode;
  final bool isFeaturedStar;

  const JourneyNodeBadge({
    super.key,
    required this.status,
    this.isSelected = false,
    this.isPeriodNode = false,
    this.isFeaturedStar = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color borderColor;
    final IconData icon;
    final Color iconColor;
    final bool hasGlow;
    final double size;

    if (isFeaturedStar || status == LearnerPathStatus.mastered) {
      fill = const Color(0xFFC92525);
      borderColor = const Color(0xFFFFE599);
      icon = Icons.star_rounded;
      iconColor = const Color(0xFFFFD54F);
      hasGlow = true;
      size = 50;
    } else if (isSelected ||
        status.isInProgress ||
        (!isPeriodNode && status.isAvailable)) {
      fill = const Color(0xFFC92525);
      borderColor = const Color(0xFFFFF3D1);
      icon = isPeriodNode ? Icons.star_rounded : Icons.menu_book_rounded;
      iconColor = Colors.white;
      hasGlow = true;
      size = 52;
    } else if (status.isDone) {
      fill = const Color(0xFF2E8B57);
      borderColor = Colors.white;
      icon = Icons.check_rounded;
      iconColor = Colors.white;
      hasGlow = false;
      size = 44;
    } else if (status.isNotReady) {
      fill = const Color(0xFF9E9A90);
      borderColor = Colors.white;
      icon = Icons.hourglass_empty_rounded;
      iconColor = Colors.white;
      hasGlow = false;
      size = 44;
    } else if (status == LearnerPathStatus.locked) {
      fill = const Color(0xFF9E9A90);
      borderColor = const Color(0xFFF5F1E8);
      icon = Icons.lock_rounded;
      iconColor = Colors.white;
      hasGlow = false;
      size = 44;
    } else {
      fill = isPeriodNode ? const Color(0xFF247D78) : const Color(0xFFC88A32);
      borderColor = Colors.white;
      icon = Icons.explore_rounded;
      iconColor = Colors.white;
      hasGlow = false;
      size = 46;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasGlow
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill.withValues(alpha: 0.98),
                  const Color(0xFF9E1818),
                ],
              )
            : null,
        color: hasGlow ? null : fill,
        border: Border.all(color: borderColor, width: 3.2),
        boxShadow: [
          if (hasGlow)
            const BoxShadow(
              color: Color(0x88FFB74D),
              blurRadius: 14,
              spreadRadius: 3,
            ),
          const BoxShadow(
            color: Color(0x38261E19),
            offset: Offset(0, 3),
            blurRadius: 7,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: iconColor),
    );
  }
}

/// Canvas Đường đi Phong cảnh 2.5D (`WindingLandscapeJourneyCanvas`):
/// Hỗ trợ 2 chế độ:
/// 1. Bản đồ Hành trình thời kỳ (`cardListMode == false`): nền tranh phong cảnh
///    sông nước, cổng thành và Chú Tê Giác cầm bản đồ + đường cong Catmull-Rom
///    uốn lượn nối các nút mốc tròn.
/// 2. Danh sách thẻ Thời kỳ minh họa (`cardListMode == true`): hiển thị danh sách
///    thẻ thời kỳ rộng trên nền giấy kem.
class WindingLandscapeJourneyCanvas extends StatefulWidget {
  final List<JourneyCanvasEntry> entries;
  final String? backgroundAssetId;
  final String backgroundAsset;
  final String fallbackBackgroundAsset;
  final EdgeInsets contentPadding;
  final bool cardListMode;
  final bool glowingDottedStyle;
  final bool gentleLeftCurve;
  final Widget? headerOverlay;
  final Widget? footerOverlay;
  final double milestoneMinHeight;

  const WindingLandscapeJourneyCanvas({
    super.key,
    required this.entries,
    this.backgroundAssetId,
    this.backgroundAsset = 'assets/images/journey/heritage_scroll_bg.jpg',
    this.fallbackBackgroundAsset = 'assets/images/vietnam_journey_map_bg.jpg',
    this.contentPadding = const EdgeInsets.fromLTRB(12, 20, 12, 32),
    this.cardListMode = false,
    this.glowingDottedStyle = true,
    this.gentleLeftCurve = false,
    this.headerOverlay,
    this.footerOverlay,
    this.milestoneMinHeight = 92,
  });

  @override
  State<WindingLandscapeJourneyCanvas> createState() =>
      _WindingLandscapeJourneyCanvasState();
}

class _WindingLandscapeJourneyCanvasState
    extends State<WindingLandscapeJourneyCanvas>
    with TickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  List<GlobalKey> _badgeKeys = [];
  List<Offset> _badgePoints = const [];

  // Tạo theo nhu cầu để an toàn cả khi hot reload giữ lại State cũ
  // (initState không chạy lại); dispose chỉ hủy controller đã được tạo.
  AnimationController? _entranceCtrl;
  AnimationController? _marchingCtrl;

  AnimationController get _entranceController =>
      _entranceCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        value: 1.0,
      );

  AnimationController get _marchingController =>
      _marchingCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
        value: 0.0,
      );
  bool _animationsStarted = false;

  @override
  void initState() {
    super.initState();
    _syncBadgeKeys();
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _entranceController.stop();
      _marchingController.stop();
      _entranceController.value = 1.0;
      _marchingController.value = 0.0;
      _animationsStarted = true;
    } else if (!_animationsStarted && !widget.cardListMode) {
      _animationsStarted = true;
      _entranceController.forward(from: 0.0);
      _marchingController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant WindingLandscapeJourneyCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBadgeKeys();
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _entranceCtrl?.dispose();
    _marchingCtrl?.dispose();
    super.dispose();
  }

  void _syncBadgeKeys() {
    final milestoneCount =
        widget.entries.where((e) => e.isMilestone).length;
    if (_badgeKeys.length != milestoneCount) {
      _badgeKeys = List.generate(milestoneCount, (_) => GlobalKey());
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBadgePoints());
  }

  void _measureBadgePoints() {
    if (!mounted) return;
    final canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null || !canvasBox.hasSize) return;

    final points = <Offset>[];
    for (final key in _badgeKeys) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final topLeft = renderObject.localToGlobal(
        Offset.zero,
        ancestor: canvasBox,
      );
      points.add(topLeft + renderObject.size.center(Offset.zero));
    }

    bool changed = points.length != _badgePoints.length;
    if (!changed) {
      for (int i = 0; i < points.length; i++) {
        if ((points[i] - _badgePoints[i]).distance > 0.5) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      setState(() => _badgePoints = points);
    }
  }

  int? _computeActiveUpToIndex() {
    int? lastUnlocked;
    int milestoneIdx = 0;
    bool anyLocked = false;
    for (final entry in widget.entries) {
      if (!entry.isMilestone) continue;
      if (entry.isUnlocked) {
        lastUnlocked = milestoneIdx;
      } else {
        anyLocked = true;
      }
      milestoneIdx++;
    }
    if (!anyLocked) return null;
    return lastUnlocked ?? 0;
  }

  static const List<double> _curveIndents = <double>[
    54,
    78,
    92,
    82,
    108,
    118,
    98,
    76,
  ];

  Widget _wrapStaggeredEntrance({
    required Widget child,
    required int milestoneIndex,
    required bool disableAnimations,
  }) {
    if (disableAnimations || widget.cardListMode) return child;
    final double start = (milestoneIndex * 0.07).clamp(0.0, 0.65);
    final double end = (start + 0.35).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, inner) {
        final double raw = _entranceController.value;
        final double t = raw >= end
            ? 1.0
            : (raw <= start ? 0.0 : Curves.easeOutCubic.transform((raw - start) / (end - start)));
        if (t >= 0.999) return inner!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12.0 * (1.0 - t)),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    int milestoneIndex = 0;
    final rows = <Widget>[];
    if (widget.headerOverlay != null) {
      rows.add(widget.headerOverlay!);
    }

    for (final entry in widget.entries) {
      if (entry.isMilestone) {
        final int currentMilestoneIdx = milestoneIndex;
        final badgeKey = _badgeKeys[currentMilestoneIdx];
        final double leftIndent = widget.gentleLeftCurve
            ? _curveIndents[currentMilestoneIdx % _curveIndents.length]
            : 0.0;
        final bool effectiveCardOnLeft = entry.focusX != null
            ? entry.focusX! >= 0.56
            : (widget.gentleLeftCurve ? false : entry.cardOnLeft);
        rows.add(
          _MilestoneRow(
            badge: KeyedSubtree(key: badgeKey, child: entry.badge!),
            cardOnLeft: effectiveCardOnLeft,
            leftIndent: leftIndent,
            focusX: entry.focusX,
            minHeight: widget.milestoneMinHeight,
            child: _wrapStaggeredEntrance(
              child: entry.child,
              milestoneIndex: currentMilestoneIdx,
              disableAnimations: disableAnimations,
            ),
          ),
        );
        milestoneIndex++;
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: entry.child,
          ),
        );
      }
    }

    if (widget.footerOverlay != null) {
      rows.add(widget.footerOverlay!);
    }

    if (widget.cardListMode) {
      return Container(
        key: _canvasKey,
        color: Colors.transparent,
        padding: widget.contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      );
    }

    final int? activeUpToIndex = _computeActiveUpToIndex();

    return Stack(
      key: _canvasKey,
      children: [
        // Nền tranh phong cảnh cổ (tải theo thời kỳ từ DB hoặc fallback cuộn tranh thuỷ mặc).
        Positioned.fill(
          child: _LandscapeBackdrop(
            primaryAssetId: widget.backgroundAssetId,
            primaryAsset: widget.backgroundAsset,
            fallbackAsset: widget.fallbackBackgroundAsset,
          ),
        ),
        // Con đường cong Catmull-Rom uốn lượn mượt xuyên qua tâm các huy hiệu.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _entranceController,
              _marchingController,
            ]),
            builder: (context, _) {
              return CustomPaint(
                painter: WindingStonePathPainter(
                  points: _badgePoints,
                  glowingDottedStyle: widget.glowingDottedStyle,
                  activeUpToIndex: activeUpToIndex,
                  drawProgress: disableAnimations
                      ? 1.0
                      : Curves.easeOutCubic.transform(_entranceController.value),
                  marchingPhase: disableAnimations
                      ? 0.0
                      : _marchingController.value,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: widget.contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// Một hàng nút mốc: huy hiệu tròn và thẻ nội dung nổi bên cạnh.
class _MilestoneRow extends StatelessWidget {
  final Widget badge;
  final Widget child;
  final bool cardOnLeft;
  final double leftIndent;
  final double? focusX;
  final double minHeight;

  const _MilestoneRow({
    required this.badge,
    required this.child,
    required this.cardOnLeft,
    this.leftIndent = 0,
    this.focusX,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rail = SizedBox(
      width: 64,
      child: Center(child: badge),
    );
    final card = Expanded(
      child: Align(
        alignment: cardOnLeft ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: child,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxSafeOffset = math.max(0.0, constraints.maxWidth - 275);
        final double computedIndent;
        if (focusX != null) {
          final clamped = focusX!.clamp(0.15, 0.85);
          if (cardOnLeft) {
            computedIndent = ((0.85 - clamped) / 0.35).clamp(0.0, 1.0) *
                math.min(48.0, maxSafeOffset);
          } else {
            computedIndent = ((clamped - 0.15) / 0.45).clamp(0.0, 1.0) *
                math.min(68.0, maxSafeOffset);
          }
        } else {
          computedIndent =
              leftIndent > 0 ? math.min(leftIndent, maxSafeOffset) : 0.0;
        }
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: cardOnLeft
                ? [
                    card,
                    const SizedBox(width: 6),
                    rail,
                    if (computedIndent > 0) SizedBox(width: computedIndent),
                  ]
                : [
                    if (computedIndent > 0) SizedBox(width: computedIndent),
                    rail,
                    const SizedBox(width: 6),
                    card,
                  ],
          ),
        );
      },
    );
  }
}

/// Nền tranh phong cảnh cuộn dọc không giới hạn chiều cao:
/// - Ưu tiên tải ảnh nền cấu hình riêng theo từng thời kỳ từ DB (`primaryAssetId`)
///   với fallback ảnh cuộn tranh thuỷ mặc (`primaryAsset`).
/// - Khi thời kỳ có nhiều bài học / sự kiện vượt quá chiều cao 1 khung ảnh,
///   tự động nối dài các đoạn tranh cuộn theo chiều dọc (`tileHeight = width * 1.65`)
///   kèm lớp sương mù chuyển tiếp mềm tại mối nối để ảnh không bao giờ bị phóng
///   to vỡ nét hay đứt gãy.
class _LandscapeBackdrop extends StatelessWidget {
  final String? primaryAssetId;
  final String primaryAsset;
  final String fallbackAsset;

  const _LandscapeBackdrop({
    this.primaryAssetId,
    required this.primaryAsset,
    required this.fallbackAsset,
  });

  Widget _buildSingleTile() {
    return DbOrBundledImage(
      assetId: primaryAssetId,
      bundledPath: primaryAsset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      placeholder: Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, _, _) => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFBF7EF),
                Color(0xFFF3EDE0),
                Color(0xFFE7D9BF),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 390.0;
        final double totalHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 844.0;
        final double tileHeight = math.max(580.0, width * 1.65);

        if (totalHeight <= tileHeight * 1.15) {
          return _buildSingleTile();
        }

        final int tileCount = (totalHeight / tileHeight).ceil();
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (int i = 0; i < tileCount; i++)
                Positioned(
                  top: i * tileHeight,
                  left: 0,
                  right: 0,
                  height: tileHeight + 2,
                  child: i.isOdd
                      ? Transform.flip(
                          flipY: true,
                          child: _buildSingleTile(),
                        )
                      : _buildSingleTile(),
                ),
              // Lớp sương mù thuỷ mặc nối mềm giữa các đoạn tranh khi kéo dài
              for (int i = 1; i < tileCount; i++)
                Positioned(
                  top: i * tileHeight - 36,
                  left: 0,
                  right: 0,
                  height: 72,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00E4D8C1),
                            Color(0xB8E4D8C1),
                            Color(0x00E4D8C1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Vẽ con đường uốn lượn xuyên qua [points] (tâm các nút) bằng **Catmull-Rom spline**:
/// - Khi [glowingDottedStyle] == true (mặc định):
///   - Đoạn đã qua / đang mở (tới [activeUpToIndex]): vẽ hào quang vàng cam ấm áp,
///     sợi chỉ vàng và chuỗi hạt sáng chuyển động dọc theo đường đi ([marchingPhase]).
///   - Đoạn chưa mở (sau [activeUpToIndex]): vẽ nét đứt xám kem nhạt mềm mại.
/// - Khi [glowingDottedStyle] == false: vẽ con đường đá vàng 2.5D truyền thống.
class WindingStonePathPainter extends CustomPainter {
  final List<Offset> points;
  final bool glowingDottedStyle;
  final int? activeUpToIndex;
  final double drawProgress;
  final double marchingPhase;

  const WindingStonePathPainter({
    required this.points,
    this.glowingDottedStyle = true,
    this.activeUpToIndex,
    this.drawProgress = 1.0,
    this.marchingPhase = 0.0,
  });

  /// Tạo đường cong Catmull-Rom liên tục ($C^1$) đi qua toàn bộ [knots]
  /// kèm hai điểm ảo ở đầu và cuối để không bị gãy khúc tại các nút mốc.
  static Path buildCatmullRomPath(
    List<Offset> knots, {
    bool includeLeadInOut = true,
  }) {
    final path = Path();
    if (knots.isEmpty) return path;
    if (knots.length == 1) {
      final p = knots.first;
      path.moveTo(p.dx, p.dy - 18);
      path.lineTo(p.dx, p.dy + 18);
      return path;
    }

    final List<Offset> pts = <Offset>[
      if (includeLeadInOut) Offset(knots.first.dx, knots.first.dy - 22),
      ...knots,
      if (includeLeadInOut) Offset(knots.last.dx, knots.last.dy + 26),
    ];

    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final Offset p0 = i == 0 ? (pts[0] * 2.0 - pts[1]) : pts[i - 1];
      final Offset p1 = pts[i];
      final Offset p2 = pts[i + 1];
      final Offset p3 = i + 2 < pts.length
          ? pts[i + 2]
          : (pts.last * 2.0 - pts[pts.length - 2]);

      final double minY = math.min(p1.dy, p2.dy);
      final double maxY = math.max(p1.dy, p2.dy);

      final Offset c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        (p1.dy + (p2.dy - p0.dy) / 6.0).clamp(minY, maxY),
      );
      final Offset c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        (p2.dy - (p3.dy - p1.dy) / 6.0).clamp(minY, maxY),
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// Trích xuất đoạn `Path` theo tiến độ `0.0..1.0`.
  static Path _extractProgressPath(Path source, double progress) {
    final double clamped = progress.clamp(0.0, 1.0);
    if (clamped >= 0.999) return source;
    if (clamped <= 0.001) return Path();
    final out = Path();
    for (final metric in source.computeMetrics()) {
      out.addPath(metric.extractPath(0.0, metric.length * clamped), Offset.zero);
    }
    return out;
  }

  /// Tách đường spline thành (activePath, lockedPath) tại nút `activeUpToIndex`.
  (Path activePath, Path? lockedPath) _buildSplitPaths() {
    if (points.length <= 1 ||
        activeUpToIndex == null ||
        activeUpToIndex! >= points.length - 1) {
      final full = _extractProgressPath(buildCatmullRomPath(points), drawProgress);
      return (full, null);
    }

    final int splitIdx = activeUpToIndex!.clamp(0, points.length - 1);
    final List<Offset> pts = <Offset>[
      Offset(points.first.dx, points.first.dy - 22),
      ...points,
      Offset(points.last.dx, points.last.dy + 26),
    ];
    // Trong mảng `pts`, `points[splitIdx]` nằm tại vị trí `splitIdx + 1`.
    final int knotSplit = splitIdx + 1;

    final activeRaw = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < knotSplit; i++) {
      _appendCatmullSegment(activeRaw, pts, i);
    }

    final lockedRaw = Path()..moveTo(pts[knotSplit].dx, pts[knotSplit].dy);
    for (int i = knotSplit; i < pts.length - 1; i++) {
      _appendCatmullSegment(lockedRaw, pts, i);
    }

    return (
      _extractProgressPath(activeRaw, drawProgress),
      _extractProgressPath(lockedRaw, drawProgress),
    );
  }

  static void _appendCatmullSegment(Path path, List<Offset> pts, int i) {
    final Offset p0 = i == 0 ? (pts[0] * 2.0 - pts[1]) : pts[i - 1];
    final Offset p1 = pts[i];
    final Offset p2 = pts[i + 1];
    final Offset p3 = i + 2 < pts.length
        ? pts[i + 2]
        : (pts.last * 2.0 - pts[pts.length - 2]);

    final double minY = math.min(p1.dy, p2.dy);
    final double maxY = math.max(p1.dy, p2.dy);

    final Offset c1 = Offset(
      p1.dx + (p2.dx - p0.dx) / 6.0,
      (p1.dy + (p2.dy - p0.dy) / 6.0).clamp(minY, maxY),
    );
    final Offset c2 = Offset(
      p2.dx - (p3.dx - p1.dx) / 6.0,
      (p2.dy - (p3.dy - p1.dy) / 6.0).clamp(minY, maxY),
    );
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  void _paintActiveGlowingPath(Canvas canvas, Path path) {
    // 1. Hào quang vàng cam ấm áp dọc theo đường cong đã mở.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x70FFA726)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. Sợi chỉ vàng nối mềm giữa các hạt sáng.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xCCFFE082)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // 3. Chuỗi hạt chấm tròn phát sáng dọc theo đường đi.
    final glowDotPaint = Paint()
      ..color = const Color(0x99FFB300)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final coreDotPaint = Paint()
      ..color = const Color(0xFFFFFBE6)
      ..style = PaintingStyle.fill;

    const double step = 16.0;
    final double phaseOffset = (marchingPhase % 1.0) * step;
    for (final metric in path.computeMetrics()) {
      double dist = 6.0 + phaseOffset;
      while (dist < metric.length) {
        final tangent = metric.getTangentForOffset(dist);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 5.2, glowDotPaint);
          canvas.drawCircle(tangent.position, 3.2, coreDotPaint);
        }
        dist += step;
      }
    }
  }

  void _paintLockedDashedPath(Canvas canvas, Path path) {
    // Đường nền mờ cho chặng chưa mở khóa.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x386E5D4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round,
    );

    final dashPaint = Paint()
      ..color = const Color(0xCCE6D9C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const double dashLength = 8.0;
    const double gapLength = 9.0;
    for (final metric in path.computeMetrics()) {
      double dist = 4.0;
      while (dist < metric.length) {
        final double end = math.min(dist + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), dashPaint);
        dist += dashLength + gapLength;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      final p = points.first;
      canvas.drawCircle(
        p,
        30,
        Paint()
          ..color = const Color(0x55FFB74D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      return;
    }

    if (glowingDottedStyle) {
      final (Path activePath, Path? lockedPath) = _buildSplitPaths();
      _paintActiveGlowingPath(canvas, activePath);
      if (lockedPath != null) {
        _paintLockedDashedPath(canvas, lockedPath);
      }
      return;
    }

    final path = _extractProgressPath(buildCatmullRomPath(points), drawProgress);
    // Chế độ đường đá truyền thống
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()
        ..color = DauVietColors.pixelShadowColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8C5E2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 27
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF3D299),
            Color(0xFFEFC583),
            Color(0xFFDFB06B),
          ],
        ).createShader(
          bounds.isEmpty ? Rect.fromLTWH(0, 0, size.width, size.height) : bounds,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant WindingStonePathPainter oldDelegate) {
    if (oldDelegate.glowingDottedStyle != glowingDottedStyle ||
        oldDelegate.activeUpToIndex != activeUpToIndex ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.marchingPhase != marchingPhase) {
      return true;
    }
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}
