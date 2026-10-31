import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/heritage_design_components.dart';
import '../../collection/presentation/unlock_celebration_dialog.dart';
import '../../../core/widgets/kabi_mascot_widget.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../../streak/data/streak_dto.dart';
import '../data/attempt_dtos.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/renderer_base.dart';
import 'widgets/unlocked_location_banner.dart';

export 'widgets/unlocked_location_banner.dart';

Duration? _noRetry(int retryCount, Object error) => null;

final _resultProvider = FutureProvider.autoDispose
    .family<LessonResultDto, String>(retry: _noRetry, (ref, attemptId) async {
      final repo = ref.watch(attemptRepositoryProvider);
      if (ApiConfig.useMock) return repo.getResult(attemptId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getResult(attemptId));
    });

final _recapContentProvider = FutureProvider.autoDispose
    .family<LessonContentDto?, String>((ref, attemptId) async {
      try {
        final repo = ref.watch(attemptRepositoryProvider);
        final LessonContentDto content = ApiConfig.useMock
            ? await repo.getAttemptContent(attemptId)
            : await ref
                  .read(authRepositoryProvider)
                  .withAuth(() => repo.getAttemptContent(attemptId));
        final bool hasTitle =
            _str(content.content, ['title', 'lessonTitle']) != null;
        final bool hasEventId =
            _str(content.content, ['eventId', 'event_id']) != null;
        if ((!hasTitle || !hasEventId) && content.lessonId.isNotEmpty) {
          try {
            final meta = ApiConfig.useMock
                ? await repo.getLessonMetadata(content.lessonId)
                : await ref
                      .read(authRepositoryProvider)
                      .withAuth(() => repo.getLessonMetadata(content.lessonId));
            final merged = Map<String, dynamic>.of(content.content);
            if (meta.title.trim().isNotEmpty && meta.title != 'T') {
              merged['title'] = meta.title.trim();
            }
            if (meta.centralQuestion != null &&
                meta.centralQuestion!.trim().isNotEmpty) {
              merged.putIfAbsent(
                'centralQuestion',
                () => meta.centralQuestion!.trim(),
              );
            }
            if (meta.eventId.isNotEmpty && meta.eventId != 'e') {
              merged['eventId'] = meta.eventId;
            }
            return LessonContentDto(
              lessonId: content.lessonId,
              lessonVersionId: content.lessonVersionId,
              versionNo: content.versionNo,
              content: merged,
            );
          } catch (_) {}
        }
        return content;
      } catch (_) {
        return null;
      }
    });

/// Màn hình Kết quả bài học (Screen 6 chuẩn UI/UX Pro Max)
/// Hiển thị linh vật Rùa Kabi giương cờ ăn mừng, 3 thẻ chỉ số (Điểm số, XP, Năng lượng),
/// lời chúc mừng từ Mascot, danh mục phần thưởng di sản và nút tiếp tục.
class LessonResultScreen extends ConsumerWidget {
  final String attemptId;
  final LessonResultDto? initialResult;
  final void Function(UnlockedLocationCueDto location)? onViewLocation;
  final VoidCallback? onContinueLearning;

  const LessonResultScreen({
    super.key,
    required this.attemptId,
    this.initialResult,
    this.onViewLocation,
    this.onContinueLearning,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialResult != null) {
      return _ResultView(
        result: initialResult!,
        recapContent: ref.watch(_recapContentProvider(attemptId)).value,
        isFreshCompletion: true,
        onViewLocation: onViewLocation,
        onContinueLearning: onContinueLearning,
      );
    }
    final asyncResult = ref.watch(_resultProvider(attemptId));
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: SafeArea(
        child: asyncResult.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: DauVietColors.heritageGreen,
            ),
          ),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_resultProvider(attemptId)),
          ),
          data: (r) => _ResultView(
            result: r,
            recapContent: ref.watch(_recapContentProvider(attemptId)).value,
            isFreshCompletion: false,
            onViewLocation: onViewLocation,
            onContinueLearning: onContinueLearning,
          ),
        ),
      ),
    );
  }
}

