import 'package:flutter/material.dart';

import '../scenes/historical_map_scene.dart';

/// ANIM-02 — Vùng chạm cho một địa điểm trên map scene. Đặt chồng lên
/// CustomPaint trong Stack — touch target ≥44px quanh tâm marker, có
/// semantics tiếng Việt. Marker thật do painter vẽ; overlay chỉ nhận
/// tap + hiển thị viền selected.
class MapMarkerOverlay extends StatelessWidget {
  final MapLocation location;
  final Size canvasSize;
  final bool selected;
  final VoidCallback onTap;

  const MapMarkerOverlay({
    super.key,
    required this.location,
    required this.canvasSize,
    required this.selected,
    required this.onTap,
  });

  static const double _target = 44;

  @override
  Widget build(BuildContext context) {
    final cx = location.position.dx * canvasSize.width;
    final cy = location.position.dy * canvasSize.height;
    // Kẹp vùng chạm trong canvas để marker sát mép vẫn bấm được.
    final left = (cx - _target / 2).clamp(0.0, canvasSize.width - _target);
    final top = (cy - _target / 2).clamp(0.0, canvasSize.height - _target);
    return Positioned(
      left: left,
      top: top,
      width: _target,
      height: _target,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Địa điểm ${location.name}',
        child: InkResponse(
          onTap: onTap,
          radius: _target / 2,
          containedInkWell: true,
          child: selected
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFA51F18),
                      width: 2,
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
