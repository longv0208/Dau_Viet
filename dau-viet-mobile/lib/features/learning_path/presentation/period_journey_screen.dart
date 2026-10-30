import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../../core/widgets/heritage_design_components.dart';
import '../../campaign/presentation/campaign_detail_screen.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'widgets/bottom_floating_summary_card.dart';
import 'widgets/historical_event_card.dart';
import 'widgets/winding_landscape_journey_canvas.dart';

/// Màn Hành trình thời kỳ (`PeriodJourneyScreen` — Issue #48,
/// `/journey/:periodCode`).
///
/// Đặc tả (theo `journey-mockup.png`):
/// - Header kem: nút `<` quay lại, overline `HÀNH TRÌNH THỜI KỲ`, tiêu đề
///   `"Hành trình"` + tên thời kỳ/niên đại, nút tròn mở Bản đồ `/map`.
/// - Thanh tab ngang chuyển nhanh sang bất kỳ `PERIOD` nào khác — tự do chọn,
///   không khóa tuần tự giữa các thời kỳ (AC-2).
/// - Canvas Đường đi Phong cảnh 2.5D (`WindingLandscapeJourneyCanvas`): các mốc
///   `EVENT` nằm dọc con đường đá uốn lượn — mốc đang học đỏ chu sa, mốc hoàn
///   thành xanh lá `✓`, mốc khóa tuần tự nội bộ xám với ổ khóa.
/// - `BottomFloatingSummaryCard` nổi ở chân hiển thị `X/Y sự kiện`, `A/B bài
///   học`, `Z%` và nút `>` tiếp tục học.
/// - Giữ `HeritageBackground` đồng bộ ảnh nền do Admin cấu hình (Phần E).
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
      backgroundColor: const Color(0xFFFBF7EF),
      body: HeritageBackground(
        config: bgConfig,
        heroHeight: 210,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, asyncPath.asData?.value),
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

  /// Header theo mockup màn 2: nút `<` tròn, overline `HÀNH TRÌNH THỜI KỲ`,
  /// tiêu đề `"Hành trình"` + tên thời kỳ & niên đại, nút tròn bản đồ.
  Widget _buildHeader(BuildContext context, LearningPathDto? path) {
    final period = path?.periodByCode(widget.periodCode);
    final era = period?.parentId != null
        ? path?.chapterById(period!.parentId)
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EF).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.imperialGold.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE8DFD1), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A261E19),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF4A3F37),
                size: 20,
              ),
              tooltip: 'Chọn thời kỳ khác',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HÀNH TRÌNH THỜI KỲ',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 10.5,
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Hành trình',
                  style: DauVietTypography.headlineLarge.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F1814),
                    height: 1.15,
                  ),
                ),
                Text(
                  period?.title ?? widget.periodCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB92B27),
                  ),
                ),
                if (era != null)
                  Text(
                    era.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: const Color(0xFF6E6257),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE8DFD1), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A261E19),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.map_outlined,
                color: Color(0xFF4A3F37),
                size: 20,
              ),
              tooltip: 'Mở bản đồ di sản',
              onPressed: () => _openHeritageMap(context),
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
    // Không có router/route /map (widget test độc lập) → bỏ qua êm.
  }

  /// Thanh chip ngang chuyển nhanh sang bất kỳ `PERIOD` nào khác — AC-2: mọi
  /// thời kỳ đều tự do chọn, không có khóa tuần tự giữa các thời kỳ.
  Widget _buildPeriodSwitcher(BuildContext context, LearningPathDto path) {
    final periods = path.periods;
    if (periods.length <= 1) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFFBF7EF).withValues(alpha: 0.92),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final p in periods)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: p.code == widget.periodCode
                      ? const Color(0xFFB92B27)
                      : const Color(0xFFF3EDE0),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: p.code == widget.periodCode
                        ? null
                        : () => _switchPeriod(context, p.code),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        maxWidth: 190,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelMedium.copyWith(
                          fontSize: 12.5,
                          fontWeight: p.code == widget.periodCode
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: p.code == widget.periodCode
                              ? Colors.white
                              : const Color(0xFF4A3F37),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Chuyển trực tiếp sang thời kỳ khác (1 chạm — không khóa): gọi touch rồi
  /// điều hướng `/journey/<code>` (fallback push thay thế khi không có router).
  Future<void> _switchPeriod(BuildContext context, String periodCode) async {
    try {
      await ref.read(learningPathProvider.notifier).touchPeriod(periodCode);
    } catch (_) {
      // Không chặn chuyển thời kỳ nếu mạng lỗi.
    }
    if (!context.mounted) return;

    final router = GoRouter.maybeOf(context);
    final targetLocation = '/journey/$periodCode';
    if (router != null &&
        router.configuration.findMatch(Uri.parse(targetLocation)).isNotEmpty) {
      router.go(targetLocation);
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PeriodJourneyScreen(periodCode: periodCode),
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

    final progress = path.progressForPeriod(period.code);
    final currentPointer = path.currentForPeriod(period.code);
    final allEvents = path.eventsOfPeriod(period.chapterId);

    if (allEvents.isEmpty) {
      return Column(
        children: [
          _buildPeriodSwitcher(context, path),
          Expanded(
            child: AsyncStateView.empty(
              message: 'Thời kỳ này hiện đang được biên tập nội dung sự kiện.',
            ),
          ),
        ],
      );
    }

    final sections = _buildPhaseSections(path, period);
    // Quy tắc "ẩn tầng chỉ có 1 mục": nếu thời kỳ chỉ có 0 hoặc 1 nhóm giai
    // đoạn (PHASE) → ẩn tiêu đề tầng PHASE.
    final bool showPhaseHeaders = sections.length > 1;

    // Dựng các hàng trên con đường: tiêu đề PHASE (nếu có) + mốc từng EVENT.
    final entries = <JourneyCanvasEntry>[];
    bool milestoneOnLeft = true;
    for (int s = 0; s < sections.length; s++) {
      if (showPhaseHeaders && sections[s].phase != null) {
        final phase = sections[s].phase!;
        entries.add(
          JourneyCanvasEntry.fullWidth(
            child: HeritageSectionHeader(
              key: Key('phase-header-${phase.code}'),
              title: phase.title,
              periodLabel: phase.periodLabel,
              accentColor: const Color(0xFFB92B27),
            ),
          ),
        );
      }
      for (int i = 0; i < sections[s].events.length; i++) {
        final event = sections[s].events[i];
        final isCurrentTarget =
            currentPointer?.eventNodeId == event.eventNodeId;
        final stepNumber = _globalEventNumber(sections, s, i);
        entries.add(
          JourneyCanvasEntry.milestone(
            cardOnLeft: milestoneOnLeft,
            badge: JourneyNodeBadge(
              status: event.status,
              isSelected: isCurrentTarget,
            ),
            child: HistoricalEventCard(
              event: event,
              stepNumber: stepNumber,
              isCurrentTarget: isCurrentTarget,
              onTap: () => _openEventCampaign(context, event),
            ),
          ),
        );
        milestoneOnLeft = !milestoneOnLeft;
      }
    }

    return Column(
      children: [
        _buildPeriodSwitcher(context, path),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 156),
                child: WindingLandscapeJourneyCanvas(entries: entries),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
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
          ),
        ),
      ],
    );
  }

  /// Thẻ tổng quan nổi ở chân: ảnh tròn thời kỳ, tên + niên đại, thanh tiến
  /// độ xanh, chỉ số `X/Y sự kiện • A/B bài học` và `Z%`, nút `>` tiếp tục
  /// học (mở sự kiện mốc tiếp theo hoặc sự kiện đầu tiên mở được).
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
      imageAsset: cover,
      ctaLabel: 'Học tiếp',
      onTap: () => _continueLearning(context, events, currentPointer),
    );
  }

  /// Mở sự kiện "mốc tiếp theo" (con trỏ hiện tại) hoặc sự kiện đầu tiên còn
  /// học được trong thời kỳ — CTA trên `BottomFloatingSummaryCard`.
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
}

class _PhaseSection {
  final LearningPathChapterDto? phase;
  final List<LearningPathEventNodeDto> events;

  const _PhaseSection({required this.phase, required this.events});
}
