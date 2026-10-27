import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/game_button.dart';
import '../../auth/data/auth_state.dart';
import '../../energy/data/energy_providers.dart';
import '../../energy/presentation/energy_depleted_sheet.dart';
import '../data/attempt_dtos.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/learning_asset_image.dart';

/// Màn nhập bài học (Lesson Entry) — nhận `lessonId` từ route, tải
/// `GET /api/v1/lessons/{lessonId}` và `my-progress` để quyết định nút
/// "Bắt đầu bài học" hay "Tiếp tục bài học" (kèm tiến độ `x/y` nếu dở).
///
/// Bấm nút gọi `POST /api/v1/lessons/{lessonId}/attempts` rồi điều hướng sang
/// `/learning/play/{attemptId}?lessonId=...`.
class LessonEntryScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonEntryScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonEntryScreen> createState() => _LessonEntryScreenState();
}

class _LessonEntryScreenState extends ConsumerState<LessonEntryScreen> {
  bool _starting = false;
  String? _startError;

  Future<void> _onStartPressed() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final repo = ref.read(attemptRepositoryProvider);
      final start = ApiConfig.useMock
          ? await repo.startOrResume(widget.lessonId)
          : await ref
                .read(authRepositoryProvider)
                .withAuth(() => repo.startOrResume(widget.lessonId));
      // Start mới có thể trừ 1 năng lượng (resume miễn phí) → đồng bộ lại
      // badge trên header bản đồ để lần quay về thấy số mới ngay.
      ref.invalidate(energyStatusProvider);
      if (!mounted) return;
      final encodedLesson = Uri.encodeComponent(widget.lessonId);
      context.push(
        '/learning/play/${start.attemptId}?lessonId=$encodedLesson',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ENERGY_DEPLETED') {
        setState(() => _starting = false);
        await showEnergyDepletedSheet(context, details: e.details);
        ref.invalidate(energyStatusProvider);
        return;
      }
      if (e.code == 'LESSON_LOCKED_BY_PATH') {
        setState(() {
          _startError =
              'Bài học này chưa mở khóa trên hành trình. Hãy hoàn thành các sự kiện trước đó trước nhé!';
        });
        return;
      }
      setState(() {
        _startError = e.message.isNotEmpty
            ? e.message
            : 'Không thể bắt đầu bài học. Vui lòng thử lại.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _startError = 'Không thể bắt đầu bài học. Vui lòng thử lại.';
      });
    } finally {
      if (mounted && _starting) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(lessonMetadataProvider(widget.lessonId));
    final progressAsync = ref.watch(myProgressProvider);

    return Scaffold(
      backgroundColor: DauVietColors.warmParchment,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: DauVietColors.darkInk,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/map'),
        ),
        title: Text('Bài học', style: DauVietTypography.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: metaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorBody(
            message: err is ApiException && err.statusCode == 404
                ? 'Bài học không tồn tại hoặc chưa xuất bản.'
                : 'Không tải được thông tin bài học.',
            onRetry: () =>
                ref.invalidate(lessonMetadataProvider(widget.lessonId)),
          ),
          data: (meta) => _EntryContent(
            meta: meta,
            inProgress: _findInProgress(progressAsync.asData?.value),
            starting: _starting,
            startError: _startError,
            onStart: _onStartPressed,
          ),
        ),
      ),
    );
  }

  AttemptSummaryDto? _findInProgress(MyProgressDto? p) {
    if (p == null) return null;
    for (final a in p.inProgress) {
      if (a.lessonId == widget.lessonId) return a;
    }
    return null;
  }
}

class _EntryContent extends StatelessWidget {
  final LessonMetadataDto meta;
  final AttemptSummaryDto? inProgress;
  final bool starting;
  final String? startError;
  final VoidCallback onStart;

  const _EntryContent({
    required this.meta,
    required this.inProgress,
    required this.starting,
    required this.startError,
    required this.onStart,
  });

