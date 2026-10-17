import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../data/attempt_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/renderer_base.dart';

/// Provider fetch result khi màn hình được mở trực tiếp (deep link / reload)
/// mà không có `extra` từ player.
Duration? _noRetry(int retryCount, Object error) => null;

final _resultProvider = FutureProvider.autoDispose
    .family<LessonResultDto, String>(retry: _noRetry, (ref, attemptId) async {
      final repo = ref.watch(attemptRepositoryProvider);
      return repo.getResult(attemptId);
    });

/// Màn hình kết quả bài học — nhận `LessonResultDto` qua `extra` (từ player)
/// hoặc tự fetch theo `attemptId` khi deep-link. KHÔNG hiển thị answer key;
/// chỉ status/score/tóm tắt server trả về.
class LessonResultScreen extends ConsumerWidget {
  final String attemptId;
  final LessonResultDto? initialResult;

  const LessonResultScreen({
    super.key,
    required this.attemptId,
    this.initialResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialResult != null) {
      return _ResultView(result: initialResult!);
    }
    final asyncResult = ref.watch(_resultProvider(attemptId));
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: SafeArea(
        child: asyncResult.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_resultProvider(attemptId)),
          ),
          data: (r) => _ResultView(result: r),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final LessonResultDto result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final bool completed = result.status.toUpperCase() == 'COMPLETED';
    final score = result.score;
    final summary =
        result.result['summary'] as String? ??
        result.result['message'] as String?;

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  completed ? Icons.emoji_events_rounded : Icons.flag_outlined,
                  size: 72,
                  color: completed
                      ? DauVietColors.imperialGold
                      : DauVietColors.inkMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  completed ? 'HOÀN THÀNH BÀI HỌC' : 'KẾT THÚC LƯỢT HỌC',
                  style: DauVietTypography.headlineSmall.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (score != null)
                  ActivityCard(
                    child: Column(
                      children: [
                        const SectionLabel('ĐIỂM SỐ'),
                        const SizedBox(height: 4),
                        Text(
                          score == score.roundToDouble()
                              ? '${score.toInt()}'
                              : score.toStringAsFixed(1),
                          style: DauVietTypography.headlineMedium.copyWith(
                            color: DauVietColors.cinnabarRed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ActivityCard(
                    child: Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                DongSonButton(
                  label: 'VỀ TRANG CHỦ',
                  icon: Icons.home_rounded,
                  variant: DongSonButtonVariant.primaryCinnabar,
                  height: 48,
                  onPressed: () => context.go('/dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: DauVietColors.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tải được kết quả bài học.',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            DongSonButton(
              label: 'THỬ LẠI',
              icon: Icons.refresh_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 44,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
