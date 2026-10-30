import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../../core/widgets/heritage_design_components.dart';
import '../../campaign/presentation/campaign_detail_screen.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'path_status_badge.dart';
import 'widgets/historical_event_card.dart';

/// Màn Hành trình thời kỳ (`PeriodJourneyScreen` — Vietnamese Heritage Modern).
///
/// Đặc tả:
/// - Tự động gọi `touchPeriod(periodCode)` khi vào thời kỳ.
/// - Sử dụng `HeritageBackground` render ảnh nền động do Admin cấu hình
///   (hoặc nền giấy cổ + vân mây & hoa văn Đông Sơn nhẹ khi không có ảnh).
/// - Thẻ tổng quan thời kỳ (`HeritageCard` + `HeritageProgressIndicator`).
/// - Timeline dọc liền mạch (`HeritageTimelineNode` + `HistoricalEventCard`).
/// - Ẩn tầng chỉ có 1 mục:
///   - Nếu thời kỳ có `<= 1` nhóm giai đoạn (`PHASE`), ẩn tiêu đề tầng `PHASE`.
///   - Nếu sự kiện chỉ có `<= 1` bài học, ẩn danh sách bài học con nhiều dòng.
/// - Bấm vào sự kiện mở [CampaignDetailScreen] (`campaign_detail_screen.dart`).
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
    // Quy tắc A3 & D1: Chỉ sử dụng cấu hình ảnh nền riêng của thời kỳ;
    // không tự lấy ảnh sự kiện làm nền thời kỳ và không hardcode theo tên/ID.
    final bgConfig =
        period?.backgroundConfig ?? HeritageBackgroundConfigDto.paperDefault;

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: HeritageBackground(
        config: bgConfig,
        heroHeight: 210,
        child: SafeArea(
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
      ),
    );
  }

  /// Header D1 — Phong cách Vietnamese Heritage Modern:
  /// Nút quay lại, nhãn Hành trình thời kỳ, tiêu đề thời kỳ đặt trên nền
  /// `HeritageBackground` có lớp phủ bảo vệ độ tương phản.
  Widget _buildTopBar(BuildContext context, LearningPathDto? path) {
    final period = path?.periodByCode(widget.periodCode);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DauVietColors.paperBackground.withValues(alpha: 0.78),
            DauVietColors.paperBackground.withValues(alpha: 0.35),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.imperialGold.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DauVietColors.paperCard.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(
                color: DauVietColors.outlineVariant,
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: DauVietColors.inkText,
                size: 20,
              ),
              tooltip: 'Chọn thời kỳ khác',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.paperCard.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: DauVietColors.imperialGold.withValues(alpha: 0.55),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'HÀNH TRÌNH THỜI KỲ',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 10.5,
                      color: DauVietColors.cinnabarRed,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period?.title ?? widget.periodCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 17,
                    color: DauVietColors.inkHeading,
                    height: 1.2,
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPeriodHeaderCard(
            period: period,
            era: era,
            events: allEvents,
            progress: progress,
          ),
          const SizedBox(height: 18),
          for (int s = 0; s < sections.length; s++) ...[
            if (s > 0) const SizedBox(height: 16),
            if (showPhaseHeaders && sections[s].phase != null) ...[
              _buildPhaseHeader(sections[s].phase!),
              const SizedBox(height: 12),
            ],
            for (int i = 0; i < sections[s].events.length; i++)
              _EventTimelineItem(
                event: sections[s].events[i],
                stepNumber: _globalEventNumber(sections, s, i),
                isFirstInSection: i == 0,
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

  /// Thẻ tổng quan thời kỳ (D2):
  /// Card nền giấy bo tròn mềm, viền vàng nhạt, đổ bóng nhẹ, chứa trạng thái,
  /// thời kỳ cha, tên thời kỳ, tiến độ bắt buộc, progress bar và phần trăm hoàn thành.
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

    return HeritageCard(
      backgroundColor: DauVietColors.paperCard,
      borderColor: const Color(0xFFD8BA73),
      borderWidth: 1.1,
      borderRadius: 16,
      showCornerMotif: true,
      showTopAccentLine: true,
      topAccentColor: DauVietColors.imperialGold,
      padding: const EdgeInsets.all(15),
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
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.paperCardHi,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: DauVietColors.outlineVariant.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
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
                      Flexible(
                        child: Text(
                          era.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DauVietTypography.labelSmall.copyWith(
                            color: DauVietColors.woodBrown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            period.title,
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 18,
              color: DauVietColors.inkHeading,
            ),
          ),
          if (period.periodLabel != null &&
              period.periodLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              period.periodLabel!,
              style: DauVietTypography.labelMedium.copyWith(
                color: DauVietColors.cinnabarRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (period.description != null &&
              period.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              period.description!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          HeritageProgressIndicator(
            label:
                'Tiến độ thời kỳ: $completedEvents/$requiredEvents sự kiện bắt buộc',
            percent: percent,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseHeader(LearningPathChapterDto phase) {
    return HeritageSectionHeader(
      key: Key('phase-header-${phase.code}'),
      title: phase.title,
      periodLabel: phase.periodLabel,
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

/// D3 — Một dòng trên Timeline các chặng:
/// Kết hợp `HeritageTimelineNode` (bên trái) và `HistoricalEventCard` (bên phải)
/// trong `IntrinsicHeight` để đường nối dọc luôn khớp chính xác giữa các node.
class _EventTimelineItem extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final int stepNumber;
  final bool isFirstInSection;
  final bool isLastInSection;
  final bool isCurrentTarget;
  final VoidCallback onTap;

  const _EventTimelineItem({
    required this.event,
    required this.stepNumber,
    this.isFirstInSection = false,
    required this.isLastInSection,
    required this.isCurrentTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeritageTimelineNode(
            status: event.status,
            isFirst: isFirstInSection,
            isLast: isLastInSection,
            isCurrentTarget: isCurrentTarget,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HistoricalEventCard(
                event: event,
                stepNumber: stepNumber,
                isCurrentTarget: isCurrentTarget,
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