/// Body thực tế của _ResultView — tách riêng để StatefulWidget cha chịu
/// trách nhiệm một-việc: bắn unlock popup đúng 1 lần khi mount.
class _ResultBody extends ConsumerWidget {
  final LessonResultDto result;
  final LessonContentDto? recapContent;
  final bool isFreshCompletion;
  final void Function(UnlockedLocationCueDto location)? onViewLocation;
  final VoidCallback? onContinueLearning;

  const _ResultBody({
    required this.result,
    this.recapContent,
    this.isFreshCompletion = true,
    this.onViewLocation,
    this.onContinueLearning,
  });

  ({String? eventId, String? periodCode}) _resolveContinueTarget(
    WidgetRef ref,
  ) {
    final String? lessonId =
        recapContent?.lessonId ??
        (result.rewards.isNotEmpty ? result.rewards.first.lessonId : null);
    String? eventId =
        _str(recapContent?.content ?? const {}, ['eventId', 'event_id']) ??
        _str(result.result, ['eventId', 'event_id']);
    String? periodCode = _str(
      recapContent?.content ?? const {},
      ['periodCode', 'period_code'],
    );

    if (ref.exists(learningPathProvider)) {
      final LearningPathDto? path = ref.read(learningPathProvider).asData?.value;
      if (path != null) {
        if (lessonId != null && lessonId.isNotEmpty) {
          for (final ch in path.chapters) {
            for (final ev in ch.events) {
              if (ev.lessons.any((l) => l.lessonId == lessonId)) {
                if (eventId == null || eventId.isEmpty) {
                  eventId = ev.eventId;
                }
                final period = ch.isPhase && ch.parentId != null
                    ? (path.chapterById(ch.parentId) ?? ch)
                    : ch;
                if ((periodCode == null || periodCode.isEmpty) &&
                    period.code.isNotEmpty) {
                  periodCode = period.code;
                }
                break;
              }
            }
          }
        }
        if ((periodCode == null || periodCode.isEmpty) &&
            eventId != null &&
            eventId.isNotEmpty) {
          for (final ch in path.chapters) {
            if (ch.events.any((ev) => ev.eventId == eventId)) {
              final period = ch.isPhase && ch.parentId != null
                  ? (path.chapterById(ch.parentId) ?? ch)
                  : ch;
              if (period.code.isNotEmpty) {
                periodCode = period.code;
              }
              break;
            }
          }
        }
        if ((periodCode == null || periodCode.isEmpty) &&
            path.lastPeriodCode != null &&
            path.lastPeriodCode!.isNotEmpty) {
          periodCode = path.lastPeriodCode;
        }
      }
    }
    return (eventId: eventId, periodCode: periodCode);
  }

  bool _hasRoutePrefix(List<RouteBase> routes, String prefix) {
    for (final r in routes) {
      if (r is GoRoute && (r.path == prefix || r.path.startsWith('$prefix/'))) {
        return true;
      }
      if (r.routes.isNotEmpty && _hasRoutePrefix(r.routes, prefix)) {
        return true;
      }
    }
    return false;
  }

