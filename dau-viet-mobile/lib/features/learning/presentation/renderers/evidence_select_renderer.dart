import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/empty_state_card.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'learning_asset_image.dart';
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

  const EvidenceSelectRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
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
          'Chạm vào thẻ để xem chi tiết; chạm nút Chọn để đánh dấu.';
    }
    final parts = <String>[
      'Chạm vào thẻ để xem chi tiết; chạm nút Chọn để đánh dấu',
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
                _EvidenceCard(
                  evidence: widget.content.evidenceById(id),
                  fallbackId: id,
                  selected: _selected.contains(id),
                  verdict: verdicts[id],
                  enabled: !widget.submitting,
                  onSelect: () => _toggle(id),
                  onDetail: () => _showDetail(id),
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
        SubmitBar(
          enabled: _selected.length >= minRequired,
          submitting: widget.submitting,
          onPressed: () =>
              widget.onSubmit({'selectedEvidenceIds': _selected.toList()}),
        ),
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
      builder: (ctx) => _EvidenceDetailSheet(
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

String _sourceText(Map<String, dynamic>? e) {
  final Object? source = e?['source'];
  if (source is Map) {
    final parts = <String>[
      if ((source['title'] as String?) != null) source['title'] as String,
      if ((source['author'] as String?) != null) source['author'] as String,
    ];
    return parts.join(' • ');
  }
  if (source is String) return source;
  return '';
}

String? _imageAssetId(Map<String, dynamic>? e) {
  final raw = e?['imageAssetId'] ?? e?['assetId'] ?? e?['imageId'];
  return raw is String && raw.isNotEmpty ? raw : null;
}

String? _evidenceCategory(Map<String, dynamic>? e) {
  final raw = e?['type'] ?? e?['category'] ?? e?['kind'];
  return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
}

class _EvidenceCard extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  /// Verdict của server cho thẻ đã nộp ('correct' | 'incorrect' | null).
  final String? verdict;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onDetail;

  const _EvidenceCard({
    required this.evidence,
    required this.fallbackId,
    required this.selected,
    this.verdict,
    required this.enabled,
    required this.onSelect,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final String title = (e?['title'] as String?) ?? fallbackId;
    final String? desc = e?['description'] as String?;
    final String sourceText = _sourceText(e);
    final String? assetId = _imageAssetId(e);
    final String? category = _evidenceCategory(e);
    final bool isVerdictCorrect = verdict == 'correct';
    final bool isVerdictIncorrect = verdict == 'incorrect';

    final Color borderColor = isVerdictCorrect
        ? DauVietColors.natureGreen
        : isVerdictIncorrect
        ? DauVietColors.cinnabarRed.withValues(alpha: 0.75)
        : selected
        ? const Color(0xFFC02D24)
        : const Color(0xFFDECBA8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TactileCard(
        usePixelShadow: false,
        enabled: enabled,
        onTap: enabled ? onDetail : null,
        backgroundColor: selected
            ? const Color(0xFFFFFDF9)
            : const Color(0xFFFAF5E8),
        borderColor: borderColor,
        borderWidth: (selected || isVerdictCorrect || isVerdictIncorrect)
            ? 1.8
            : 1.2,
        borderRadius: 14,
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isVerdictCorrect || isVerdictIncorrect) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (category != null)
                    ClueTag.category(category, filled: selected),
                  if (isVerdictCorrect)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.natureGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: DauVietColors.natureGreen),
                      ),
                      child: Text(
                        '✓ Đúng dấu vết liên quan',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.natureGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (isVerdictIncorrect)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: DauVietColors.cinnabarRed.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      child: Text(
                        '✗ Chưa liên quan câu hỏi',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (assetId != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 78,
                      height: 82,
                      child: LearningAssetImage(
                        assetId: assetId,
                        altText: title,
                        height: 82,
                        fit: BoxFit.cover,
                        tappable: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category != null &&
                          !isVerdictCorrect &&
                          !isVerdictIncorrect &&
                          assetId == null) ...[
                        ClueTag.category(category, filled: selected),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        title,
                        style: DauVietTypography.headlineSmall.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF7A1C16),
                          height: 1.28,
                        ),
                      ),
                      if (desc != null && desc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: const Color(0xFF2B1F17),
                              fontSize: 12.2,
                              height: 1.38,
                            ),
                          ),
                        ),
                      if (sourceText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 13.5,
                                color: Color(0xFF1E6B52),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Nguồn: $sourceText',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DauVietTypography.labelSmall.copyWith(
                                    color: const Color(0xFF4A3C2E),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: enabled ? onDetail : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 24),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.manage_search_rounded,
                                  size: 15,
                                  color: Color(0xFF1A6B64),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Xem chi tiết dấu vết',
                                  style: DauVietTypography.labelSmall.copyWith(
                                    color: const Color(0xFF1A6B64),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  excludeSemantics: true,
                  button: true,
                  selected: selected,
                  enabled: enabled,
                  label: selected
                      ? 'Bỏ chọn bằng chứng $title'
                      : 'Chọn bằng chứng $title',
                  child: GestureDetector(
                    key: ValueKey('evidence-select-btn-$fallbackId'),
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? onSelect : null,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 56,
                        minHeight: 58,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFDF5EE)
                            : const Color(0xFFFAF3E4),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFC02D24)
                              : const Color(0xFFD5C3A6),
                          width: selected ? 1.5 : 1.1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          selected
                              ? const Icon(
                                  Icons.radio_button_checked_rounded,
                                  size: 23,
                                  color: Color(0xFFA8221B),
                                )
                              : const Icon(
                                  Icons.radio_button_off,
                                  size: 23,
                                  color: Color(0xFF4A3C2E),
                                ),
                          const SizedBox(height: 3),
                          Text(
                            selected ? 'Đã chọn' : 'Chọn',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xFFA8221B)
                                  : const Color(0xFF4A3C2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet đọc chi tiết bằng chứng trước khi quyết định chọn.
class _EvidenceDetailSheet extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  final bool canSelect;
  final VoidCallback onToggle;

  const _EvidenceDetailSheet({
    required this.evidence,
    required this.fallbackId,
    required this.selected,
    required this.canSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final String title = (e?['title'] as String?) ?? fallbackId;
    final String? desc = e?['description'] as String?;
    final String? body = (e?['body'] ?? e?['text'] ?? e?['content']) as String?;
    final String sourceText = _sourceText(e);
    final String? assetId = _imageAssetId(e);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DauVietColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: DauVietTypography.headlineMedium.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
              ),
            ),
            if (sourceText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Nguồn: $sourceText',
                style: DauVietTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: DauVietColors.inkMuted,
                ),
              ),
            ],
            if (assetId != null) ...[
              const SizedBox(height: 12),
              LearningAssetImage(
                assetId: assetId,
                altText: title,
                height: 200,
                fit: BoxFit.cover,
              ),
            ],
            if (desc != null && desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                desc,
                style: DauVietTypography.bodyMedium.copyWith(height: 1.6),
              ),
            ],
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                body,
                style: DauVietTypography.bodyMedium.copyWith(height: 1.6),
              ),
            ],
            const SizedBox(height: 18),
            if (canSelect)
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  selected ? Icons.remove_circle_outline : Icons.add_circle,
                  color: DauVietColors.cinnabarRed,
                ),
                label: Text(
                  selected ? 'BỎ CHỌN BẰNG CHỨNG NÀY' : 'CHỌN BẰNG CHỨNG NÀY',
                  style: DauVietTypography.labelMedium.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
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
