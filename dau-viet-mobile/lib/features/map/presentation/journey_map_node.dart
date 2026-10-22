import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/map_location_dto.dart';

/// Node trên đường hành trình — biểu tượng + nhãn ngắn + semantics.
/// UNLOCKED vàng đặc, AVAILABLE xanh/viền son, LOCKED xám. Selected có
/// vòng focus rõ. Hit target ≥ 44px bằng GestureDetector mở rộng.
class JourneyMapNode extends StatelessWidget {
  final MapLocationDto location;
  final bool selected;
  final VoidCallback onTap;

  const JourneyMapNode({
    super.key,
    required this.location,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, fill) = switch (location.unlockState) {
      MapUnlockState.unlocked => (
        DauVietColors.imperialGold,
        Icons.lock_open_rounded,
        DauVietColors.imperialGoldLight.withValues(alpha: 0.9),
      ),
      MapUnlockState.available => (
        DauVietColors.cinnabarRed,
        Icons.place_rounded,
        DauVietColors.natureGreen.withValues(alpha: 0.85),
      ),
      MapUnlockState.locked => (
        DauVietColors.inkLight,
        Icons.lock_rounded,
        DauVietColors.parchmentDim,
      ),
    };
    return Semantics(
      button: true,
      label: '${location.title} — ${_stateLabel(location.unlockState)}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: selected ? 50 : 44,
                height: selected ? 50 : 44,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? DauVietColors.cinnabarRed : color,
                    width: selected ? 2.8 : 1.8,
                  ),
                  boxShadow: DauVietColors.heritageShadow,
                ),
                child: Icon(
                  icon,
                  size: selected ? 24 : 20,
                  color: location.unlockState == MapUnlockState.locked
                      ? DauVietColors.inkLight
                      : DauVietColors.parchmentSurface,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: DauVietColors.parchmentSurface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.outlineVariant,
                    width: selected ? 1.4 : 0.7,
                  ),
                ),
                child: Text(
                  location.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.inkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stateLabel(MapUnlockState s) => switch (s) {
    MapUnlockState.unlocked => 'đã mở khoá',
    MapUnlockState.available => 'sẵn sàng khám phá',
    MapUnlockState.locked => 'chưa mở khoá',
  };
}
