import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/attempt_dtos.dart';
import 'renderers/learning_asset_image.dart';

/// Lưới 2×2 dấu vết cho Bước 1 "Truy tìm dấu vết" của bài học 4 bước.
///
/// Mỗi ô hiển thị: ảnh đại diện / icon clue type, tên dấu vết, mô tả ngắn,
/// loại hoạt động và trạng thái (NOT_STARTED / IN_PROGRESS / COMPLETED).
/// Clue chưa hoàn thành có thể chọn; clue đã xong hiển thị badge "Đã tìm thấy".
class DiscoveryClueGrid extends StatelessWidget {
  final List<ClueStatusDto> clues;
  final bool submitting;
  final void Function(ClueStatusDto clue) onSelectClue;

  const DiscoveryClueGrid({
    super.key,
    required this.clues,
    required this.submitting,
    required this.onSelectClue,
  });

  static const _clueIcons = <String, IconData>{
    'CONTEXT': Icons.terrain_rounded,
    'CHARACTERS': Icons.people_alt_rounded,
    'DEVELOPMENT': Icons.timeline_rounded,
    'SIGNIFICANCE': Icons.emoji_events_rounded,
  };

  static const _clueLabels = <String, String>{
    'CONTEXT': 'Bối cảnh',
    'CHARACTERS': 'Nhân vật',
    'DEVELOPMENT': 'Diễn biến',
    'SIGNIFICANCE': 'Ý nghĩa',
  };

  static const _activityLabels = <String, String>{
    'READ': 'Đọc tư liệu',
    'VIEW_IMAGE': 'Quan sát hình',
    'MULTIPLE_CHOICE': 'Trắc nghiệm',
    'MATCHING': 'Ghép cặp',
    'DRAG_ORDER': 'Sắp xếp',
    'REASONING_CONNECT': 'Lập luận',
    'EXPLORE_MAP': 'Bản đồ',
    'EVIDENCE_SELECT': 'Chọn bằng chứng',
  };

  @override
  Widget build(BuildContext context) {
    if (clues.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: clues.length,
      itemBuilder: (ctx, i) => _ClueCard(
        clue: clues[i],
        disabled: submitting,
        onTap: () => onSelectClue(clues[i]),
        clueLabel: _clueLabels[clues[i].clueType] ?? clues[i].clueType ?? '',
        clueIcon: _clueIcons[clues[i].clueType] ?? Icons.search_rounded,
        activityLabel: _activityLabels[clues[i].activityType] ?? '',
      ),
    );
  }
}

class _ClueCard extends StatelessWidget {
  final ClueStatusDto clue;
  final bool disabled;
  final VoidCallback onTap;
  final String clueLabel;
  final IconData clueIcon;
  final String activityLabel;

  const _ClueCard({
    required this.clue,
    required this.disabled,
    required this.onTap,
    required this.clueLabel,
    required this.clueIcon,
    required this.activityLabel,
  });

  Widget _iconFallback() => Container(
        color: const Color(0xFFEDE4CF),
        child: Center(
          child: Icon(
            clueIcon,
            size: 32,
            color: DauVietColors.imperialGold.withValues(alpha: 0.6),
          ),
        ),
      );

  Widget _statusChip(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: DauVietTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isDone = clue.completed || clue.status == 'COMPLETED';
    final isInProgress = clue.status == 'IN_PROGRESS';

    final borderColor = isDone
        ? DauVietColors.natureGreen
        : isInProgress
        ? DauVietColors.imperialGold
        : DauVietColors.outlineVariant;

    final title = clue.title ?? clueLabel;
    final desc = clue.description ?? '';

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFFE8F7ED)
              : isInProgress
              ? const Color(0xFFFFF8E8)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isDone ? 2.0 : 1.4),
          boxShadow: isDone || isInProgress
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cover area ────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              child: SizedBox(
                height: 76,
                child: clue.coverAssetId != null
                    ? LearningAssetImage(
                        assetId: clue.coverAssetId!,
                        fit: BoxFit.cover,
                        tappable: false,
                      )
                    : _iconFallback(),
              ),
            ),
            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chip loại dấu vết
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.imperialGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: DauVietColors.imperialGold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(clueIcon, size: 10, color: DauVietColors.imperialGold),
                          const SizedBox(width: 3),
                          Text(
                            clueLabel.toUpperCase(),
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.imperialGold,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Tiêu đề dấu vết
                    Text(
                      title,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DauVietColors.inkText,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkMuted,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    // Status row
                    Row(
                      children: [
                        if (isDone)
                          _statusChip(
                            'ĐÃ TÌM THẤY',
                            DauVietColors.natureGreen,
                            Icons.check_circle_rounded,
                          )
                        else if (isInProgress)
                          _statusChip(
                            'ĐANG TÌM',
                            DauVietColors.imperialGoldDark,
                            Icons.hourglass_top_rounded,
                          )
                        else
                          _statusChip(
                            activityLabel.isNotEmpty ? activityLabel : 'CHƯA TÌM',
                            DauVietColors.inkMuted,
                            Icons.lock_open_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
