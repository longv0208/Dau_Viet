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
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;

  const HypothesisRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
  });

  @override
  State<HypothesisRenderer> createState() => _HypothesisRendererState();
}

class _HypothesisRendererState extends State<HypothesisRenderer> {
  String? _hypothesisId;
  final Set<String> _evidenceIds = {};
  bool _prefilled = false;

  void _dirty() => widget.onInputChanged?.call(
    _hypothesisId != null || _evidenceIds.isNotEmpty,
  );

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'title']);
    final hypotheses = configList(config, 'hypotheses');
    // Issue #35: ưu tiên dấu vết học viên đã thu thập ở EVIDENCE_SELECT
    // (injected qua config.priorOutputs[priorEvidenceSource]) rồi mới tới
    // visibleEvidenceIds tĩnh — learner gắn bằng chứng thật vào giả thuyết.
    final collected = _priorEvidenceIds();
    final evidenceIds = <String>{
      ...configIdList(config, 'visibleEvidenceIds'),
      ...collected,
    }.toList();
    final int rawMinEvidence =
        ((config['minEvidence'] ?? config['minRequired']) as num?)?.toInt() ??
        (evidenceIds.isNotEmpty ? 1 : 0);
    final int minEvidence = evidenceIds.isEmpty
        ? 0
        : rawMinEvidence.clamp(1, evidenceIds.length);

    // Prefill các dấu vết đã thu thập MỘT LẦN (không ghi đè lựa chọn sau đó —
    // learner phải được bỏ chọn mà không bị add lại).
    if (!_prefilled && collected.isNotEmpty) {
      _evidenceIds.addAll(collected);
      _prefilled = true;
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
        const SectionLabel('CHỌN GIẢ THUYẾT PHÙ HỢP NHẤT'),
        const SizedBox(height: 6),
        if (hypotheses.isEmpty)
          const ActivityCard(child: Text('Chưa có giả thuyết nào.'))
        else
          RadioGroup<String>(
            groupValue: _hypothesisId,
            onChanged: widget.submitting
                ? (_) {}
                : (v) => setState(() {
                    _hypothesisId = v;
                    _dirty();
                  }),
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
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      _evidenceTitle(id),
                      softWrap: true,
                      style: DauVietTypography.bodySmall.copyWith(fontSize: 13),
                    ),
                  ),
                  selected: _evidenceIds.contains(id),
                  onSelected: widget.submitting
                      ? null
                      : (v) => setState(() {
                          v ? _evidenceIds.add(id) : _evidenceIds.remove(id);
                          _dirty();
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
          enabled: _hypothesisId != null && _evidenceIds.length >= minEvidence,
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

  /// Dấu vết đã thu thập: `config.priorEvidenceSource` (hoặc `evidenceSource`)
  /// trỏ vào output của activity trước, injected dưới `config.priorOutputs`.
  List<String> _priorEvidenceIds() {
    final config = widget.activity.config;
    final source = config['priorEvidenceSource'] ?? config['evidenceSource'];
    final prior = config['priorOutputs'];
    if (source is! String || prior is! Map) return const [];
    final out = prior[source];
    if (out is! Map) return const [];
    final ids = out['selectedEvidenceIds'] ?? out['evidenceIds'];
    if (ids is! List) return const [];
    return ids.whereType<String>().toList();
  }
}
