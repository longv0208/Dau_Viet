import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'path_status_badge.dart';
import 'period_journey_screen.dart';
import 'widgets/bottom_floating_summary_card.dart';
import 'widgets/winding_landscape_journey_canvas.dart';

/// Màn Chọn thời kỳ lịch sử (`PeriodSelectionScreen` — Issue #48, `/journey`).
///
/// Đặc tả (theo `journey-mockup.png`):
/// - Header kem `#FBF7EF`: overline `CHỌN THỜI KỲ LỊCH SỬ`, tiêu đề
///   `"Hành trình"` Noto Serif đậm + phụ đề `"Khám phá dòng chảy lịch sử
///   Việt Nam"`, nút tròn mở Bản đồ `/map` ở góc phải.
/// - Thanh tab ngang chọn Đại thời kỳ (`ERA`, hiện khi có từ 2 nhóm trở lên):
///   tab đang chọn nền đỏ chu sa `#B92B27`, tab thường nền ngà `#F3EDE0`.
/// - Canvas Đường đi Phong cảnh 2.5D (`WindingLandscapeJourneyCanvas`) với các
///   nút mốc tròn + thẻ pill nổi cho từng `PERIOD` — mọi thời kỳ đều tự do
///   chọn, không hiển thị ổ khóa (AC-2).
/// - `BottomFloatingSummaryCard` nổi ở chân hiển thị tiến độ thời kỳ đang chọn.
/// - Chạm thẻ pill / nút `>` → `touchPeriod(periodCode)` + vào
///   [PeriodJourneyScreen]; chạm huy hiệu tròn → chỉ đổi thời kỳ đang chọn.
class PeriodSelectionScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onPeriodSelected;
  final bool showBottomNav;

  const PeriodSelectionScreen({
    super.key,
    this.onPeriodSelected,
    this.showBottomNav = true,
  });

  @override
  ConsumerState<PeriodSelectionScreen> createState() =>
      _PeriodSelectionScreenState();
}

