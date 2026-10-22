import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import 'journey_chapter.dart';

/// Thanh điều hướng chặng: nút prev/next + tên sự kiện + "Chặng X/Y".
/// Chỉ điều hướng hiển thị — KHÔNG thay đổi unlockState backend.
class JourneyChapterHeader extends StatelessWidget {
  final JourneyChapter chapter;
  final int totalChapters;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const JourneyChapterHeader({
    super.key,
    required this.chapter,
    required this.totalChapters,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = onPrev != null;
    final canNext = onNext != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          _navButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Chặng trước',
            onPressed: canPrev ? onPrev : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.labelLarge.copyWith(
                    color: DauVietColors.inkText,
                  ),
                ),
                Text(
                  'Chặng ${chapter.index + 1} / $totalChapters • '
                  '${chapter.total} địa điểm',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          _navButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Chặng sau',
            onPressed: canNext ? onNext : null,
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 26),
      color: DauVietColors.woodBrown,
      disabledColor: DauVietColors.outlineVariant,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
