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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final prior = _priorEvidenceIds();
    if (prior.isNotEmpty) {
      _evidenceIds.addAll(prior);
    }
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

  void _pickClaim(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _claimId = id;
      widget.onInputChanged?.call(true);
    });
  }

  void _toggleEvidence(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _evidenceIds.contains(id)
          ? _evidenceIds.remove(id)
          : _evidenceIds.add(id);
      widget.onInputChanged?.call(_evidenceIds.isNotEmpty);
    });
  }

  void _pickReasoning(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _reasoningId = id;
      widget.onInputChanged?.call(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final claims = configList(config, 'claims');
    final reasoningOptions = configList(config, 'reasoningOptions');
    final evidenceOptions = configList(config, 'evidenceOptions');
    final priorEvidenceIds = _priorEvidenceIds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1 — Claim
        const SectionLabel('1. CHỌN KẾT LUẬN'),
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
        const SectionLabel('2. CHỌN BẰNG CHỨNG HỖ TRỢ'),
        if (priorEvidenceIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Đã điền sẵn ${priorEvidenceIds.length} bằng chứng đã chọn ở bước trước.',
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
            Builder(builder: (ctx) {
              final id = e['id'] as String? ?? '';
              final doc = widget.content.evidenceById(id);
              final label = (doc?['title'] as String?) ?? id;
              return _PickTile(
                id: id,
                label: label,
                selected: _evidenceIds.contains(id),
                multi: true,
                enabled: !widget.submitting,
                onTap: () => _toggleEvidence(id),
              );
            }),
        const SizedBox(height: 12),

        // Card 3 — Reasoning
        const SectionLabel('3. CHỌN LẬP LUẬN'),
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

class _PickTile extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final bool multi;
  final bool enabled;
  final VoidCallback onTap;

  const _PickTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration:
                reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
