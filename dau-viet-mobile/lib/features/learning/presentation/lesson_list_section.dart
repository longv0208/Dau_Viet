import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';

/// Danh sách bài học đã xuất bản của một sự kiện — gọi thật
/// `GET /api/v1/events/{eventId}/lessons`. Empty state rõ ràng khi chưa có
/// bài học nào được publish (không fallback mock).
class LessonListSection extends ConsumerWidget {
  final String eventId;

  const LessonListSection({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LessonListItemDto>> lessonsAsync = ref.watch(
      eventLessonsProvider(eventId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BÀI HỌC LỊCH SỬ',
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.inkMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        lessonsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, _) => _LessonCardError(
            error: error,
            onRetry: () => ref.invalidate(eventLessonsProvider(eventId)),
          ),
          data: (lessons) => lessons.isEmpty
              ? const _EmptyLessons()
              : Column(
                  children: [
                    for (final lesson in lessons) ...[
                      _LessonCard(lesson: lesson),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  final LessonListItemDto lesson;

  const _LessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/learning/lesson/${lesson.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DauVietColors.cinnabarRed.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: DauVietColors.cinnabarRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (lesson.centralQuestion != null &&
                      lesson.centralQuestion!.isNotEmpty)
                    Text(
                      lesson.centralQuestion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DauVietColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            color: DauVietColors.inkMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chưa có bài học được xuất bản',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCardError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _LessonCardError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Không tải được danh sách bài học.',
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.inkMuted,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    );
  }
}
