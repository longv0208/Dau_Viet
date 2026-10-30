import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
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
      return _TurtleSyncBannerContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: DauVietColors.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sự kiện này chưa có mục tiêu hoàn thành — hãy khám phá '
                    'các bài học bên dưới.',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF4A3C2E),
                      height: 1.35,
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
              const SizedBox(height: 6),
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
    return _TurtleSyncBannerContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 17,
                color: done
                    ? DauVietColors.imperialGoldDark
                    : DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 6),
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
                        ? DauVietColors.imperialGoldDark
                        : DauVietColors.cinnabarRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (pathEvent != null) ...[
                _PathStatusBadge(status: pathEvent.status),
                const SizedBox(width: 6),
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
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p.fraction ?? 0,
              minHeight: 6,
              backgroundColor: DauVietColors.parchmentHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                done ? DauVietColors.imperialGold : DauVietColors.cinnabarRed,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hoàn thành ${p.requiredLessonsCompleted}/${p.requiredLessonsTotal} '
            'bài bắt buộc'
            '${p.masteryThreshold != null ? ' • Ngưỡng tinh thông: ${p.masteryThreshold}' : ''}',
            style: DauVietTypography.bodySmall.copyWith(
              color: const Color(0xFF5C4E42),
              fontSize: 11.5,
            ),
          ),
          if (earnedOlder) ...[
            const SizedBox(height: 4),
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
            const SizedBox(height: 6),
            _PathLessonStatusSummary(lessons: pathEvent.lessons),
          ],
          if (p.unlockedDossiersCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: DauVietColors.imperialGoldDark,
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
                    minimumSize: const Size(0, 30),
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

/// Khung banner giấy dó có linh vật Rùa Kabi cầm chiếu thư bên trái (khớp ảnh mẫu #1).
class _TurtleSyncBannerContainer extends StatelessWidget {
  final Widget child;
  const _TurtleSyncBannerContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFCF7EB), Color(0xFFF6EAD3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEC69A), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x145D4024),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/kabi_sync_scroll.png',
            width: 58,
            height: 50,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const Icon(
              Icons.auto_stories_rounded,
              size: 32,
              color: DauVietColors.heritageGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Loading placeholder — gọn, có Rùa Kabi cầm chiếu thư (khớp ảnh mẫu #1).
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return _TurtleSyncBannerContainer(
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang tải tiến độ sự kiện…',
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B1F17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error nhỏ gọn + nút THỬ LẠI bo viền đỏ/vàng (khớp ảnh mẫu #1).
class _Error extends StatelessWidget {
  final VoidCallback onRetry;

  const _Error({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _TurtleSyncBannerContainer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Không tải được tiến độ',
                  style: DauVietTypography.labelMedium.copyWith(
                    color: const Color(0xFF2B1F17),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dữ liệu học tập của bạn sẽ được cập nhật mới nhất trên mọi thiết bị.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: const Color(0xFF6B5B4B),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 14,
              color: Color(0xFFA8221B),
            ),
            label: const Text('THỬ LẠI'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA8221B),
              backgroundColor: const Color(0xFFFFFDF8),
              side: const BorderSide(color: Color(0xFFDEC69A), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
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
