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
  final bool hasSubmitError;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const ExploreMapRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    this.hasSubmitError = false,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<ExploreMapRenderer> createState() => _ExploreMapRendererState();
}

class _ExploreMapRendererState extends State<ExploreMapRenderer> {
  final Set<String> _visited = {};

  @override
  void initState() {
    super.initState();
    _hydrateFromPriorOutputs();
  }

  @override
  void didUpdateWidget(covariant ExploreMapRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hydrateFromPriorOutputs();
  }

  void _hydrateFromPriorOutputs() {
    final prior = widget.activity.config['priorOutputs'];
    if (prior is! Map) return;
    final actOut = prior[widget.activity.id];
    if (actOut is Map && actOut['discoveredMarkerIds'] is List) {
      for (final id
          in (actOut['discoveredMarkerIds'] as List).whereType<String>()) {
        _visited.add(id);
      }
      return;
    }
    for (final v in prior.values) {
      if (v is Map && v['discoveredMarkerIds'] is List) {
        for (final id
            in (v['discoveredMarkerIds'] as List).whereType<String>()) {
          _visited.add(id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'title']);
    final markers = configList(config, 'markers');

    if (markers.isEmpty) {
      return const ActivityCard(child: Text('Bản đồ chưa có điểm khám phá.'));
    }
    final int rawMin =
        (config['minMarkers'] as num?)?.toInt() ?? markers.length;
    final int targetCount = rawMin.clamp(1, markers.length);

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
          'CHẠM VÀO TỪNG ĐIỂM ĐỂ KHÁM PHÁ (${_visited.length}/$targetCount)',
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
              try {
                await widget.onSubmit({'markerId': id});
                if (mounted && !widget.hasSubmitError) {
                  setState(() => _visited.add(id));
                }
              } catch (_) {
                // Do not optimistically mark visited on network/server failure.
              }
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

    return Semantics(
      button: true,
      enabled: enabled,
      selected: visited,
      label: visited ? '$label (Đã khám phá)' : 'Điểm bản đồ: $label',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
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
      ),
    );
  }
}
