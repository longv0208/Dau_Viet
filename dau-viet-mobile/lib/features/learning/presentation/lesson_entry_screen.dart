import 'dart:convert';
import 'lesson_cover_resolver.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../../core/widgets/heritage_ornaments.dart';
import '../../auth/data/auth_state.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../../streak/data/streak_providers.dart';
import '../data/attempt_dtos.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/learning_asset_image.dart';

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

/// Màn hình Giới thiệu bài học (Screen 1 chuẩn UI/UX Pro Max)
/// Tóm tắt nội dung lịch sử, chỉ số thời lượng, số hoạt động, phần thưởng XP,
/// và tranh minh hoạ di sản hào hùng.
class LessonEntryScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonEntryScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonEntryScreen> createState() => _LessonEntryScreenState();
}

class _LessonEntryScreenState extends ConsumerState<LessonEntryScreen> {
  bool _starting = false;
  String? _startError;
  bool _lockedByPath = false;

  List<String> _parseObjectives(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final item in decoded)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ];
      }
    } catch (_) {
      // Fallback single string objective if not JSON array
    }
    return [raw.trim()];
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
      _lockedByPath = false;
    });
    try {
      final AttemptRepository repo = ref.read(attemptRepositoryProvider);
      final started = ApiConfig.useMock
          ? await repo.startOrResume(widget.lessonId)
          : await ref
                .read(authRepositoryProvider)
                .withAuth(() => repo.startOrResume(widget.lessonId));
      if (!mounted) return;
      ref.invalidate(myProgressProvider);
      ref.invalidate(learningPathProvider);
      context.pushReplacement('/learning/attempt/${started.attemptId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e.error.message;
        _lockedByPath =
            e.error.code == 'LESSON_LOCKED_BY_PATH' || e.statusCode == 403;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = 'Không mở được bài học. Thử lại.';
        _lockedByPath = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LessonMetadataDto> metaAsync = ref.watch(
      _lessonMetadataProvider(widget.lessonId),
    );
    final AsyncValue<MyProgressDto> progressAsync = ref.watch(
      myProgressProvider,
    );
    final AttemptSummaryDto? resume = progressAsync.maybeWhen(
      data: (p) {
        for (final a in p.inProgress) {
          if (a.lessonId == widget.lessonId) return a;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: DauVietColors.parchmentSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: DauVietColors.inkText,
          tooltip: 'Quay lại',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/journey');
            }
          },
        ),
        title: Text(
          'Bài học',
          style: DauVietTypography.headlineMedium.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DauVietColors.inkText,
          ),
        ),
        centerTitle: true,
        actions: const [
          // Huy hiệu ngọn lửa Streak — số thật từ streakProvider (STREAK-01).
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _StreakAppBarBadge()),
          ),
        ],
      ),
      body: SafeArea(
        child: metaAsync.when(
          loading: () =>
              AsyncStateView.loading(message: 'Đang mở sử liệu bài học...'),
          error: (error, _) => AsyncStateView.error(
            error: error,
            onRetry: () =>
                ref.invalidate(_lessonMetadataProvider(widget.lessonId)),
          ),
          data: (meta) {
            return Stack(
              children: [
                Positioned.fill(
                  child: HeritageBackground(
                    config: meta.backgroundConfig,
                    heroHeight: 215,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Dải tranh phong cảnh chân trang
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.22,
                    child: Image.asset(
                      'assets/images/lotus_footer.png',
                      height: 110,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Nội dung chính cuộn dọc
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Tranh minh hoạ di sản mở bài khổ lớn (hỗ trợ coverAssetId từ backend)
                      _LessonCoverHero(
                        coverAssetId:
                            meta.resolvedCoverAssetId ??
                            meta.backgroundConfig.resolvedAssetId,
                        title: meta.title,
                      ),
                      const SizedBox(height: 14),

                      // 3. Tiêu đề bài học
                      Text(
                        meta.title,
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: DauVietColors.inkText,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. Câu hỏi lịch sử trung tâm trên thẻ giấy dó (TC-NAV-08)
                      if (meta.centralQuestion != null &&
                          meta.centralQuestion!.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DauVietColors.parchmentContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DauVietColors.imperialGold,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.help_outline_rounded,
                                size: 20,
                                color: DauVietColors.cinnabarRed,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CÂU HỎI LỊCH SỬ TRUNG TÂM',
                                      style: DauVietTypography.labelSmall
                                          .copyWith(
                                            color: DauVietColors.cinnabarRed,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      meta.centralQuestion!.trim(),
                                      style: DauVietTypography.bodyMedium
                                          .copyWith(
                                            fontSize: 14.5,
                                            color: DauVietColors.inkText,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Mục tiêu bài học (nếu có)
                      if (_parseObjectives(meta.objectivesJson).isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DauVietColors.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MỤC TIÊU KHÁM PHÁ',
                                style: DauVietTypography.labelSmall.copyWith(
                                  color: DauVietColors.inkMuted,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final obj in _parseObjectives(
                                meta.objectivesJson,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: DauVietColors.heritageGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          obj,
                                          style: DauVietTypography.bodyMedium
                                              .copyWith(
                                                fontSize: 14,
                                                color: DauVietColors.inkText,
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Trạng thái Resume (nếu có bài đang học dở)
                      if (resume != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFA5D6A7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đang học dở — đã hoàn thành '
                                  '${resume.progress.completedRequired}/'
                                  '${resume.progress.totalRequired} hoạt động',
                                  style: DauVietTypography.bodySmall.copyWith(
                                    color: const Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Báo lỗi (nếu có, kèm nút quay lại lộ trình khi bị khóa)
                      if (_startError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DauVietColors.cinnabarRed.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: DauVietColors.cinnabarRed,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _lockedByPath
                                        ? Icons.lock_outline_rounded
                                        : Icons.error_outline_rounded,
                                    size: 18,
                                    color: DauVietColors.cinnabarRed,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startError!,
                                      style: DauVietTypography.bodyMedium
                                          .copyWith(
                                            fontSize: 14,
                                            color: DauVietColors.cinnabarRed,
                                            height: 1.45,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_lockedByPath) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/journey');
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.route_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('QUAY LẠI LỘ TRÌNH'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: DauVietColors.cinnabarRed,
                                    minimumSize: const Size.fromHeight(44),
                                    side: const BorderSide(
                                      color: DauVietColors.cinnabarRed,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 6. Nút hành động Bắt đầu học nổi khối 3D (Heritage Green)
                      DongSonButton(
                        label: _starting
                            ? 'ĐANG MỞ BÀI HỌC...'
                            : (resume != null
                                  ? 'TIẾP TỤC BÀI HỌC ›'
                                  : 'BẮT ĐẦU HỌC ›'),
                        icon: Icons.arrow_forward_rounded,
                        variant: DongSonButtonVariant.natureGreen,
                        height: 52,
                        isLoading: _starting,
                        onPressed: _starting ? null : _start,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Khối ảnh bìa hero của bài học — tải qua `fetchLearningAssetBytes`
/// (xác thực Bearer qua `/api/v1/assets/{id}/content`, có cache theo phiên).
/// Nếu bài học chưa cấu hình ảnh bìa hoặc tải lỗi → hiển thị fallback mặc định.
class _LessonCoverHero extends ConsumerStatefulWidget {
  final String? coverAssetId;
  final String title;

  const _LessonCoverHero({required this.coverAssetId, required this.title});

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
      return _DefaultLessonHeroFallback(title: widget.title);
    }

    ref.listen<AuthState>(authSessionProvider, (prev, next) {
      if (prev?.profile?.id != next.profile?.id ||
          prev?.status != next.status) {
        setState(_loadIfPresent);
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFE8DA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8C8B0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B4513).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: FutureBuilder<List<int>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _DefaultLessonHeroFallback(
                  title: widget.title,
                  embedded: true,
                );
              }
              final bytes = snapshot.data;
              if (snapshot.hasError || bytes == null || bytes.isEmpty) {
                return _DefaultLessonHeroFallback(
                  title: widget.title,
                  embedded: true,
                );
              }
              return Image.memory(
                Uint8List.fromList(bytes),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: widget.title,
                errorBuilder: (_, _, _) => _DefaultLessonHeroFallback(
                  title: widget.title,
                  embedded: true,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DefaultLessonHeroFallback extends StatelessWidget {
  final String title;
  final bool embedded;

  const _DefaultLessonHeroFallback({
    required this.title,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = resolveOptionalLessonFallbackAsset(title);
    final Widget imageChild = assetPath != null
        ? Image.asset(
            assetPath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: title,
            errorBuilder: (_, _, _) => const _HeritagePaperHeroFallback(),
          )
        : const _HeritagePaperHeroFallback();
    if (embedded) {
      return imageChild;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8C8B0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B4513).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(aspectRatio: 16 / 10, child: imageChild),
      ),
    );
  }
}

class _HeritagePaperHeroFallback extends StatelessWidget {
  const _HeritagePaperHeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DauVietColors.paperCardHi,
            DauVietColors.paperBackground,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: const [
          Positioned(
            right: -18,
            top: -18,
            child: DongSonWatermark(size: 140, opacity: 0.14),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TraditionalCloudOrnament(height: 32, opacity: 0.24),
          ),
          Center(
            child: Icon(
              Icons.account_balance_rounded,
              size: 52,
              color: DauVietColors.heritageGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu ngọn lửa trên AppBar — số streak thật từ streakProvider,
/// placeholder '—' khi loading/error (STREAK-01, không hard-code).
class _StreakAppBarBadge extends ConsumerWidget {
  const _StreakAppBarBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak}',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: DauVietTypography.labelSmall.copyWith(
              color: const Color(0xFFE65100),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
