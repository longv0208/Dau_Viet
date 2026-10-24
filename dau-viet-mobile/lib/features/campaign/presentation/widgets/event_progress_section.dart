import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/parchment_card.dart';
import '../../../collection/data/dossier_providers.dart';
import '../../../collection/data/event_progress_dto.dart';

/// Section tiến độ event trong Campaign Detail (GAME-04 §15). States:
/// NOT_CONFIGURED → neutral "chưa cấu hình mục tiêu"; IN_PROGRESS →
/// "Hoàn thành x/y bài bắt buộc" + progress bar; COMPLETED/MASTERED →
/// trạng thái + số dossier đã mở + CTA xem collection.
class EventProgressSection extends ConsumerWidget {
  final String eventId;

  const EventProgressSection({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventProgressProvider(eventId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (p) => _build(context, p),
    );
  }

  Widget _build(BuildContext context, EventProgressDto p) {
    if (p.status == 'NOT_CONFIGURED') {
      return ParchmentCard(
        padding: const EdgeInsets.all(14),
        child: Row(
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
          ],
        ),
      );
    }

    final done = p.eventCompleted;
    final mastered = p.eventMastered;
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
