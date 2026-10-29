import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      backgroundColor: DauVietColors.parchmentSurface,
      body: SafeArea(
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
      bottomNavigationBar: showBottomNav ? const MainBottomNav() : null,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: DauVietColors.parchmentContainer,
        border: Border(
          bottom: BorderSide(color: DauVietColors.outlineVariant, width: 1),
        ),
      ),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DauVietColors.cinnabarRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
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
                    color: DauVietColors.inkMuted,
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
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.explore_rounded,
                size: 18,
                color: DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path.title ?? 'Hành trình Lịch sử Việt Nam',
                  style: DauVietTypography.headlineSmall.copyWith(fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DauVietColors.imperialGoldLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: DauVietColors.imperialGold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
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
            const SizedBox(height: 6),
            Text(
              path.description!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.eventProgressFraction,
              minHeight: 7,
              backgroundColor: DauVietColors.parchmentHigh,
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

    return ParchmentCard(
      key: Key('period-card-${period.code}'),
      onTap: onTap,
      backgroundColor: isLastTouched
          ? DauVietColors.parchmentContainer
          : DauVietColors.parchmentSurface,
      borderColor: isLastTouched
          ? DauVietColors.cinnabarRed
          : DauVietColors.outlineVariant,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PathStatusBadge(status: periodStatus, compact: true),
              if (isLastTouched)
                Container(
                  key: Key('period-active-badge-${period.code}'),
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
                        Icons.bookmark_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đang theo học',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10.5,
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
                      size: 13,
                      color: DauVietColors.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        period.periodLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
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
                    Text(
                      period.title,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    if (period.description != null &&
                        period.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        period.description!,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: DauVietColors.woodBrown,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: DauVietColors.parchmentHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DauVietColors.heritageGreen,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$completedEvents/$requiredEvents sự kiện • $completedLessons/$requiredLessons bài học',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
}
