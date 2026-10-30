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
import 'learning_asset_image.dart';
import 'renderer_base.dart';

/// CER — Claim (Khẳng định) + Evidence (Bằng chứng) + Reasoning (Lập luận).
/// Submit `{claim, evidenceIds[], reasoning}`; server yêu cầu claim+reasoning
/// >= 20 ký tự — client validate tối thiểu đó (server vẫn authoritative).
/// Text giữ nguyên khi chọn/bỏ chọn evidence và khi lỗi mạng (controller
/// không bị reset).
class CerRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;

  const CerRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
  });

  @override
  State<CerRenderer> createState() => _CerRendererState();
}

class _CerRendererState extends State<CerRenderer> {
  final _claimCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _claimFocus = FocusNode();
  final _reasonFocus = FocusNode();
  final Set<String> _evidenceIds = {};

  Set<String> get _selectedEvidence => _evidenceIds;

  List<String> _priorEvidenceIds() {
    final config = widget.activity.config;
    final prior = config['priorOutputs'];
    if (prior is! Map) return const [];
    final source = config['priorEvidenceSource'] ?? config['evidenceSource'];
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
  void initState() {
    super.initState();
    final prior = _priorEvidenceIds();
    if (prior.isNotEmpty) {
      _selectedEvidence.addAll(prior);
    }
  }
  /// Báo player còn input chưa gửi (text/chips) để chặn thoát vô tình.
  void _reportDirty() => widget.onInputChanged?.call(
    _claimCtrl.text.trim().isNotEmpty ||
        _reasonCtrl.text.trim().isNotEmpty ||
        _evidenceIds.isNotEmpty,
  );

  @override
  void dispose() {
    _claimCtrl.dispose();
    _reasonCtrl.dispose();
    _claimFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _claimCtrl.text.trim().length >= 20 &&
      _reasonCtrl.text.trim().length >= 20 &&
      _selectedEvidence.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final priorIds = _priorEvidenceIds();
    final existingIds = <String>{
      for (final e in widget.content.evidence)
        if (e['id'] is String) e['id'] as String,
    };
    final evidence = <Map<String, dynamic>>[
      ...widget.content.evidence,
      for (final id in priorIds)
        if (!existingIds.contains(id)) {'id': id, 'title': id},
    ];
    final bool locked = widget.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SectionEyebrow('ĐÚC KẾT · LẬP LUẬN CER'),
        ),
        const SizedBox(height: 12),

        // Slot 1 — Claim (Khẳng định)
        TactileCard(
          padding: const EdgeInsets.all(14),
          backgroundColor: DauVietColors.paperCard,
          borderColor: _claimCtrl.text.trim().length >= 20
              ? DauVietColors.jade
              : DauVietColors.outlineVariant,
          borderWidth: _claimCtrl.text.trim().length >= 20 ? 1.8 : 1.4,
          child: _field(
            code: 'C',
            tagLabel: 'Khẳng định',
            accentColor: DauVietColors.jade,
            label: 'LUẬN ĐIỂM (CLAIM)',
            hint: 'Bạn kết luận điều gì? (tối thiểu 20 ký tự)',
            controller: _claimCtrl,
            focusNode: _claimFocus,
            nextFocus: _reasonFocus,
            locked: locked,
          ),
        ),

        const _CERConnector(),

        // Slot 2 — Evidence (Bằng chứng)
        TactileCard(
          padding: const EdgeInsets.all(14),
          backgroundColor: DauVietColors.paperCard,
          borderColor: _evidenceIds.isNotEmpty
              ? DauVietColors.cinnabarRed
              : DauVietColors.outlineVariant,
          borderWidth: _evidenceIds.isNotEmpty ? 1.8 : 1.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SlotHeader(
                code: 'E',
                tagLabel: 'Bằng chứng',
                color: DauVietColors.cinnabarRed,
                title: 'BẰNG CHỨNG (EVIDENCE) — CHỌN CÁC NGUỒN HỖ TRỢ',
              ),
              const SizedBox(height: 10),
              if (evidence.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '(Không có bằng chứng nhúng sẵn)',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                // Evidence chips — chọn/bỏ chọn không đụng vào text đã viết.
                Column(
                  children: [
                    for (final e in evidence)
                      _evidenceTile(
                        e,
                        locked,
                        priorIds.contains(e['id'] as String? ?? ''),
                      ),
                  ],
                ),
            ],
          ),
        ),

        const _CERConnector(),