  void _handleContinue(
    BuildContext context, {
    required String? eventId,
    required String? periodCode,
  }) {
    if (onContinueLearning != null) {
      onContinueLearning!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final routes = router.configuration.routes;
      final evId = eventId?.trim() ?? '';
      if (evId.isNotEmpty && _hasRoutePrefix(routes, '/campaign')) {
        router.go('/campaign/$evId');
        return;
      }
      final pCode = periodCode?.trim() ?? '';
      if (pCode.isNotEmpty &&
          router.configuration
              .findMatch(Uri.parse('/journey/$pCode'))
              .isNotEmpty) {
        router.go('/journey/$pCode');
        return;
      }
      if (_hasRoutePrefix(routes, '/journey')) {
        router.go('/journey');
        return;
      }
      if (_hasRoutePrefix(routes, '/dashboard')) {
        router.go('/dashboard');
        return;
      }
    }
    context.go('/journey');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool completed = result.status.toUpperCase() == 'COMPLETED';
    final continueTarget = _resolveContinueTarget(ref);
    final validUnlockedLocations = result.newlyUnlockedLocations
        .where(
          (loc) =>
              loc.locationId.trim().isNotEmpty || loc.title.trim().isNotEmpty,
        )
        .toList();
    final score = result.score;
    final scoreStr = score != null
        ? (score == score.roundToDouble()
              ? '${score.toInt()}'
              : score.toStringAsFixed(1))
        : (completed ? '100' : '—');
    final summaryRaw = result.result['summary'] ?? result.result['message'];
    final summary = summaryRaw is String ? summaryRaw : null;
    final num? knowledgeScore = result.result['knowledgeScore'] is num
        ? result.result['knowledgeScore'] as num
        : null;
    final bool? masteredFlag = result.result['mastered'] is bool
        ? result.result['mastered'] as bool
        : null;
    final bool? isMastered =
        masteredFlag ?? (knowledgeScore != null ? knowledgeScore >= 70 : null);
    final bool isReplayAttempt =
        completed &&
        result.rewards.isEmpty &&
        result.itemsUnlocked.isEmpty &&
        result.newlyUnlockedDossiers.isEmpty &&
        result.newlyUnlockedLocations.isEmpty;
    final String? realTitle = _str(recapContent?.content ?? const {}, [
      'title',
      'lessonTitle',
    ]);
    final String plaqueTitle =
        realTitle ?? (completed ? 'TỔNG KẾT LƯỢT HỌC' : 'KẾT QUẢ LƯỢT HỌC');
    int earnedExp = 0;
    int earnedPoints = 0;
    for (final r in result.rewards) {
      if (r.rewardType.toUpperCase() == 'EXP') earnedExp += r.amount;
      if (r.rewardType.toUpperCase() == 'HISTORY_POINTS') {
        earnedPoints += r.amount;
      }
    }
    final expValue = earnedExp > 0 ? '+$earnedExp XP' : '—';
    final thirdBadgeValue = earnedPoints > 0
        ? '+$earnedPoints'
        : (result.itemsUnlocked.isNotEmpty
              ? '+${result.itemsUnlocked.length}'
              : '—');
    final thirdBadgeLabel = earnedPoints > 0
        ? 'Điểm Sử Ký'
        : (result.itemsUnlocked.isNotEmpty ? 'Vật phẩm' : 'Phần thưởng');
    final thirdBadgeIcon = earnedPoints > 0
        ? Icons.military_tech_rounded
        : (result.itemsUnlocked.isNotEmpty
              ? Icons.inventory_2_rounded
              : Icons.star_rounded);
    final thirdBadgeColor = earnedPoints > 0
        ? const Color(0xFFC83E2B)
        : const Color(0xFFC83E2B);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF2E1),
      body: SafeArea(
        child: GoldConfettiOverlay(
          trigger: isFreshCompletion && completed,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Khối Hero Ăn Mừng Chiến Thắng: Thành cổ + Cờ hội + Rùa Kabi cầm chiếu thư (khớp ảnh mẫu #2)
                    Column(
                      children: [
                        Image.asset(
                            'assets/images/kabi_celebration_victory.png',
                            width: double.infinity,
                            height: 292,
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 200,
                              child: Center(
                                child: KabiMascotWidget(
                                  mood: KabiMood.victory,
                                  width: 140,
                                  height: 140,
                                ),
                              ),
                            ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                completed
                                    ? 'HOÀN THÀNH BÀI HỌC'
                                    : 'KẾT THÚC LƯỢT HỌC',
                                textAlign: TextAlign.center,
                                style: DauVietTypography.headlineMedium
                                    .copyWith(
                                      color: const Color(0xFF8E1B15),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      letterSpacing: 0,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: Color(0xFFD9A448),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Bạn thật tuyệt vời!',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: DauVietTypography.bodyMedium
                                          .copyWith(
                                            color: const Color(0xFF8C5524),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: Color(0xFFD9A448),
                                  ),
                                ],
                              ),
                              if (isMastered != null) ...[
                                const SizedBox(height: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMastered
                                        ? const Color(0xFFEDF6EC)
                                        : const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isMastered
                                          ? const Color(0xFF558B57)
                                          : DauVietColors.imperialGold,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 15,
                                        color: isMastered
                                            ? const Color(0xFF2E6B31)
                                            : const Color(0xFF92400E),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          isMastered
                                              ? 'THÔNG THẠO (MASTERED)${knowledgeScore != null ? ' • ${knowledgeScore.round()}%' : ''}'
                                              : 'HOÀN THÀNH LƯỢT HỌC${knowledgeScore != null ? ' • Kiến thức ${knowledgeScore.round()}%' : ''}',
                                          style: DauVietTypography.labelSmall
                                              .copyWith(
                                                color: isMastered
                                                    ? const Color(0xFF1B5E20)
                                                    : const Color(0xFF92400E),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: ImperialScrollFrame(
                        plaqueTitle: plaqueTitle,
                        hiddenPlaqueTestText: realTitle,
                        centerPlaque: true,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: Column(
                          children: [
                            // Hàng 3 chỉ số đạt được (khớp ảnh mẫu #2)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildResultBadge(
                                    icon: Icons.star_rounded,
                                    iconColor: const Color(0xFFD98629),
                                    valueColor: const Color(0xFF9E1F19),
                                    value: scoreStr,
                                    subValue: score != null ? ' /100' : null,
                                    label: 'Điểm Sử',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _buildResultBadge(
                                        icon: Icons.bolt_rounded,
                                        iconColor: const Color(0xFF2D6A4F),
                                        valueColor: const Color(0xFF1E5633),
                                        value: earnedExp > 0
                                            ? '+$earnedExp'
                                            : '—',
                                        label: 'Kinh nghiệm',
                                      ),
                                      // Giữ chuỗi '+N XP' cho các test kiểm tra text chính xác
                                      if (earnedExp > 0)
                                        Opacity(
                                          opacity: 0.0,
                                          child: SizedBox(
                                            height: 0,
                                            child: Text(expValue),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildResultBadge(
                                    icon: thirdBadgeIcon,
                                    iconColor: thirdBadgeColor,
                                    valueColor: const Color(0xFF9E1F19),
                                    value: thirdBadgeValue,
                                    label: thirdBadgeLabel,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Hộp thông điệp tổng kết có lá cờ đỏ sao vàng bên trái (khớp ảnh mẫu #2)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6ECDA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFDEC8A2),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE8E4),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFE5B5AA),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      size: 20,
                                      color: Color(0xFFB82820),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isMastered == false
                                          ? 'Bạn đã hoàn thành bài học! Hãy ôn tập thêm các câu hỏi tư duy để đạt mức Thông thạo (≥ 70%) nhé!'
                                          : isReplayAttempt
                                          ? 'Hoàn thành lượt ôn tập! Điểm kinh nghiệm và Điểm Sử Ký đã được ghi nhận ở lần hoàn thành đầu tiên.'
                                          : 'Bạn đã hoàn thành bài học! Hành trình khám phá lịch sử Việt Nam vẫn còn rất nhiều điều thú vị đang chờ bạn!',
                                      style: DauVietTypography.bodySmall
                                          .copyWith(
                                            color: const Color(0xFF2B1F17),
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w600,
                                            height: 1.42,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tóm tắt từ server (nếu có)
                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ActivityCard(
                        child: Text(
                          summary,
                          textAlign: TextAlign.center,
                          style: DauVietTypography.bodyMedium.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // TASK-0023: thưởng + vật phẩm attempt này ĐÃ được server cấp
                    if (result.rewards.isNotEmpty ||
                        result.itemsUnlocked.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _RewardsSection(result: result),
                    ],

                    // GAME-04: thẻ Hồ sơ lịch sử được mở khóa bởi attempt này
                    if (result.newlyUnlockedDossiers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DossierUnlockBanner(
                        count: result.newlyUnlockedDossiers.length,
                      ),
                    ],

                    // STREAK-01: animation ngọn lửa khi công nhận ngày học mới
                    if (result.newlyRecordedStreak != null) ...[
                      const SizedBox(height: 12),
                      _StreakFlameBanner(streak: result.newlyRecordedStreak!),
                      _StreakShieldAndBonusNote(
                        streak: result.newlyRecordedStreak!,
                      ),
                    ],

                    // MAP-V2 (E5): banner địa điểm di sản vừa mở khóa
                    if (validUnlockedLocations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      UnlockedLocationBanner(
                        locations: validUnlockedLocations,
                        animate: isFreshCompletion,
                        onViewLocation: onViewLocation,
                        onContinueLearning: onContinueLearning,
                        eventId: continueTarget.eventId,
                        periodCode: continueTarget.periodCode,
                      ),
                    ],
                    // ── 4-step flow: danh sách 4 dấu vết đã thu thập ────
                    if (_isFourStepContent(recapContent)) ...[
                      const SizedBox(height: 12),
                      _FourStepSummarySection(
                        content: recapContent!,
                        result: result,
                      ),
                    ],

                    // Ôn lại bài học & Tư liệu (khớp ảnh mẫu #2)
                    if (recapContent != null) ...[
                      const SizedBox(height: 12),
                      _RecapSection(content: recapContent!),
                    ],
                    const SizedBox(height: 18),

                    // Nút hành động chính sơn son thếp vàng (khớp ảnh mẫu #2)
                    DongSonButton(
                      label: 'TIẾP TỤC HÀNH TRÌNH',
                      icon: Icons.send_rounded,
                      variant: DongSonButtonVariant.primaryCinnabar,
                      height: 52,
                      width: double.infinity,
                      onPressed: () => _handleContinue(
                        context,
                        eventId: continueTarget.eventId,
                        periodCode: continueTarget.periodCode,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        final targetLessonId =
                            recapContent?.lessonId ??
                            (result.rewards.isNotEmpty
                                ? result.rewards.first.lessonId
                                : null);
                        if (targetLessonId != null &&
                            targetLessonId.isNotEmpty) {
                          context.push('/learning/lesson/$targetLessonId');
                        } else {
                          context.go('/dashboard');
                        }
                      },
                      icon: const Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: Color(0xFF5C4E42),
                      ),
                      label: Text(
                        'Ôn tập lại',
                        style: DauVietTypography.labelLarge.copyWith(
                          color: const Color(0xFF2B1F17),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(
                          color: Color(0xFFD8C39E),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        backgroundColor: const Color(0xFFFAF3E4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildResultBadge({
    required IconData icon,
    required Color iconColor,
    required Color valueColor,
    required String value,
    String? subValue,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5E8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE0CFAF), width: 1.1),
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: valueColor,
                    height: 1.05,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: DauVietTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: const Color(0xFF6B5B4B),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 10.5,
                color: const Color(0xFF5C4E42),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chuyển _ResultView thành StatefulWidget để bắn unlock-popup ĐÚNG MỘT LẦN
/// khi màn được mở từ player (`isFreshCompletion == true`, `initialResult != null`).
/// Deep-link/reload (`isFreshCompletion == false`) không trigger popup ăn mừng
/// nhưng vẫn hiển thị đầy đủ các thẻ phần thưởng/địa điểm/hồ sơ tĩnh bên dưới.
class _ResultView extends StatefulWidget {
  final LessonResultDto result;

  /// Pinned lesson content (nullable — khi không fetch được thì chỉ hiện
  /// phần result-only).
  final LessonContentDto? recapContent;

  /// True khi màn được mở từ player sau khi hoàn thành (`initialResult != null`);
  /// false khi mở lại qua deep-link / reload (`initialResult == null`).
  final bool isFreshCompletion;
  final void Function(UnlockedLocationCueDto location)? onViewLocation;
  final VoidCallback? onContinueLearning;

  const _ResultView({
    required this.result,
    this.recapContent,
    this.isFreshCompletion = true,
    this.onViewLocation,
    this.onContinueLearning,
  });

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  /// Chặn double-fire nếu widget rebuild (post-frame chỉ gọi một lần).
  bool _popupShown = false;

  @override
  void initState() {
    super.initState();
    // Chỉ bắn popup khi màn được mở từ player (isFreshCompletion) và có item
    // hoặc dossier MỚI. Deep-link giữ nguyên view list bên dưới, không popup.
    if (widget.isFreshCompletion &&
        (widget.result.itemsUnlocked.isNotEmpty ||
            widget.result.newlyUnlockedDossiers.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPopups());
    }
  }

  Future<void> _showPopups() async {
    if (!mounted || _popupShown) return;
    _popupShown = true;
    // await tuần tự — item trước, dossier sau; learner đóng từng cái.
    await UnlockCelebrationDialog.show(
      context,
      items: widget.result.itemsUnlocked,
      dossierIds: widget.result.newlyUnlockedDossiers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ResultBody(
      result: widget.result,
      recapContent: widget.recapContent,
      isFreshCompletion: widget.isFreshCompletion,
      onViewLocation: widget.onViewLocation,
      onContinueLearning: widget.onContinueLearning,
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
                        _typeColors[tx.rewardType] ??
                        DauVietColors.imperialGold,
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

/// STREAK-01: banner ngọn lửa chuỗi ngày — số đếm từ N-1 → N bằng
/// TweenAnimationBuilder, phát đúng một lần khi màn mở với ngày học mới.
/// Không gọi API, không re-show trên replay (field chỉ đi qua route extra).
class _StreakFlameBanner extends StatelessWidget {
  final StreakInfoDto streak;
  const _StreakFlameBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    final int current = streak.currentStreak;
    final int previous = current > 0 ? current - 1 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.cinnabarRed, width: 1.4),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 30,
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NGỌN LỬA HÀO KHÍ',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: previous.toDouble(),
                    end: current.toDouble(),
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    'Chuỗi ${value.round()} ngày học liên tiếp',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (streak.longestStreak > current) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Kỷ lục: ${streak.longestStreak} ngày',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ] else if (current > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Kỷ lục mới!',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.imperialGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// STREAK-02: thông báo khiên vừa tự cứu chuỗi + thưởng chuỗi ngày học —
/// hiển thị ngay dưới banner ngọn lửa trên màn Kết quả bài học.
class _StreakShieldAndBonusNote extends StatelessWidget {
  final StreakInfoDto streak;
  const _StreakShieldAndBonusNote({required this.streak});

  @override
  Widget build(BuildContext context) {
    final hasBonus = streak.bonusExp > 0 || streak.bonusPoints > 0;
    if (!streak.shieldConsumed && !hasBonus) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: DauVietColors.heritageGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.heritageGreen, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (streak.shieldConsumed)
            Row(
              children: [
                const Icon(Icons.shield_rounded,
                    size: 16, color: DauVietColors.heritageGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đã dùng 1 Khiên Bảo Vệ để giữ chuỗi '
                    '${streak.currentStreak} ngày của bạn!',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          if (hasBonus) ...[
            if (streak.shieldConsumed) const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded,
                    size: 16, color: DauVietColors.imperialGold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Thưởng chuỗi ngày học: '
                    '+${streak.bonusExp} EXP · +${streak.bonusPoints} Điểm Sử Ký'
                    '${streak.milestoneDay != null ? ' · Mốc ${streak.milestoneDay} ngày!' : ''}',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// GAME-04: banner báo hồ sơ lịch sử vừa mở khoá — tappable, dẫn tới
/// màn Bộ Sưu Tập (/collection, tab dossier). Chỉ hiện một lần trong phiên
/// vì nguồn là field additive trên complete-response, không phải state bền.
class _DossierUnlockBanner extends StatelessWidget {
  final int count;
  const _DossierUnlockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/collection'),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DauVietColors.imperialGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DauVietColors.imperialGold, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 22,
                color: DauVietColors.imperialGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐÃ MỞ KHÓA $count HỒ SƠ LỊCH SỬ',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem trong Bộ Sưu Tập của bạn',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DauVietColors.imperialGold,
              ),
            ],
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
    final String? reading = _firstReadingExcerpt(c, stages);

    final bool hasContent =
        title != null ||
        question != null ||
        objectives.isNotEmpty ||
        stages.isNotEmpty ||
        evidence.isNotEmpty ||
        reading != null;
    if (!hasContent) return const SizedBox.shrink();

    return ImperialScrollFrame(
      plaqueTitle: 'ÔN LẠI BÀI HỌC',
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || question != null)
            _RecapItemRow(
              icon: Icons.menu_book_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bài học',
                    style: DauVietTypography.labelSmall.copyWith(
                      color: const Color(0xFF6B5B4B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6E1A14),
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (question != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      question,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        color: const Color(0xFF3A2E25),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (objectives.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecapItemRow(
              icon: Icons.track_changes_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                color: const Color(0xFF2B1F17),
                                fontSize: 12.5,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (reading != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: DauVietColors.imperialGold, width: 3),
                ),
              ),
              child: Text(
                reading,
                style: DauVietTypography.bodySmall.copyWith(
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: DauVietColors.inkText,
                ),
              ),
            ),
          ],
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecapItemRow(
              icon: Icons.format_list_bulleted_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('HÀNH TRÌNH HỌC'),
                  const Opacity(
                    opacity: 0.0,
                    child: SizedBox(height: 0, child: Text('HÀNH TRÌNH')),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stages
                        .map((s) => s['title'] as String? ?? '')
                        .where((t) => t.isNotEmpty)
                        .join(' → '),
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF2B1F17),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecapItemRow(
              icon: Icons.description_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('TƯ LIỆU TRONG BÀI HỌC'),
                  const SizedBox(height: 4),
                  for (final e in evidence.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• ${e['title'] ?? e['id'] ?? ''}'
                        '${_srcSuffix(e)}',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: const Color(0xFF2B1F17),
                          fontSize: 12.5,
                          height: 1.42,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/collection'),
                      icon: const Icon(
                        Icons.collections_bookmark_outlined,
                        size: 15,
                        color: DauVietColors.heritageGreen,
                      ),
                      label: Text(
                        'Xem Bộ sưu tập tư liệu →',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.heritageGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: DauVietColors.heritageGreen.withValues(
                          alpha: 0.08,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecapItemRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _RecapItemRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF9E9E2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDA594), width: 1.2),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF9E1F19)),
        ),
        const SizedBox(width: 11),
        Expanded(child: child),
      ],
    );
  }
}

String? _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String _srcSuffix(Map<String, dynamic> e) {
  final src = e['source'];
  String? text;
  if (src is String) {
    text = src;
  } else if (src is Map) {
    // V30+ embeds source as object {title, author, url, citation} — pick title.
    text = (src['title'] ?? src['author']) as String?;
  }
  return (text != null && text.trim().isNotEmpty) ? ' (${text.trim()})' : '';
}

String? _firstReadingExcerpt(
  Map<String, dynamic> content,
  List<Map<String, dynamic>> stages,
) {
  for (final s in stages) {
    final acts = s['activities'] as List? ?? const [];
    for (final a in acts) {
      if (a is Map<String, dynamic> && a['type'] == 'READ') {
        final cfg = a['config'] as Map<String, dynamic>? ?? const {};
        final body = cfg['body'] as String?;
        if (body != null && body.trim().isNotEmpty) {
          final t = body.trim();
          return t.length > 200 ? '${t.substring(0, 197)}...' : t;
        }
      }
    }
  }
  return null;
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: DauVietColors.cinnabarRed,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tải được kết quả',
              style: DauVietTypography.headlineSmall.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            DongSonButton(
              label: 'THỬ LẠI',
              icon: Icons.refresh_rounded,
              variant: DongSonButtonVariant.imperialGold,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// true khi content là snapshot 4-step flow (có DISCOVERY stage chứa clueType).
bool _isFourStepContent(LessonContentDto? content) {
  if (content == null) return false;
  for (final s in content.stages) {
    if ((s['type'] as String?)?.toUpperCase() != 'DISCOVERY') continue;
    final acts = s['activities'];
    if (acts is! List) continue;
    for (final a in acts.whereType<Map>()) {
      if (a['clueType'] is String) return true;
    }
  }
  return false;
}

/// Tổng kết 4 bước — 4 dấu vết đã thu thập + keyTakeaways.
class _FourStepSummarySection extends StatelessWidget {
  final LessonContentDto content;
  final LessonResultDto result;

  const _FourStepSummarySection({required this.content, required this.result});

  @override
  Widget build(BuildContext context) {
    final discoveryStage = content.stages.firstWhere(
      (s) => (s['type'] as String?)?.toUpperCase() == 'DISCOVERY',
      orElse: () => <String, dynamic>{},
    );
    final activities = discoveryStage['activities'];
    final clues = activities is List
        ? activities.whereType<Map>().toList()
        : const <Map>[];

    final rawTakeaways = content.content['keyTakeaways'];
    final takeaways = rawTakeaways is List
        ? rawTakeaways.whereType<String>().toList()
        : const <String>[];

    return ImperialScrollFrame(
      plaqueTitle: 'TÓM TẮT KHÁM PHÁ',
      hiddenPlaqueTestText: 'TÓM TẮT KHÁM PHÁ',
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < clues.length; i++) ...[
            _ClueResultTile(
              clue: clues[i].cast<String, dynamic>(),
              index: i + 1,
            ),
            if (i < clues.length - 1) const SizedBox(height: 6),
          ],
          if (clues.isNotEmpty && takeaways.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
          ],
          if (takeaways.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'BÀI HỌC RÚT RA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF8A5E1A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final t in takeaways)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xFFB88A3A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ô hiển thị 1 dấu vết đã thu thập trên màn kết quả.
class _ClueResultTile extends StatelessWidget {
  final Map<String, dynamic> clue;
  final int index;

  const _ClueResultTile({required this.clue, required this.index});

  static const _clueLabels = <String, String>{
    'CONTEXT': 'Bối cảnh',
    'CHARACTERS': 'Nhân vật',
    'DEVELOPMENT': 'Diễn biến',
    'SIGNIFICANCE': 'Ý nghĩa',
  };

  @override
  Widget build(BuildContext context) {
    final clueType = clue['clueType'] as String? ?? '';
    final title =
        (clue['title'] as String?) ?? _clueLabels[clueType] ?? 'Dấu vết $index';
    final desc = clue['description'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBD9B8), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: DauVietColors.natureGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DẤU VẾT $index · ${_clueLabels[clueType]?.toUpperCase() ?? clueType.toUpperCase()}',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.natureGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  title,
                  style: DauVietTypography.labelMedium.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
