import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
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

  const EvidenceSelectRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<EvidenceSelectRenderer> createState() => _EvidenceSelectRendererState();
}

class _EvidenceSelectRendererState extends State<EvidenceSelectRenderer> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    final int? maxSelect = (widget.activity.config['maxSelect'] as num?)
        ?.toInt();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (maxSelect == null || _selected.length < maxSelect) {
        _selected.add(id);
      }
      widget.onInputChanged?.call(_selected.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final ids = configIdList(config, 'visibleEvidenceIds');
    final int minRequired =
        ((config['minRequired'] ?? config['minSelect']) as num?)?.toInt() ?? 1;
    if (ids.isEmpty) {
      return const _NoEvidence();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('CHỌN ÍT NHẤT $minRequired BẰNG CHỨNG PHÙ HỢP'),
        const SizedBox(height: 4),
        Text(
          'Chạm vào thẻ để xem chi tiết; chạm dấu tích để chọn.',
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: DauVietColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (final id in ids)
          _EvidenceCard(
            evidence: widget.content.evidenceById(id),
            fallbackId: id,
            selected: _selected.contains(id),
            enabled: !widget.submitting,
            onSelect: () => _toggle(id),
            onDetail: () => _showDetail(id),
          ),
        const SizedBox(height: 10),
        Text(
          'Đã chọn ${_selected.length}/$minRequired',
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            color: _selected.length >= minRequired
                ? const Color(0xFF4C7C44)
                : DauVietColors.inkMuted,
            fontWeight: _selected.length >= minRequired
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
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
      backgroundColor: DauVietColors.parchmentSurface,
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

class _EvidenceCard extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onDetail;

  const _EvidenceCard({
    required this.evidence,
    required this.fallbackId,
    required this.selected,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onDetail : null, // mở detail trước
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? DauVietColors.cinnabarRed.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: enabled ? 0.9 : 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.outlineVariant,
                width: selected ? 1.7 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (assetId != null) ...[
                  LearningAssetImage(
                    assetId: assetId,
                    altText: title,
                    height: 120,
                    fit: BoxFit.cover,
                    tappable: false, // tap card = detail sheet
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DauVietColors.inkText,
                              height: 1.35,
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
                                  color: DauVietColors.inkMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          if (sourceText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Nguồn: $sourceText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 8),
                    // Nút chọn riêng — dừng propagation để không mở detail.
                    Semantics(
                      button: true,
                      selected: selected,
                      enabled: enabled,
                      label: selected
                          ? 'Bỏ chọn bằng chứng $title'
                          : 'Chọn bằng chứng $title',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled ? onSelect : null,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_off,
                            size: 24,
                            color: selected
                                ? DauVietColors.cinnabarRed
                                : DauVietColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return const ActivityCard(
      child: Text('Không có bằng chứng nào để chọn trong hoạt động này.'),
    );
  }
}