class _PeriodSelectionScreenState
    extends ConsumerState<PeriodSelectionScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _eraSectionKeys = {};
  String? _selectedEraCode;
  String? _selectedPeriodCode;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncPath = ref.watch(learningPathProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7EF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: asyncPath.when(
                loading: () => AsyncStateView.loading(
                  message: 'Đang mở cuộn thư lộ trình lịch sử...',
                ),
                error: (err, _) => AsyncStateView.error(
                  error: err,
                  onRetry: () =>
                      ref.read(learningPathProvider.notifier).refresh(),
                ),
                data: (path) => _buildContent(context, path),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showBottomNav ? const MainBottomNav() : null,
    );
  }

  /// Header kem theo mockup: overline, "Hành trình" Noto Serif 800, phụ đề
  /// "Khám phá dòng chảy lịch sử Việt Nam" và nút tròn bản đồ 44x44.
  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Quay lại',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHỌN THỜI KỲ LỊCH SỬ',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 10.5,
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hành trình',
                  style: DauVietTypography.headlineLarge.copyWith(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F1814),
                    height: 1.15,
                  ),
                ),
                Text(
                  'Khám phá dòng chảy lịch sử Việt Nam',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF6E6257),
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            icon: Icons.map_outlined,
            tooltip: 'Mở bản đồ di sản',
            onPressed: () => _openHeritageMap(context),
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

  Widget _buildContent(BuildContext context, LearningPathDto path) {
    final visibleGroups =
        path.eraGroups.where((g) => g.periods.isNotEmpty).toList();

    if (visibleGroups.isEmpty) {
      return AsyncStateView.empty(
        message: 'Lộ trình học tập hiện chưa có thời kỳ nào được công bố.',
      );
    }

    // Quy tắc "ẩn tầng chỉ có 1 mục": chỉ hiện thanh tab & tiêu đề ERA khi
    // lộ trình có từ 2 nhóm ERA trở lên.
    final bool showEraChrome = visibleGroups.length > 1;

    // Thời kỳ đang chọn trên BottomFloatingSummaryCard: ưu tiên lựa chọn của
    // người học → lastPeriodCode → thời kỳ đầu tiên có sự kiện.
    final allPeriods = [
      for (final g in visibleGroups) ...g.periods,
    ];
    final selected = _resolveSelectedPeriod(path, allPeriods);

    final entries = <JourneyCanvasEntry>[];
    bool milestoneOnLeft = true;
    for (int i = 0; i < visibleGroups.length; i++) {
      final group = visibleGroups[i];
      final era = group.era;
      if (showEraChrome && era != null) {
        final key = _eraSectionKeys.putIfAbsent(
          era.code,
          () => GlobalKey(debugLabel: 'era-section-${era.code}'),
        );
        entries.add(
          JourneyCanvasEntry.fullWidth(
            child: SizedBox(key: key, child: _EraHeaderBanner(era: era)),
          ),
        );
      }
      for (final period in group.periods) {
        final events = path.eventsOfPeriod(period.chapterId);
        final progress = path.progressForPeriod(period.code);
        final isLastTouched = path.lastPeriodCode == period.code;
        final isSelected = selected?.code == period.code;
        entries.add(
          JourneyCanvasEntry.milestone(
            cardOnLeft: milestoneOnLeft,
            badge: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _selectedPeriodCode = period.code),
              child: JourneyNodeBadge(
                status: derivePeriodStatus(events: events, progress: progress),
                isSelected: isSelected || isLastTouched,
                isPeriodNode: true,
              ),
            ),
            child: _PeriodMilestonePill(
              period: period,
              events: events,
              progress: progress,
              isLastTouched: isLastTouched,
              isSelected: isSelected,
              onTap: () => _handleSelectPeriod(period.code),
            ),
          ),
        );
        milestoneOnLeft = !milestoneOnLeft;
      }
    }

    return Column(
      children: [
        if (showEraChrome) _buildEraTabBar(visibleGroups),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 156),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WindingLandscapeJourneyCanvas(entries: entries),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _StatusLegendStrip(),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: _buildSelectedSummaryCard(path, selected),
                ),
            ],
          ),
        ),
      ],
    );
  }

  LearningPathChapterDto? _resolveSelectedPeriod(
    LearningPathDto path,
    List<LearningPathChapterDto> allPeriods,
  ) {
    if (allPeriods.isEmpty) return null;
    for (final candidate in [
      _selectedPeriodCode,
      path.lastPeriodCode,
    ]) {
      if (candidate == null) continue;
      for (final p in allPeriods) {
        if (p.code == candidate) return p;
      }
    }
    // Fallback: thời kỳ đầu tiên có sự kiện học được, hoặc thời kỳ đầu tiên.
    for (final p in allPeriods) {
      if (path.eventsOfPeriod(p.chapterId).isNotEmpty) return p;
    }
    return allPeriods.first;
  }

  /// Thanh tab ngang chọn Đại thời kỳ: "Tất cả" + từng ERA. Tab đang chọn đỏ
  /// chu sa `#B92B27`; tab thường ngà `#F3EDE0` chữ nâu `#4A3F37`. Bấm tab cuộn
  /// tới nhóm ERA tương ứng trên con đường phong cảnh.
  Widget _buildEraTabBar(List<EraGroupDto> visibleGroups) {
    return Container(
      color: const Color(0xFFFBF7EF),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _EraFilterTab(
            label: 'Tất cả',
            selected: _selectedEraCode == null,
            onTap: () {
              setState(() => _selectedEraCode = null);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
          for (final group in visibleGroups)
            if (group.era != null)
              _EraFilterTab(
                key: Key('era-tab-${group.era!.code}'),
                label: _shortEraLabel(group.era!),
                selected: _selectedEraCode == group.era!.code,
                onTap: () {
                  setState(() => _selectedEraCode = group.era!.code);
                  final target = _eraSectionKeys[group.era!.code];
                  if (target?.currentContext != null) {
                    Scrollable.ensureVisible(
                      target!.currentContext!,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      alignment: 0.08,
                    );
                  }
                },
              ),
        ],
      ),
    );
  }

  /// Nhãn ngắn cho tab ERA — bỏ tiền tố "Thời kỳ " để tránh lặp với tiêu đề
  /// đầy đủ trên banner nhóm (giữ `era-header-*` là nguồn tiêu đề đầy đủ duy
  /// nhất trên màn hình).
  String _shortEraLabel(LearningPathChapterDto era) {
    final title = era.title.trim();
    const prefix = 'Thời kỳ ';
    if (title.startsWith(prefix) && title.length > prefix.length) {
      return title.substring(prefix.length).trim();
    }
    return title;
  }

  Widget _buildSelectedSummaryCard(
    LearningPathDto path,
    LearningPathChapterDto period,
  ) {
    final events = path.eventsOfPeriod(period.chapterId);
    final progress = path.progressForPeriod(period.code);
    final stats = _PeriodStats.compute(events, progress);
    final cover = const AssetResolver().resolvePeriodCover(
      period.coverImageKey,
      period.code,
    );
    return BottomFloatingSummaryCard(
      title: period.title,
      yearLabel: _yearRangeLabel(period),
      statsText: '${stats.completedEvents}/${stats.requiredEvents} sự kiện',
      percent: stats.percent,
      imageAsset: cover,
      onTap: () => _handleSelectPeriod(period.code),
    );
  }

  String? _yearRangeLabel(LearningPathChapterDto period) {
    if (period.startYear != null &&
        period.endYear != null &&
        period.startYear! > 0 &&
        period.endYear! > 0) {
      return '(${period.startYear} – ${period.endYear})';
    }
    if (period.periodLabel != null && period.periodLabel!.trim().isNotEmpty) {
      return period.periodLabel;
    }
    if (period.startYear != null && period.endYear != null) {
      final s = period.startYear! < 0
          ? '${-period.startYear!} TCN'
          : '${period.startYear}';
      final e = period.endYear! < 0
          ? '${-period.endYear!} TCN'
          : '${period.endYear}';
      return '($s – $e)';
    }
    return '(Tự do khám phá)';
  }

  Future<void> _handleSelectPeriod(String periodCode) async {
    // Gọi touch khi vào thời kỳ (không chặn điều hướng nếu mạng lỗi).
    try {
      await ref.read(learningPathProvider.notifier).touchPeriod(periodCode);
    } catch (_) {
      // Lỗi mạng trên endpoint touch không làm kẹt người học ngoài thời kỳ.
    }

    if (!mounted) return;
    if (widget.onPeriodSelected != null) {
      widget.onPeriodSelected!(periodCode);
      return;
    }

    final router = GoRouter.maybeOf(context);
    final targetLocation = '/journey/$periodCode';
    if (router != null &&
        router.configuration.findMatch(Uri.parse(targetLocation)).isNotEmpty) {
      await context.push(targetLocation);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PeriodJourneyScreen(periodCode: periodCode, touchOnInit: false),
      ),
    );
  }
}

