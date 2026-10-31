import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/asset_resolver.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../../learning/presentation/renderers/asset_cover_image.dart';
import '../../data/learning_path_dto.dart';
import '../path_status_badge.dart';

/// Thông tin phần thưởng mở khóa Địa điểm di sản (`map_locations`) và
/// Vật phẩm sưu tầm (`item_catalog`) gắn với một chặng sự kiện trên bản đồ hành trình.
class EventRewardPreview {
  final String? locationId;
  final String locationTitle;
  final String locationUnlockHint;
  final bool isLocationUnlocked;
  final String itemTitle;
  final String itemDescription;
  final bool isItemUnlocked;

  const EventRewardPreview({
    this.locationId,
    required this.locationTitle,
    this.locationUnlockHint = 'Mở khóa khi hoàn thành 1 bài học trong chặng',
    required this.isLocationUnlocked,
    required this.itemTitle,
    this.itemDescription = 'Nhận tự động khi hoàn thành toàn bộ bài học của chặng',
    required this.isItemUnlocked,
  });

  bool get hasLocation => locationTitle.trim().isNotEmpty;
  bool get hasItem => itemTitle.trim().isNotEmpty;
}

/// Historical Event Card (`HistoricalEventCard` — Phần C2, D4 & D5).
///
/// Hiển thị thông tin một chặng sự kiện lịch sử trong `PeriodJourneyScreen`:
/// - Khi [compactCallout] == true: hiển thị thẻ pill giấy kem bo tròn bên cạnh
///   huy hiệu tròn trên đường chấm sáng vàng (khớp mockup "Hành trình").
/// - Khi [compactCallout] == false: hiển thị thẻ sự kiện đầy đủ.
class HistoricalEventCard extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final int stepNumber;
  final bool isCurrentTarget;
  final VoidCallback onTap;
  final ValueChanged<LearningPathLessonNodeDto>? onLessonTap;
  final bool compactCallout;
  final EventRewardPreview? rewardPreview;
  final VoidCallback? onShowDetailsSheet;

  const HistoricalEventCard({
    super.key,
    required this.event,
    required this.stepNumber,
    required this.isCurrentTarget,
    required this.onTap,
    this.onLessonTap,
    this.compactCallout = false,
    this.rewardPreview,
    this.onShowDetailsSheet,
  });

  @override
  Widget build(BuildContext context) {
    if (compactCallout) return _buildCompactCallout(context);

    final visual = PathStatusVisual.of(event.status);
    final bool isLocked = event.status == LearnerPathStatus.locked;
    final bool showLessonSubtree = event.lessons.length > 1;

    final Color cardBg = isLocked
        ? DauVietColors.paperBackground
        : DauVietColors.paperCard;
    final Color cardBorder = isCurrentTarget
        ? DauVietColors.imperialGoldDark
        : (event.status.isDone
              ? DauVietColors.heritageGreen.withValues(alpha: 0.45)
              : visual.borderColor.withValues(alpha: 0.75));

    return HeritageCard(
      key: Key('event-card-${event.eventId}'),
      onTap: onTap,
      backgroundColor: cardBg,
      borderColor: cardBorder,
      borderWidth: isCurrentTarget ? 1.4 : 1.0,
      borderRadius: 15,
      showCornerMotif: !isLocked,
      showTopAccentLine: isCurrentTarget,
      topAccentColor: DauVietColors.cinnabarRed,
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
          const SizedBox(height: 10),
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
                          color: isLocked
                              ? DauVietColors.inkMuted
                              : DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      event.title,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 15.5,
                        color: isLocked
                            ? DauVietColors.inkSecondary
                            : DauVietColors.inkText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _OptionalEventThumbnail(event: event),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: isLocked
                      ? DauVietColors.inkLight
                      : DauVietColors.woodBrown,
                ),
              ),
            ],
          ),
          if (!event.contentStatus.isPlayable) ...[
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: DauVietColors.outlineVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Column(
              key: Key('event-lessons-${event.eventId}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int l = 0; l < event.lessons.length; l++) ...[
                  if (l > 0) const SizedBox(height: 6),
                  _EventLessonRow(
                    lesson: event.lessons[l],
                    orderNumber: l + 1,
                    onUnlockedTap: () {
                      if (onLessonTap != null) {
                        onLessonTap!(event.lessons[l]);
                      } else {
                        onTap();
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Nhãn mốc gọn trên bản đồ hành trình:
  /// Chỉ hiển thị **ảnh nền bài học / sự kiện** (tải từ DB `assets` hoặc fallback
  /// nội bộ), **tên bài học / sự kiện** và **năm** — gọn gàng, không tràn chiều cao.
  Widget _buildCompactCallout(BuildContext context) {
    final bool isLocked = event.status == LearnerPathStatus.locked ||
        event.status == LearnerPathStatus.notReady;
    final bool isHighlightedRed = !isLocked &&
        (isCurrentTarget ||
            event.status.isInProgress ||
            event.status == LearnerPathStatus.mastered ||
            stepNumber == 1);
    final bool hasRedBorder = !isLocked &&
        (isCurrentTarget || event.status.isInProgress);

    final Color pillBg = isLocked
        ? const Color(0xFFF3EFE4)
        : const Color(0xFFFBF6EC);
    final Color borderColor = hasRedBorder
        ? const Color(0xFFC92525)
        : const Color(0xFFE2D4BC);
    final Color titleColor = isLocked
        ? const Color(0xFF3A322B)
        : (isHighlightedRed
              ? const Color(0xFFB81D1D)
              : const Color(0xFF241B15));
    final Color yearColor = isLocked
        ? const Color(0xFF63564B)
        : (hasRedBorder ? const Color(0xFF9E1D1D) : const Color(0xFF4A3E35));

    String? coverAssetId =
        event.backgroundConfig.resolvedAssetId ??
        HeritageBackgroundConfigDto.extractAssetId(event.coverAssetKey);
    if (coverAssetId == null || coverAssetId.isEmpty) {
      for (final les in event.lessons) {
        final lesAsset =
            HeritageBackgroundConfigDto.extractAssetId(les.coverAssetId) ??
            les.backgroundConfig.resolvedAssetId;
        if (lesAsset != null && lesAsset.isNotEmpty) {
          coverAssetId = lesAsset;
          break;
        }
      }
    }
    final String? bundledCover = const AssetResolver().resolveEventCover(
      event.coverAssetKey,
      event.slug,
    );

    return Material(
      key: Key('event-card-${event.eventId}'),
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
                // Ảnh nền bài học / sự kiện ở nửa phải thẻ kèm lớp phủ kem chuyển sắc mềm
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
                        event.title,
                        softWrap: true,
                        style: DauVietTypography.labelLarge.copyWith(
                          fontSize: 13.2,
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
                            fontSize: 11.5,
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
                          child: Text(event.status.labelVi),
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

/// Dòng bài học bên trong thẻ sự kiện (Phần D5).
class _EventLessonRow extends StatelessWidget {
  final LearningPathLessonNodeDto lesson;
  final int orderNumber;
  final VoidCallback onUnlockedTap;

  const _EventLessonRow({
    required this.lesson,
    required this.orderNumber,
    required this.onUnlockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBlocked =
        lesson.status == LearnerPathStatus.locked ||
        lesson.status == LearnerPathStatus.notReady;

    return Material(
      color: isBlocked
          ? DauVietColors.paperDim.withValues(alpha: 0.45)
          : DauVietColors.paperBackground.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isBlocked
            ? () {
                final msg = lesson.status == LearnerPathStatus.notReady
                    ? 'Bài học này hiện đang được biên soạn nội dung.'
                    : 'Vui lòng hoàn thành bài học bắt buộc đứng trước trong lộ trình để mở khóa bài học này.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            : onUnlockedTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$orderNumber. ${lesson.title}',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: isBlocked
                          ? DauVietColors.inkMuted
                          : DauVietColors.inkText,
                      fontWeight: lesson.status == LearnerPathStatus.available ||
                              lesson.status == LearnerPathStatus.inProgress
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PathStatusBadge(status: lesson.status, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail sự kiện tùy chọn (48x48 bo góc).
class _OptionalEventThumbnail extends ConsumerWidget {
  final LearningPathEventNodeDto event;

  const _OptionalEventThumbnail({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? assetId =
        HeritageBackgroundConfigDto.extractAssetId(event.coverAssetKey) ??
        event.backgroundConfig.resolvedAssetId;

    final String? bundledPath =
        (assetId == null &&
                event.coverAssetKey != null &&
                event.coverAssetKey!.trim().isNotEmpty)
            ? const AssetResolver().resolveEventCover(
                event.coverAssetKey,
                event.slug,
              )
            : null;

    if ((assetId == null || assetId.isEmpty) &&
        (bundledPath == null || bundledPath.isEmpty)) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: DauVietColors.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AssetCoverImage(
            assetId: assetId,
            bundledPath: bundledPath,
            width: 48,
            height: 48,
            placeholder: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
