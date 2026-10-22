import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/map_location_dto.dart';

/// Danh sách địa điểm trong chặng — chip cuộn ngang compact, thay thế
/// list lớn chiếm nửa màn hình cũ. Mọi địa điểm vẫn truy cập được bằng
/// tap (accessibility fallback cho node nhỏ).
class JourneyLocationList extends StatelessWidget {
  final List<MapLocationDto> locations;
  final ValueChanged<MapLocationDto> onTap;

  const JourneyLocationList({
    super.key,
    required this.locations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final loc = locations[i];
          return _chip(loc);
        },
      ),
    );
  }

  Widget _chip(MapLocationDto loc) {
    final (color, icon) = switch (loc.unlockState) {
      MapUnlockState.unlocked => (
        DauVietColors.imperialGold,
        Icons.lock_open_rounded,
      ),
      MapUnlockState.available => (
        DauVietColors.natureGreen,
        Icons.place_rounded,
      ),
      MapUnlockState.locked => (DauVietColors.inkLight, Icons.lock_rounded),
    };
    return Semantics(
      button: true,
      label: '${loc.title} — ${_stateLabel(loc.unlockState)}',
      child: InkWell(
        onTap: () => onTap(loc),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: DauVietColors.parchmentContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.8), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  loc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelMedium.copyWith(fontSize: 11),
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