/// Nút tròn 44x44 trắng viền kem + bóng mềm (nút bản đồ / quay lại trên header).
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        icon: Icon(icon, size: 20, color: const Color(0xFF4A3F37)),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Một tab chọn Đại thời kỳ trên thanh ngang (bo góc 14 theo mockup).
class _EraFilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EraFilterTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFFB92B27) : const Color(0xFFF3EDE0),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: DauVietTypography.labelMedium.copyWith(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color:
                    selected ? Colors.white : const Color(0xFF4A3F37),
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner tiêu đề Đại thời kỳ nổi trên con đường phong cảnh (giữ contract
/// `Key('era-header-<code>')` và hiển thị tiêu đề đầy đủ duy nhất một lần).
class _EraHeaderBanner extends StatelessWidget {
  final LearningPathChapterDto era;

  const _EraHeaderBanner({required this.era});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('era-header-${era.code}'),
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EC),
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: Color(0xFFB92B27), width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F261E19),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_rounded,
                size: 17,
                color: Color(0xFFB92B27),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  era.title,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 15.5,
                    color: DauVietColors.cinnabarRedDark,
                  ),
                ),
              ),
              if (era.periodLabel != null &&
                  era.periodLabel!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    era.periodLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.labelSmall.copyWith(
                      color: DauVietColors.woodBrown,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (era.description != null &&
              era.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              era.description!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ Pill nổi bên cạnh nút mốc trên con đường (`period-card-<code>`):
/// nền kem `#FBF6EC` bo góc 16, tiêu đề đỏ khi đang chọn/học, niên đại +
/// chỉ số `X/Y sự kiện • A/B bài học`, `%` và chevron `>` ở mép phải.
class _PeriodMilestonePill extends StatelessWidget {
  final LearningPathChapterDto period;
  final List<LearningPathEventNodeDto> events;
  final PeriodProgressDto? progress;
  final bool isLastTouched;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodMilestonePill({
    required this.period,
    required this.events,
    required this.progress,
    required this.isLastTouched,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final periodStatus = derivePeriodStatus(events: events, progress: progress);
    final stats = _PeriodStats.compute(events, progress);
    final bool highlighted =
        isSelected || isLastTouched || periodStatus.isInProgress;

    return Material(
      key: Key('period-card-${period.code}'),
      color: const Color(0xFFFBF6EC),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFB92B27).withValues(alpha: 0.55)
                  : const Color(0xFFE4D7C2),
              width: highlighted ? 1.4 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F261E19),
                offset: Offset(0, 3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PathStatusBadge(status: periodStatus, compact: true),
                        if (isLastTouched)
                          Container(
                            key: Key('period-active-badge-${period.code}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB92B27),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bookmark_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Đang theo học',
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
                    const SizedBox(height: 5),
                    Text(
                      period.title,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 14.5,
                        color: highlighted
                            ? const Color(0xFFB92B27)
                            : const Color(0xFF261E19),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (period.periodLabel != null &&
                        period.periodLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        period.periodLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10.5,
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${stats.completedEvents}/${stats.requiredEvents} '
                            'sự kiện • ${stats.completedLessons}/'
                            '${stats.requiredLessons} bài học',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: DauVietColors.inkMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stats.percent}%',
                          style: DauVietTypography.labelSmall.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF2E7D47),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF4A3F37),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số liệu tiến độ gộp của một thời kỳ (ưu tiên `PeriodProgressDto` từ server,
/// rơi về đếm trực tiếp từ danh sách sự kiện).
class _PeriodStats {
  final int completedEvents;
  final int requiredEvents;
  final int completedLessons;
  final int requiredLessons;
  final int percent;

  const _PeriodStats({
    required this.completedEvents,
    required this.requiredEvents,
    required this.completedLessons,
    required this.requiredLessons,
    required this.percent,
  });

  static _PeriodStats compute(
    List<LearningPathEventNodeDto> events,
    PeriodProgressDto? progress,
  ) {
    final completedEvents = progress?.completedEvents ??
        events.where((e) => e.isRequired && e.status.isDone).length;
    final requiredEvents =
        progress?.requiredEvents ?? events.where((e) => e.isRequired).length;
    final completedLessons = progress?.completedLessons ??
        events.fold<int>(0, (sum, e) => sum + e.completedLessonsCount);
    final requiredLessons = progress?.requiredLessons ??
        events.fold<int>(0, (sum, e) => sum + e.lessons.length);
    final percent = progress?.percent ??
        (requiredEvents > 0
            ? ((completedEvents * 100) / requiredEvents).round()
            : 0);
    return _PeriodStats(
      completedEvents: completedEvents,
      requiredEvents: requiredEvents,
      completedLessons: completedLessons,
      requiredLessons: requiredLessons,
      percent: percent,
    );
  }
}

/// Dải chú giải trạng thái có đầy đủ biểu tượng + nhãn văn bản (AC-1).
/// Vẫn liệt kê cả trạng thái `Đang khóa`/`Đang biên soạn` vì chúng áp dụng
/// cho sự kiện & bài học bên trong thời kỳ (khóa tuần tự nội bộ), còn ở cấp
/// `PERIOD` mọi thời kỳ đều tự do chọn (AC-2).
class _StatusLegendStrip extends StatelessWidget {
  const _StatusLegendStrip();

  static const List<LearnerPathStatus> _legendStatuses = [
    LearnerPathStatus.mastered,
    LearnerPathStatus.completed,
    LearnerPathStatus.inProgress,
    LearnerPathStatus.available,
    LearnerPathStatus.locked,
    LearnerPathStatus.notReady,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: DauVietColors.woodBrown,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chú giải trạng thái — thời kỳ nào cũng tự do chọn, '
                  'khóa chỉ áp dụng tuần tự bên trong mỗi thời kỳ',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.woodBrown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final status in _legendStatuses)
                PathStatusBadge(status: status, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
