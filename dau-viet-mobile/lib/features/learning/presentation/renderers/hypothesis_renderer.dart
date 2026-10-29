import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/empty_state_card.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/stamp_seal_badge.dart';
import '../../../../core/widgets/tactile_card.dart';
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
    final supportingConfigIds = _supportingEvidenceIds(config);
    final evidenceIds = <String>{
      ...configIdList(config, 'visibleEvidenceIds'),
      ...supportingConfigIds,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SectionEyebrow('BÀN SUY LUẬN · ĐẶT GIẢ THUYẾT'),
              ),
            ),
            const SizedBox(width: 8),
            const StampSealBadge('GIẢ THUYẾT', size: 36),
          ],
        ),
        if (prompt != null) ...[
          const SizedBox(height: 8),
          TactileCard(
            backgroundColor: DauVietColors.paperCardHi,
            borderColor: DauVietColors.imperialGold,
            child: Text(
              prompt,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (hypotheses.isEmpty)
          const EmptyStateCard(
            title: 'Chưa có giả thuyết',
            description: 'Hoạt động này chưa cấu hình danh sách giả thuyết.',
            icon: Icons.lightbulb_outline,
          )
        else
          for (int i = 0; i < hypotheses.length; i++)
            _buildHypothesisOption(hypotheses[i], i, evidenceIds),
        if (evidenceIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SectionEyebrow(
              collected.isNotEmpty
                  ? 'DẤU VẾT ĐÃ CHỌN · BẰNG CHỨNG ỦNG HỘ'
                  : 'BẰNG CHỨNG ỦNG HỘ',
              color: DauVietColors.jadeDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in evidenceIds) _buildEvidenceClueChip(id),
            ],
          ),
        ],
        const SizedBox(height: 10),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
        const SizedBox(height: 8),
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

  Widget _buildHypothesisOption(
    Map<String, dynamic> h,
    int index,
    List<String> poolEvidenceIds,
  ) {
    final String id = h['id'] as String? ?? '';
    final String label = (h['text'] ?? h['label'] ?? id) as String;
    final bool selected = _hypothesisId == id;
    final String badgeLetter = String.fromCharCode(65 + (index % 26));
    final List<String> subTags = _optionSupportingTags(h, poolEvidenceIds);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TactileCard(
            enabled: !widget.submitting,
            onTap: widget.submitting
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hypothesisId = id;
                      _dirty();
                    });
                  },
            backgroundColor: selected
                ? DauVietColors.paperCardHi
                : DauVietColors.paperCard,
            borderColor: selected
                ? DauVietColors.cinnabarRed
                : DauVietColors.outlineVariant,
            borderWidth: selected ? 2.4 : 1.4,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ChapterNumberBadge(
                      badgeLetter,
                      size: 32,
                      color: selected
                          ? DauVietColors.cinnabarRed
                          : DauVietColors.chapterGreen,
                      filled: selected,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkText,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (selected) const SizedBox(width: 36),
                  ],
                ),
                if (subTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in subTags)
                        ClueTag(
                          tag,
                          icon: Icons.bookmark_border,
                          color: DauVietColors.jade,
                          filled: selected,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (selected)
            const Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: StampSealBadge.success('✓', size: 32),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvidenceClueChip(String id) {
    final bool selected = _evidenceIds.contains(id);
    final String title = _evidenceTitle(id);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !widget.submitting,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.submitting
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (selected) {
                    _evidenceIds.remove(id);
                  } else {
                    _evidenceIds.add(id);
                  }
                  _dirty();
                });
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 300),
          child: Align(
            widthFactor: 1.0,
            alignment: Alignment.centerLeft,
            child: ClueTag(
              title,
              icon: selected
                  ? Icons.check_circle_outline
                  : Icons.bookmark_border,
              color: selected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.jade,
              filled: selected,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _supportingEvidenceIds(Map<String, dynamic> config) {
    final raw = config['supportingEvidence'];
    if (raw is! List) return const [];
    final result = <String>[];
    for (final item in raw) {
      if (item is String && item.isNotEmpty) {
        result.add(item);
      } else if (item is Map && item['id'] is String) {
        result.add(item['id'] as String);
      }
    }
    return result;
  }

  List<String> _optionSupportingTags(
    Map<String, dynamic> h,
    List<String> poolEvidenceIds,
  ) {
    final raw = h['supportingEvidence'];
    if (raw is! List) return const [];
    final tags = <String>[];
    for (final item in raw) {
      if (item is String &&
          item.isNotEmpty &&
          !poolEvidenceIds.contains(item)) {
        tags.add(_evidenceTitle(item));
      }
    }
    return tags;
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
