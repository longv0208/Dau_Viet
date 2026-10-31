import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// CER_CHOICE — structured conclusion: pick 1 claim + ≥1 evidence + 1
/// reasoning. Three cards, no free text. `priorOutputs` injected by the
/// backend pre-fills the evidence section from an upstream EVIDENCE_SELECT
/// (no pointless re-selection). Answer keys never reach the client — the
/// server grades; the renderer only emits `{claimId, evidenceIds,
/// reasoningId}`.
class CerChoiceRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;
  final SubmitSpecCallback? onSubmitSpec;

  const CerChoiceRenderer({
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
  State<CerChoiceRenderer> createState() => _CerChoiceRendererState();
}

class _CerChoiceRendererState extends State<CerChoiceRenderer> {
  String? _claimId;
  final Set<String> _evidenceIds = {};
  String? _reasoningId;
  bool _prefilled = false;
  String _sourceFingerprint = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPrefill();
  }

  /// TASK-0020 §P5: khi config/attempt content thay đổi (re-fetch sau khi
  /// upstream EVIDENCE_SELECT bị invalidate hoặc admin republish), prefill
  /// phải refresh — bằng chứng cũ không còn trong pool của nguồn thì bị gỡ.
  @override
  void didUpdateWidget(covariant CerChoiceRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPrefill();
  }

  void _syncPrefill() {
    final prior = _priorEvidenceIds();
    final fingerprint = prior.join('|');
    if (!_prefilled) {
      _prefilled = true;
      _sourceFingerprint = fingerprint;
      if (prior.isNotEmpty) _evidenceIds.addAll(prior);
      return;
    }
    if (fingerprint == _sourceFingerprint) return;
    _sourceFingerprint = fingerprint;
    // Source selection changed: sync the prefilled ids with the new pool —
    // ids no longer collected upstream are dropped, newly collected ids are
    // added. Manual picks overlap the pool so the union keeps them honest.
    setState(() {
      _evidenceIds
        ..clear()
        ..addAll(prior);
    });
  }

  /// Evidence ids carried over from the upstream activity named by
  /// `config.priorEvidenceSource` (injected under `config.priorOutputs`).
  List<String> _priorEvidenceIds() {
    final config = widget.activity.config;
    final source = config['priorEvidenceSource'];
    final prior = config['priorOutputs'];
    if (prior is! Map) return const [];
    if (source is String && source.trim().isNotEmpty) {
      final out = prior[source];
      if (out is Map) {
        final ids = out['selectedEvidenceIds'];
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

  bool get _canSubmit =>
      _claimId != null && _reasoningId != null && _evidenceIds.isNotEmpty;

  bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  void _reportDirty() {
    final bool dirty =
        _claimId != null ||
        _reasoningId != null ||
        !_sameSet(_evidenceIds, _priorEvidenceIds().toSet());
    widget.onInputChanged?.call(dirty);
  }

  void _pickClaim(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _claimId = id;
      _reportDirty();
    });
  }

  void _toggleEvidence(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _evidenceIds.contains(id)
          ? _evidenceIds.remove(id)
          : _evidenceIds.add(id);
      _reportDirty();
    });
  }

  void _pickReasoning(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _reasoningId = id;
      _reportDirty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final claims = configList(config, 'claims');
    final reasoningOptions = configList(config, 'reasoningOptions');
    final rawEvidenceOptions = configList(config, 'evidenceOptions');
    final priorEvidenceIds = _priorEvidenceIds();
    final existingOptionIds = <String>{
      for (final e in rawEvidenceOptions)
        if (e['id'] is String) e['id'] as String,
    };
    final evidenceOptions = <Map<String, dynamic>>[
      ...rawEvidenceOptions,
      for (final id in priorEvidenceIds)
        if (!existingOptionIds.contains(id)) {'id': id},
    ];
    String? pickedClaimText;
    for (final c in claims) {
      if (c['id'] == _claimId) {
        pickedClaimText = (c['text'] ?? c['label']) as String?;
        break;
      }
    }
    String? pickedReasoningText;
    for (final r in reasoningOptions) {
      if (r['id'] == _reasoningId) {
        pickedReasoningText = (r['text'] ?? r['label']) as String?;
        break;
      }
    }
    final List<String> pickedEvidenceTitles = [
      for (final id in _evidenceIds)
        (widget.content.evidenceById(id)?['title'] as String?) ?? id,
    ];

    final String? claimPrompt = configText(config, [
      'claimPrompt',
      'prompt',
      'question',
    ]);
    final String? evidencePrompt = configText(config, ['evidencePrompt']);
    final String? reasoningPrompt = configText(config, ['reasoningPrompt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImperialScrollFrame(
          plaqueTitle: 'ĐÚC KẾT • LẬP LUẬN CER',
          hiddenPlaqueTestText: 'ĐÚC KẾT · LẬP LUẬN CER',
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slot 1 — Claim (Khẳng định)
              TactileCard(
                usePixelShadow: false,
                padding: const EdgeInsets.all(13),
                backgroundColor: const Color(0xFFFAF5E8),
                borderColor: _claimId != null
                    ? const Color(0xFF1A6B64)
                    : const Color(0xFFDECBA8),
                borderWidth: _claimId != null ? 1.6 : 1.2,
                borderRadius: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CerRoleHeader(
                      code: 'C',
                      tagLabel: 'Khẳng định',
                      title: 'CHỌN KẾT LUẬN (CLAIM)',
                      color: Color(0xFF1A6B64),
                    ),
                    if (claimPrompt != null &&
                        claimPrompt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        claimPrompt.trim(),
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: const Color(0xFF2B1F17),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.38,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    for (final c in claims)
                      _PickTile(
                        id: c['id'] as String? ?? '',
                        label: (c['text'] ?? c['label'] ?? '') as String,
                        selected: _claimId == c['id'],
                        multi: false,
                        accentColor: const Color(0xFF1A6B64),
                        enabled: !widget.submitting,
                        onTap: () => _pickClaim(c['id'] as String? ?? ''),
                      ),
                  ],
                ),
              ),

              const _CERConnector(),

              // Slot 2 — Evidence (Bằng chứng)
              TactileCard(
                usePixelShadow: false,
                padding: const EdgeInsets.all(13),
                backgroundColor: const Color(0xFFFAF5E8),
                borderColor: _evidenceIds.isNotEmpty
                    ? const Color(0xFFA8221B)
                    : const Color(0xFFDECBA8),
                borderWidth: _evidenceIds.isNotEmpty ? 1.6 : 1.2,
                borderRadius: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CerRoleHeader(
                      code: 'E',
                      tagLabel: 'Bằng chứng',
                      title: 'CHỌN BẰNG CHỨNG HỖ TRỢ (EVIDENCE)',
                      color: Color(0xFFA8221B),
                    ),
                    if (evidencePrompt != null &&
                        evidencePrompt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        evidencePrompt.trim(),
                        style: DauVietTypography.bodySmall.copyWith(
                          color: const Color(0xFF3A2E25),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ] else if (priorEvidenceIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(
                          'Đã điền sẵn ${priorEvidenceIds.length} bằng chứng đã thu thập ở bước trước.',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF5C4E42),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (evidenceOptions.isEmpty)
                      Text(
                        'Chưa có bằng chứng nào để chọn.',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: DauVietColors.inkMuted,
                        ),
                      )
                    else
                      for (final e in evidenceOptions)
                        Builder(
                          builder: (ctx) {
                            final id = e['id'] as String? ?? '';
                            final doc = widget.content.evidenceById(id);
                            final label = (doc?['title'] as String?) ?? id;
                            return _PickTile(
                              id: id,
                              label: label,
                              selected: _evidenceIds.contains(id),
                              multi: true,
                              accentColor: const Color(0xFFA8221B),
                              enabled: !widget.submitting,
                              priorCollected: priorEvidenceIds.contains(id),
                              onTap: () => _toggleEvidence(id),
                            );
                          },
                        ),
                  ],
                ),
              ),

              const _CERConnector(),

              // Slot 3 — Reasoning (Lập luận)
              TactileCard(
                usePixelShadow: false,
                padding: const EdgeInsets.all(13),
                backgroundColor: const Color(0xFFFAF5E8),
                borderColor: _reasoningId != null
                    ? const Color(0xFFB8781C)
                    : const Color(0xFFDECBA8),
                borderWidth: _reasoningId != null ? 1.6 : 1.2,
                borderRadius: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CerRoleHeader(
                      code: 'R',
                      tagLabel: 'Lập luận',
                      title: 'CHỌN LẬP LUẬN (REASONING)',
                      color: Color(0xFFB8781C),
                    ),
                    if (reasoningPrompt != null &&
                        reasoningPrompt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasoningPrompt.trim(),
                        style: DauVietTypography.bodySmall.copyWith(
                          color: const Color(0xFF3A2E25),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    for (final r in reasoningOptions)
                      _PickTile(
                        id: r['id'] as String? ?? '',
                        label: (r['text'] ?? r['label'] ?? '') as String,
                        selected: _reasoningId == r['id'],
                        multi: false,
                        accentColor: const Color(0xFFB8781C),
                        enabled: !widget.submitting,
                        onTap: () => _pickReasoning(r['id'] as String? ?? ''),
                      ),
                  ],
                ),
              ),

              // Khung tổng hợp kết luận lịch sử C-E-R (TC-ACT-17)
              if (pickedClaimText != null ||
                  pickedEvidenceTitles.isNotEmpty ||
                  pickedReasoningText != null) ...[
                const SizedBox(height: 12),
                TactileCard(
                  usePixelShadow: false,
                  padding: const EdgeInsets.all(13),
                  backgroundColor: const Color(0xFFFFFDF8),
                  borderColor: const Color(0xFFD5B67C),
                  borderWidth: 1.4,
                  borderRadius: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TỔNG HỢP LẬP LUẬN LỊCH SỬ (C–E–R)',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: const Color(0xFFA8221B),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (pickedClaimText != null)
                        Text(
                          '• Luận điểm: $pickedClaimText',
                          style: DauVietTypography.bodySmall.copyWith(
                            color: DauVietColors.inkText,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      if (pickedEvidenceTitles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• Bằng chứng: ${pickedEvidenceTitles.join('; ')}',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.inkText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (pickedReasoningText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• Lập luận: $pickedReasoningText',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.inkText,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
        SubmitBar(
          enabled: _canSubmit,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'claimId': _claimId,
            'evidenceIds': _evidenceIds.toList(),
            'reasoningId': _reasoningId,
          }),
        ),
      ],
    );
  }
}

