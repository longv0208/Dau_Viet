import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// VERIFICATION — học viên đối chiếu lại các nguồn (`visibleSourceIds` /
/// `visibleEvidenceIds`) rồi xác nhận muốn kiểm chứng lại.
/// Submit `{revise: true}` — server quyết định kết quả.
class VerificationRenderer extends StatelessWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const VerificationRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final config = activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'text']);
    final sourceIds = configIdList(config, 'visibleSourceIds').isNotEmpty
        ? configIdList(config, 'visibleSourceIds')
        : configIdList(config, 'visibleEvidenceIds');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt != null)
          ActivityCard(
            child: Text(
              prompt,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        if (sourceIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionLabel('ĐỐI CHIẾU CÁC NGUỒN SAU'),
          const SizedBox(height: 6),
          for (final id in sourceIds) _SourceTile(id: id, content: content),
        ],
        const SizedBox(height: 14),
        SubmitBar(
          label: 'KIỂM CHỨNG LẠI',
          enabled: true,
          submitting: submitting,
          onPressed: () => onSubmit({'revise': true}),
        ),
      ],
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DauVietColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: DauVietColors.cinnabarRed,
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
    );
  }
}
