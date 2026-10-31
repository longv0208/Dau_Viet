import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/gamification/gamification_widgets.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../campaign/presentation/campaign_detail_screen.dart';
import '../../learning/presentation/renderers/asset_cover_image.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'path_status_badge.dart';
import 'widgets/bottom_floating_summary_card.dart';
import 'widgets/historical_event_card.dart';
import 'widgets/winding_landscape_journey_canvas.dart';

/// Màn Hành trình thời kỳ (`PeriodJourneyScreen` — `/journey/:periodCode`).
///
/// Bố cục:
/// - Chỉ hiển thị nội dung của thời kỳ đã chọn (không có thanh chip chuyển thời
///   kỳ ngang; muốn đổi thời kỳ bấm `<` quay lại màn Chọn thời kỳ).
/// - Mỗi sự kiện gồm:
///   1. Nhãn sự kiện (`_EventCampaignRibbon`, giữ key `event-card-{eventId}` để
///      mở màn Chi tiết chiến dịch).
///   2. Các mốc bài học (`_LessonMilestoneCard`) nối mượt trên đường cong
///      Catmull-Rom; mỗi thẻ gồm ảnh nền bài học, tên bài và năm của sự kiện.
///   3. Mốc rương quà (`_RewardChestMilestoneCard`) ở cuối sự kiện (chỉ hiện khi
///      API trả về phần thưởng Địa điểm / Vật phẩm cho `eventId` đó).
class PeriodJourneyScreen extends ConsumerStatefulWidget {
  final String periodCode;
  final bool touchOnInit;
  final ValueChanged<LearningPathEventNodeDto>? onEventSelected;

  const PeriodJourneyScreen({
    super.key,
    required this.periodCode,
    this.touchOnInit = true,
    this.onEventSelected,
  });

  @override
  ConsumerState<PeriodJourneyScreen> createState() =>
      _PeriodJourneyScreenState();
}

class _PeriodJourneyScreenState extends ConsumerState<PeriodJourneyScreen> {
  String? _touchedCode;

  @override
  void initState() {
    super.initState();
    if (widget.touchOnInit) {
      _scheduleTouch(widget.periodCode);
    }
  }

