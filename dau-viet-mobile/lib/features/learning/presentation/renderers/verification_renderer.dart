import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// VERIFICATION — Learning Flow 2.0 (TASK-0020 §P7): màn hình hiển thị lại
/// giả thuyết đã chọn (output HYPOTHESIS_CHOICE) cùng bằng chứng đã thu thập
/// (output của EVIDENCE_SELECT được khai báo qua `config.evidenceSource`, hoặc
/// bằng chứng kèm giả thuyết ở snapshot cũ), cộng với `visibleSourceIds` để
/// đối chiếu. Học viên thực hiện một hành động kiểm chứng có chủ đích —
/// submit `{action: "verify"}`; server chấm SUPPORTED/PARTIAL/CONTRADICTED.
/// Không có chọn verdict phía client (verdict do backend quyết định).
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
  /// fallback về `hypothesisId` khi chạy preview độc lập không có stages.
  String _resolveHypothesisLabel(String hypothesisId) {
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
    final config = activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'text']);
    final sourceIds = configIdList(config, 'visibleSourceIds').isNotEmpty
        ? configIdList(config, 'visibleSourceIds')
        : configIdList(config, 'visibleEvidenceIds');
    final hypothesisId = _priorHypothesisId(config);
    final givenIds = _evidenceGiven(config);

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

        // Giả thuyết đã chọn ở bước HYPOTHESIS — ngữ cảnh kiểm chứng.
        if (hypothesisId != null) ...[
          const SizedBox(height: 10),
          const SectionLabel('GIẢ THUYẾT ĐÃ CHỌN'),
          const SizedBox(height: 6),
          _PickedTile(
            label: _resolveHypothesisLabel(hypothesisId),
            icon: Icons.lightbulb_outline,
          ),
        ],

        // Bằng chứng đã thu thập trước đó — server dùng chính tập này để chấm.
        if (givenIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionLabel('BẰNG CHỨNG ĐÃ THU THẬP'),
          const SizedBox(height: 6),
          for (final id in givenIds)
            _PickedTile(
              label: _evidenceTitle(id),
              icon: Icons.bookmark_added_outlined,
            ),
        ],

        if (sourceIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionLabel('ĐỐI CHIẾU CÁC NGUỒN SAU'),
          const SizedBox(height: 6),
          for (final id in sourceIds) _SourceTile(id: id, content: content),
        ],
        const SizedBox(height: 14),
        SubmitBar(
          label: 'KIỂM CHỨNG',
          enabled: true,
          submitting: submitting,
          onPressed: () => onSubmit({'action': 'verify'}),
        ),
      ],
    );
  }

  String _evidenceTitle(String id) {
    final e = content.evidenceById(id);
    return (e?['title'] as String?) ?? id;
  }
}

/// Ô hiển thị một lựa chọn đã ghi nhận trước đó (read-only).
class _PickedTile extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PickedTile({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DauVietColors.cinnabarRed),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: DauVietColors.cinnabarRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: DauVietTypography.labelMedium.copyWith(
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
