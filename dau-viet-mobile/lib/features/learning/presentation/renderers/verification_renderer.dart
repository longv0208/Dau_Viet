import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/stamp_seal_badge.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// VERIFICATION — Bước 3 "Kiểm chứng" của bài học 4 bước.
///
/// Hai chế độ:
///   • Interactive (mặc định, không `evidenceSource` trong config):
///     học viên chọn bằng chứng ủng hộ giả thuyết từ `visibleSourceIds` /
///     `visibleEvidenceIds`, submit `{selectedEvidenceIds: [...]}`.
///     Server chấm SUPPORTED/PARTIAL/CONTRADICTED + subOutcome.
///   • Legacy (có `evidenceSource`): server tự chấm từ output
///     EVIDENCE_SELECT upstream — UI read-only như cũ.
///
/// Nút "Sửa giả thuyết" → onBackToHypothesis callback (player gọi
/// selectActivity để quay về Bước 2 HYPOTHESIS).
class VerificationRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final EvaluationDto? lastEvaluation;

  /// Quay về Bước 2 để sửa giả thuyết — player inject selectActivity.
  /// Null → ẩn nút "Sửa giả thuyết" (server cũ / mock).
  final VoidCallback? onBackToHypothesis;

  const VerificationRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.lastEvaluation,
    this.onBackToHypothesis,
  });

  @override
  State<VerificationRenderer> createState() => _VerificationRendererState();
}

class _VerificationRendererState extends State<VerificationRenderer> {
  String? _selectedVerdict; // legacy verdict mode
  final Set<String> _selectedEvidenceIds = {}; // interactive mode

  /// Id giả thuyết đã chọn — đọc từ priorOutputs.
  String? _priorHypothesisId(Map<String, dynamic> config) {
    final prior = config['priorOutputs'];
    if (prior is! Map) return null;
    for (final out in prior.values) {
      if (out is Map && out['hypothesisId'] is String) {
        return out['hypothesisId'] as String;
      }
    }
    return null;
  }

  /// Tra cứu nhãn tiếng Việt của giả thuyết trong `content.stages` nếu có.
  String _resolveHypothesisLabel(String hypothesisId) {
    for (final s in widget.content.stages) {
      final acts = s['activities'];
      if (acts is! List) continue;
      for (final a in acts.whereType<Map>()) {
        final cfg = a['config'];
        if (cfg is! Map) continue;
        final hyps = cfg['hypotheses'];
        if (hyps is! List) continue;
        for (final h in hyps.whereType<Map>()) {
          if (h['id'] == hypothesisId) {
            final text = (h['text'] ?? h['label']) as String?;
            if (text != null && text.trim().isNotEmpty) return text.trim();
          }
        }
      }
    }
    return hypothesisId;
  }

