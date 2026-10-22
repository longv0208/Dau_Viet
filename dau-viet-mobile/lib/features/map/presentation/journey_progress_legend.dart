import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/map_location_dto.dart';

/// Chú giải trạng thái + tiến độ khám phá. Chỉ đếm UNLOCKED là hoàn
/// thành — AVAILABLE chưa tính. Server-authoritative.
class JourneyProgressLegend extends StatelessWidget {
  final List<MapLocationDto> locations;

  const JourneyProgressLegend({super.key, required this.locations});

  @override
  Widget build(BuildContext context) {
    final done = locations
        .where((l) => l.unlockState == MapUnlockState.unlocked)
        .length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: const [
              _LegendDot(
                color: DauVietColors.imperialGold,
                label: 'Đã mở khoá',
              ),
              _LegendDot(color: DauVietColors.natureGreen, label: 'Sẵn sàng'),
              _LegendDot(color: DauVietColors.inkLight, label: 'Chưa mở'),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Đã khám phá $done / ${locations.length} địa điểm — '
            'Bản đồ hành trình minh họa, không thể hiện tuyến đường thực tế',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: DauVietTypography.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }
}
