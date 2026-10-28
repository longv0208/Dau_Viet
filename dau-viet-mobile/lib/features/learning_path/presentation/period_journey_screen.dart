import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../campaign/presentation/campaign_detail_screen.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'path_status_badge.dart';

/// Màn Hành trình thời kỳ (`PeriodJourneyScreen` — Issue #22 / E2).
///
/// Đặc tả:
/// - Tự động gọi `touchPeriod(periodCode)` khi vào thời kỳ.
/// - Hiển thị chuỗi sự kiện lịch sử thuộc thời kỳ (`PERIOD` và các `PHASE` con).
/// - Ẩn tầng chỉ có 1 mục:
///   - Nếu thời kỳ có `<= 1` nhóm giai đoạn (`PHASE`), ẩn tiêu đề tầng `PHASE`
///     và hiển thị trực tiếp chuỗi sự kiện.
///   - Nếu sự kiện chỉ có `<= 1` bài học, ẩn danh sách bài học con nhiều dòng.
/// - Bấm vào sự kiện mở [CampaignDetailScreen] (`campaign_detail_screen.dart`).
/// - Mọi trạng thái sự kiện/bài học đều có cả `Icon` và nhãn chữ (`AC-1`).
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

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, asyncPath.asData?.value),
            Expanded(
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, LearningPathDto? path) {
    final period = path?.periodByCode(widget.periodCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: DauVietColors.parchmentContainer,
        border: Border(
          bottom: BorderSide(color: DauVietColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: DauVietColors.inkText,
            ),
            tooltip: 'Chọn thời kỳ khác',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HÀNH TRÌNH THỜI KỲ',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  period?.title ?? widget.periodCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

    final era = period.parentId != null
        ? path.chapterById(period.parentId)
        : null;
    final progress = path.progressForPeriod(period.code);
    final currentPointer = path.currentForPeriod(period.code);
    final allEvents = path.eventsOfPeriod(period.chapterId);

    if (allEvents.isEmpty) {
      return AsyncStateView.empty(
        message: 'Thời kỳ này hiện đang được biên tập nội dung sự kiện.',
      );
    }

    final sections = _buildPhaseSections(path, period);
    // Quy tắc "ẩn tầng chỉ có 1 mục":
    // Nếu thời kỳ chỉ có 0 hoặc 1 nhóm giai đoạn (PHASE), ẩn tiêu đề tầng PHASE.
    final bool showPhaseHeaders = sections.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPeriodHeaderCard(
            period: period,
            era: era,
            events: allEvents,
            progress: progress,
          ),
          const SizedBox(height: 16),
          for (int s = 0; s < sections.length; s++) ...[
            if (s > 0) const SizedBox(height: 16),
            if (showPhaseHeaders && sections[s].phase != null) ...[
              _buildPhaseHeader(sections[s].phase!),
              const SizedBox(height: 10),
            ],
            for (int i = 0; i < sections[s].events.length; i++)
              _EventTimelineItem(
                event: sections[s].events[i],
                stepNumber: _globalEventNumber(sections, s, i),
                isLastInSection: i == sections[s].events.length - 1,
                isCurrentTarget:
                    currentPointer?.eventNodeId ==
                    sections[s].events[i].eventNodeId,
                onTap: () => _openEventCampaign(context, sections[s].events[i]),
              ),
          ],
        ],
      ),
    );
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

  Widget _buildPeriodHeaderCard({
    required LearningPathChapterDto period,
    required LearningPathChapterDto? era,
    required List<LearningPathEventNodeDto> events,
    required PeriodProgressDto? progress,
  }) {
    final periodStatus = derivePeriodStatus(events: events, progress: progress);
    final completedEvents =
        progress?.completedEvents ??
        events.where((e) => e.isRequired && e.status.isDone).length;
    final requiredEvents =
        progress?.requiredEvents ?? events.where((e) => e.isRequired).length;
    final percent =
        progress?.percent ??
        (requiredEvents > 0
            ? ((completedEvents * 100) / requiredEvents).round()
            : 0);

    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PathStatusBadge(status: periodStatus),
              if (era != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.parchmentHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_rounded,
                        size: 12,
                        color: DauVietColors.woodBrown,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        era.title,
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.woodBrown,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            period.title,
            style: DauVietTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          if (period.periodLabel != null &&
              period.periodLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              period.periodLabel!,
              style: DauVietTypography.labelMedium.copyWith(
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ],
          if (period.description != null &&
              period.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              period.description!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ thời kỳ: $completedEvents/$requiredEvents sự kiện bắt buộc',
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: DauVietColors.inkMuted,
                ),
              ),
              Text(
                '$percent%',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.heritageGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseHeader(LearningPathChapterDto phase) {
    return Container(
      key: Key('phase-header-${phase.code}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentHigh,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: DauVietColors.heritageGreen, width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timeline_rounded,
            size: 16,
            color: DauVietColors.heritageGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phase.title,
              style: DauVietTypography.labelLarge.copyWith(
                color: DauVietColors.heritageGreenDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (phase.periodLabel != null && phase.periodLabel!.trim().isNotEmpty)
            Text(
              phase.periodLabel!,
              style: DauVietTypography.labelSmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
        ],
      ),
    );
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
}

class _PhaseSection {
  final LearningPathChapterDto? phase;
  final List<LearningPathEventNodeDto> events;

  const _PhaseSection({required this.phase, required this.events});
}

class _EventTimelineItem extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final int stepNumber;
  final bool isLastInSection;
  final bool isCurrentTarget;
  final VoidCallback onTap;

  const _EventTimelineItem({
    required this.event,
    required this.stepNumber,
    required this.isLastInSection,
    required this.isCurrentTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = PathStatusVisual.of(event.status);
    // Quy tắc "ẩn tầng chỉ có 1 mục":
    // Chỉ hiển thị danh sách bài học con khi sự kiện có từ 2 bài học trở lên.
    final bool showLessonSubtree = event.lessons.length > 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: visual.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: visual.borderColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    visual.icon,
                    size: 15,
                    color: visual.foregroundColor,
                  ),
                ),
                if (!isLastInSection)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: DauVietColors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ParchmentCard(
                key: Key('event-card-${event.eventId}'),
                onTap: onTap,
                backgroundColor: isCurrentTarget
                    ? DauVietColors.parchmentContainer
                    : DauVietColors.parchmentSurface,
                borderColor: isCurrentTarget
                    ? DauVietColors.cinnabarRed
                    : visual.borderColor,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PathStatusBadge(status: event.status, compact: true),
                        ParticipationTypeBadge(
                          participationType: event.participationType,
                        ),
                        if (isCurrentTarget)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: DauVietColors.cinnabarRed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.my_location_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mốc tiếp theo',
                                  style: DauVietTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (event.yearLabel.trim().isNotEmpty)
                                Text(
                                  'Chặng $stepNumber • ${event.yearLabel}',
                                  style: DauVietTypography.labelSmall.copyWith(
                                    color: DauVietColors.cinnabarRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                event.title,
                                style: DauVietTypography.headlineSmall.copyWith(
                                  fontSize: 15.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: DauVietColors.woodBrown,
                        ),
                      ],
                    ),
                    if (!event.contentStatus.isPlayable) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: DauVietColors.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.contentStatus.labelVi,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 11.5,
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showLessonSubtree) ...[
                      const SizedBox(height: 10),
                      const Divider(
                        height: 1,
                        color: DauVietColors.outlineVariant,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        key: Key('event-lessons-${event.eventId}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int l = 0; l < event.lessons.length; l++) ...[
                            if (l > 0) const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${l + 1}. ${event.lessons[l].title}',
                                    style: DauVietTypography.bodySmall.copyWith(
                                      color: DauVietColors.inkText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PathStatusBadge(
                                  status: event.lessons[l].status,
                                  compact: true,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
