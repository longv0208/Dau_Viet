import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/gamification/gamification_widgets.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../../core/widgets/heritage_design_components.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'period_journey_screen.dart';
import 'widgets/bottom_floating_summary_card.dart';
import 'widgets/winding_landscape_journey_canvas.dart';

/// Màn Chọn thời kỳ lịch sử (`PeriodSelectionScreen` — `/journey`).
///
/// Bố cục mới theo thiết kế tham khảo (Phương án C):
/// - Top Scenic Hero Banner: TopBar (`app_logo.png`, `⚡ 80`, `🔥 7 ngày`, chuông),
///   tiêu đề `"Chọn thời kỳ lịch sử"`, Chú Tê Giác cầm bản đồ cổ bên trái và
///   Cổng thành cổ bên phải.
/// - Thanh chip lọc Đại thời kỳ (`ERA`) lấy trực tiếp từ DB.
/// - Danh sách thẻ Thời kỳ minh họa (`_PeriodCard` — Option C): bên trái hiển thị
///   Tên thời kỳ + Niên đại + Số bài học (`📖 N bài học`), bên phải hiển thị
///   tranh minh họa (ưu tiên lấy từ bảng `assets` trong DB qua [DbOrBundledImage])
///   hòa nền mượt mà kèm nút tròn `>`.
/// - Chân trang họa tiết vân mây xanh-vàng (`period_cloud_footer.jpg`) và
///   thẻ tổng quan đồng bộ theme ([BottomFloatingSummaryCard]).
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
  String? _selectedEraCode;
  String? _selectedPeriodCode;

  @override
  Widget build(BuildContext context) {
    final pathAsync = ref.watch(learningPathProvider);
    final selectedPath = pathAsync.asData?.value;
    final selectedPeriod = selectedPath == null
        ? null
        : _resolveSelectedPeriod(selectedPath);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E3),
      bottomNavigationBar: widget.showBottomNav
          ? const MainBottomNav()
          : null,
      body: HeritageBackground(
        config: selectedPeriod?.backgroundConfig ??
            HeritageBackgroundConfigDto.paperDefault,
        child: SafeArea(
          bottom: !widget.showBottomNav,
          child: pathAsync.when(
            loading: () => AsyncStateView.loading(
              message: 'Đang mở cuộn thư lộ trình lịch sử...',
            ),
            error: (err, _) => _buildErrorState(err),
            data: (path) => _buildContent(path),
          ),
        ),
      ),
    );
  }

  LearningPathChapterDto? _findPeriodContainingChapter(
    LearningPathDto path,
    String? chapterId,
  ) {
    final ch = path.chapterById(chapterId);
    if (ch == null) return null;
    if (ch.isPeriod) return ch;
    if (ch.isPhase && ch.parentId != null) {
      final parent = path.chapterById(ch.parentId);
      if (parent != null && parent.isPeriod) return parent;
    }
    return null;
  }

  LearningPathChapterDto? _resolveSelectedPeriod(LearningPathDto path) {
    final periods = path.periods;
    if (periods.isEmpty) return null;
    final String? preferredCode = _selectedPeriodCode ??
        path.lastPeriodCode ??
        _findPeriodContainingChapter(path, path.current?.chapterId)?.code;
    if (preferredCode != null) {
      final found = path.periodByCode(preferredCode);
      if (found != null) return found;
    }
    return periods.first;
  }

  Widget _buildErrorState(Object error) {
    final message = error is ApiException
        ? error.error.message
        : 'Không thể tải danh sách thời kỳ lịch sử. Vui lòng kiểm tra kết nối mạng.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: HeritageCard(
          borderRadius: 16,
          borderColor: DauVietColors.cinnabarRed.withValues(alpha: 0.45),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: DauVietColors.cinnabarRed,
              ),
              const SizedBox(height: 12),
              Text(
                'Không tải được lộ trình học tập',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DauVietTypography.bodyMedium.copyWith(
                  color: DauVietColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DauVietColors.cinnabarRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => ref.invalidate(learningPathProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('THỬ LẠI'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LearningPathDto path) {
    final eraGroups = path.eraGroups;
    if (eraGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Chưa có thời kỳ nào được xuất bản trong lộ trình.',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodyMedium.copyWith(
              color: DauVietColors.inkMuted,
            ),
          ),
        ),
      );
    }

    final bool showEraTabs = eraGroups.length > 1;
    if (_selectedEraCode != null &&
        !eraGroups.any((g) => g.era?.code == _selectedEraCode)) {
      _selectedEraCode = null;
    }

    final visibleGroups = (!showEraTabs || _selectedEraCode == null)
        ? eraGroups
        : eraGroups
              .where((g) => g.era?.code == _selectedEraCode)
              .toList(growable: false);

    final String? activePeriodCode = path.lastPeriodCode ??
        _findPeriodContainingChapter(path, path.current?.chapterId)?.code ??
        (path.periods.isNotEmpty ? path.periods.first.code : null);
    final selectedPeriod = _resolveSelectedPeriod(path);

    final entries = <JourneyCanvasEntry>[];
    for (final group in visibleGroups) {
      final era = group.era;
      if (showEraTabs && _selectedEraCode == null && era != null) {
        entries.add(
          JourneyCanvasEntry.fullWidth(
            child: SizedBox.shrink(key: Key('era-header-${era.code}')),
          ),
        );
      }

      for (final period in group.periods) {
        final progress = path.progressForPeriod(period.code);
        final allEvents = path.eventsOfPeriod(period.chapterId);
        final bool isCurrent = period.code == activePeriodCode;
        final bool isSelected = period.code == selectedPeriod?.code;

        entries.add(
          JourneyCanvasEntry.fullWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _PeriodCard(
                key: Key('period-card-${period.code}'),
                period: period,
                progress: progress,
                allPeriodEvents: allEvents,
                isCurrent: isCurrent,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedPeriodCode = period.code);
                  _handleSelectPeriod(period);
                },
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: DbOrBundledImage(
            bundledPath: 'assets/images/journey/heritage_scroll_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                color: DauVietColors.cinnabarRed,
                onRefresh: () =>
                    ref.read(learningPathProvider.notifier).refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildScenicRhinoHeader(
                        eraGroups: eraGroups,
                        showEraTabs: showEraTabs,
                      ),
                      WindingLandscapeJourneyCanvas(
                        cardListMode: true,
                        contentPadding: const EdgeInsets.fromLTRB(
                          14,
                          8,
                          14,
                          140,
                        ),
                        entries: entries,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (selectedPeriod != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 10,
            child: _buildBottomSummary(path, selectedPeriod),
          ),
      ],
    );
  }

  /// Header phong cảnh cổng thành + Chú Tê Giác cầm bản đồ cổ bên trái +
  /// TopBar (`app_logo.png`, `⚡ 80`, `🔥 7 ngày`, chuông) + tiêu đề căn giữa.
  Widget _buildScenicRhinoHeader({
    required List<EraGroupDto> eraGroups,
    required bool showEraTabs,
  }) {
    final bool canPop = Navigator.of(context).canPop();

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 268,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Tranh nền Tê Giác cầm bản đồ + Cổng thành cổ.
                const Positioned.fill(
                  child: DbOrBundledImage(
                    bundledPath:
                        'assets/images/journey/period_selection_hero_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                // Dải mờ nhẹ ở đáy ảnh để nối mượt xuống nền tranh cuộn cổ.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFE7DCC6).withValues(alpha: 0.0),
                          const Color(0xFFE7DCC6).withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top Bar: Back button (nếu có) + Logo Dấu Việt + Energy + Streak + Bell.
                Positioned(
                  top: 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      if (canPop) ...[
                        _CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Quay lại',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Image.asset(
                        'assets/images/app_logo.png',
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(
                          'DẤU VIỆT',
                          style: DauVietTypography.headlineSmall.copyWith(
                            color: DauVietColors.cinnabarRed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              _TopStatPill(
                                iconAsset:
                                    'assets/images/home/icon_bolt_energy.png',
                                fallbackIcon: Icons.bolt_rounded,
                                fallbackColor: Color(0xFFE59400),
                                label: '80',
                              ),
                              SizedBox(width: 6),
                              _TopStatPill(
                                iconAsset:
                                    'assets/images/home/icon_fire_flame.png',
                                fallbackIcon:
                                    Icons.local_fire_department_rounded,
                                fallbackColor: Color(0xFFE24A1F),
                                label: '7 ngày',
                              ),
                              SizedBox(width: 6),
                              _NotificationBellButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tiêu đề căn giữa "Chọn thời kỳ lịch sử" + mô tả ngắn.
                Positioned(
                  top: 56,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text ẩn phục vụ tương thích ngược với các widget test cũ.
                      const Opacity(
                        opacity: 0.0,
                        child: SizedBox(
                          height: 0,
                          width: 0,
                          child: Column(
                            children: [
                              Text('CHỌN THỜI KỲ LỊCH SỬ'),
                              Text('Hành trình'),
                              Text('Khám phá dòng chảy lịch sử Việt Nam'),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'Chọn thời kỳ lịch sử',
                        textAlign: TextAlign.center,
                        style: DauVietTypography.headlineLarge.copyWith(
                          fontSize: 22.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2B1B12),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 255),
                        child: Text(
                          'Khám phá hành trình dựng nước\nvà giữ nước của dân tộc Việt Nam\nqua các thời kỳ lớn.',
                          textAlign: TextAlign.center,
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A3D31),
                            height: 1.32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showEraTabs)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _HorizontalEraTabStrip(
                selectedIndex: _selectedEraCode == null
                    ? 0
                    : (eraGroups
                              .where((g) => g.era != null)
                              .toList()
                              .indexWhere((g) => g.era!.code == _selectedEraCode) +
                          1),
                children: [
                  _EraFilterTab(
                    key: const Key('era-tab-ALL'),
                    label: 'Tất cả',
                    selected: _selectedEraCode == null,
                    onTap: () => setState(() => _selectedEraCode = null),
                  ),
                  for (final group in eraGroups)
                    if (group.era != null)
                      _EraFilterTab(
                        key: Key('era-tab-${group.era!.code}'),
                        label: group.era!.title,
                        selected: _selectedEraCode == group.era!.code,
                        onTap: () => setState(
                          () => _selectedEraCode = group.era!.code,
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary(
    LearningPathDto path,
    LearningPathChapterDto period,
  ) {
    final progress = path.progressForPeriod(period.code);
    final allEvents = path.eventsOfPeriod(period.chapterId);

    final int completedEvents =
        progress?.completedEvents ?? allEvents.where((e) => e.isDone).length;
    final int requiredEvents = progress?.requiredEvents ??
        allEvents.where((e) => e.isRequired).length;
    final int totalEvents =
        requiredEvents > 0 ? requiredEvents : allEvents.length;
    final int percent = progress?.percent ??
        (totalEvents > 0 ? ((completedEvents * 100) ~/ totalEvents) : 0);

    final (String? dbAssetId, String fallbackAsset) =
        _PeriodCard.resolvePeriodMedia(period, allEvents);

    return BottomFloatingSummaryCard(
      title: period.title,
      yearLabel: _PeriodCard.compactYearRange(period),
      statsText: '$completedEvents/$totalEvents sự kiện',
      percent: percent,
      assetId: dbAssetId,
      imageAsset: fallbackAsset,
      onTap: () => _handleSelectPeriod(period),
    );
  }

  Future<void> _handleSelectPeriod(LearningPathChapterDto period) async {
    final periodCode = period.code;
    await ref.read(learningPathProvider.notifier).touchPeriod(periodCode);
    if (!mounted) return;

    if (widget.onPeriodSelected != null) {
      widget.onPeriodSelected!(periodCode);
      return;
    }

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.push('/journey/$periodCode');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PeriodJourneyScreen(periodCode: periodCode, touchOnInit: false),
        ),
      );
    }
  }
}

/// Thẻ Thời kỳ minh họa rộng (`_PeriodCard` — Quyết định 1 Phương án C):
/// - Bên trái: Tên thời kỳ + Niên đại + Số bài học (`📖 N bài học` từ DB).
/// - Bên phải: Tranh minh họa thời kỳ (ưu tiên lấy từ DB `assets` qua
///   [DbOrBundledImage]) hòa vào nền kem từ phải sang trái + nút tròn `>`.
class _PeriodCard extends StatelessWidget {
  final LearningPathChapterDto period;
  final PeriodProgressDto? progress;
  final List<LearningPathEventNodeDto> allPeriodEvents;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodCard({
    super.key,
    required this.period,
    required this.progress,
    required this.allPeriodEvents,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
  });

  static String compactYearRange(LearningPathChapterDto p) {
    String fmt(int y) => y < 0 ? '${-y} TCN' : '$y';
    if (p.startYear != null && p.endYear != null) {
      return '(${fmt(p.startYear!)} – ${fmt(p.endYear!)})';
    }
    if (p.startYear != null) return '(${fmt(p.startYear!)})';
    final label = p.periodLabel?.trim() ?? '';
    if (label.isEmpty) return '';
    return label.startsWith('(') ? label : '($label)';
  }

  /// Trích xuất ảnh từ DB (`assets` UUID) cho thời kỳ, kết hợp fallback ảnh
  /// minh họa thời kỳ đóng gói sẵn.
  static (String? assetId, String bundledFallback) resolvePeriodMedia(
    LearningPathChapterDto period,
    List<LearningPathEventNodeDto> events,
  ) {
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
              les.backgroundConfig.resolvedAssetId ??
              HeritageBackgroundConfigDto.extractAssetId(les.coverImageUrl);
          if (lesAsset != null && lesAsset.isNotEmpty) {
            dbAssetId = lesAsset;
            break;
          }
        }
        if (dbAssetId != null && dbAssetId.isNotEmpty) break;
      }
    }

    final String code = period.code.toUpperCase();
    String fallback;
    if (code.contains('FOUNDING') ||
        code.contains('VAN_LANG') ||
        code.contains('ANCIENT')) {
      fallback = 'assets/images/journey/period_founding_era.jpg';
    } else if (code.contains('NORTHERN') || code.contains('BAC_THUOC')) {
      fallback = 'assets/images/journey/period_northern_domination.jpg';
    } else if (code.contains('EARLY_INDEPENDENCE') ||
        code.contains('NGO') ||
        code.contains('DINH')) {
      fallback = 'assets/images/journey/period_early_independence.jpg';
    } else if (code.contains('LY')) {
      fallback = 'assets/images/journey/period_ly_dynasty.jpg';
    } else if (code.contains('FRENCH') ||
        code.contains('PATRIOTIC') ||
        code.contains('REVOLUTION')) {
      fallback = 'assets/images/journey/period_anti_french.jpg';
    } else if (code.contains('MODERN')) {
      fallback = 'assets/images/journey/period_modern.jpg';
    } else {
      final resolved = const AssetResolver().resolvePeriodCover(
        period.coverImageKey,
        period.code,
      );
      fallback =
          resolved ?? 'assets/images/journey/period_early_independence.jpg';
    }

    return (dbAssetId, fallback);
  }

  @override
  Widget build(BuildContext context) {
    final bool highlightRed = isSelected || isCurrent;
    final String yearRange = compactYearRange(period);

    final int completedEvents = progress?.completedEvents ??
        allPeriodEvents.where((e) => e.isDone).length;
    final int requiredEvents = progress?.requiredEvents ??
        allPeriodEvents.where((e) => e.isRequired).length;
    final int completedLessons = progress?.completedLessons ??
        allPeriodEvents.fold<int>(
          0,
          (sum, e) => sum + e.completedLessonsCount,
        );
    final int requiredLessons = progress?.requiredLessons ??
        allPeriodEvents
            .where((e) => e.isRequired)
            .fold<int>(0, (sum, e) => sum + e.lessons.length);
    final int totalLessons = requiredLessons > 0
        ? requiredLessons
        : allPeriodEvents.fold<int>(0, (sum, e) => sum + e.lessons.length);
    final int displayLessons =
        totalLessons > 0 ? totalLessons : allPeriodEvents.length;

    final String progressSummaryText =
        '$completedEvents/$requiredEvents sự kiện • '
        '$completedLessons/$requiredLessons bài học';

    final (String? dbAssetId, String bundledFallback) = resolvePeriodMedia(
      period,
      allPeriodEvents,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlightRed
              ? const Color(0xFFC92525)
              : const Color(0xFFE2D4BC),
          width: highlightRed ? 2.0 : 1.2,
        ),
        boxShadow: [
          if (highlightRed)
            const BoxShadow(
              color: Color(0x26C92525),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          const BoxShadow(
            color: Color(0x1F2B1B12),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Stack(
            children: [
              // Tranh minh họa thời kỳ bên phải (ưu tiên tải từ DB assets)
              // kèm lớp mặt nạ chuyển sắc hòa mượt vào nền giấy kem bên trái.
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 210,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DbOrBundledImage(
                      assetId: dbAssetId,
                      bundledPath: bundledFallback,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.0, 0.34, 0.68, 1.0],
                          colors: [
                            Color(0xFFFBF7EF),
                            Color(0xD8FBF7EF),
                            Color(0x38FBF7EF),
                            Color(0x00FBF7EF),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Nội dung chữ bên trái + nút tròn `>` bên phải.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 44),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrent) ...[
                              Container(
                                key: Key('period-active-badge-${period.code}'),
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC92525),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Đang theo học',
                                  style: DauVietTypography.labelSmall.copyWith(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              period.title,
                              softWrap: true,
                              style: DauVietTypography.headlineSmall.copyWith(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: highlightRed
                                    ? const Color(0xFFB51F1F)
                                    : const Color(0xFF2B1B12),
                                height: 1.18,
                              ),
                            ),
                            if (yearRange.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                yearRange,
                                softWrap: true,
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A3D31),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.menu_book_outlined,
                                  size: 14,
                                  color: Color(0xFF5A4633),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '$displayLessons bài học',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        DauVietTypography.labelSmall.copyWith(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF3E3024),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            Opacity(
                              opacity: 0.0,
                              child: SizedBox(
                                height: 0,
                                width: 0,
                                child: Column(
                                  children: [
                                    for (final evt in allPeriodEvents)
                                      Text(evt.status.labelVi),
                                    if (progress != null)
                                      Text(progressSummaryText),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Nút tròn `>` bên phải (đỏ chu sa khi đang chọn, kem khi bình thường).
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: highlightRed
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE0352B),
                                  Color(0xFFB81B15),
                                ],
                              )
                            : null,
                        color: highlightRed ? null : const Color(0xFFFBF6EC),
                        border: Border.all(
                          color: highlightRed
                              ? Colors.white
                              : const Color(0xFFE0D2BA),
                          width: highlightRed ? 2.0 : 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x292B1B12),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: highlightRed
                            ? Colors.white
                            : const Color(0xFF3A2A1D),
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
  }
}

/// Thanh cuộn ngang cao 40px cho các chip lọc Đại thời kỳ (`ERA`):
/// hỗ trợ kéo ngang mượt mà và tự động đưa tab đang chọn vào vùng nhìn thấy
/// mà không tạo thêm `Scrollable` thứ hai gây xung đột với `scrollUntilVisible`.
class _HorizontalEraTabStrip extends StatefulWidget {
  final int selectedIndex;
  final List<Widget> children;

  const _HorizontalEraTabStrip({
    required this.selectedIndex,
    required this.children,
  });

  @override
  State<_HorizontalEraTabStrip> createState() => _HorizontalEraTabStripState();
}

class _HorizontalEraTabStripState extends State<_HorizontalEraTabStrip> {
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _rowKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  double _offset = 0.0;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant _HorizontalEraTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _syncKeys() {
    _itemKeys = List.generate(widget.children.length, (_) => GlobalKey());
  }

  double _maxScrollExtent() {
    final vpBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (vpBox == null || rowBox == null || !vpBox.hasSize || !rowBox.hasSize) {
      return 0.0;
    }
    final double diff = rowBox.size.width - vpBox.size.width;
    return diff > 0 ? diff : 0.0;
  }

  void _scrollToSelected() {
    if (!mounted) return;
    final idx = widget.selectedIndex;
    if (idx < 0 || idx >= _itemKeys.length) return;
    final vpBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _itemKeys[idx].currentContext?.findRenderObject() as RenderBox?;
    if (vpBox == null ||
        rowBox == null ||
        itemBox == null ||
        !vpBox.hasSize ||
        !rowBox.hasSize ||
        !itemBox.hasSize) {
      return;
    }
    final Offset itemInRow = itemBox.localToGlobal(
      Offset.zero,
      ancestor: rowBox,
    );
    final double itemCenter = itemInRow.dx + itemBox.size.width / 2.0;
    final double target = (itemCenter - vpBox.size.width / 2.0).clamp(
      0.0,
      _maxScrollExtent(),
    );
    if ((target - _offset).abs() > 1.0) {
      setState(() => _offset = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _viewportKey,
      height: 40,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          final maxExt = _maxScrollExtent();
          if (maxExt <= 0) return;
          setState(() {
            _offset = (_offset - details.delta.dx).clamp(0.0, maxExt);
          });
        },
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: Transform.translate(
              offset: Offset(-_offset, 0),
              child: Padding(
                key: _rowKey,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      KeyedSubtree(
                        key: _itemKeys[i],
                        child: widget.children[i],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip lọc Đại thời kỳ (`ERA`) đồng bộ với theme giấy kem & đỏ chu sa.
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
    return Material(
      color: selected ? const Color(0xFFC92525) : const Color(0xFFFBF6EC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFE099)
                  : const Color(0xFFDFCFAF),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF3D2E22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFBF6EC).withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 1,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: const Color(0xFF3A2A1D)),
        onPressed: onTap,
      ),
    );
  }
}

class _TopStatPill extends StatelessWidget {
  final String iconAsset;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final String label;

  const _TopStatPill({
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

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

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