class _CerRoleHeader extends StatelessWidget {
  final String code;
  final String tagLabel;
  final String title;
  final Color color;

  const _CerRoleHeader({
    required this.code,
    required this.tagLabel,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ImperialDoubleCircleBadge(code, size: 36, color: color, filled: true),
        const SizedBox(width: 6),
        // Dải băng màu viền vàng kèm chấm vàng hai bên (khớp ảnh mẫu #3)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6BE74), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6D98E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                tagLabel,
                style: DauVietTypography.labelSmall.copyWith(
                  color: const Color(0xFFFFF8EB),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6D98E),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: DauVietTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final bool multi;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;
  final bool priorCollected;

  const _PickTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.multi,
    required this.accentColor,
    required this.enabled,
    required this.onTap,
    this.priorCollected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: TactileCard(
        usePixelShadow: false,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 10,
        enabled: enabled,
        backgroundColor: selected
            ? const Color(0xFFFFFDF8)
            : const Color(0xFFFCF9F2),
        borderColor: selected ? accentColor : const Color(0xFFE0D2BA),
        borderWidth: selected ? 1.6 : 1.1,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Row(
            children: [
              // Nút chọn đặt bên TRÁI đúng như ảnh mẫu #3 (Radio cho C/R, Checkbox cho E)
              Icon(
                multi
                    ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : (selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off),
                size: 21,
                color: selected ? accentColor : const Color(0xFF4A3C2E),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: enabled
                        ? const Color(0xFF2B1F17)
                        : const Color(0xFF2B1F17).withValues(alpha: 0.75),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13.2,
                    height: 1.4,
                  ),
                ),
              ),
              if (priorCollected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.history_edu_outlined,
                    size: 16,
                    color: DauVietColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
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