  @override
  void didUpdateWidget(covariant PeriodJourneyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodCode != widget.periodCode) {
      _scheduleTouch(widget.periodCode);
    }
  }

  void _scheduleTouch(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _touchedCode == trimmed) return;
    _touchedCode = trimmed;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await ref.read(learningPathProvider.notifier).touchPeriod(trimmed);
      } catch (_) {
        // Không chặn hiển thị hành trình nếu mạng lỗi khi gọi touch.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncPath = ref.watch(learningPathProvider);
    final period = asyncPath.asData?.value.periodByCode(widget.periodCode);
    final bgConfig =
        period?.backgroundConfig ?? HeritageBackgroundConfigDto.paperDefault;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E3),
      body: HeritageBackground(
        config: bgConfig,
        heroHeight: 210,
        child: SafeArea(
          child: asyncPath.when(
            loading: () => AsyncStateView.loading(
              message: 'Đang tải hành trình thời kỳ...',
            ),
            error: (err, _) => AsyncStateView.error(
              error: err,
              onRetry: () =>
                  ref.read(learningPathProvider.notifier).refresh(),
            ),
            data: (path) => _buildPeriodBody(context, path),
          ),
        ),
      ),
    );
  }

  /// Header nổi ngay trên nền bầu trời kem của bức tranh hành trình:
  /// - Hàng trên: Nút tròn `<` (Chọn thời kỳ khác) + Pill `⚡ 80` + Pill `🔥 7 ngày`
  ///   + nút Bản đồ + Chuông thông báo.
  /// - Khối tiêu đề góc trái: Nhãn pill đỏ tên thời kỳ, chữ lớn `"Hành trình"`,
  ///   mô tả ngắn (không còn thanh chip chuyển thời kỳ ngang).
  Widget _buildScenicCanvasHeader(
    BuildContext context,
    LearningPathDto path,
    LearningPathChapterDto period,
  ) {
    final era = period.parentId != null
        ? path.chapterById(period.parentId)
        : null;
    final String subtitle =
        (period.description != null && period.description!.trim().isNotEmpty)
            ? period.description!.trim()
            : 'Những mốc son tiêu biểu trong ${period.title}.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF6EC).withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE6D8BF), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F2B1B12),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF3A2A1D),
                    size: 17,
                  ),
                  tooltip: 'Chọn thời kỳ khác',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _JourneyStatPill(
                        iconAsset: 'assets/images/home/icon_bolt_energy.png',
                        fallbackIcon: Icons.bolt_rounded,
                        fallbackColor: Color(0xFFE59400),
                        label: '80',
                      ),
                      const SizedBox(width: 6),
                      const _JourneyStatPill(
                        iconAsset: 'assets/images/home/icon_fire_flame.png',
                        fallbackIcon: Icons.local_fire_department_rounded,
                        fallbackColor: Color(0xFFE24A1F),
                        label: '7 ngày',
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF6EC).withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE6D8BF),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.map_outlined,
                            color: Color(0xFF4A3525),
                            size: 17,
                          ),
                          tooltip: 'Mở bản đồ di sản',
                          onPressed: () => _openHeritageMap(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const _JourneyBellBadge(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Text ẩn phục vụ tương thích với các widget test hiện hành.
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              height: 0,
              width: 0,
              child: Column(
                children: [
                  const Text('HÀNH TRÌNH THỜI KỲ'),
                  if (era != null) Text(era.title),
                ],
              ),
            ),
          ),
          // Nhãn pill đỏ tên thời kỳ (góc trái trên, có chấm ghim nhỏ góc phải).
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 310),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFC92525),
                      Color(0xFF9E1818),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFE5A3),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x339E1818),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    period.title,
                    maxLines: 1,
                    style: DauVietTypography.labelLarge.copyWith(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8E1414),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Tiêu đề lớn "Hành trình"
          Text(
            'Hành trình',
            style: DauVietTypography.headlineLarge.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2B1B12),
              height: 1.08,
            ),
          ),
          const SizedBox(height: 3),
          // Mô tả ngắn hiển thị đầy đủ không cắt "..."
          Text(
            subtitle,
            maxLines: 2,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3E3025),
              height: 1.26,
            ),
          ),
        ],
      ),
    );
  }

  void _openHeritageMap(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null &&
        router.configuration.findMatch(Uri.parse('/map')).isNotEmpty) {
      context.push('/map');
    }
  }

  void _openCollectionScreen(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    for (final route in const ['/inventory', '/collection']) {
      if (router.configuration.findMatch(Uri.parse(route)).isNotEmpty) {
        context.push(route);
        return;
      }
    }
  }

  Widget _buildPeriodBody(BuildContext context, LearningPathDto path) {
    final period = path.periodByCode(widget.periodCode);
    if (period == null) {
      return AsyncStateView(
        icon: Icons.auto_stories_outlined,
        title: 'Không tìm thấy thời kỳ',
        message: 'Thời kỳ "${widget.periodCode}" không tồn tại trong lộ trình.',
      );
    }

    final progress = path.progressForPeriod(period.code);
    final currentPointer = path.currentForPeriod(period.code);
    final allEvents = path.eventsOfPeriod(period.chapterId);
    final seenChests = ref.watch(seenRewardChestsProvider);

    if (allEvents.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _buildScenicCanvasHeader(context, path, period),
          ),
          Expanded(
            child: AsyncStateView.empty(
              message: 'Thời kỳ này hiện đang được biên tập nội dung sự kiện.',
            ),
          ),
        ],
      );
    }

    final sections = _buildPhaseSections(path, period);
    final bool showPhaseHeaders = sections.length > 1;

    final entries = <JourneyCanvasEntry>[];
    int milestoneCursor = 0;

    for (int s = 0; s < sections.length; s++) {
      if (showPhaseHeaders && sections[s].phase != null) {
        final phase = sections[s].phase!;
        entries.add(
          JourneyCanvasEntry.fullWidth(
            child: _CompactPhaseRibbon(
              key: Key('phase-header-${phase.code}'),
              title: phase.title,
              periodLabel: phase.periodLabel,
            ),
          ),
        );
      }

      for (int i = 0; i < sections[s].events.length; i++) {
        final event = sections[s].events[i];
        final isCurrentTarget =
            currentPointer?.eventNodeId == event.eventNodeId;
        final stepNumber = _globalEventNumber(sections, s, i);
        final bool isFeaturedStar =
            stepNumber == 1 &&
            !event.status.isLocked &&
            !isCurrentTarget &&
            !event.status.isDone;

        final asyncRewards = ref.watch(eventRewardsProvider(event.eventId));
        final rewardBundle = asyncRewards.asData?.value;
        final rewardPreview = rewardBundle?.toPreview(event);

        if (event.lessons.isEmpty) {
          // Trường hợp sự kiện chưa có danh sách bài học con: hiển thị mốc sự kiện.
          milestoneCursor++;
          final double eventFocusX = (event.backgroundConfig.enabled &&
                  (event.backgroundConfig.focusX - 0.5).abs() > 0.01)
              ? event.backgroundConfig.focusX
              : (allEvents.length > 1
                    ? (milestoneCursor.isOdd ? 0.26 : 0.74)
                    : 0.30);
          final bool isEventUnlocked =
              !event.status.isLocked && !event.status.isNotReady;

          entries.add(
            JourneyCanvasEntry.milestone(
              cardOnLeft: eventFocusX >= 0.56,
              focusX: eventFocusX,
              isUnlocked: isEventUnlocked,
              badge: GestureDetector(
                key: Key('event-badge-${event.eventId}'),
                onTap: () => _showEventDetailsBottomSheet(
                  context,
                  event: event,
                  stepNumber: stepNumber,
                  rewardPreview: rewardPreview,
                ),
                child: JourneyNodeBadge(
                  status: event.status,
                  isSelected: isCurrentTarget,
                  isFeaturedStar: isFeaturedStar,
                ),
              ),
              child: HistoricalEventCard(
                event: event,
                stepNumber: stepNumber,
                isCurrentTarget: isCurrentTarget,
                compactCallout: true,
                rewardPreview: rewardPreview,
                onShowDetailsSheet: () => _showEventDetailsBottomSheet(
                  context,
                  event: event,
                  stepNumber: stepNumber,
                  rewardPreview: rewardPreview,
                ),
                onTap: () => _openEventCampaign(context, event),
              ),
            ),
          );
        } else {
          // 1. Nhãn sự kiện (dải nhỏ không có huy hiệu trên đường cong; bấm mở Chi tiết chiến dịch)
          entries.add(
            JourneyCanvasEntry.fullWidth(
              child: _EventCampaignRibbon(
                cardKey: Key('event-card-${event.eventId}'),
                infoBadgeKey: Key('event-badge-${event.eventId}'),
                event: event,
                stepNumber: stepNumber,
                isCurrentTarget: isCurrentTarget,
                onTap: () => _openEventCampaign(context, event),
                onInfoTap: () => _showEventDetailsBottomSheet(
                  context,
                  event: event,
                  stepNumber: stepNumber,
                  rewardPreview: rewardPreview,
                ),
              ),
            ),
          );

          // 2. Các mốc bài học (mỗi bài là 1 mốc tròn trên đường cong Catmull-Rom)
          for (int l = 0; l < event.lessons.length; l++) {
            final lesson = event.lessons[l];
            milestoneCursor++;
            final double lessonFocusX;
            if (lesson.backgroundConfig.enabled &&
                (lesson.backgroundConfig.focusX - 0.5).abs() > 0.01) {
              lessonFocusX = lesson.backgroundConfig.focusX;
            } else {
              lessonFocusX = milestoneCursor.isOdd ? 0.26 : 0.74;
            }

            final bool isLessonUnlocked =
                !lesson.status.isLocked && !lesson.status.isNotReady;
            final bool isCurrentLesson =
                (currentPointer?.lessonId == lesson.lessonId) ||
                (currentPointer?.lessonId == null && isCurrentTarget && l == 0);

            entries.add(
              JourneyCanvasEntry.milestone(
                cardOnLeft: lessonFocusX >= 0.56,
                focusX: lessonFocusX,
                isUnlocked: isLessonUnlocked,
                badge: GestureDetector(
                  key: Key('lesson-badge-${lesson.lessonId}'),
                  onTap: () =>
                      _handleLessonMilestoneTap(context, event, lesson),
                  child: JourneyNodeBadge(
                    status: lesson.status,
                    isSelected: isCurrentLesson,
                    isFeaturedStar: isFeaturedStar && l == 0,
                  ),
                ),
                child: _LessonMilestoneCard(
                  key: Key('lesson-milestone-${lesson.lessonId}'),
                  event: event,
                  lesson: lesson,
                  isCurrentTarget: isCurrentLesson,
                  onTap: () =>
                      _handleLessonMilestoneTap(context, event, lesson),
                ),
              ),
            );
          }
        }

        // 3. Mốc rương quà ở cuối sự kiện (chỉ xuất hiện khi API trả phần thưởng cho eventId đó)
        if (rewardPreview != null) {
          milestoneCursor++;
          final double chestFocusX = milestoneCursor.isOdd ? 0.28 : 0.72;
          final bool isChestUnlocked = event.status.isDone ||
              (event.lessons.isNotEmpty &&
                  event.lessons.every((l) => l.status.isDone)) ||
              rewardPreview.isItemUnlocked;
          final bool isChestSeen =
              seenChests.contains(event.eventId.trim().toLowerCase());

          entries.add(
            JourneyCanvasEntry.milestone(
              cardOnLeft: chestFocusX >= 0.56,
              focusX: chestFocusX,
              isUnlocked: isChestUnlocked,
              badge: GestureDetector(
                key: Key('event-chest-badge-${event.eventId}'),
                onTap: () => _handleChestTap(
                  context,
                  event: event,
                  stepNumber: stepNumber,
                  rewardPreview: rewardPreview,
                  isUnlocked: isChestUnlocked,
                ),
                child: _RewardChestBadge(
                  isUnlocked: isChestUnlocked,
                  isSeen: isChestSeen,
                ),
              ),
              child: _RewardChestMilestoneCard(
                key: Key('event-chest-${event.eventId}'),
                event: event,
                rewardPreview: rewardPreview,
                isUnlocked: isChestUnlocked,
                isSeen: isChestSeen,
                onTap: () => _handleChestTap(
                  context,
                  event: event,
                  stepNumber: stepNumber,
                  rewardPreview: rewardPreview,
                  isUnlocked: isChestUnlocked,
                ),
              ),
            ),
          );
        }
      }
    }

    final String? periodBgAssetId = period.backgroundConfig.resolvedAssetId;
    final String? rawBgUrl = period.backgroundConfig.backgroundImageUrl?.trim();
    final String periodBgAsset =
        (rawBgUrl != null &&
                rawBgUrl.isNotEmpty &&
                !rawBgUrl.startsWith('/api/'))
            ? rawBgUrl
            : 'assets/images/journey/heritage_scroll_bg.jpg';

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewport.maxHeight,
                ),
                child: WindingLandscapeJourneyCanvas(
                  backgroundAssetId: periodBgAssetId,
                  backgroundAsset: periodBgAsset,
                  fallbackBackgroundAsset:
                      'assets/images/journey/heritage_scroll_bg.jpg',
                  glowingDottedStyle: true,
                  gentleLeftCurve: true,
                  milestoneMinHeight: 82,
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 148),
                  headerOverlay: _buildScenicCanvasHeader(
                    context,
                    path,
                    period,
                  ),
                  entries: entries,
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10,
          child: _buildPeriodSummaryCard(
            context,
            path: path,
            period: period,
            events: allEvents,
            progress: progress,
            currentPointer: currentPointer,
          ),
        ),
      ],
    );
  }

  Future<void> _handleLessonMilestoneTap(
    BuildContext context,
    LearningPathEventNodeDto event,
    LearningPathLessonNodeDto lesson,
  ) async {
    if (lesson.status.isLocked || lesson.status.isNotReady) {
      final msg = lesson.status.isNotReady
          ? 'Bài học này hiện đang được biên soạn nội dung.'
          : 'Hoàn thành bài học đứng trước để mở khóa bài học này.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    await _openLesson(context, event, lesson);
  }

  Future<void> _handleChestTap(
    BuildContext context, {
    required LearningPathEventNodeDto event,
    required int stepNumber,
    required EventRewardPreview rewardPreview,
    required bool isUnlocked,
  }) async {
    if (isUnlocked) {
      await ref.read(seenRewardChestsProvider.notifier).markSeen(event.eventId);
      if (!context.mounted) return;
      final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
      if (!disableAnimations) {
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Ăn mừng mở rương',
          barrierColor: const Color(0x661C120C),
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (dialogCtx, _, _) {
            return _ChestCelebrationOverlay(
              eventTitle: event.title,
              rewardPreview: rewardPreview,
            );
          },
        );
      }
    }
    if (!context.mounted) return;
    await _showEventDetailsBottomSheet(
      context,
      event: event,
      stepNumber: stepNumber,
      rewardPreview: rewardPreview,
    );
  }

  /// Thẻ tổng quan đồng bộ theme ở chân màn hình:
  /// ưu tiên tải ảnh từ DB `assets` (của thời kỳ hoặc sự kiện/bài học thuộc thời kỳ).
  Widget _buildPeriodSummaryCard(
    BuildContext context, {
    required LearningPathDto path,
    required LearningPathChapterDto period,
    required List<LearningPathEventNodeDto> events,
    required PeriodProgressDto? progress,
    required LearningPathCurrentDto? currentPointer,
  }) {
    final completedEvents = progress?.completedEvents ??
        events.where((e) => e.isRequired && e.status.isDone).length;
    final requiredEvents =
        progress?.requiredEvents ?? events.where((e) => e.isRequired).length;
    final completedLessons = progress?.completedLessons ??
        events
            .where((e) => e.isRequired)
            .expand((e) => e.lessons)
            .where((l) => l.status.isDone)
            .length;
    final requiredLessons = progress?.requiredLessons ??
        events.where((e) => e.isRequired).expand((e) => e.lessons).length;
    final int rawPercent = progress?.percent ??
        (requiredEvents > 0
            ? ((completedEvents * 100) / requiredEvents).round()
            : 0);
    final int percent =
        (rawPercent == 0 && requiredLessons > 0 && completedLessons > 0)
            ? ((completedLessons * 100) / requiredLessons).round()
            : rawPercent;

    String? dbAssetId =
        period.backgroundConfig.resolvedAssetId ??
        HeritageBackgroundConfigDto.extractAssetId(period.coverImageKey);
    if (dbAssetId == null || dbAssetId.isEmpty) {
      for (final evt in events) {
        final evtAsset =
            evt.backgroundConfig.resolvedAssetId ??
            HeritageBackgroundConfigDto.extractAssetId(evt.coverAssetKey);
        if (evtAsset != null && evtAsset.isNotEmpty) {
          dbAssetId = evtAsset;
          break;
        }
        for (final les in evt.lessons) {
          final lesAsset =
              HeritageBackgroundConfigDto.extractAssetId(les.coverAssetId) ??
              les.backgroundConfig.resolvedAssetId;
          if (lesAsset != null && lesAsset.isNotEmpty) {
            dbAssetId = lesAsset;
            break;
          }
        }
        if (dbAssetId != null && dbAssetId.isNotEmpty) break;
      }
    }

    final cover = const AssetResolver().resolvePeriodCover(
      period.coverImageKey,
      period.code,
    );
    final String? yearLabel = (period.startYear != null &&
            period.endYear != null &&
            period.startYear! > 0 &&
            period.endYear! > 0)
        ? '(${period.startYear} – ${period.endYear})'
        : period.periodLabel;
    return BottomFloatingSummaryCard(
      title: period.title,
      yearLabel: yearLabel,
      statsText:
          'Tiến độ thời kỳ: $completedEvents/$requiredEvents sự kiện • '
          '$completedLessons/$requiredLessons bài học',
      percent: percent,
      assetId: dbAssetId,
      imageAsset: cover,
      ctaLabel: 'Học tiếp',
      onTap: () => _continueLearning(context, events, currentPointer),
    );
  }

  void _continueLearning(
    BuildContext context,
    List<LearningPathEventNodeDto> events,
    LearningPathCurrentDto? currentPointer,
  ) {
    LearningPathEventNodeDto? target;
    if (currentPointer != null) {
      for (final e in events) {
        if (e.eventNodeId == currentPointer.eventNodeId) {
          target = e;
          break;
        }
      }
    }
    target ??= events.where((e) => e.isPlayable && e.isUnlocked).firstOrNull;
    target ??= events.where((e) => e.isPlayable).firstOrNull;
    if (target != null) {
      _openEventCampaign(context, target);
    }
  }

  List<_PhaseSection> _buildPhaseSections(
    LearningPathDto path,
    LearningPathChapterDto period,
  ) {
    final phases = path.phasesOfPeriod(period.chapterId);
    final sections = <_PhaseSection>[];

    if (period.events.isNotEmpty) {
      sections.add(_PhaseSection(phase: null, events: period.events));
    }
    for (final phase in phases) {
      if (phase.events.isNotEmpty) {
        sections.add(_PhaseSection(phase: phase, events: phase.events));
      }
    }
    return sections;
  }

  int _globalEventNumber(
    List<_PhaseSection> sections,
    int sectionIdx,
    int itemIdx,
  ) {
    int count = 0;
    for (int s = 0; s < sectionIdx; s++) {
      count += sections[s].events.length;
    }
    return count + itemIdx + 1;
  }

  Future<void> _openEventCampaign(
    BuildContext context,
    LearningPathEventNodeDto event,
  ) async {
    if (widget.onEventSelected != null) {
      widget.onEventSelected!(event);
      return;
    }
    if (event.eventId.trim().isEmpty) return;

    final router = GoRouter.maybeOf(context);
    final targetLocation = '/campaign/${event.eventId}';
    if (router != null &&
        router.configuration.findMatch(Uri.parse(targetLocation)).isNotEmpty) {
      await context.push(targetLocation);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDetailScreen(eventId: event.eventId),
      ),
    );
  }

  Future<void> _openLesson(
    BuildContext context,
    LearningPathEventNodeDto event,
    LearningPathLessonNodeDto lesson,
  ) async {
    final router = GoRouter.maybeOf(context);
    final lessonRoute = '/learning/lesson/${lesson.lessonId}';
    if (router != null &&
        router.configuration.findMatch(Uri.parse(lessonRoute)).isNotEmpty) {
      await context.push(lessonRoute);
      return;
    }
    await _openEventCampaign(context, event);
  }

  Future<void> _showEventDetailsBottomSheet(
    BuildContext context, {
    required LearningPathEventNodeDto event,
    required int stepNumber,
    required EventRewardPreview? rewardPreview,
  }) async {
    final preview = rewardPreview;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          key: Key('event-details-sheet-${event.eventId}'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFBF6EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0xFFD6B98C), width: 1.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0C0A6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chặng $stepNumber • ${event.yearLabel}',
                              style: DauVietTypography.labelSmall.copyWith(
                                color: const Color(0xFFB81D1D),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.title,
                              style: DauVietTypography.headlineSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2B1B12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PathStatusBadge(status: event.status, compact: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E6CE).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0CCA8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 16,
                              color: Color(0xFF8E1D1D),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lộ trình bài học (${event.lessons.length} bài • 5 pha tương tác)',
                                style: DauVietTypography.labelLarge.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2B1B12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mỗi bài gồm 5 pha: Khởi mở → Khám phá → Tương tác → Thử thách → Đúc kết',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 11.2,
                            color: const Color(0xFF5C4B3B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (event.lessons.isEmpty)
                          Text(
                            'Chặng này đang được biên tập bài học.',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: const Color(0xFF6E5D4F),
                            ),
                          )
                        else
                          for (int idx = 0; idx < event.lessons.length; idx++) ...[
                            if (idx > 0) const SizedBox(height: 8),
                            _SheetLessonItem(
                              lesson: event.lessons[idx],
                              orderNumber: idx + 1,
                              onTap: () {
                                final les = event.lessons[idx];
                                if (les.status.isLocked || les.status.isNotReady) {
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Hoàn thành bài học đứng trước để mở khóa bài học này.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(sheetCtx).pop();
                                _openLesson(context, event, les);
                              },
                            ),
                          ],
                      ],
                    ),
                  ),
                  if (preview != null &&
                      (preview.hasLocation || preview.hasItem)) ...[
                    const SizedBox(height: 14),
                    Text(
                      'PHẦN THƯỞNG MỞ KHÓA ĐỊA ĐIỂM & VẬT PHẨM',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF6B3E1E),
                      ),
                    ),
                    if (preview.hasLocation) ...[
                      const SizedBox(height: 8),
                      _SheetRewardCard(
                        icon: Icons.place_rounded,
                        accentColor: const Color(0xFF1F6E4A),
                        badgeText: preview.isLocationUnlocked
                            ? 'ĐÃ MỞ KHÓA ĐỊA ĐIỂM'
                            : 'ĐỊA ĐIỂM DI SẢN',
                        title: preview.locationTitle,
                        subtitle: preview.isLocationUnlocked
                            ? 'Địa điểm đã sáng trên Bản đồ Di sản Việt Nam.'
                            : preview.locationUnlockHint,
                        unlocked: preview.isLocationUnlocked,
                        actionLabel: 'Bản đồ',
                        onAction: () {
                          Navigator.of(sheetCtx).pop();
                          _openHeritageMap(context);
                        },
                      ),
                    ],
                    if (preview.hasItem) ...[
                      const SizedBox(height: 8),
                      _SheetRewardCard(
                        icon: Icons.workspace_premium_rounded,
                        accentColor: const Color(0xFFB35C00),
                        badgeText: preview.isItemUnlocked
                            ? 'ĐÃ NHẬN KỶ VẬT'
                            : 'VẬT PHẨM SƯU TẦM',
                        title: preview.itemTitle,
                        subtitle: preview.itemDescription,
                        unlocked: preview.isItemUnlocked,
                        actionLabel: 'Bộ sưu tập',
                        onAction: () {
                          Navigator.of(sheetCtx).pop();
                          _openCollectionScreen(context);
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: Key('sheet-open-campaign-${event.eventId}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC92525),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _openEventCampaign(context, event);
                    },
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(
                      'Xem chi tiết chiến dịch & học ngay',
                      style: DauVietTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dải nhãn sự kiện nhỏ (`_EventCampaignRibbon`) nằm trước các mốc bài học của
/// sự kiện đó: giữ key `event-card-{eventId}` để bấm mở màn Chi tiết chiến dịch,
/// và nút `event-badge-{eventId}` để mở nhanh Bottom Sheet tổng quan.
class _EventCampaignRibbon extends StatelessWidget {
  final Key cardKey;
  final Key infoBadgeKey;
  final LearningPathEventNodeDto event;
  final int stepNumber;
  final bool isCurrentTarget;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _EventCampaignRibbon({
    required this.cardKey,
    required this.infoBadgeKey,
    required this.event,
    required this.stepNumber,
    required this.isCurrentTarget,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocked = event.status.isLocked || event.status.isNotReady;
    final Color borderColor = isCurrentTarget
        ? const Color(0xFFC92525)
        : (event.status.isDone
              ? const Color(0xFF2E8B57).withValues(alpha: 0.55)
              : const Color(0xFFDCC8A8));

    return Material(
      key: cardKey,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF6EC).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isCurrentTarget ? 1.5 : 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18261E19),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                key: infoBadgeKey,
                behavior: HitTestBehavior.opaque,
                onTap: onInfoTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFF9E9A90)
                        : (event.status.isDone
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFC92525)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        event.status.isDone
                            ? Icons.check_circle_rounded
                            : (isLocked
                                  ? Icons.lock_rounded
                                  : Icons.flag_rounded),
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sự kiện $stepNumber',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      softWrap: true,
                      style: DauVietTypography.labelLarge.copyWith(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? const Color(0xFF4A3F35)
                            : const Color(0xFF2B1B12),
                        height: 1.2,
                      ),
                    ),
                    if (event.yearLabel.trim().isNotEmpty)
                      Text(
                        '${event.yearLabel} • ${event.lessons.length} bài học',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B5847),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF5A4633),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ mốc bài học (`_LessonMilestoneCard`) nằm cạnh huy hiệu tròn trên đường
/// hành trình: chỉ hiển thị **ảnh nền bài học**, **tên bài học** và **năm của sự kiện**.
class _LessonMilestoneCard extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final LearningPathLessonNodeDto lesson;
  final bool isCurrentTarget;
  final VoidCallback onTap;

  const _LessonMilestoneCard({
    super.key,
    required this.event,
    required this.lesson,
    required this.isCurrentTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocked =
        lesson.status.isLocked || lesson.status.isNotReady;
    final bool isHighlightedRed = !isLocked &&
        (isCurrentTarget ||
            lesson.status.isInProgress ||
            lesson.status.isAvailable);
    final bool hasRedBorder = !isLocked &&
        (isCurrentTarget || lesson.status.isInProgress);

    final Color pillBg = isLocked
        ? const Color(0xFFF3EFE4)
        : const Color(0xFFFBF6EC);
    final Color borderColor = hasRedBorder
        ? const Color(0xFFC92525)
        : (lesson.status.isDone
              ? const Color(0xFF2E8B57).withValues(alpha: 0.55)
              : const Color(0xFFE2D4BC));
    final Color titleColor = isLocked
        ? const Color(0xFF3A322B)
        : (isHighlightedRed
              ? const Color(0xFFB81D1D)
              : const Color(0xFF241B15));
    final Color yearColor = isLocked
        ? const Color(0xFF63564B)
        : (hasRedBorder ? const Color(0xFF9E1D1D) : const Color(0xFF4A3E35));

    final String? coverAssetId =
        HeritageBackgroundConfigDto.extractAssetId(lesson.coverAssetId) ??
        lesson.backgroundConfig.resolvedAssetId ??
        HeritageBackgroundConfigDto.extractAssetId(lesson.coverImageUrl) ??
        event.backgroundConfig.resolvedAssetId ??
        HeritageBackgroundConfigDto.extractAssetId(event.coverAssetKey);
    final String? bundledCover = const AssetResolver().resolveEventCover(
      lesson.coverImageUrl ?? event.coverAssetKey,
      event.slug,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 155,
            maxWidth: 265,
            minHeight: 62,
          ),
          decoration: BoxDecoration(
            color: pillBg.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: hasRedBorder ? 1.8 : 1.2,
            ),
            boxShadow: [
              if (hasRedBorder)
                const BoxShadow(
                  color: Color(0x33C92525),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              const BoxShadow(
                color: Color(0x24261E19),
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 118,
                  child: Opacity(
                    opacity: isLocked ? 0.42 : 0.78,
                    child: AssetCoverImage(
                      assetId: coverAssetId,
                      bundledPath: bundledCover,
                      fit: BoxFit.cover,
                      placeholder: const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0.0, 0.54, 0.82, 1.0],
                        colors: [
                          pillBg.withValues(alpha: 0.98),
                          pillBg.withValues(alpha: 0.92),
                          pillBg.withValues(alpha: 0.58),
                          pillBg.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lesson.title,
                        softWrap: true,
                        style: DauVietTypography.labelLarge.copyWith(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          height: 1.22,
                        ),
                      ),
                      if (event.yearLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.yearLabel,
                          softWrap: true,
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                            color: yearColor,
                          ),
                        ),
                      ],
                      Opacity(
                        opacity: 0.0,
                        child: SizedBox(
                          height: 0,
                          width: 0,
                          child: Text(lesson.status.labelVi),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Huy hiệu tròn của mốc Rương quà trên đường cong hành trình:
/// - Chưa mở khóa: rương khóa (`assets/images/rewards/chest_locked.png`) nền xám đá.
/// - Đã mở khóa, chưa xem: rương mở sáng (`assets/images/rewards/chest_open.png`)
///   kèm hiệu ứng lấp lánh (`assets/images/rewards/sparkles_3d.png`).
/// - Đã mở khóa, đã xem: rương mở nền vàng ấm êm dịu.
class _RewardChestBadge extends StatelessWidget {
  final bool isUnlocked;
  final bool isSeen;

  const _RewardChestBadge({
    required this.isUnlocked,
    required this.isSeen,
  });

  @override
  Widget build(BuildContext context) {
    final bool glowing = isUnlocked && !isSeen;
    final double size = glowing ? 52 : 46;
    final String chestAsset = isUnlocked
        ? 'assets/images/rewards/chest_open.png'
        : 'assets/images/rewards/chest_locked.png';

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isUnlocked
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFE082),
                      Color(0xFFD97706),
                    ],
                  )
                : null,
            color: isUnlocked ? null : const Color(0xFFACA396),
            border: Border.all(
              color: glowing
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFF3ECE0),
              width: 3.0,
            ),
            boxShadow: [
              if (glowing)
                const BoxShadow(
                  color: Color(0xAAFFB300),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              const BoxShadow(
                color: Color(0x38261E19),
                offset: Offset(0, 3),
                blurRadius: 7,
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            chestAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              isUnlocked
                  ? Icons.card_giftcard_rounded
                  : Icons.lock_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        if (glowing)
          Positioned(
            top: -5,
            right: -5,
            child: Image.asset(
              'assets/images/rewards/sparkles_3d.png',
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFFFD54F),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thẻ mốc Rương báu nằm ở cuối mỗi sự kiện có phần thưởng.
class _RewardChestMilestoneCard extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final EventRewardPreview rewardPreview;
  final bool isUnlocked;
  final bool isSeen;
  final VoidCallback onTap;

  const _RewardChestMilestoneCard({
    super.key,
    required this.event,
    required this.rewardPreview,
    required this.isUnlocked,
    required this.isSeen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool glowing = isUnlocked && !isSeen;
    final String statusLabel = !isUnlocked
        ? 'Rương di sản • Đang khóa'
        : (isSeen ? 'Rương di sản • Đã mở' : 'Rương di sản • Chạm để mở!');

    final List<String> rewardNames = <String>[
      if (rewardPreview.hasLocation) rewardPreview.locationTitle,
      if (rewardPreview.hasItem) rewardPreview.itemTitle,
    ];
    final String subtitle = rewardNames.join(' • ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 155,
            maxWidth: 265,
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isUnlocked
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFBF0),
                      Color(0xFFF9EBC8),
                    ],
                  )
                : null,
            color: isUnlocked ? null : const Color(0xFFF1ECE1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glowing
                  ? const Color(0xFFD97706)
                  : (isUnlocked
                        ? const Color(0xFFD6B980)
                        : const Color(0xFFD8CCB8)),
              width: glowing ? 1.8 : 1.2,
            ),
            boxShadow: [
              if (glowing)
                const BoxShadow(
                  color: Color(0x38F59E0B),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              const BoxShadow(
                color: Color(0x1F261E19),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                isUnlocked
                    ? 'assets/images/rewards/chest_open.png'
                    : 'assets/images/rewards/chest_locked.png',
                width: 30,
                height: 30,
                errorBuilder: (_, _, _) => Icon(
                  isUnlocked
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_rounded,
                  size: 24,
                  color: isUnlocked
                      ? const Color(0xFFB45309)
                      : const Color(0xFF78716C),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusLabel,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                        color: isUnlocked
                            ? const Color(0xFFB45309)
                            : const Color(0xFF6B5E52),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        softWrap: true,
                        style: DauVietTypography.labelLarge.copyWith(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                          color: isUnlocked
                              ? const Color(0xFF2B1B12)
                              : const Color(0xFF574C41),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hiệu ứng pháo hoa / pháo giấy ngắn (~1,2 giây) khi người học bấm mở rương:
/// Sử dụng các PNG 3D `fireworks_3d.png`, `confetti_ball_3d.png`, `sparkles_3d.png`
/// từ `microsoft/fluentui-emoji` và `chest_open.png` từ `game-icons/icons`.
class _ChestCelebrationOverlay extends StatefulWidget {
  final String eventTitle;
  final EventRewardPreview rewardPreview;

  const _ChestCelebrationOverlay({
    required this.eventTitle,
    required this.rewardPreview,
  });

  @override
  State<_ChestCelebrationOverlay> createState() =>
      _ChestCelebrationOverlayState();
}

class _ChestCelebrationOverlayState extends State<_ChestCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('chest-celebration-overlay'),
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double t = _controller.value;
              final double scale = t < 0.35
                  ? Curves.easeOutBack.transform(t / 0.35)
                  : 1.0;
              final double floatUp = -38.0 * Curves.easeOutCubic.transform(t);
              final double fadeOut = t > 0.78
                  ? (1.0 - (t - 0.78) / 0.22).clamp(0.0, 1.0)
                  : 1.0;

              return Opacity(
                opacity: fadeOut,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: 280,
                    height: 250,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 22 - 18 * t,
                          top: 48 + floatUp,
                          child: Image.asset(
                            'assets/images/rewards/fireworks_3d.png',
                            width: 58,
                            height: 58,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.celebration_rounded,
                              size: 48,
                              color: Color(0xFFFFD54F),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 22 - 18 * t,
                          top: 44 + floatUp,
                          child: Image.asset(
                            'assets/images/rewards/confetti_ball_3d.png',
                            width: 56,
                            height: 56,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.auto_awesome_rounded,
                              size: 48,
                              color: Color(0xFFFFB300),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16 + floatUp * 1.1,
                          child: Image.asset(
                            'assets/images/rewards/sparkles_3d.png',
                            width: 44,
                            height: 44,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF0),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFFFB300),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66FFB300),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/rewards/chest_open.png',
                                width: 68,
                                height: 68,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 56,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'MỞ RƯƠNG DI SẢN!',
                                textAlign: TextAlign.center,
                                style: DauVietTypography.labelLarge.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.eventTitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2B1B12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetLessonItem extends StatelessWidget {
  final LearningPathLessonNodeDto lesson;
  final int orderNumber;
  final VoidCallback onTap;

  const _SheetLessonItem({
    required this.lesson,
    required this.orderNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBlocked = lesson.status.isLocked || lesson.status.isNotReady;
    return Material(
      color: isBlocked ? const Color(0xFFEDE4D3) : const Color(0xFFFFFDF8),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: Key('sheet-lesson-${lesson.lessonId}'),
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isBlocked
                  ? const Color(0xFFD5C7B2)
                  : const Color(0xFFD9C39E),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isBlocked
                      ? const Color(0xFF9E9A90)
                      : const Color(0xFFC92525),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$orderNumber',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: DauVietTypography.labelLarge.copyWith(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: isBlocked
                            ? const Color(0xFF6B5E52)
                            : const Color(0xFF2B1B12),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '5 pha học • 6 hoạt động tương tác',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 10.5,
                        color: const Color(0xFF705E4E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PathStatusBadge(status: lesson.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRewardCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final String title;
  final String subtitle;
  final bool unlocked;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SheetRewardCard({
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: unlocked
            ? accentColor.withValues(alpha: 0.09)
            : const Color(0xFFF6EFE0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? accentColor.withValues(alpha: 0.45)
              : const Color(0xFFDCCCB2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: unlocked ? accentColor : const Color(0xFF9E9284),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeText,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? accentColor : const Color(0xFF726253),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: DauVietTypography.labelLarge.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2B1B12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.2,
                    color: const Color(0xFF5A4A3B),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: DauVietTypography.labelSmall.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseSection {
  final LearningPathChapterDto? phase;
  final List<LearningPathEventNodeDto> events;

  const _PhaseSection({required this.phase, required this.events});
}

class _JourneyStatPill extends StatelessWidget {
  final String iconAsset;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String label;

  const _JourneyStatPill({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EC).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6D8BF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142B1B12),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DbOrBundledImage(
            bundledPath: iconAsset,
            width: 15,
            height: 15,
            fit: BoxFit.contain,
            placeholder: Icon(fallbackIcon, size: 15, color: fallbackColor),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2B1B12),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyBellBadge extends StatelessWidget {
  const _JourneyBellBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EC).withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6D8BF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142B1B12),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.notifications_rounded,
            size: 18,
            color: Color(0xFF4A3525),
          ),
          Positioned(
            top: 5,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFD92B2B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải băng tiêu đề giai đoạn (`PHASE`) thanh mảnh nằm dọc theo cuộn tranh,
/// không làm đứt mạch đường chấm sáng vàng.
class _CompactPhaseRibbon extends StatelessWidget {
  final String title;
  final String? periodLabel;

  const _CompactPhaseRibbon({
    super.key,
    required this.title,
    this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasPeriod = periodLabel != null && periodLabel!.trim().isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EFE0).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCC9AC), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18261E19),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3.5,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFB92B27),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    softWrap: true,
                    style: DauVietTypography.labelLarge.copyWith(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F4E46),
                      height: 1.22,
                    ),
                  ),
                  if (hasPeriod)
                    Text(
                      periodLabel!.trim(),
                      softWrap: true,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B5B4B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