        // Slot 3 — Reasoning (Lập luận)
        TactileCard(
          padding: const EdgeInsets.all(14),
          backgroundColor: DauVietColors.paperCard,
          borderColor: _reasonCtrl.text.trim().length >= 20
              ? DauVietColors.imperialGoldDark
              : DauVietColors.outlineVariant,
          borderWidth: _reasonCtrl.text.trim().length >= 20 ? 1.8 : 1.4,
          child: _field(
            code: 'R',
            tagLabel: 'Lập luận',
            accentColor: DauVietColors.imperialGoldDark,
            label: 'LẬP LUẬN (REASONING)',
            hint: 'Vì sao bằng chứng đó ủng hộ luận điểm? (tối thiểu 20 ký tự)',
            controller: _reasonCtrl,
            focusNode: _reasonFocus,
            maxLines: 5,
            locked: locked,
          ),
        ),

        const SizedBox(height: 14),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
        SubmitBar(
          enabled: _valid,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'claim': _claimCtrl.text.trim(),
            'evidenceIds': _evidenceIds.toList(),
            'reasoning': _reasonCtrl.text.trim(),
          }),
        ),
      ],
    );
  }

  String? _imageAssetId(Map<String, dynamic> e) {
    final raw = e['imageAssetId'] ?? e['assetId'] ?? e['imageId'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  Widget _evidenceTile(
    Map<String, dynamic> e,
    bool locked, [
    bool isPriorCollected = false,
  ]) {
    final String id = e['id'] as String? ?? '';
    final bool selected = _evidenceIds.contains(id);
    final String title = (e['title'] as String?) ?? id;
    final String? assetId = _imageAssetId(e);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !locked,
      label: title,
      child: TactileCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: 12,
        enabled: !locked,
        backgroundColor: selected
            ? DauVietColors.paperCardHi
            : DauVietColors.paperCard,
        borderColor: selected
            ? DauVietColors.cinnabarRed
            : DauVietColors.outlineVariant,
        borderWidth: selected ? 1.8 : 1.2,
        onTap: locked
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  selected ? _evidenceIds.remove(id) : _evidenceIds.add(id);
                  _reportDirty();
                });
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              if (assetId != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: LearningAssetImage(
                      assetId: assetId,
                      altText: title,
                      height: 40,
                      fit: BoxFit.cover,
                      tappable: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (isPriorCollected) ...[
                      const SizedBox(height: 4),
                      const ClueTag(
                        'Đã thu thập ở bước Khám phá',
                        icon: Icons.bookmark_added_outlined,
                        color: DauVietColors.jadeDark,
                        filled: false,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                const StampSealBadge(
                  '✓',
                  size: 28,
                  color: DauVietColors.cinnabarRed,
                )
              else
                const Icon(
                  Icons.radio_button_off,
                  size: 20,
                  color: DauVietColors.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String code,
    required String tagLabel,
    required Color accentColor,
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool locked,
    FocusNode? nextFocus,
    int maxLines = 3,
  }) {
    final int currentLen = controller.text.trim().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SlotHeader(
          code: code,
          tagLabel: tagLabel,
          color: accentColor,
          title: label,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          enabled: !locked,
          textInputAction: nextFocus != null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              focusNode.unfocus();
            }
          },
          onChanged: (_) => setState(_reportDirty),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
            filled: true,
            fillColor: DauVietColors.paperCardHi,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DauVietColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DauVietColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.6),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: DauVietTypography.bodyMedium.copyWith(height: 1.55),
        ),
        const SizedBox(height: 6),
        Text(
          '$currentLen/20 ký tự tối thiểu',
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            color: currentLen >= 20
                ? DauVietColors.natureGreen
                : DauVietColors.inkMuted,
            fontWeight: currentLen >= 20 ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SlotHeader extends StatelessWidget {
  final String code;
  final String tagLabel;
  final Color color;
  final String title;

  const _SlotHeader({
    required this.code,
    required this.tagLabel,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChapterNumberBadge(code, size: 32, color: color),
        const SizedBox(width: 8),
        Flexible(
          flex: 0,
          child: ClueTag(tagLabel, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: SectionLabel(title)),
      ],
    );
  }
}

/// Connector dọc nối giữa các slot C → E → R: đường thẳng 2px `inkHeading`
/// kèm đầu mũi tên nhỏ ở đáy.
class _CERConnector extends StatelessWidget {
  const _CERConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 22,
          child: CustomPaint(painter: _CERConnectorPainter()),
        ),
      ),
    );
  }
}

class _CERConnectorPainter extends CustomPainter {
  const _CERConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DauVietColors.inkHeading
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double cx = size.width / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height - 2), paint);
    final Path arrow = Path()
      ..moveTo(cx - 5, size.height - 7)
      ..lineTo(cx, size.height - 1)
      ..lineTo(cx + 5, size.height - 7);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
