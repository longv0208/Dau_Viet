import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../data/map_location_dto.dart';

/// Node SỰ KIỆN / BÀI HỌC trên canvas Bản Đồ Dấu Ấn (Issue #36 / #40).
///
/// Nguồn dữ liệu chuẩn là `LearningPathEventNodeDto` từ
/// `GET /api/v1/me/learning-path` — KHÔNG phụ thuộc `map_locations`,
/// nên bài học không gắn địa điểm di tích vẫn render đầy đủ (AC-2).
///
/// Visual grammar v3:
/// - `AVAILABLE` / `IN_PROGRESS`: `TactileCard` nhỏ (padding 10, radius 18,
///   viền `chapterGreen` 2px).
/// - `COMPLETED` / `MASTERED`: overlay `StampSealBadge.success('✓', size: 28)` ở góc.
/// - `LOCKED`: grayscale + `StampSealBadge.outline('🔒', size: 24)` + icon khóa `jade`.
/// - `yearLabel` nhỏ bằng `sectionEyebrow` typography.
/// - Tap-scale animation 90ms qua `GestureDetector` + `AnimatedScale`.
class PathEventNode extends StatefulWidget {
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
  State<PathEventNode> createState() => _PathEventNodeState();
}

class _PathEventNodeState extends State<PathEventNode> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final (color, icon, fill) = _visualFor(event);
    final lessonsTotal = event.lessons.length;
    final lessonsDone = event.completedLessonsCount;

    final isPlayable = event.isPlayable && !event.status.isNotReady;
    final isActive =
        isPlayable &&
        (event.status == LearnerPathStatus.available ||
            event.status == LearnerPathStatus.inProgress);
    final isDone =
        isPlayable &&
        (event.status == LearnerPathStatus.completed ||
            event.status == LearnerPathStatus.mastered);
    final isLocked = !isPlayable || event.status == LearnerPathStatus.locked;

    final borderColor = isActive
        ? DauVietColors.chapterGreen
        : isDone
        ? DauVietColors.imperialGold
        : DauVietColors.outlineVariant;
    final borderWidth = (isActive || isDone || widget.selected) ? 2.0 : 1.4;
    final cardBg = widget.selected
        ? DauVietColors.paperCardHi
        : isLocked
        ? DauVietColors.paperDim
        : DauVietColors.paperCard;

    Widget cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: isLocked ? DauVietColors.jade : color,
              width: 2.0,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isLocked ? DauVietColors.jade : color,
          ),
        ),
        if (event.yearLabel.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            event.yearLabel.trim().toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: DauVietTypography.sectionEyebrow.copyWith(
              fontSize: 8.5,
              letterSpacing: 0.8,
              color: isLocked
                  ? DauVietColors.inkLight
                  : DauVietColors.cinnabarRed,
            ),
          ),
        ],
        const SizedBox(height: 3),
        Text(
          event.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DauVietTypography.labelSmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isLocked
                ? DauVietColors.inkMuted
                : DauVietColors.inkHeading,
            height: 1.15,
          ),
        ),
        if (lessonsTotal > 1) ...[
          const SizedBox(height: 2),
          Text(
            '$lessonsDone/$lessonsTotal bài',
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 9,
              color: isLocked ? DauVietColors.inkLight : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    if (isLocked) {
      cardContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.55, 0.35, 0.10, 0, 0, //
          0.25, 0.65, 0.10, 0, 0, //
          0.20, 0.30, 0.50, 0, 0, //
          0, 0, 0, 0.88, 0, //
        ]),
        child: cardContent,
      );
    }

    return Semantics(
      button: true,
      label: '${event.title} — ${event.status.labelVi}',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
              maxWidth: 128,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                TactileCard(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 18,
                  backgroundColor: cardBg,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  usePixelShadow: !isLocked,
                  child: cardContent,
                ),
                if (isDone)
                  const Positioned(
                    top: -8,
                    right: -8,
                    child: StampSealBadge.success('✓', size: 28),
                  )
                else if (isLocked)
                  const Positioned(
                    top: -6,
                    right: -6,
                    child: StampSealBadge.outline('🔒', size: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData, Color) _visualFor(LearningPathEventNodeDto e) {
    if (!e.isPlayable || e.status.isNotReady) {
      return (
        DauVietColors.jade,
        Icons.edit_note_rounded,
        DauVietColors.paperDim,
      );
    }
    if (e.isExplorationOnly) {
      return (
        DauVietColors.woodBrown,
        Icons.travel_explore_rounded,
        DauVietColors.paperCardHi,
      );
    }
    return switch (e.status) {
      LearnerPathStatus.completed ||
      LearnerPathStatus.mastered => (
        DauVietColors.imperialGoldDark,
        Icons.check_circle_rounded,
        DauVietColors.imperialGoldLight.withValues(alpha: 0.9),
      ),
      LearnerPathStatus.inProgress => (
        DauVietColors.cinnabarRed,
        Icons.play_circle_filled_rounded,
        DauVietColors.imperialGoldLight.withValues(alpha: 0.85),
      ),
      LearnerPathStatus.available => (
        DauVietColors.chapterGreen,
        Icons.flag_rounded,
        DauVietColors.heritageGreenSurface,
      ),
      LearnerPathStatus.locked => (
        DauVietColors.jade,
        Icons.lock_rounded,
        DauVietColors.paperDim,
      ),
      LearnerPathStatus.notReady => (
        DauVietColors.jade,
        Icons.edit_note_rounded,
        DauVietColors.paperDim,
      ),
    };
  }
}
