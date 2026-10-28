import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/parchment_card.dart';
import '../../../collection/data/dossier_providers.dart';
import '../../../collection/data/event_progress_dto.dart';
import '../../../learning_path/data/learning_path_dto.dart';
import '../../../learning_path/data/learning_path_providers.dart';

/// Section tiến độ event trong Campaign Detail (GAME-04 §15 + FIX 7/8).
/// States:
///   loading     → placeholder gọn (không SizedBox.shrink — learner thấy
///                 rõ đang tải).
///   error       → thông báo nhỏ + nút Thử lại (không ẩn lỗi mạng).
///   NOT_CONFIGURED → neutral "chưa có mục tiêu".
///   IN_PROGRESS → progress bar x/y bài bắt buộc.
///   COMPLETED/MASTERED → trạng thái + dossier đã mở + CTA collection.
///   FIX 7: earnedPolicyVersion < policyVersion → learner đã hoàn thành
///   bản cũ, còn bài mới — banner nhỏ giải thích.
class EventProgressSection extends ConsumerWidget {
  final String eventId;

  const EventProgressSection({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventProgressProvider(eventId));
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) =>
          _Error(onRetry: () => ref.invalidate(eventProgressProvider(eventId))),
      data: (p) {
        final pathEvent = ref
            .watch(learnerLearningPathProvider)
            .maybeWhen(
              data: (path) => path.findEventById(eventId),
              orElse: () => null,
            );
        return _build(context, p, pathEvent);
      },
    );
  }

  Widget _build(
    BuildContext context,
    EventProgressDto p,
    LearningPathEventNodeDto? pathEvent,
  ) {
    if (p.status == 'NOT_CONFIGURED') {
      return ParchmentCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: DauVietColors.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sự kiện này chưa có mục tiêu hoàn thành — hãy khám phá '
                    'các bài học bên dưới.',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
                if (pathEvent != null) ...[
                  const SizedBox(width: 8),
                  _PathStatusBadge(status: pathEvent.status),
                ],
              ],
            ),
            if (pathEvent != null && pathEvent.lessons.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PathLessonStatusSummary(lessons: pathEvent.lessons),
            ],
          ],
        ),
      );
    }

    final done = p.eventCompleted;
    final mastered = p.eventMastered;
    // FIX 7: milestone cấp theo policy cũ — còn bài mới theo policy hiện tại.
    final earnedOlder =
        done &&
        p.earnedPolicyVersion != null &&
        p.policyVersion != null &&
        p.earnedPolicyVersion! < p.policyVersion!;
    return ParchmentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 18,
                color: done
                    ? DauVietColors.imperialGold
                    : DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  done
                      ? (mastered
                            ? 'ĐÃ TINH THÔNG SỰ KIỆN'
                            : 'ĐÃ HOÀN THÀNH SỰ KIỆN')
                      : 'TIẾN ĐỘ SỰ KIỆN',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: done
                        ? DauVietColors.imperialGold
                        : DauVietColors.cinnabarRed,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (pathEvent != null) ...[
                _PathStatusBadge(status: pathEvent.status),
                const SizedBox(width: 8),
              ],
              Text(
                '${p.requiredLessonsCompleted}/${p.requiredLessonsTotal}',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.inkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            // fraction null khi total=0 — render 0 an toàn.
            value: p.fraction ?? 0,
            minHeight: 6,
            backgroundColor: DauVietColors.parchmentHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              done ? DauVietColors.imperialGold : DauVietColors.cinnabarRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hoàn thành ${p.requiredLessonsCompleted}/${p.requiredLessonsTotal} '
            'bài bắt buộc'
            '${p.masteryThreshold != null ? ' • Ngưỡng tinh thông: ${p.masteryThreshold}' : ''}',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
          ),
          // FIX 7: thông báo nhẹ khi milestone cấp theo policy cũ.
          if (earnedOlder) ...[
            const SizedBox(height: 6),
            Text(
              'Bạn đã hoàn thành phiên bản trước — chính sách mới bổ sung '
              'bài học để khám phá thêm.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (pathEvent != null && pathEvent.lessons.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PathLessonStatusSummary(lessons: pathEvent.lessons),
          ],
          if (p.unlockedDossiersCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: DauVietColors.imperialGold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đã mở ${p.unlockedDossiersCount} hồ sơ lịch sử',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/collection'),
                  style: TextButton.styleFrom(
                    foregroundColor: DauVietColors.cinnabarRed,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    textStyle: DauVietTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('XEM BỘ SƯU TẬP ›'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading placeholder — gọn, không mở rộng layout.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const ParchmentCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Đang tải tiến độ sự kiện…', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Error nhỏ gọn + retry — không ẩn lỗi mạng khỏi learner.
class _Error extends StatelessWidget {
  final VoidCallback onRetry;

  const _Error({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: DauVietColors.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Không tải được tiến độ',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: DauVietColors.cinnabarRed,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              textStyle: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('THỬ LẠI'),
          ),
        ],
      ),
    );
  }
}

/// Nhãn trạng thái của sự kiện/bài học trong lộ trình (icon + nhãn tiếng Việt).
class _PathStatusBadge extends StatelessWidget {
  final LearnerPathStatus status;

  const _PathStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color fg, Color bg) = _styleFor(status);
    return Container(
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
            status.labelVi,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, Color) _styleFor(LearnerPathStatus status) {
    switch (status) {
      case LearnerPathStatus.completed:
        return (
          Icons.check_circle_rounded,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
        );
      case LearnerPathStatus.mastered:
        return (
          Icons.workspace_premium_rounded,
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
        );
      case LearnerPathStatus.inProgress:
        return (
          Icons.timelapse_rounded,
          DauVietColors.cinnabarRed,
          const Color(0xFFFDF2F2),
        );
      case LearnerPathStatus.available:
        return (
          Icons.play_circle_outline_rounded,
          DauVietColors.heritageGreen,
          const Color(0xFFE8F5E9),
        );
      case LearnerPathStatus.locked:
        return (
          Icons.lock_outline_rounded,
          DauVietColors.inkMuted,
          const Color(0xFFEFEBE2),
        );
      case LearnerPathStatus.notReady:
        return (
          Icons.hourglass_empty_rounded,
          DauVietColors.inkMuted,
          const Color(0xFFEFEBE2),
        );
    }
  }
}

/// Tóm tắt trạng thái các bài học thuộc sự kiện theo lộ trình (`LearnerPathStatus`).
class _PathLessonStatusSummary extends StatelessWidget {
  final List<LearningPathLessonNodeDto> lessons;

  const _PathLessonStatusSummary({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final int doneCount = lessons.where((l) => l.status.isDone).length;
    final int openCount = lessons
        .where((l) => l.status.isAvailable || l.status.isInProgress)
        .length;
    final int lockedCount = lessons
        .where((l) => l.status.isLocked || l.status.isNotReady)
        .length;

    return Text(
      'Lộ trình: $doneCount đã xong • $openCount đang mở • $lockedCount đang khóa',
      style: DauVietTypography.bodySmall.copyWith(
        fontSize: 11.5,
        color: DauVietColors.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
