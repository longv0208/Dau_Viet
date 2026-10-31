import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/tactile_card.dart';
import 'learning_asset_image.dart';

/// Compact evidence card (~76–90px) — checkbox riêng + title + 1–2 dòng
/// desc + nút 'Đọc đầy đủ' text (không phải icon đơn độc). Tapping content
/// hoặc 'Đọc đầy đủ' gọi [onReadFull]; chỉ checkbox gọi [onToggleSelect].
/// Dùng chung cho EVIDENCE_SELECT + VERIFICATION (interactive + legacy).
class CompactEvidenceCard extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  final bool enabled;

  /// 'correct' | 'incorrect' | null — verdict của EVIDENCE_SELECT.
  final String? verdict;

  /// `false` → ẩn cột checkbox (legacy verification read-only).
  final bool showCheckbox;
  final VoidCallback onToggleSelect;
  final VoidCallback onReadFull;

  /// Hiện 'Nguồn: ...' — chỉ bỏ khi parent đã render category/source khác.
  final bool showSource;

  const CompactEvidenceCard({
    super.key,
    required this.evidence,
    required this.fallbackId,
    required this.selected,
    required this.enabled,
    this.verdict,
    this.showCheckbox = true,
    required this.onToggleSelect,
    required this.onReadFull,
    this.showSource = true,
  });

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final String title = (e?['title'] as String?) ?? fallbackId;
    final String? desc = e?['description'] as String?;
    final String sourceText = sourceTextOf(e);
    final String? assetId = imageAssetIdOf(e);
    final String? category = evidenceCategoryOf(e);
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
      padding: const EdgeInsets.only(bottom: 8),
      child: TactileCard(
        usePixelShadow: false,
        enabled: enabled,
        onTap: enabled ? onReadFull : null,
        backgroundColor: selected
            ? const Color(0xFFFFFDF9)
            : const Color(0xFFFAF5E8),
        borderColor: borderColor,
        borderWidth: (selected || isVerdictCorrect || isVerdictIncorrect)
            ? 1.8
            : 1.2,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                    _verdictBadge(
                      '✓ Đúng dấu vết liên quan',
                      DauVietColors.natureGreen,
                    ),
                  if (isVerdictIncorrect)
                    _verdictBadge(
                      '✗ Chưa liên quan câu hỏi',
                      DauVietColors.cinnabarRed,
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showCheckbox) ...[
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
                      onTap: enabled ? onToggleSelect : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: selected
                                  ? DauVietColors.imperialGold
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected
                                    ? DauVietColors.imperialGold
                                    : DauVietColors.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (assetId != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 64,
                      child: LearningAssetImage(
                        assetId: assetId,
                        altText: title,
                        height: 64,
                        fit: BoxFit.cover,
                        tappable: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category != null &&
                          !isVerdictCorrect &&
                          !isVerdictIncorrect &&
                          assetId == null) ...[
                        ClueTag.category(category, filled: selected),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A1C16),
                          height: 1.28,
                        ),
                      ),
                      if (desc != null && desc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
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
                      if (showSource && sourceText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 11,
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
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled ? onReadFull : null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.manage_search_rounded,
                                size: 14,
                                color: Color(0xFF1A6B64),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Đọc đầy đủ',
                                style: DauVietTypography.labelSmall.copyWith(
                                  color: const Color(0xFF1A6B64),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVerdictCorrect || isVerdictIncorrect)
                  const SizedBox(width: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verdictBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: DauVietTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Bottom sheet đọc chi tiết bằng chứng — tự giới hạn max 85% chiều cao
/// màn hình. `canSelect=false` → ẩn nút chọn (read-only).
class EvidenceDetailSheet extends StatelessWidget {
  final Map<String, dynamic>? evidence;
  final String fallbackId;
  final bool selected;
  final bool canSelect;
  final VoidCallback onToggle;

  const EvidenceDetailSheet({
    super.key,
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
    final String sourceText = sourceTextOf(e);
    final String? assetId = imageAssetIdOf(e);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
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
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String sourceTextOf(Map<String, dynamic>? e) {
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

String? imageAssetIdOf(Map<String, dynamic>? e) {
  final raw = e?['imageAssetId'] ?? e?['assetId'] ?? e?['imageId'];
  return raw is String && raw.isNotEmpty ? raw : null;
}

String? evidenceCategoryOf(Map<String, dynamic>? e) {
  final raw = e?['type'] ?? e?['category'] ?? e?['kind'];
  return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
}
