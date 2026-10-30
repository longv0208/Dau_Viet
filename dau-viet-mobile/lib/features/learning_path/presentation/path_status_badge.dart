import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/learning_path_dto.dart';

/// Cấu hình hiển thị trực quan cho từng trạng thái [LearnerPathStatus].
/// Luôn kết hợp cả [icon] và [label] tiếng Việt rõ nghĩa (AC-1: không chỉ dùng màu).
class PathStatusVisual {
  final LearnerPathStatus status;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const PathStatusVisual({
    required this.status,
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  static PathStatusVisual of(LearnerPathStatus status) {
    switch (status) {
      case LearnerPathStatus.mastered:
        return PathStatusVisual(
          status: status,
          icon: Icons.workspace_premium_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.woodBrown,
          backgroundColor: DauVietColors.imperialGoldLight,
          borderColor: DauVietColors.imperialGold,
        );
      case LearnerPathStatus.completed:
        return PathStatusVisual(
          status: status,
          icon: Icons.check_circle_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.heritageGreen,
          backgroundColor: DauVietColors.heritageGreenSurface,
          borderColor: DauVietColors.natureGreen,
        );
      case LearnerPathStatus.inProgress:
        return PathStatusVisual(
          status: status,
          icon: Icons.timelapse_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.cinnabarRed,
          backgroundColor: const Color(0xFFFCEAE8),
          borderColor: DauVietColors.cinnabarRed,
        );
      case LearnerPathStatus.available:
        return PathStatusVisual(
          status: status,
          icon: Icons.lock_open_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.heritageGreen,
          backgroundColor: DauVietColors.parchmentContainer,
          borderColor: DauVietColors.heritageGreenLight,
        );
      case LearnerPathStatus.locked:
        return PathStatusVisual(
          status: status,
          icon: Icons.lock_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.inkMuted,
          backgroundColor: DauVietColors.parchmentDim,
          borderColor: DauVietColors.outlineVariant,
        );
      case LearnerPathStatus.notReady:
        return PathStatusVisual(
          status: status,
          icon: Icons.hourglass_empty_rounded,
          label: status.labelVi,
          foregroundColor: DauVietColors.inkLight,
          backgroundColor: DauVietColors.parchmentDim,
          borderColor: DauVietColors.outlineVariant,
        );
    }
  }
}

/// Huy hiệu trạng thái học tập — hiển thị cả biểu tượng [Icon] và nhãn chữ
/// tiếng Việt (AC-1: không phụ thuộc duy nhất vào màu sắc).
class PathStatusBadge extends StatelessWidget {
  final LearnerPathStatus status;
  final bool compact;
  final String? customLabel;

  const PathStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final visual = PathStatusVisual.of(status);
    final displayLabel = customLabel ?? visual.label;

    return Semantics(
      container: true,
      label: 'Trạng thái: $displayLabel',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: visual.backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visual.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              visual.icon,
              size: compact ? 13 : 15,
              color: visual.foregroundColor,
            ),
            SizedBox(width: compact ? 4 : 5),
            Text(
              displayLabel,
              style:
                  (compact
                          ? DauVietTypography.labelSmall
                          : DauVietTypography.labelMedium)
                      .copyWith(
                        fontSize: compact ? 11 : 12,
                        color: visual.foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Huy hiệu phân loại sự kiện (`REQUIRED` / `EXPLORATION_ONLY`) kèm icon + nhãn.
class ParticipationTypeBadge extends StatelessWidget {
  final ParticipationType participationType;

  const ParticipationTypeBadge({super.key, required this.participationType});

  @override
  Widget build(BuildContext context) {
    final isRequired = participationType.isRequired;
    final icon = isRequired ? Icons.flag_rounded : Icons.explore_rounded;
    final fg = isRequired ? DauVietColors.woodBrown : DauVietColors.riverBlue;
    final bg = isRequired
        ? DauVietColors.parchmentHigh
        : const Color(0xFFE6F3F8);

    return Semantics(
      container: true,
      label: 'Loại sự kiện: ${participationType.labelVi}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              participationType.labelVi,
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 10.5,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tổng hợp trạng thái đại diện của một thời kỳ (`PERIOD`) từ tiến độ và danh sách sự kiện.
LearnerPathStatus derivePeriodStatus({
  required List<LearningPathEventNodeDto> events,
  PeriodProgressDto? progress,
}) {
  if (events.isEmpty) {
    return LearnerPathStatus.notReady;
  }
  if (events.every((e) => e.status.isNotReady)) {
    return LearnerPathStatus.notReady;
  }

  final requiredEvents = events.where((e) => e.isRequired).toList();
  if (requiredEvents.isNotEmpty &&
      requiredEvents.every((e) => e.status.isMastered)) {
    return LearnerPathStatus.mastered;
  }
  if ((progress != null && progress.isCompleted) ||
      (requiredEvents.isNotEmpty &&
          requiredEvents.every((e) => e.status.isDone))) {
    return LearnerPathStatus.completed;
  }

  final hasInProgressOrDone =
      (progress != null && progress.hasStarted) ||
      events.any(
        (e) =>
            e.status.isInProgress ||
            e.status.isDone ||
            e.lessons.any((l) => l.status.isInProgress || l.status.isDone),
      );
  if (hasInProgressOrDone) {
    return LearnerPathStatus.inProgress;
  }
  // AC-2 (Issue #48): thời kỳ có nội dung học luôn tự do được chọn — tuyệt đối
  // không trả về `locked`/`Đang khóa`. Chưa bắt đầu (0%) → "Sẵn sàng khám phá".
  return LearnerPathStatus.available;
}