  /// Bằng chứng đã thu thập — fallback từ priorOutputs khi evidenceSource khai báo.
  List<String> _evidenceGiven(Map<String, dynamic> config) {
    final prior = config['priorOutputs'];
    if (prior is! Map) return const [];
    final source = config['evidenceSource'];
    if (source is String && source.trim().isNotEmpty) {
      final out = prior[source];
      final ids = out is Map ? out['selectedEvidenceIds'] : null;
      if (ids is List) {
        final list = ids.whereType<String>().toList();
        if (list.isNotEmpty) return list;
      }
    }
    for (final out in prior.values) {
      if (out is Map && out['hypothesisId'] is String) {
        final ids = out['evidenceIds'];
        if (ids is List) {
          final list = ids.whereType<String>().toList();
          if (list.isNotEmpty) return list;
        }
      }
    }
    for (final out in prior.values) {
      if (out is Map) {
        final ids = out['selectedEvidenceIds'] ?? out['evidenceIds'];
        if (ids is List) {
          final list = ids.whereType<String>().toList();
          if (list.isNotEmpty) return list;
        }
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final bool isLegacy = config['evidenceSource'] != null;
    final String? prompt = configText(
      config,
      ['prompt', 'question', 'text', 'claim', 'statement'],
    );
    final sourceIds = configIdList(config, 'visibleSourceIds').isNotEmpty
        ? configIdList(config, 'visibleSourceIds')
        : configIdList(config, 'visibleEvidenceIds');
    final hypothesisId = _priorHypothesisId(config);
    final givenIds = _evidenceGiven(config);
    final evaluation = widget.lastEvaluation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImperialScrollFrame(
          plaqueTitle: 'KIỂM CHỨNG • ĐỐI CHIẾU NGUỒN',
          hiddenPlaqueTestText: 'KIỂM CHỨNG · ĐỐI CHIẾU NGUỒN',
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (evaluation != null) ...[
                _VerificationFeedbackCard(evaluation: evaluation),
                const SizedBox(height: 8),
              ],
              if (prompt != null) ...[
                TactileCard(
                  usePixelShadow: false,
                  backgroundColor: const Color(0xFFFFFDF8),
                  borderColor: const Color(0xFFDECBA8),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    prompt,
                    style: DauVietTypography.ancientCitation.copyWith(
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Giả thuyết đã chọn — luôn hiển thị + nút sửa khi cần.
              if (hypothesisId != null) ...[
                Row(
                  children: [
                    const Expanded(
                      child: SectionEyebrow('GIẢ THUYẾT ĐÃ CHỌN'),
                    ),
                    if (widget.onBackToHypothesis != null && !widget.submitting)
                      GestureDetector(
                        onTap: widget.onBackToHypothesis,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: DauVietColors.imperialGold.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: DauVietColors.imperialGold.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            'SỬA GIẢ THUYẾT',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.imperialGoldDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _PickedTile(
                  label: _resolveHypothesisLabel(hypothesisId),
                  icon: Icons.lightbulb_outline,
                  isCitation: true,
                ),
                const SizedBox(height: 8),
              ],
              if (givenIds.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SectionEyebrow(
                    'BẰNG CHỨNG ĐÃ THU THẬP',
                    color: DauVietColors.jadeDark,
                  ),
                ),
                const SizedBox(height: 6),
                for (final id in givenIds)
                  _PickedTile(
                    label: _evidenceTitle(id),
                    icon: Icons.bookmark_added_outlined,
                  ),
                const SizedBox(height: 8),
              ],
              // ── Interactive mode: chọn bằng chứng ủng hộ giả thuyết ─────
              if (!isLegacy && sourceIds.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SectionEyebrow(
                    'CHỌN BẰNG CHỨNG ỦNG HỘ GIẢ THUYẾT',
                    color: DauVietColors.chapterGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn những bằng chứng đã thu thập hoặc đối chiếu được để '
                  'kiểm chứng giả thuyết của bạn:',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                for (final id in sourceIds)
                  _InteractiveSourceTile(
                    id: id,
                    content: widget.content,
                    selected: _selectedEvidenceIds.contains(id),
                    enabled: !widget.submitting,
                    onToggle: (selected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (selected) {
                          _selectedEvidenceIds.add(id);
                        } else {
                          _selectedEvidenceIds.remove(id);
                        }
                      });
                    },
                  ),
                const SizedBox(height: 8),
              ],
              // ── Legacy mode: đối chiếu nguồn + chọn verdict ──────────────
              if (isLegacy && sourceIds.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SectionEyebrow(
                    'ĐỐI CHIẾU CÁC NGUỒN SAU',
                    color: DauVietColors.chapterGreen,
                  ),
                ),
                const SizedBox(height: 6),
                for (final id in sourceIds)
                  _SourceTile(id: id, content: widget.content),
                const SizedBox(height: 8),
                Text(
                  'Đối chiếu giả thuyết với các bằng chứng đã thu thập và chọn 1 kết luận kiểm chứng:',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildVerdictRow(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SubmitBar(
          label: isLegacy ? 'KIỂM CHỨNG' : 'KIỂM CHỨNG',
          enabled: isLegacy
              ? _selectedVerdict != null
              : _selectedEvidenceIds.isNotEmpty,
          submitting: widget.submitting,
          onPressed: () {
            if (isLegacy) {
              widget.onSubmit({'action': 'verify', 'verdict': _selectedVerdict});
            } else {
              widget.onSubmit({
                'selectedEvidenceIds': _selectedEvidenceIds.toList(),
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildVerdictRow() {
    const items = <_VerdictOptionSpec>[
      _VerdictOptionSpec(
        code: 'SUPPORTED',
        badge: 'A',
        label: 'Chứng thực',
        color: DauVietColors.natureGreen,
      ),
      _VerdictOptionSpec(
        code: 'PARTIAL',
        badge: 'B',
        label: 'Một phần',
        color: DauVietColors.imperialGoldDark,
      ),
      _VerdictOptionSpec(
        code: 'CONTRADICTED',
        badge: 'C',
        label: 'Mâu thuẫn',
        color: DauVietColors.cinnabarRed,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildVerdictCard(items[i])),
        ],
      ],
    );
  }

  Widget _buildVerdictCard(_VerdictOptionSpec spec) {
    final bool selected = _selectedVerdict == spec.code;
    return TactileCard(
      enabled: !widget.submitting,
      onTap: widget.submitting
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selectedVerdict = spec.code);
            },
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      backgroundColor:
          selected ? DauVietColors.paperCardHi : DauVietColors.paperCard,
      borderColor: selected ? spec.color : DauVietColors.outlineVariant,
      borderWidth: selected ? 2.2 : 1.2,
      borderRadius: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChapterNumberBadge(
            spec.badge,
            size: 26,
            color: spec.color,
            filled: selected,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.labelSmall.copyWith(
                color: selected ? spec.color : DauVietColors.inkText,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _evidenceTitle(String id) {
    final e = widget.content.evidenceById(id);
    return (e?['title'] as String?) ?? id;
  }
}

/// Ô bằng chứng có thể chọn — hiển thị checkbox + nội dung bằng chứng.
class _InteractiveSourceTile extends StatelessWidget {
  final String id;
  final LessonContentDto content;
  final bool selected;
  final bool enabled;
  final void Function(bool selected) onToggle;

  const _InteractiveSourceTile({
    required this.id,
    required this.content,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final e = content.evidenceById(id);
    final String title = (e?['title'] as String?) ?? id;
    final String? desc = e?['description'] as String?;
    final Object? source = e?['source'];
    String? sourceText;
    if (source is Map) {
      sourceText = (source['title'] ?? source['author']) as String?;
    } else if (source is String) {
      sourceText = source;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: enabled ? () => onToggle(!selected) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.imperialGold.withValues(alpha: 0.08)
                : DauVietColors.paperCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? DauVietColors.imperialGold
                  : DauVietColors.outlineVariant,
              width: selected ? 2.0 : 1.2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox icon
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? DauVietColors.imperialGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected
                        ? DauVietColors.imperialGold
                        : DauVietColors.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 16,
                          color: DauVietColors.jade,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DauVietColors.inkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          desc,
                          style: DauVietTypography.ancientCitation.copyWith(
                            fontSize: 12.5,
                            color: DauVietColors.inkSecondary,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (sourceText != null && sourceText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Nguồn: $sourceText',
                          style: DauVietTypography.labelSmall.copyWith(
                            fontStyle: FontStyle.italic,
                            color: DauVietColors.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictOptionSpec {
  final String code;
  final String badge;
  final String label;
  final Color color;

  const _VerdictOptionSpec({
    required this.code,
    required this.badge,
    required this.label,
    required this.color,
  });
}

/// Phản hồi khi `lastEvaluation != null`:
/// SUPPORTED → Chính xác | PARTIAL → Gần chính xác | CONTRADICTED → Cần xem lại.
/// subOutcome đưa thêm chi tiết lý do (MISSING_HYPOTHESIS, INSUFFICIENT_EVIDENCE…).
class _VerificationFeedbackCard extends StatelessWidget {
  final EvaluationDto evaluation;

  const _VerificationFeedbackCard({required this.evaluation});

  String _subOutcomeDetail(String? subOutcome) {
    switch (subOutcome) {
      case 'MISSING_HYPOTHESIS':
        return 'Chưa có giả thuyết để kiểm chứng — hãy quay lại Bước 2.';
      case 'HYPOTHESIS_CONTRADICTED':
        return 'Các bằng chứng đã chọn không ủng hộ giả thuyết này.';
      case 'EVIDENCE_CONTRADICTED':
        return 'Bằng chứng được chọn mâu thuẫn với giả thuyết.';
      case 'INSUFFICIENT_EVIDENCE':
        return 'Chưa đủ bằng chứng cần thiết để kết luận.';
      case 'PARTIAL_SUPPORT':
        return 'Bằng chứng đã chọn ủng hộ giả thuyết ở mức độ một phần.';
      case 'SUPPORTED':
        return 'Bằng chứng đã chọn hoàn toàn ủng hộ giả thuyết.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String outcome = (evaluation.outcome ?? '').toUpperCase();
    final String? subOutcome =
        evaluation.output?['subOutcome'] as String?;
    late final Widget tag;
    late final Widget seal;
    late final Color borderColor;
    String detail;

    if (outcome == 'SUPPORTED' || outcome == 'COMPLETED') {
      tag = const ClueTag(
        'Chính xác',
        color: DauVietColors.natureGreen,
        filled: true,
      );
      seal = const StampSealBadge.success('✓', size: 36);
      borderColor = DauVietColors.natureGreen;
      detail = 'Giả thuyết được sử liệu và bằng chứng khảo cổ chứng thực.';
    } else if (outcome == 'PARTIAL') {
      tag = const ClueTag(
        'Gần chính xác',
        color: DauVietColors.imperialGold,
        filled: true,
      );
      seal = const StampSealBadge(
        '≈',
        size: 36,
        color: DauVietColors.imperialGoldDark,
      );
      borderColor = DauVietColors.imperialGoldDark;
      detail = 'Giả thuyết mới phản ánh một phần bức tranh lịch sử.';
    } else {
      tag = const ClueTag(
        'Cần xem lại',
        color: DauVietColors.cinnabarRed,
        filled: true,
      );
      seal = const StampSealBadge(
        '!',
        size: 36,
        color: DauVietColors.cinnabarRed,
      );
      borderColor = DauVietColors.cinnabarRed;
      detail = 'Giả thuyết mâu thuẫn với các nguồn sử liệu đối chiếu.';
    }

    // Ghi đè chi tiết theo subOutcome khi có — chính xác hơn default text.
    final subDetail = _subOutcomeDetail(subOutcome);
    if (subDetail.isNotEmpty) detail = subDetail;

    return TactileCard(
      backgroundColor: DauVietColors.paperCardHi,
      borderColor: borderColor,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tag,
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          seal,
        ],
      ),
    );
  }
}

/// Ô hiển thị một lựa chọn đã ghi nhận trước đó (read-only).
class _PickedTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCitation;

  const _PickedTile({
    required this.label,
    required this.icon,
    this.isCitation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TactileCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: DauVietColors.paperCardHi,
        borderColor: DauVietColors.cinnabarRed,
        borderWidth: 1.6,
        borderRadius: 12,
        child: Row(
          children: [
            Icon(icon, size: 18, color: DauVietColors.cinnabarRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: isCitation
                    ? DauVietTypography.ancientCitation.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      )
                    : DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String id;
  final LessonContentDto content;

  const _SourceTile({required this.id, required this.content});

  @override
  Widget build(BuildContext context) {
    final e = content.evidenceById(id);
    final String title = (e?['title'] as String?) ?? id;
    final String? desc = e?['description'] as String?;
    final Object? source = e?['source'];
    String? sourceText;
    if (source is Map) {
      sourceText = (source['title'] ?? source['author']) as String?;
    } else if (source is String) {
      sourceText = source;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TactileCard(
        padding: const EdgeInsets.all(12),
        backgroundColor: DauVietColors.paperCard,
        borderColor: DauVietColors.outlineVariant,
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: DauVietColors.jade,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
            if (desc != null && desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  desc,
                  style: DauVietTypography.ancientCitation.copyWith(
                    fontSize: 13,
                    color: DauVietColors.inkSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            if (sourceText != null && sourceText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nguồn: $sourceText',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
