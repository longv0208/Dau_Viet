import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/parchment_card.dart';
import '../../../collection/data/dossier_providers.dart';
import '../../../collection/data/event_progress_dto.dart';

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
