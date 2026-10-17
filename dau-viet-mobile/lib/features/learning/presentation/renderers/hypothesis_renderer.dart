import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// HYPOTHESIS_CHOICE — chọn 1 giả thuyết trong `hypotheses[]` + các bằng chứng
/// ủng hộ. Submit `{hypothesisId, evidenceIds[]}`.
class HypothesisRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const HypothesisRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<HypothesisRenderer> createState() => _HypothesisRendererState();
}

class _HypothesisRendererState extends State<HypothesisRenderer> {
  String? _hypothesisId;
  final Set<String> _evidenceIds = {};

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'title']);
    final hypotheses = configList(config, 'hypotheses');
    final evidenceIds = configIdList(config, 'visibleEvidenceIds');

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
        const SectionLabel('CHỌN GIẢ THUYẾT PHÙ HỢP NHẤT'),
        const SizedBox(height: 6),
        if (hypotheses.isEmpty)
          const ActivityCard(child: Text('Chưa có giả thuyết nào.'))
        else
          RadioGroup<String>(
            groupValue: _hypothesisId,
            onChanged: widget.submitting
                ? (_) {}
                : (v) => setState(() => _hypothesisId = v),
            child: Column(
              children: [
                for (final h in hypotheses)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (h['text'] ?? h['label'] ?? h['id']) as String,
                      style: DauVietTypography.bodySmall,
                    ),
                    value: h['id'] as String? ?? '',
                    activeColor: DauVietColors.cinnabarRed,
                  ),
              ],
            ),
          ),
        if (evidenceIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionLabel('BẰNG CHỨNG ỦNG HỘ'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in evidenceIds)
                FilterChip(
                  label: Text(
                    _evidenceTitle(id),
                    style: DauVietTypography.bodySmall,
                  ),
                  selected: _evidenceIds.contains(id),
                  onSelected: widget.submitting
                      ? null
                      : (v) => setState(() {
                          v ? _evidenceIds.add(id) : _evidenceIds.remove(id);
                        }),
                  selectedColor: DauVietColors.cinnabarRed.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: DauVietColors.cinnabarRed,
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SubmitBar(
          enabled: _hypothesisId != null,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'hypothesisId': _hypothesisId,
            'evidenceIds': _evidenceIds.toList(),
          }),
        ),
      ],
    );
  }

  String _evidenceTitle(String id) {
    final e = widget.content.evidenceById(id);
    return (e?['title'] as String?) ?? id;
  }
}
