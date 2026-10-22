import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/api/api_config.dart';
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
      if (ApiConfig.useMock) return repo.getResult(attemptId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getResult(attemptId));
    });

/// Provider lấy pinned-lesson content để dựng recap — gọi lại endpoint
/// learner đã có (`getAttemptContent`); thất bại → null → view result-only.
final _recapContentProvider = FutureProvider.autoDispose
    .family<LessonContentDto?, String>((ref, attemptId) async {
      try {
        final repo = ref.watch(attemptRepositoryProvider);
        if (ApiConfig.useMock) {
          return await repo.getAttemptContent(attemptId);
        }
        // Cùng pattern auth với player: refresh-on-401 qua withAuth.
        return await ref
            .read(authRepositoryProvider)
            .withAuth(() => repo.getAttemptContent(attemptId));
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
                // TASK-0023: thưởng + vật phẩm attempt này ĐÃ được server
                // cấp trong transaction complete() — chỉ hiển thị thật,
                // không phát thêm request "nhận thưởng" nào.
                if (result.rewards.isNotEmpty ||
                    result.itemsUnlocked.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RewardsSection(result: result),
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

/// Section thưởng + vật phẩm mới mở khóa của chính attempt (TASK-0023).
/// Dữ liệu đã được server ghi trong transaction complete(); đọc lại màn
/// này (deep-link) vẫn hiện đúng những gì attempt kích hoạt — KHÔNG
/// hiện lại như "thưởng mới" lần hai vì nguồn là ledger/inventory,
/// không phải client flag.
class _RewardsSection extends StatelessWidget {
  final LessonResultDto result;
  const _RewardsSection({required this.result});

  static const _typeLabels = {
    'EXP': 'Kinh nghiệm Sĩ Tử',
    'HISTORY_POINTS': 'Điểm Sử Ký',
  };

  static const _typeIcons = {
    'EXP': Icons.auto_awesome_rounded,
    'HISTORY_POINTS': Icons.history_edu_rounded,
  };

  static const _typeColors = {
    'EXP': DauVietColors.riverBlue,
    'HISTORY_POINTS': DauVietColors.imperialGold,
  };

  @override
  Widget build(BuildContext context) {
    return ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PHẦN THƯỞNG ĐÃ NHẬN'),
          const SizedBox(height: 10),
          for (final tx in result.rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _typeIcons[tx.rewardType] ?? Icons.card_giftcard_rounded,
                    size: 20,
                    color:
                        _typeColors[tx.rewardType] ?? DauVietColors.imperialGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _typeLabels[tx.rewardType] ?? tx.rewardType,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${tx.amount}',
                    style: DauVietTypography.labelMedium.copyWith(
                      color:
                          _typeColors[tx.rewardType] ??
                          DauVietColors.imperialGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          if (result.itemsUnlocked.isNotEmpty) ...[
            const SizedBox(height: 4),
            const SectionLabel('VẬT PHẨM VỪA MỞ KHÓA'),
            const SizedBox(height: 8),
            for (final item in result.itemsUnlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: DauVietColors.imperialGold,
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Vật phẩm học tập — xem trong Túi Đồ Sĩ Tử.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
    // Trích ngắn từ nội dung READ đã authored trong stage CONTEXT — chỉ lấy
    // text thật trong snapshot, không tự sinh narrative.
    final String? reading = _firstReadingExcerpt(c, stages);

    // Không có gì đáng recap → không render section này.
    final bool hasContent =
        title != null ||
        question != null ||
        objectives.isNotEmpty ||
        stages.isNotEmpty ||
        evidence.isNotEmpty ||
        reading != null;
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
          if (reading != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: DauVietColors.imperialGold, width: 3),
                ),
              ),
              child: Text(
                reading,
                style: DauVietTypography.bodySmall.copyWith(
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: DauVietColors.inkText,
                ),
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
            const SectionLabel('TƯ LIỆU TRONG BÀI HỌC'),
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

  /// Trích ~2 câu đầu của đoạn READ đầu tiên tìm thấy trong snapshot stages
  /// (config.body/text/content/passage). Trả null nếu snapshot không chứa
  /// READ content — view rơi về các section metadata còn lại.
  static String? _firstReadingExcerpt(
    Map<String, dynamic> c,
    List<Map<String, dynamic>> stages,
  ) {
    String? pickFrom(Map<String, dynamic>? cfg) {
      if (cfg == null) return null;
      for (final k in const ['body', 'text', 'content', 'passage']) {
        final v = cfg[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      final Object? paras = cfg['paragraphs'];
      if (paras is List) {
        final first = paras.whereType<String>().firstWhere(
          (p) => p.trim().isNotEmpty,
          orElse: () => '',
        );
        if (first.isNotEmpty) return first.trim();
      }
      return null;
    }

    // activities có thể nằm trong stages[].activities[] hoặc top-level
    // content['activities'] tùy projection — quét cả hai nguồn.
    final List<Map<String, dynamic>> acts = [];
    for (final s in stages) {
      final Object? sa = s['activities'];
      if (sa is List) {
        acts.addAll(sa.whereType<Map>().map((e) => e.cast<String, dynamic>()));
      }
    }
    final Object? top = c['activities'];
    if (top is List) {
      acts.addAll(top.whereType<Map>().map((e) => e.cast<String, dynamic>()));
    }
    for (final a in acts) {
      if ((a['type'] as String?)?.toUpperCase() != 'READ') continue;
      final cfg = (a['config'] as Map?)?.cast<String, dynamic>();
      final text = pickFrom(cfg);
      if (text == null) continue;
      // Cắt ~2 câu đầu / 220 ký tự.
      final sentences = text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      final excerpt = sentences.take(2).join(' ');
      return excerpt.length <= 260
          ? excerpt
          : '${excerpt.substring(0, 257).trimRight()}…';
    }
    return null;
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
