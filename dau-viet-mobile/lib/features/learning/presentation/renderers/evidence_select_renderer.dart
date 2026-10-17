import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// EVIDENCE_SELECT — chọn các bằng chứng liên quan từ `visibleEvidenceIds`
/// (resolve metadata từ snapshot `evidence[]`). Submit `{selectedEvidenceIds}`.
/// Enable submit khi đủ `minRequired` (mặc định 1). KHÔNG lộ requiredEvidenceIds.
class EvidenceSelectRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const EvidenceSelectRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<EvidenceSelectRenderer> createState() => _EvidenceSelectRendererState();
}

class _EvidenceSelectRendererState extends State<EvidenceSelectRenderer> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final ids = configIdList(config, 'visibleEvidenceIds');
    final int minRequired = (config['minRequired'] as num?)?.toInt() ?? 1;

    if (ids.isEmpty) {
      return const _NoEvidence();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('CHỌN ÍT NHẤT $minRequired BẰNG CHỨNG PHÙ HỢP'),
        const SizedBox(height: 8),
        for (final id in ids)
          _EvidenceTile(
            evidence: widget.content.evidenceById(id),
            fallbackId: id,
            selected: _selected.contains(id),
            enabled: !widget.submitting,
            onTap: () => setState(() {
              _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
            }),
          ),
        const SizedBox(height: 10),
        SubmitBar(
          enabled: _selected.length >= minRequired,
          submitting: widget.submitting,
          onPressed: () =>
              widget.onSubmit({'selectedEvidenceIds': _selected.toList()}),
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _EvidenceTile({
    required this.evidence,
    required this.fallbackId,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final String title = (e?['title'] as String?) ?? fallbackId;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.cinnabarRed.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.inkMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          desc,
                          style: DauVietTypography.bodySmall.copyWith(
                            color: DauVietColors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (sourceText != null && sourceText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Nguồn: $sourceText',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 11,
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

class _NoEvidence extends StatelessWidget {
  const _NoEvidence();

  @override
  Widget build(BuildContext context) {
    return const ActivityCard(
      child: Text('Không có bằng chứng nào để chọn trong hoạt động này.'),
    );
  }
}
