import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/learning_path_dto.dart';

/// Một hàng trên canvas hành trình 2.5D.
///
/// - [JourneyCanvasEntry.milestone]: nút mốc trên đường đi — gồm huy hiệu tròn
///   ([badge]) nằm trên con đường và thẻ nội dung ([child]) nổi bên cạnh.
/// - [JourneyCanvasEntry.fullWidth]: hàng rộng toàn khung (tiêu đề ERA/PHASE,
///   nhãn phụ) — không có huy hiệu và con đường vẫn nối qua các mốc hai bên.
class JourneyCanvasEntry {
  final Widget? badge;
  final Widget child;
  final bool cardOnLeft;

  const JourneyCanvasEntry.milestone({
    required Widget badge,
    required Widget child,
    bool cardOnLeft = false,
  }) : this._(badge: badge, child: child, cardOnLeft: cardOnLeft);

  const JourneyCanvasEntry.fullWidth({required Widget child})
      : this._(child: child);

  const JourneyCanvasEntry._({
    this.badge,
    required this.child,
    this.cardOnLeft = false,
  });

  bool get isMilestone => badge != null;
}

/// Vòng tròn huy hiệu 48px nằm ngay trên con đường đá (theo mockup Issue #48):
/// - Đang chọn / Đang học → đỏ chu sa `#B92B27` + ngôi sao/thành trì vàng.
/// - Đã hoàn thành / tinh thông → xanh lá `#387F46` + dấu `✓` trắng.
/// - Sẵn sàng khám phá (`available`) → vàng ngự `#C88A32` (thời kỳ) hoặc xanh
///   cổ `#247D78` + icon la bàn — thời kỳ KHÔNG BAO GIỜ hiển thị ổ khóa (AC-2).
/// - Khóa tuần tự (sự kiện sau trong cùng thời kỳ) → xám `#A8A8A8` + ổ khóa.
class JourneyNodeBadge extends StatelessWidget {
  final LearnerPathStatus status;
  final bool isSelected;
  final bool isPeriodNode;

  const JourneyNodeBadge({
    super.key,
    required this.status,
    this.isSelected = false,
    this.isPeriodNode = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final IconData icon;
    final Color iconColor;

    if (isSelected || status.isInProgress) {
      fill = const Color(0xFFB92B27);
      icon = Icons.star_rounded;
      iconColor = const Color(0xFFFFD778);
    } else if (status.isDone) {
      fill = const Color(0xFF387F46);
      icon = Icons.check_rounded;
      iconColor = Colors.white;
    } else if (status.isNotReady) {
      fill = const Color(0xFFA8A8A8);
      icon = Icons.hourglass_empty_rounded;
      iconColor = Colors.white;
    } else if (status == LearnerPathStatus.locked) {
      fill = const Color(0xFFA8A8A8);
      icon = Icons.lock_rounded;
      iconColor = Colors.white;
    } else {
      // available — thời kỳ tự do chọn: la bàn khám phá (không dùng icon khóa).
      fill = isPeriodNode ? const Color(0xFF247D78) : const Color(0xFFC88A32);
      icon = Icons.explore_rounded;
      iconColor = Colors.white;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40261E19),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 23, color: iconColor),
    );
  }
}

/// Canvas Đường đi Phong cảnh 2.5D (`WindingLandscapeJourneyCanvas` — Issue #48):
/// Nền tranh non nước & thành cổ ven biển + con đường đá vàng uốn lượn chữ S
/// nối các nút mốc tròn với thẻ thông tin nổi hai bên.
///
/// Tọa độ tâm các huy hiệu được đo sau layout (GlobalKey) rồi đưa cho
/// [WindingStonePathPainter] vẽ đường bezier mềm mại xuyên qua từng mốc.
class WindingLandscapeJourneyCanvas extends StatefulWidget {
  final List<JourneyCanvasEntry> entries;
  final String backgroundAsset;
  final String fallbackBackgroundAsset;

  /// Khoảng đệm hai mép ngoài để con đường không chạm sát cạnh khung.
  final EdgeInsets contentPadding;

  const WindingLandscapeJourneyCanvas({
    super.key,
    required this.entries,
    this.backgroundAsset = 'assets/images/journey_coastal_landscape_bg.jpg',
    this.fallbackBackgroundAsset = 'assets/images/vietnam_journey_map_bg.jpg',
    this.contentPadding = const EdgeInsets.fromLTRB(12, 26, 12, 40),
  });

  @override
  State<WindingLandscapeJourneyCanvas> createState() =>
      _WindingLandscapeJourneyCanvasState();
}

