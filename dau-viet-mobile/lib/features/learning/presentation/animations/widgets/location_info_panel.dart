import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../../../core/theme/dau_viet_typography.dart';
import '../historical_animation_definition.dart';
import '../scenes/historical_map_scene.dart';

/// ANIM-02 — Panel thông tin khi learner chạm một địa điểm trên map.
/// Chỉ hiển thị khi có selection; nội dung lấy từ [MapLocation] typed —
/// không phải submission, không gửi server.
class LocationInfoPanel extends StatelessWidget {
  final HistoricalScenePainter painter;
  final String? selectedId;
  final VoidCallback onClose;

  const LocationInfoPanel({
    super.key,
    required this.painter,
    required this.selectedId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (painter is! MapScenePainter) return const SizedBox.shrink();
    final mp = painter as MapScenePainter;
    MapLocation? loc;
    for (final l in mp.locations) {
      if (l.id == selectedId) loc = l;
    }
    if (loc == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 16,
                color: DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  loc.name.toUpperCase(),
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (loc.contextLabel != null)
                Text(
                  loc.contextLabel!,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkLight,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Đóng thông tin địa điểm',
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            loc.description,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
