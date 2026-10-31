import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/empty_state_card.dart';
import '../../../../core/widgets/heritage_design_components.dart';
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
  final SubmitSpecCallback? onSubmitSpec;

  const HypothesisRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
    this.onSubmitSpec,
  });

  @override
  State<HypothesisRenderer> createState() => _HypothesisRendererState();
}

class _HypothesisRendererState extends State<HypothesisRenderer> {
  String? _hypothesisId;
  final Set<String> _evidenceIds = {};
  final Set<String> _expandedHypothesisIds = {};
  bool _prefilled = false;
  bool _promptExpanded = false;

  void _dirty() => widget.onInputChanged?.call(
    _hypothesisId != null || _evidenceIds.isNotEmpty,
  );

  int _currentMinEvidence() {
    final config = widget.activity.config;
    final collected = _priorEvidenceIds();
    final evidenceIds = <String>{
      ...configIdList(config, 'visibleEvidenceIds'),
      ..._supportingEvidenceIds(config),
      ...collected,
    };
    final int rawMinEvidence =
        ((config['minEvidence'] ?? config['minRequired']) as num?)?.toInt() ??
        (evidenceIds.isNotEmpty ? 1 : 0);
    return evidenceIds.isEmpty ? 0 : rawMinEvidence.clamp(1, evidenceIds.length);
  }

  void _notifySpec() {
    notifySubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled:
            _hypothesisId != null && _evidenceIds.length >= _currentMinEvidence(),
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {
          'hypothesisId': _hypothesisId,
          'evidenceIds': _evidenceIds.toList(),
        },
      ),
    );
  }

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

    emitSubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled: _hypothesisId != null && _evidenceIds.length >= minEvidence,
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {
          'hypothesisId': _hypothesisId,
          'evidenceIds': _evidenceIds.toList(),
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImperialScrollFrame(
          plaqueTitle: 'BÀN SUY LUẬN • ĐẶT GIẢ THUYẾT',
          hiddenPlaqueTestText: 'BÀN SUY LUẬN · ĐẶT GIẢ THUYẾT',
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (prompt != null) ...[
                TactileCard(
                  usePixelShadow: false,
                  backgroundColor: const Color(0xFFFFFDF8),
                  borderColor: const Color(0xFFDECBA8),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: _ExpandableCopy(
                    text: prompt,
                    expanded: _promptExpanded,
                    onToggle: () =>
                        setState(() => _promptExpanded = !_promptExpanded),
                    style: DauVietTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (hypotheses.isEmpty)
                const EmptyStateCard(
                  title: 'Chưa có giả thuyết',
                  description:
                      'Hoạt động này chưa cấu hình danh sách giả thuyết.',
                  icon: Icons.lightbulb_outline,
                )
              else
                for (int i = 0; i < hypotheses.length; i++)
                  _buildHypothesisOption(hypotheses[i], i, evidenceIds),
              if (evidenceIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SectionEyebrow(
                    collected.isNotEmpty
                        ? 'DẤU VẾT ĐÃ CHỌN · BẰNG CHỨNG ỦNG HỘ'
                        : 'BẰNG CHỨNG ỦNG HỘ',
                    color: DauVietColors.jadeDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in evidenceIds) _buildEvidenceClueChip(id),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
        if (widget.onSubmitSpec == null) ...[
          const SizedBox(height: 8),
          SubmitBar(
            enabled:
                _hypothesisId != null && _evidenceIds.length >= minEvidence,
            submitting: widget.submitting,
            onPressed: () => widget.onSubmit({
              'hypothesisId': _hypothesisId,
              'evidenceIds': _evidenceIds.toList(),
            }),
          ),
        ],
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

    final bool expanded = _expandedHypothesisIds.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
                    _notifySpec();
                  },
            backgroundColor: selected
                ? DauVietColors.paperCardHi
                : DauVietColors.paperCard,
            borderColor: selected
                ? DauVietColors.cinnabarRed
                : DauVietColors.outlineVariant,
            borderWidth: selected ? 2.2 : 1.2,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ChapterNumberBadge(
                      badgeLetter,
                      size: 28,
                      color: selected
                          ? DauVietColors.cinnabarRed
                          : DauVietColors.chapterGreen,
                      filled: selected,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExpandableCopy(
                        text: label,
                        expanded: expanded,
                        onToggle: () => setState(() {
                          if (expanded) {
                            _expandedHypothesisIds.remove(id);
                          } else {
                            _expandedHypothesisIds.add(id);
                          }
                        }),
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkText,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.35,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected) const SizedBox(width: 32),
                  ],
                ),
                if (subTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: StampSealBadge.success('✓', size: 28),
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
                _notifySpec();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, maxWidth: 280),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    if (prior is! Map) return const [];
    if (source is String && source.trim().isNotEmpty) {
      final out = prior[source];
      if (out is Map) {
        final ids = out['selectedEvidenceIds'] ?? out['evidenceIds'];
        if (ids is List) {
          final list = ids.whereType<String>().toList();
          if (list.isNotEmpty) return list;
        }
      }
    }
    for (final out in prior.values) {
      if (out is Map) {
        final ids = out['selectedEvidenceIds'];
        if (ids is List) {
          final list = ids.whereType<String>().toList();
          if (list.isNotEmpty) return list;
        }
      }
    }
    return const [];
  }
}

/// Văn bản dài: 3 dòng + "Xem thêm" / "Thu gọn" — không cắt mất nội dung.
class _ExpandableCopy extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final TextStyle style;

  const _ExpandableCopy({
    required this.text,
    required this.expanded,
    required this.onToggle,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    const int collapsedLines = 3;
    final bool canCollapse = text.trim().length > 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded || !canCollapse ? null : collapsedLines,
          overflow: expanded || !canCollapse
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: style,
        ),
        if (canCollapse)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                expanded ? 'Thu gọn' : 'Xem thêm',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.jadeDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