class _WindingLandscapeJourneyCanvasState
    extends State<WindingLandscapeJourneyCanvas> {
  final GlobalKey _canvasKey = GlobalKey();
  List<GlobalKey> _badgeKeys = [];
  List<Offset> _badgePoints = const [];

  @override
  void initState() {
    super.initState();
    _syncBadgeKeys();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant WindingLandscapeJourneyCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBadgeKeys();
    _scheduleMeasure();
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

  @override
  Widget build(BuildContext context) {
    int milestoneIndex = 0;
    final rows = <Widget>[];
    for (final entry in widget.entries) {
      if (entry.isMilestone) {
        final badgeKey = _badgeKeys[milestoneIndex];
        rows.add(
          _MilestoneRow(
            badge: KeyedSubtree(key: badgeKey, child: entry.badge!),
            cardOnLeft: entry.cardOnLeft,
            // Giãn khoảng dọc giữa các mốc để con đường trải dài suốt canvas
            // (mockup đường đi): hàng mốc cao tối thiểu, chip canh giữa.
            minHeight: 150,
            child: entry.child,
          ),
        );
        milestoneIndex++;
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: entry.child,
          ),
        );
      }
    }

    return Stack(
      key: _canvasKey,
      children: [
        // Nền tranh phong cảnh non nước ven biển 2.5D.
        Positioned.fill(
          child: _LandscapeBackdrop(
            primaryAsset: widget.backgroundAsset,
            fallbackAsset: widget.fallbackBackgroundAsset,
          ),
        ),
        // Con đường đá vàng uốn lượn xuyên qua tâm các huy hiệu.
        Positioned.fill(
          child: CustomPaint(
            painter: WindingStonePathPainter(points: _badgePoints),
          ),
        ),
        // Veil kem mờ ở mép trên để tranh nối liền với header `#FBF7EF`.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 72,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBF7EF),
                    Color(0x00FBF7EF),
                  ],
                ),
              ),
            ),
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

/// Một hàng nút mốc: huy hiệu tròn ở một bên (so le trái/phải tạo khúc cua
/// chữ S) và thẻ nội dung nổi chiếm phần còn lại.
class _MilestoneRow extends StatelessWidget {
  final Widget badge;
  final Widget child;
  final bool cardOnLeft;

  /// Chiều cao tối thiểu của hàng mốc — giãn khoảng cách giữa các nút trên
  /// con đường cho khớp mockup đường đi (không dùng Expanded vì canvas nằm
  /// trong scroll view không giới hạn chiều cao).
  final double minHeight;

  const _MilestoneRow({
    required this.badge,
    required this.child,
    required this.cardOnLeft,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rail = SizedBox(
      width: 74,
      child: Center(child: badge),
    );
    final card = Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: child,
        ),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cardOnLeft ? [card, rail] : [rail, card],
        ),
      ),
    );
  }
}

/// Nền tranh phong cảnh — ưu tiên tranh ven biển mới, rơi về bản đồ hành trình
/// cũ rồi cuối cùng là dải gradient giấy + núi xa nếu cả hai asset đều thiếu.
class _LandscapeBackdrop extends StatelessWidget {
  final String primaryAsset;
  final String fallbackAsset;

  const _LandscapeBackdrop({
    required this.primaryAsset,
    required this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      primaryAsset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, _, _) => Image.asset(
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
}

/// Vẽ con đường đá vàng 2.5D uốn lượn chữ S xuyên qua [points] (tâm các nút):
/// bóng đổ đất `#402C29`, viền đá `#8C5E2A`, mặt đường `#F3D299 → #DFB06B`
/// và vạch sáng `#FFF6DC` đứt nét chạy dọc giữa đường.
class WindingStonePathPainter extends CustomPainter {
  final List<Offset> points;

  const WindingStonePathPainter({required this.points});

  Path _buildPath() {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy - 30);
    path.lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midY = (prev.dy + cur.dy) / 2;
      path.cubicTo(prev.dx, midY, cur.dx, midY, cur.dx, cur.dy);
    }
    final last = points.last;
    path.lineTo(last.dx, last.dy + 30);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Nút đơn lẻ — chỉ vẽ một đoạn đá tròn dưới chân mốc.
    if (points.length == 1) {
      final p = points.first;
      final shadowPaint = Paint()
        ..color = DauVietColors.pixelShadowColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: p + const Offset(0, 16),
          width: 44,
          height: 18,
        ),
        shadowPaint,
      );
      return;
    }

    final path = _buildPath();

    // 1. Bóng đổ nền đất.
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()
        ..color = DauVietColors.pixelShadowColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 2. Viền đá hai bên.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8C5E2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 27
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 3. Mặt đường cát vàng ấm (gradient dọc).
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
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

    // 4. Vạch sáng đứt nét chạy giữa đường (hiệu ứng gạch lát).
    final dashPaint = Paint()
      ..color = const Color(0xFFFFF6DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const double dashLength = 13;
    const double gapLength = 11;
    for (final metric in path.computeMetrics()) {
      double distance = gapLength / 2;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          dashPaint,
        );
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant WindingStonePathPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}
