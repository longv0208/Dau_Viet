import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../data/attempt_dtos.dart';
import '../data/learning_dtos.dart';
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

/// Provider lấy pinned-lesson content để dựng recap — gọi lại endpoint
/// learner đã có (`getAttemptContent`); thất bại → null → view result-only.
final _recapContentProvider = FutureProvider.autoDispose
    .family<LessonContentDto?, String>((ref, attemptId) async {
      try {
        final repo = ref.watch(attemptRepositoryProvider);
        return await repo.getAttemptContent(attemptId);
      } catch (_) {
        return null; // attempt đã complete / endpoint lỗi → fallback
      }
    });

/// Màn hình kết quả bài học — nhận `LessonResultDto` qua `extra` (từ player)
/// hoặc tự fetch theo `attemptId` khi deep-link. KHÔNG hiển thị answer key;
/// chỉ status/score/tóm tắt + recap nội dung đã published (câu hỏi trung tâm,
/// mục tiêu, tiêu đề stage, metadata bằng chứng) nếu có.
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
      return _ResultView(
        result: initialResult!,
        recapContent: ref.watch(_recapContentProvider(attemptId)).value,
      );
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
          data: (r) => _ResultView(
            result: r,
            recapContent: ref.watch(_recapContentProvider(attemptId)).value,
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final LessonResultDto result;

  /// Pinned lesson content (nullable — khi không fetch được thì chỉ hiện
  /// phần result-only).
  final LessonContentDto? recapContent;

  const _ResultView({required this.result, this.recapContent});

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
                // Recap lịch sử — chỉ render khi pinned content có dữ liệu
                // đáng kể; thiếu → giữ nguyên result-only view.
                if (recapContent != null) ...[
                  const SizedBox(height: 12),
                  _RecapSection(content: recapContent!),
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

/// Recap lịch sử gọn — chỉ dùng field có thật trong pinned snapshot:
/// title/centralQuestion của content, objectives[], stage titles,
/// evidence titles + source. Không bịa narrative, không hiển thị answer key.
class _RecapSection extends StatelessWidget {
  final LessonContentDto content;
  const _RecapSection({required this.content});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> c = content.content;
    final String? title = _str(c, ['title', 'lessonTitle']);
    final String? question = _str(c, ['centralQuestion', 'central_question']);
    final List<String> objectives = [
      for (final o in (c['objectives'] as List? ?? const []))
        if (o is String && o.isNotEmpty) o,
    ];
    final stages = content.stages;
    final evidence = content.evidence;

    // Không có gì đáng recap → không render section này.
    final bool hasContent =
        title != null ||
        question != null ||
        objectives.isNotEmpty ||
        stages.isNotEmpty ||
        evidence.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('ÔN LẠI BÀI HỌC'),
          const SizedBox(height: 10),
          if (title != null)
            Text(
              title,
              style: DauVietTypography.headlineMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
              ),
            ),
          if (question != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: DauVietColors.imperialGold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    question,
                    style: DauVietTypography.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (objectives.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('MỤC TIÊU'),
            const SizedBox(height: 4),
            for (final o in objectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        o,
                        style: DauVietTypography.bodySmall.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('HÀNH TRÌNH'),
            const SizedBox(height: 4),
            Text(
              stages
                  .map((s) => s['title'] as String? ?? '')
                  .where((t) => t.isNotEmpty)
                  .join(' → '),
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.5,
              ),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('BẰNG CHỨNG ĐÃ KHẢO SÁT'),
            const SizedBox(height: 4),
            for (final e in evidence.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${e['title'] ?? e['id'] ?? ''}'
                  '${_srcSuffix(e)}',
                  style: DauVietTypography.bodySmall.copyWith(height: 1.45),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String? _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static String _srcSuffix(Map<String, dynamic> e) {
    final Object? s = e['source'];
    String? t;
    if (s is Map) t = (s['title'] ?? s['author']) as String?;
    if (s is String) t = s;
    return (t != null && t.isNotEmpty) ? ' — $t' : '';
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
