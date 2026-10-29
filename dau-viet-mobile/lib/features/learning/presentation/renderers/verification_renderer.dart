import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/stamp_seal_badge.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// VERIFICATION — Learning Flow 2.0 (TASK-0020 §P7): màn hình hiển thị lại
/// giả thuyết đã chọn (output HYPOTHESIS_CHOICE) cùng bằng chứng đã thu thập
/// (output của EVIDENCE_SELECT được khai báo qua `config.evidenceSource`, hoặc
/// bằng chứng kèm giả thuyết ở snapshot cũ), cộng với `visibleSourceIds` để
/// đối chiếu. Học viên thực hiện một hành động kiểm chứng có chủ đích —
/// submit `{action: "verify"}`; server chấm SUPPORTED/PARTIAL/CONTRADICTED.
/// Không có chọn verdict phía client trong payload (verdict do backend quyết định).
class VerificationRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final EvaluationDto? lastEvaluation;

  const VerificationRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.lastEvaluation,
  });

  @override
  State<VerificationRenderer> createState() => _VerificationRendererState();
}

class _VerificationRendererState extends State<VerificationRenderer> {
  String? _selectedVerdict;

  /// Id giả thuyết đã chọn — đọc từ priorOutputs (bất kỳ output nào mang
  /// `hypothesisId`), cùng contract VerificationHandler dùng để chấm.
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

  /// Tra cứu nhãn tiếng Việt của giả thuyết trong `content.stages` nếu có;
  String _resolveHypothesisLabel(String hypothesisId) {
    final content = widget.content;
    for (final s in content.stages) {
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
            if (text != null && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
      }
    }
    return hypothesisId;
  }

  List<String> _evidenceGiven(Map<String, dynamic> config) {
    final prior = config['priorOutputs'];
    if (prior is! Map) return const [];
    final source = config['evidenceSource'];
    if (source is String) {
      final out = prior[source];
      final ids = out is Map ? out['selectedEvidenceIds'] : null;
      return ids is List ? ids.whereType<String>().toList() : const [];
    }
    // Snapshot cũ không khai báo evidenceSource: bằng chứng đi kèm output
    // HYPOTHESIS_CHOICE (legacy contract).
    for (final out in prior.values) {
      if (out is Map && out['hypothesisId'] is String) {
        final ids = out['evidenceIds'];
        if (ids is List) return ids.whereType<String>().toList();
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
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
        const Align(
          alignment: Alignment.centerLeft,
          child: SectionEyebrow('KIỂM CHỨNG · ĐỐI CHIẾU NGUỒN'),
        ),
        if (evaluation != null) ...[
          const SizedBox(height: 8),
          _VerificationFeedbackCard(evaluation: evaluation),
        ],
        if (prompt != null) ...[
          const SizedBox(height: 8),
          TactileCard(
            backgroundColor: DauVietColors.paperCardHi,
            borderColor: DauVietColors.imperialGold,
            padding: const EdgeInsets.all(12),
            child: Text(
              prompt,
              style: DauVietTypography.ancientCitation.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
          ),
        ],

        // Giả thuyết đã chọn ở bước HYPOTHESIS — ngữ cảnh kiểm chứng.
        if (hypothesisId != null) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: SectionEyebrow('GIẢ THUYẾT ĐÃ CHỌN'),
          ),
          const SizedBox(height: 6),
          _PickedTile(
            label: _resolveHypothesisLabel(hypothesisId),
            icon: Icons.lightbulb_outline,
            isCitation: true,
          ),
        ],

        // Bằng chứng đã thu thập trước đó — server dùng chính tập này để chấm.
        if (givenIds.isNotEmpty) ...[
          const SizedBox(height: 8),
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
        ],

        if (sourceIds.isNotEmpty) ...[
          const SizedBox(height: 8),
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
        ],

        const SizedBox(height: 8),
        _buildVerdictRow(),
        const SizedBox(height: 10),
        SubmitBar(
          label: 'KIỂM CHỨNG',
          enabled: true,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({'action': 'verify'}),
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
          Expanded(
            child: _buildVerdictCard(items[i]),
          ),
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
      backgroundColor: selected
          ? DauVietColors.paperCardHi
          : DauVietColors.paperCard,
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
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

/// Phản hồi 3 mức khi `lastEvaluation != null`:
/// SUPPORTED -> Chính xác | PARTIAL -> Gần chính xác | CONTRADICTED -> Cần xem lại.
class _VerificationFeedbackCard extends StatelessWidget {
  final EvaluationDto evaluation;

  const _VerificationFeedbackCard({required this.evaluation});

  @override
  Widget build(BuildContext context) {
    final String outcome = (evaluation.outcome ?? '').toUpperCase();
    late final Widget tag;
    late final Widget seal;
    late final Color borderColor;
    late final String detail;

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
