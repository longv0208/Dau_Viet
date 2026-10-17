import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/heritage_scaffold.dart';
import '../../../core/widgets/parchment_card.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import '../../../core/api/api_config.dart';

Duration? _noRetry(int retryCount, Object error) => null;

final _lessonMetadataProvider =
    FutureProvider.family<LessonMetadataDto, String>(retry: _noRetry, (
      ref,
      lessonId,
    ) {
      final AttemptRepository repo = ref.watch(attemptRepositoryProvider);
      if (ApiConfig.useMock) return repo.getLessonMetadata(lessonId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getLessonMetadata(lessonId));
    });

/// Màn vào bài học: đọc metadata thật (`GET /lessons/{id}`) rồi
/// `POST /lessons/{id}/attempts` → sang `/learning/attempt/{attemptId}`.
/// Backend trả `resumed:true` khi đã có IN_PROGRESS → nút đổi "Tiếp tục học".
class LessonEntryScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonEntryScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonEntryScreen> createState() => _LessonEntryScreenState();
}

class _LessonEntryScreenState extends ConsumerState<LessonEntryScreen> {
  bool _starting = false;
  String? _startError;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final AttemptRepository repo = ref.read(attemptRepositoryProvider);
      final started = ApiConfig.useMock
          ? await repo.startOrResume(widget.lessonId)
          : await ref
                .read(authRepositoryProvider)
                .withAuth(() => repo.startOrResume(widget.lessonId));
      if (!mounted) return;
      context.pushReplacement('/learning/attempt/${started.attemptId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e.error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = 'Không mở được bài học. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LessonMetadataDto> metaAsync = ref.watch(
      _lessonMetadataProvider(widget.lessonId),
    );

    return HeritageScaffold(
      title: 'BÀI HỌC LỊCH SỬ',
      body: metaAsync.when(
        loading: () => AsyncStateView.loading(),
        error: (error, _) => AsyncStateView.error(
          error: error,
          onRetry: () =>
              ref.invalidate(_lessonMetadataProvider(widget.lessonId)),
        ),
        data: (meta) => SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ParchmentCard(
                backgroundColor: DauVietColors.parchmentContainer,
                borderColor: DauVietColors.imperialGold,
                borderWidth: 1.5,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BÀI HỌC LỊCH SỬ',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.cinnabarRed,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meta.title,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 20,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    if (meta.centralQuestion != null &&
                        meta.centralQuestion!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        meta.centralQuestion!,
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_startError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: DauVietColors.cinnabarRed,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _startError!,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DongSonButton(
                label: _starting ? 'ĐANG MỞ BÀI HỌC...' : 'BẮT ĐẦU KHÁM PHÁ',
                icon: Icons.explore_rounded,
                variant: DongSonButtonVariant.primaryCinnabar,
                height: 52,
                onPressed: _starting ? () {} : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
