import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../data/map_location_dto.dart';

/// Node SỰ KIỆN / BÀI HỌC trên canvas Bản Đồ Dấu Ấn (Issue #36).
///
/// Nguồn dữ liệu chuẩn là `LearningPathEventNodeDto` từ
/// `GET /api/v1/me/learning-path` — KHÔNG phụ thuộc `map_locations`,
/// nên bài học không gắn địa điểm di tích vẫn render đầy đủ (AC-2).
///
/// Visual grammar giữ nguyên hệ cũ: `COMPLETED`/`MASTERED` vàng đặc,
/// `AVAILABLE`/`IN_PROGRESS` son/xanh, `LOCKED` xám, `NOT_READY` mờ.
/// Mọi trạng thái đều có Icon + nhãn chữ; hit target ≥ 44px.
class PathEventNode extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final bool selected;
  final VoidCallback onTap;

  const PathEventNode({
    super.key,
    required this.event,
    required this.selected,
    required this.onTap,
  });

  /// Ánh xạ `LearnerPathStatus -> MapUnlockState` để tái dùng
  /// `JourneyPathPainter` (đường nối chỉ cần 3 trạng thái hiển thị).
  static MapUnlockState toUnlockState(LearnerPathStatus status) {
    return switch (status) {
      LearnerPathStatus.completed ||
      LearnerPathStatus.mastered => MapUnlockState.unlocked,
      LearnerPathStatus.available ||
      LearnerPathStatus.inProgress => MapUnlockState.available,
      LearnerPathStatus.locked ||
      LearnerPathStatus.notReady => MapUnlockState.locked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, fill) = _visualFor(event);
    final lessonsTotal = event.lessons.length;
    final lessonsDone = event.completedLessonsCount;

    return Semantics(
      button: true,
      label: '${event.title} — ${event.status.labelVi}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: color, width: 2.4),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: DauVietColors.parchmentContainer.withValues(
                    alpha: 0.92,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                        height: 1.1,
                      ),
                    ),
                    if (lessonsTotal > 1)
                      Text(
                        '$lessonsDone/$lessonsTotal bài',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.w700,
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

  (Color, IconData, Color) _visualFor(LearningPathEventNodeDto e) {
    if (!e.isPlayable || e.status.isNotReady) {
      return (
        DauVietColors.inkLight,
        Icons.edit_note_rounded,
        DauVietColors.parchmentDim,
      );
    }
    if (e.isExplorationOnly) {
      return (
        DauVietColors.woodBrown,
        Icons.travel_explore_rounded,
        DauVietColors.parchmentHigh,
      );
    }
    return switch (e.status) {
      LearnerPathStatus.completed ||
      LearnerPathStatus.mastered => (
        DauVietColors.imperialGold,
        Icons.check_circle_rounded,
        DauVietColors.imperialGoldLight.withValues(alpha: 0.9),
      ),
      LearnerPathStatus.inProgress => (
        DauVietColors.cinnabarRed,
        Icons.play_circle_filled_rounded,
        DauVietColors.imperialGoldLight.withValues(alpha: 0.85),
      ),
      LearnerPathStatus.available => (
        DauVietColors.cinnabarRed,
        Icons.flag_rounded,
        DauVietColors.natureGreen.withValues(alpha: 0.85),
      ),
      LearnerPathStatus.locked => (
        DauVietColors.inkLight,
        Icons.lock_rounded,
        DauVietColors.parchmentDim,
      ),
      LearnerPathStatus.notReady => (
        DauVietColors.inkLight,
        Icons.edit_note_rounded,
        DauVietColors.parchmentDim,
      ),
    };
  }
}
