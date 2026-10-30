import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/parchment_card.dart';
import '../data/learning_path_dto.dart';
import '../data/learning_path_providers.dart';
import 'path_status_badge.dart';
import 'period_journey_screen.dart';

/// Màn Chọn thời kỳ lịch sử (`PeriodSelectionScreen` — Issue #22 / E2).
///
/// Đặc tả:
/// - Nhóm các thời kỳ (`PERIOD`) theo đại thời kỳ (`ERA`).
/// - Ẩn tầng phân cấp khi chỉ có 1 mục (ví dụ toàn lộ trình chỉ có `<= 1` nhóm
///   `ERA` thì ẩn tiêu đề tầng `ERA`, hiển thị thẳng danh sách `PERIOD`).
/// - Khi người học chọn một thời kỳ: gọi `touchPeriod(periodCode)` và điều hướng
///   vào [PeriodJourneyScreen].
/// - Mọi trạng thái đều hiển thị cả biểu tượng (`Icon`) lẫn nhãn chữ (`Text`).
class PeriodSelectionScreen extends ConsumerWidget {
  final ValueChanged<String>? onPeriodSelected;
  final bool showBottomNav;

  const PeriodSelectionScreen({
    super.key,
    this.onPeriodSelected,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPath = ref.watch(learningPathProvider);

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: Stack(
        children: [
          // Nền tranh non nước màu nước trải toàn top (theo mockup M-03 v3).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/landscape_hero_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Veil giấy mờ để nền chìm vào parchment — fade dần từ trên xuống,
          // nặng ở đáy để nội dung dưới đọc rõ trên nền giấy.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DauVietColors.paperCard.withValues(alpha: 0.40),
                      DauVietColors.paperCard.withValues(alpha: 0.55),
                      DauVietColors.paperBackground.withValues(alpha: 0.92),
                      DauVietColors.paperBackground,
                    ],
                    stops: const [0.0, 0.35, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
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
                    data: (path) => _buildContent(context, ref, path),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: showBottomNav ? const MainBottomNav() : null,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: DauVietColors.inkText,
              ),
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
          ] else ...[
            // Icon sách đỏ trong vòng tròn nổi trên tranh nền.
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DauVietColors.paperCard.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DauVietColors.cinnabarRed.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: DauVietColors.pixelShadowSm,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 20,
                color: DauVietColors.cinnabarRed,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHỌN THỜI KỲ LỊCH SỬ',
                  style: DauVietTypography.labelLarge.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Khám phá tự do từng thời kỳ • Mở khóa tuần tự trong thời kỳ',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: DauVietColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    LearningPathDto path,
  ) {
    final visibleGroups = path.eraGroups
        .where((g) => g.periods.isNotEmpty)
        .toList();

    if (visibleGroups.isEmpty) {
      return AsyncStateView.empty(
        message: 'Lộ trình học tập hiện chưa có thời kỳ nào được công bố.',
      );
    }

    // Quy tắc "ẩn tầng chỉ có 1 mục":
    // Chỉ hiển thị tiêu đề tầng ERA khi lộ trình có từ 2 nhóm ERA trở lên.
    final bool showEraHeaders = visibleGroups.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverallSummaryCard(path),
          const SizedBox(height: 12),
          const _StatusLegendStrip(),
          const SizedBox(height: 16),
          for (int i = 0; i < visibleGroups.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            ..._buildEraGroupItems(
              context: context,
              ref: ref,
              path: path,
              group: visibleGroups[i],
              eraIndex: i + 1,
              showEraHeader: showEraHeaders && visibleGroups[i].era != null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverallSummaryCard(LearningPathDto path) {
    final summary = path.summary;
    return ParchmentCard(
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // La bàn vàng tròn (compass) — điểm nhấn nhận diện hành trình.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DauVietColors.imperialGoldLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DauVietColors.imperialGold,
                    width: 1.4,
                  ),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 21,
                  color: DauVietColors.woodBrown,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  path.title ?? 'Hành trình Lịch sử Việt Nam',
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 16,
                    color: DauVietColors.inkHeading,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: DauVietColors.imperialGoldLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: DauVietColors.imperialGold,
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      size: 12,
                      color: DauVietColors.woodBrown,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.completedEvents}/${summary.totalRequiredEvents} sự kiện',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.woodBrown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (path.description != null &&
              path.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              path.description!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.eventProgressFraction,
              minHeight: 7,
              backgroundColor: DauVietColors.paperDim,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DauVietColors.heritageGreen,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã hoàn thành ${summary.completedLessons}/${summary.totalRequiredLessons} bài học bắt buộc',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11.5,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEraGroupItems({
    required BuildContext context,
    required WidgetRef ref,
    required LearningPathDto path,
    required EraGroupDto group,
    required int eraIndex,
    required bool showEraHeader,
  }) {
    final era = group.era;
    return [
      if (showEraHeader && era != null) ...[
        Container(
          key: Key('era-header-${era.code}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DauVietColors.parchmentHigh,
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: DauVietColors.cinnabarRed, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    size: 17,
                    color: DauVietColors.cinnabarRed,
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
        ),
        const SizedBox(height: 10),
      ],
      for (int j = 0; j < group.periods.length; j++) ...[
        if (j > 0) const SizedBox(height: 10),
        _PeriodCard(
          period: group.periods[j],
          events: path.eventsOfPeriod(group.periods[j].chapterId),
          progress: path.progressForPeriod(group.periods[j].code),
          isLastTouched: path.lastPeriodCode == group.periods[j].code,
          onTap: () => _handleSelectPeriod(
            context: context,
            ref: ref,
            periodCode: group.periods[j].code,
          ),
        ),
      ],
    ];
  }

  Future<void> _handleSelectPeriod({
    required BuildContext context,
    required WidgetRef ref,
    required String periodCode,
  }) async {
    // Gọi touch khi vào thời kỳ (không chặn điều hướng nếu mạng lỗi).
    try {
      await ref.read(learningPathProvider.notifier).touchPeriod(periodCode);
    } catch (_) {
      // Lỗi mạng trên endpoint touch không làm kẹt người học ngoài thời kỳ.
    }

    if (!context.mounted) return;
    if (onPeriodSelected != null) {
      onPeriodSelected!(periodCode);
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

/// Dải chú giải trạng thái có đầy đủ biểu tượng + nhãn văn bản (AC-1).
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
        color: DauVietColors.parchmentDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
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
              Text(
                'Chú giải trạng thái học tập',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.woodBrown,
                  fontWeight: FontWeight.w700,
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

class _PeriodCard extends StatelessWidget {
  final LearningPathChapterDto period;
  final List<LearningPathEventNodeDto> events;
  final PeriodProgressDto? progress;
  final bool isLastTouched;
  final VoidCallback onTap;

  const _PeriodCard({
    required this.period,
    required this.events,
    required this.progress,
    required this.isLastTouched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final periodStatus = derivePeriodStatus(events: events, progress: progress);
    final completedEvents =
        progress?.completedEvents ??
        events.where((e) => e.isRequired && e.status.isDone).length;
    final requiredEvents =
        progress?.requiredEvents ?? events.where((e) => e.isRequired).length;
    final completedLessons =
        progress?.completedLessons ??
        events.fold<int>(0, (sum, e) => sum + e.completedLessonsCount);
    final requiredLessons =
        progress?.requiredLessons ??
        events.fold<int>(0, (sum, e) => sum + e.lessons.length);
    final percent =
        progress?.percent ??
        (requiredEvents > 0
            ? ((completedEvents * 100) / requiredEvents).round()
            : 0);
    final coverPath = _resolveCoverAsset(period);

    return ParchmentCard(
      key: Key('period-card-${period.code}'),
      onTap: onTap,
      backgroundColor: DauVietColors.paperCard,
      borderColor: isLastTouched
          ? DauVietColors.cinnabarRed
          : DauVietColors.outlineVariant,
      borderWidth: isLastTouched ? 1.5 : 1.0,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail thời kỳ — khung vuông bo góc bên trái (giống mockup).
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 76,
              height: 76,
              color: DauVietColors.paperDim,
              child: coverPath != null
                  ? Image.asset(
                      coverPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildCoverFallback(),
                    )
                  : _buildCoverFallback(),
            ),
          ),
          const SizedBox(width: 12),
          // Cột nội dung chính.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges trạng thái + niên đại.
                Wrap(
                  spacing: 6,
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
                          color: DauVietColors.cinnabarRed,
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
                    if (period.periodLabel != null &&
                        period.periodLabel!.trim().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: DauVietColors.inkMuted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              period.periodLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.labelSmall.copyWith(
                                fontSize: 10.5,
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  period.title,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 15,
                    color: DauVietColors.inkHeading,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (period.description != null &&
                    period.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    period.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: DauVietColors.inkMuted,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Hàng progress bar + %.
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (percent / 100.0).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: DauVietColors.paperDim,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            DauVietColors.heritageGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$percent%',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 11,
                        color: DauVietColors.heritageGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Stats dòng dưới.
                Text(
                  '$completedEvents/$requiredEvents sự kiện • $completedLessons/$requiredLessons bài học',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: DauVietColors.woodBrown,
            ),
          ),
        ],
      ),
    );
  }

  /// Tra cứu ảnh bìa của thời kỳ — ưu tiên `coverImageKey` do admin cấu hình,
  /// rơi về tra theo `chapter.code` (xem `AssetResolver.resolvePeriodCover`).
  String? _resolveCoverAsset(LearningPathChapterDto period) {
    return const AssetResolver().resolvePeriodCover(
      period.coverImageKey,
      period.code,
    );
  }

  /// Fallback khi chưa có ảnh hoặc file chưa bundle — icon lịch sử trên nền
  /// giấy dó mờ để giữ card không bị rỗng.
  Widget _buildCoverFallback() {
    return Container(
      color: DauVietColors.paperDim,
      alignment: Alignment.center,
      child: const Icon(
        Icons.account_balance_rounded,
        size: 28,
        color: DauVietColors.inkLight,
      ),
    );
  }
}