  List<String> _parseObjectives(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final objectives = _parseObjectives(meta.objectivesJson);
    final hasResume = inProgress != null;
    final prog = inProgress?.progress;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ApiConfig.useMock)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.imperialGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CHẾ ĐỘ DEMO — dữ liệu mẫu cục bộ',
                      textAlign: TextAlign.center,
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.AgedWoodText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                _LessonCoverHero(
                  coverAssetId: meta.resolvedCoverAssetId,
                  title: meta.title,
                ),
                const SizedBox(height: 20),
                Text(
                  meta.title,
                  style: DauVietTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                if (meta.centralQuestion != null &&
                    meta.centralQuestion!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CÂU HỎI TRỌNG TÂM',
                          style: DauVietTypography.labelSmall.copyWith(
                            color: DauVietColors.cinnabarRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meta.centralQuestion!,
                          style: DauVietTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (objectives.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Mục tiêu bài học',
                    style: DauVietTypography.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final obj in objectives)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: DauVietColors.bambooGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(obj, style: DauVietTypography.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
                if (hasResume && prog != null && prog.totalRequired > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DauVietColors.bambooGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.History_edu_rounded,
                          color: DauVietColors.bambooGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đang làm dở: ${prog.completedRequired}/${prog.totalRequired} hoạt động bắt buộc',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.darkInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (startError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    startError!,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.errorCoral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GameButton(
            text: starting
                ? 'ĐANG MỞ BÀI HỌC...'
                : (hasResume ? 'TIẾP TỤC BÀI HỌC' : 'BẮT ĐẦU BÀI HỌC'),
            icon: hasResume
                ? Icons.play_circle_fill_rounded
                : Icons.rocket_launch_rounded,
            type: GameButtonType.primary,
            width: double.infinity,
            onPressed: starting ? null : onStart,
          ),
        ),
      ],
    );
  }
}

/// Khối ảnh bìa hero tỷ lệ 16:9 của bài học — tải qua `fetchLearningAssetBytes`
/// (xác thực Bearer qua `/api/v1/assets/{id}/content`, có cache theo phiên).
/// Nếu bài học chưa cấu hình ảnh bìa hoặc tải lỗi → hiển thị fallback mặc định.
class _LessonCoverHero extends ConsumerStatefulWidget {
  final String? coverAssetId;
  final String title;

  const _LessonCoverHero({
    required this.coverAssetId,
    required this.title,
  });

  @override
  ConsumerState<_LessonCoverHero> createState() => _LessonCoverHeroState();
}

class _LessonCoverHeroState extends ConsumerState<_LessonCoverHero> {
  Future<List<int>>? _future;

  @override
  void initState() {
    super.initState();
    _loadIfPresent();
  }

  @override
  void didUpdateWidget(covariant _LessonCoverHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverAssetId != widget.coverAssetId) {
      _loadIfPresent();
    }
  }

  void _loadIfPresent() {
    final id = widget.coverAssetId;
    if (id != null && id.isNotEmpty) {
      _future = fetchLearningAssetBytes(ref, id);
    } else {
      _future = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.coverAssetId;
    if (id == null || id.isEmpty || _future == null) {
      return const _DefaultLessonHeroFallback();
    }

    ref.listen(authSessionProvider, (prev, next) {
      if (prev?.profile?.id != next.profile?.id ||
          prev?.status != next.status) {
        setState(_loadIfPresent);
      }
    });

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: DauVietColors.parchmentContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DauVietColors.outlineVariant, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<List<int>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final bytes = snapshot.data;
            if (snapshot.hasError || bytes == null || bytes.isEmpty) {
              return const _DefaultLessonHeroFallback(embedded: true);
            }
            return Image.memory(
              Uint8List.fromList(bytes),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: widget.title,
              errorBuilder: (_, _, _) =>
                  const _DefaultLessonHeroFallback(embedded: true),
            );
          },
        ),
      ),
    );
  }
}

class _DefaultLessonHeroFallback extends StatelessWidget {
  final bool embedded;

  const _DefaultLessonHeroFallback({this.embedded = false});

  @override
  Widget build(BuildContext context) {
    const iconChild = Center(
      child: Icon(
        Icons.castle_rounded,
        size: 64,
        color: DauVietColors.cinnabarRed,
      ),
    );
    if (embedded) {
      return ColoredBox(
        color: DauVietColors.parchmentContainer,
        child: iconChild,
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: DauVietColors.parchmentContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DauVietColors.outlineVariant, width: 1.5),
        ),
        alignment: Alignment.center,
        child: iconChild,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: DauVietColors.errorCoral,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyLarge,
            ),
            const SizedBox(height: 16),
            GameButton(
              text: 'THỬ LẠI',
              type: GameButtonType.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
