import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/asset_resolver.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../../learning/presentation/renderers/learning_asset_image.dart';
import '../../data/learning_path_dto.dart';
import '../path_status_badge.dart';

/// Historical Event Card (`HistoricalEventCard` — Phần C2, D4 & D5).
///
/// Hiển thị thông tin một chặng sự kiện lịch sử trong `PeriodJourneyScreen`:
/// - Nền giấy kem, góc bo mềm, viền mảnh, shadow nhẹ, họa tiết góc dưới.
/// - Trạng thái, Bắt buộc/Tùy chọn, Mốc tiếp theo, Chặng số, Năm lịch sử, Tên sự kiện.
/// - Thumbnail sự kiện tùy chọn khi sự kiện có ảnh riêng (không lấy ảnh thời kỳ).
/// - Danh sách bài học bên trong (chỉ mở khi sự kiện có >= 2 bài học).
class HistoricalEventCard extends StatelessWidget {
  final LearningPathEventNodeDto event;
  final int stepNumber;
  final bool isCurrentTarget;
  final VoidCallback onTap;
  final ValueChanged<LearningPathLessonNodeDto>? onLessonTap;

  const HistoricalEventCard({
    super.key,
    required this.event,
    required this.stepNumber,
    required this.isCurrentTarget,
    required this.onTap,
    this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = PathStatusVisual.of(event.status);
    final bool isLocked = event.status == LearnerPathStatus.locked;
    // Quy tắc "ẩn tầng chỉ có 1 mục": chỉ hiển thị danh sách bài học con khi có >= 2 bài.
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
          // Hàng huy hiệu trạng thái, loại tham gia & mốc tiếp theo
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

          // Hàng thông tin chặng, năm lịch sử, tên sự kiện và thumbnail tùy chọn
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

          // Cảnh báo nếu nội dung sự kiện đang biên soạn
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

          // Danh sách bài học bên trong sự kiện (D5)
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
}

/// Dòng bài học bên trong thẻ sự kiện (Phần D5).
/// Hỗ trợ đầy đủ trạng thái: Đã hoàn thành, Sẵn sàng học, Đang học, Đang khóa, Đang biên soạn.
/// Chặn mở nội dung khi bài học đang khóa hoặc đang biên soạn.
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

/// Thumbnail sự kiện tùy chọn (50x50 bo góc) — chỉ hiển thị khi sự kiện thực sự
/// có ảnh riêng (`coverAssetKey` hoặc `backgroundConfig`), không dùng ảnh thời kỳ.
class _OptionalEventThumbnail extends ConsumerWidget {
  final LearningPathEventNodeDto event;

  const _OptionalEventThumbnail({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? assetId =
        HeritageBackgroundConfigDto.extractAssetId(event.coverAssetKey) ??
        event.backgroundConfig.resolvedAssetId;

    if (assetId != null && assetId.isNotEmpty) {
      return FutureBuilder<List<int>>(
        future: fetchLearningAssetBytes(ref, assetId),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              bytes != null &&
              bytes.isNotEmpty) {
            return _wrapThumb(
              Image.memory(
                Uint8List.fromList(bytes),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    // Chỉ hiển thị bundled cover nếu sự kiện có coverAssetKey đã được cấu hình
    if (event.coverAssetKey != null && event.coverAssetKey!.trim().isNotEmpty) {
      final bundledPath = const AssetResolver().resolveEventCover(
        event.coverAssetKey,
        event.slug,
      );
      if (bundledPath != null && bundledPath.isNotEmpty) {
        return _wrapThumb(
          Image.asset(
            bundledPath,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _wrapThumb(Widget child) {
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
        child: SizedBox(width: 48, height: 48, child: child),
      ),
    );
  }
}
