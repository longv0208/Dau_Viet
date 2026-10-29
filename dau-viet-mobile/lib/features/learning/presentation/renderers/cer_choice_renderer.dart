import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
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

  const CerChoiceRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
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
    if (source is! String || prior is! Map) return const [];
    final out = prior[source];
    if (out is! Map) return const [];
    final ids = out['selectedEvidenceIds'];
    if (ids is! List) return const [];
    return ids.whereType<String>().toList();
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
    final evidenceOptions = configList(config, 'evidenceOptions');
    final priorEvidenceIds = _priorEvidenceIds();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1 — Claim
        const _CerRoleHeader(
          step: '1',
          title: 'CHỌN KẾT LUẬN (CLAIM)',
          color: DauVietColors.cinnabarRed,
        ),
        const SizedBox(height: 6),
        for (final c in claims)
          _PickTile(
            id: c['id'] as String? ?? '',
            label: (c['text'] ?? c['label'] ?? '') as String,
            selected: _claimId == c['id'],
            multi: false,
            enabled: !widget.submitting,
            onTap: () => _pickClaim(c['id'] as String? ?? ''),
          ),
        const SizedBox(height: 12),

        // Card 2 — Evidence
        const _CerRoleHeader(
          step: '2',
          title: 'CHỌN BẰNG CHỨNG HỖ TRỢ (EVIDENCE)',
          color: Color(0xFFB45309),
        ),
        if (priorEvidenceIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Đã điền sẵn ${priorEvidenceIds.length} bằng chứng đã thu thập ở bước trước.',
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
        const SizedBox(height: 6),
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
                  enabled: !widget.submitting,
                  priorCollected: priorEvidenceIds.contains(id),
                  onTap: () => _toggleEvidence(id),
                );
              },
            ),
        const SizedBox(height: 12),

        // Card 3 — Reasoning
        const _CerRoleHeader(
          step: '3',
          title: 'CHỌN LẬP LUẬN (REASONING)',
          color: DauVietColors.heritageGreen,
        ),
        const SizedBox(height: 6),
        for (final r in reasoningOptions)
          _PickTile(
            id: r['id'] as String? ?? '',
            label: (r['text'] ?? r['label'] ?? '') as String,
            selected: _reasoningId == r['id'],
            multi: false,
            enabled: !widget.submitting,
            onTap: () => _pickReasoning(r['id'] as String? ?? ''),
          ),

        // Khung tổng hợp kết luận lịch sử C-E-R (TC-ACT-17)
        if (pickedClaimText != null ||
            pickedEvidenceTitles.isNotEmpty ||
            pickedReasoningText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DauVietColors.imperialGold, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TỔNG HỢP LẬP LUẬN LỊCH SỬ (C–E–R)',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
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
        const SizedBox(height: 14),
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
  final String step;
  final String title;
  final Color color;

  const _CerRoleHeader({
    required this.step,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: DauVietTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
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
  final bool enabled;
  final VoidCallback onTap;

  /// TASK-0020 §P5: đánh dấu bằng chứng đã thu thập ở bước trước — học viên
  /// thấy rõ đâu là tư liệu đã kiểm chứng trong flow, không phải chọn lại mò.
  final bool priorCollected;

  const _PickTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.onTap,
    this.priorCollected = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? DauVietColors.cinnabarRed.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: enabled ? 0.85 : 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? DauVietColors.cinnabarRed
                      : DauVietColors.outlineVariant,
                  width: selected ? 1.7 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    multi
                        ? (selected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank)
                        : (selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                    size: 21,
                    color: selected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: enabled
                            ? DauVietColors.inkText
                            : DauVietColors.inkText.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (priorCollected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
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
        ),
      ),
    );
  }
}
