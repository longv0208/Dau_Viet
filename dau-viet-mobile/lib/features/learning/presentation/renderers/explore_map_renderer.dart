import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// EXPLORE_MAP — danh sách marker đơn giản. Mỗi marker chạm vào sẽ submit
/// `{markerId}` (incremental; server tự đếm số marker đã khám phá).
/// Marker đã chạm được đánh dấu tick; không có nút submit chung.
class ExploreMapRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const ExploreMapRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<ExploreMapRenderer> createState() => _ExploreMapRendererState();
}

class _ExploreMapRendererState extends State<ExploreMapRenderer> {
  final Set<String> _visited = {};

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'title']);
    final markers = configList(config, 'markers');

    if (markers.isEmpty) {
      return const ActivityCard(child: Text('Bản đồ chưa có điểm khám phá.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt != null)
          ActivityCard(
            child: Text(
              prompt,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        const SizedBox(height: 10),
        SectionLabel(
          'CHẠM VÀO TỪNG ĐIỂM ĐỂ KHÁM PHÁ (${_visited.length}/${markers.length})',
        ),
        const SizedBox(height: 8),
        for (final m in markers)
          _MarkerTile(
            marker: m,
            visited: _visited.contains(m['id']),
            enabled: !widget.submitting && !_visited.contains(m['id']),
            onTap: () async {
              final String id = m['id'] as String? ?? '';
              if (id.isEmpty) return;
              await widget.onSubmit({'markerId': id});
              if (mounted) setState(() => _visited.add(id));
            },
          ),
      ],
    );
  }
}

class _MarkerTile extends StatelessWidget {
  final Map<String, dynamic> marker;
  final bool visited;
  final bool enabled;
  final Future<void> Function() onTap;

  const _MarkerTile({
    required this.marker,
    required this.visited,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String label =
        (marker['label'] ?? marker['title'] ?? marker['id']) as String;
    final String? desc = marker['description'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visited
                ? DauVietColors.cinnabarRed.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: visited
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                visited ? Icons.check_circle : Icons.location_on_outlined,
                size: 20,
                color: visited
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.inkMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          desc,
                          style: DauVietTypography.bodySmall.copyWith(
                            color: DauVietColors.inkMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!visited)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: DauVietColors.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
