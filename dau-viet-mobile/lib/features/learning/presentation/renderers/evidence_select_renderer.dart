import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/empty_state_card.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'compact_evidence_card.dart';
import 'renderer_base.dart';

/// EVIDENCE_SELECT — điều tra bằng chứng lịch sử: chọn các nguồn liên quan
/// từ `visibleEvidenceIds` (resolve metadata từ snapshot `evidence[]`).
/// Card hiển thị title/mô tả/nguồn/tác giả/thumbnail; chạm để đọc chi tiết
/// trước khi chọn. Submit `{selectedEvidenceIds}`; KHÔNG lộ
/// requiredEvidenceIds, không bịa thông tin — chỉ dùng field trong snapshot.
class EvidenceSelectRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;
  final SubmitSpecCallback? onSubmitSpec;

  const EvidenceSelectRenderer({
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
  State<EvidenceSelectRenderer> createState() => _EvidenceSelectRendererState();
}

class _EvidenceSelectRendererState extends State<EvidenceSelectRenderer> {
  final Set<String> _selected = {};
  bool _maxSelectReached = false;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    final int? maxSelect = (widget.activity.config['maxSelect'] as num?)
        ?.toInt();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _maxSelectReached = false;
      } else if (maxSelect == null || _selected.length < maxSelect) {
        _selected.add(id);
        _maxSelectReached = false;
      } else {
        _maxSelectReached = true;
      }
      widget.onInputChanged?.call(_selected.isNotEmpty);
    });
    final int minRequired =
        ((widget.activity.config['minRequired'] ??
                    widget.activity.config['minSelect'])
                as num?)
            ?.toInt() ??
        1;
    notifySubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled: _selected.length >= minRequired,
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {'selectedEvidenceIds': _selected.toList()},
      ),
    );
  }

  String _buildSubtitle({
    required bool graded,
    required int? incorrectPenalty,
    required int? maxAttempts,
    required int remedialAttempts,
    required EvaluationDto? evaluation,
  }) {
    if (!graded) {
      return 'Chọn các dấu vết bạn thấy liên quan đến câu hỏi — không mất Thể lực. '
          'Chạm Đọc đầy đủ để xem tư liệu; chạm ô chọn để đánh dấu.';
    }
    final parts = <String>[
      'Chạm Đọc đầy đủ để xem tư liệu; chạm ô chọn để đánh dấu',
    ];
    if (incorrectPenalty != null && incorrectPenalty > 0) {
      parts.add('Sai mất $incorrectPenalty Thể lực');
    }
    if (maxAttempts != null && maxAttempts > 0) {
      final int used = evaluation?.attemptCount ?? 0;
      final bool isExhausted =
          (evaluation?.exhausted ?? false) ||
          (evaluation?.budgetExhausted ?? false);
      if (isExhausted && remedialAttempts > 0) {
        final int remLeft =
            (maxAttempts + remedialAttempts - used).clamp(0, remedialAttempts);
        parts.add(
          remLeft > 0 ? 'còn $remLeft lượt sửa bổ sung' : 'đã hết lượt thử',
        );
      } else {
        final int left = (maxAttempts - used).clamp(0, maxAttempts);
        final String remSuffix =
            remedialAttempts > 0 ? ' + $remedialAttempts sửa' : '';
        parts.add('còn $left/$maxAttempts lượt$remSuffix');
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final ids = configIdList(config, 'visibleEvidenceIds');
    final int minRequired =
        ((config['minRequired'] ?? config['minSelect']) as num?)?.toInt() ?? 1;
    final int? maxSelect = (config['maxSelect'] as num?)?.toInt();
    final bool graded = widget.activity.graded || config['graded'] == true;
    final int remedialAttempts =
        (config['remedialAttempts'] as num?)?.toInt() ?? 0;
    final Map<String, String> verdicts = graded
        ? (widget.lastEvaluation?.selectedVerdicts ?? const {})
        : const {};
    final int? expectedCount = (config['expectedCount'] as num?)?.toInt();
    final int targetCount = expectedCount ?? minRequired;
    final bool hasExpectedTarget = graded && expectedCount != null;
    if (ids.isEmpty) {
      return const _NoEvidence();
    }

    final String eyebrowText = graded
        ? 'THU THẬP DẤU VẾT · CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN'
        : 'THU THẬP DẤU VẾT · CHỌN ÍT NHẤT $minRequired';
    final String subtitleText = _buildSubtitle(
      graded: graded,
      incorrectPenalty: widget.activity.incorrectPenalty,
      maxAttempts: widget.activity.maxAttempts,
      remedialAttempts: remedialAttempts,
      evaluation: widget.lastEvaluation,
    );

    // Spec nút submit — player pin SubmitBar đáy màn hình.
    emitSubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled: _selected.length >= minRequired,
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {'selectedEvidenceIds': _selected.toList()},
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImperialScrollFrame(
          plaqueTitle: 'THU THẬP DẤU VẾT',
          hiddenPlaqueTestText: eyebrowText,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subtitleText,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF3A2E25),
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 12),
              for (final id in ids)
                CompactEvidenceCard(
                  evidence: widget.content.evidenceById(id),
                  fallbackId: id,
                  selected: _selected.contains(id),
                  verdict: verdicts[id],
                  enabled: !widget.submitting,
                  onToggleSelect: () => _toggle(id),
                  onReadFull: () => _showDetail(id),
                ),
              if (_maxSelectReached && maxSelect != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.imperialGold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DauVietColors.imperialGold.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    'Đã đạt giới hạn $maxSelect dấu vết. Bỏ chọn một thẻ trước khi chọn thẻ khác.',
                    textAlign: TextAlign.center,
                    style: DauVietTypography.labelSmall.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Đã chọn ${_selected.length}/$targetCount',
                textAlign: TextAlign.center,
                style: DauVietTypography.bodyMedium.copyWith(
                  fontSize: 13.5,
                  color: hasExpectedTarget
                      ? (_selected.length == targetCount
                            ? const Color(0xFF2B1F17)
                            : _selected.length > targetCount
                            ? DauVietColors.cinnabarRed
                            : const Color(0xFF4A3C2E))
                      : (_selected.length >= minRequired
                            ? const Color(0xFF2B1F17)
                            : const Color(0xFF4A3C2E)),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasExpectedTarget && _selected.length > targetCount) ...[
                const SizedBox(height: 4),
                Text(
                  'Cảnh báo: Bạn đã chọn nhiều hơn $targetCount dấu vết yêu cầu.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (graded)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InlineGradingHint(
              evaluation: widget.lastEvaluation,
              maxAttempts: widget.activity.maxAttempts,
            ),
          ),
        if (widget.onSubmitSpec == null) ...[
          const SizedBox(height: 8),
          SubmitBar(
            enabled: _selected.length >= minRequired,
            submitting: widget.submitting,
            onPressed: () => widget.onSubmit({
              'selectedEvidenceIds': _selected.toList(),
            }),
          ),
        ],
      ],
    );
  }

  void _showDetail(String id) {
    final e = widget.content.evidenceById(id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DauVietColors.paperBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => EvidenceDetailSheet(
        evidence: e,
        fallbackId: id,
        selected: _selected.contains(id),
        canSelect: !widget.submitting,
        onToggle: () {
          _toggle(id);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _NoEvidence extends StatelessWidget {
  const _NoEvidence();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateCard(
      title: 'Chưa có dấu vết',
      description: 'Hoạt động này chưa có bằng chứng để chọn.',
      icon: Icons.search_off,
    );
  }
}
