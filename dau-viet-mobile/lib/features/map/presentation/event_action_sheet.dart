import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/clue_tag.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/paper_grain_overlay.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../data/map_location_dto.dart';

/// Bottom sheet hành động của một NÚT SỰ KIỆN trên Bản Đồ Dấu Ấn (Issue #36 / #40).
///
/// Mở khi người học chạm vào [PathEventNode]. Hiển thị nhanh bối cảnh sự
/// kiện và CTA chính — "BẮT ĐẦU HỌC" / "TIẾP TỤC HỌC" — đi thẳng vào
/// `/learning/lesson/:lessonId` mà KHÔNG qua màn danh sách trung gian
/// (AC-1). Hàng cuối liệt kê các Địa điểm Di tích đã mở khóa của sự kiện
/// ([unlockedLocations]) như chip — xem Phase 3 (ghim vệ tinh / hồ sơ).
class EventActionSheet extends StatelessWidget {
  final LearningPathEventNodeDto event;

  /// Di tích đã UNLOCKED liên kết sự kiện này (từ `mapLocationsByEventProvider`).
  final List<MapLocationDto> unlockedLocations;
  final void Function(LearningPathLessonNodeDto lesson)? onStartLesson;
  final VoidCallback? onOpenCampaign;
  final void Function(MapLocationDto location)? onOpenLocation;

  const EventActionSheet({
    super.key,
    required this.event,
    this.unlockedLocations = const [],
    this.onStartLesson,
    this.onOpenCampaign,
    this.onOpenLocation,
  });

  /// Bài học mục tiêu của CTA chính: ưu tiên `IN_PROGRESS`, sau đó bài
  /// `AVAILABLE` đầu tiên theo `sortOrder`. `COMPLETED`/`MASTERED` → bài
  /// đầu tiên để ôn lại. Trả `null` nếu sự kiện không có bài khả dụng.
  LearningPathLessonNodeDto? get _primaryLesson {
    if (event.lessons.isEmpty) return null;
    for (final l in event.lessons) {
      if (l.status.isInProgress) return l;
    }
    for (final l in event.lessons) {
      if (l.status.isAvailable) return l;
    }
    if (event.status.isDone) return event.lessons.first;
    return null;
  }

  bool get _hasCover =>
      event.coverAssetKey != null && event.coverAssetKey!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primary = _primaryLesson;
    final status = event.status;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: ParchmentCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasCover) ...[
                        _buildHeroCover(),
                        const SizedBox(height: 14),
                      ],
                      _buildTitleRow(),
                      const SizedBox(height: 12),
                      _buildProgressRow(),
                      const SizedBox(height: 16),
                      _buildPrimaryCta(context, status, primary),
                      if (status != LearnerPathStatus.locked) ...[
                        const SizedBox(height: 8),
                        _buildSecondaryCta(context),
                      ],
                      if (unlockedLocations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildLocationsSection(),
                      ],
                    ],
                  ),
                ),
                const Positioned.fill(
                  child: PaperGrainOverlay(opacity: 0.04),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCover() {
    return HeroPaperBanner(
      height: 140,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EventCoverImage(assetPath: event.coverAssetKey),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  DauVietColors.paperBackground.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_hasCover) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: EventCoverImage(assetPath: event.coverAssetKey),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.yearLabel.trim().isNotEmpty) ...[
                SectionEyebrow(event.yearLabel.trim()),
                const SizedBox(height: 8),
              ],
              Text(
                event.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: 17,
                  color: DauVietColors.inkHeading,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildStatusSeal(event.status),
      ],
    );
  }

  Widget _buildStatusSeal(LearnerPathStatus status) {
    final Widget badge = switch (status) {
      LearnerPathStatus.completed || LearnerPathStatus.mastered =>
        const StampSealBadge.success('✓', size: 42),
      LearnerPathStatus.locked || LearnerPathStatus.notReady =>
        const StampSealBadge.outline('KHÓA', size: 42),
      LearnerPathStatus.inProgress => const StampSealBadge(
        'ĐANG',
        size: 42,
        color: DauVietColors.cinnabarRed,
      ),
      LearnerPathStatus.available => const StampSealBadge(
        'MỞ',
        size: 42,
        color: DauVietColors.cinnabarRed,
      ),
    };
    return Semantics(
      container: true,
      label: 'Trạng thái: ${status.labelVi}',
      child: badge,
    );
  }

  Widget _buildProgressRow() {
    final total = event.lessons.length;
    final done = event.completedLessonsCount;
    if (total == 0) {
      return Text(
        'Sự kiện đang được biên tập nội dung bài học.',
        style: DauVietTypography.bodySmall.copyWith(
          color: DauVietColors.inkMuted,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: DauVietColors.paperCardHi,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DauVietColors.heritageGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$done/$total bài',
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.heritageGreenDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCta(
    BuildContext context,
    LearnerPathStatus status,
    LearningPathLessonNodeDto? primary,
  ) {
    if (!event.isPlayable || status.isNotReady) {
      return _infoBox(
        icon: Icons.edit_note_rounded,
        text: 'Nội dung sự kiện đang được biên tập.',
      );
    }
    if (status.isLocked) {
      return _infoBox(
        icon: Icons.lock_rounded,
        text: 'Hoàn thành sự kiện trước để mở khóa chặng này.',
      );
    }
    if (primary == null) {
      return _infoBox(
        icon: Icons.hourglass_empty_rounded,
        text: 'Chưa có bài học khả dụng cho sự kiện này.',
      );
    }
    final label = switch (status) {
      LearnerPathStatus.inProgress => 'TIẾP TỤC HỌC',
      LearnerPathStatus.completed ||
      LearnerPathStatus.mastered => 'ÔN LẠI BÀI HỌC',
      _ => 'BẮT ĐẦU HỌC',
    };
    return DongSonButton(
      label: label,
      variant: DongSonButtonVariant.primaryCinnabar,
      icon: status.isDone ? Icons.replay_rounded : Icons.play_arrow_rounded,
      onPressed: () => onStartLesson?.call(primary),
    );
  }

  Widget _buildSecondaryCta(BuildContext context) {
    if (event.eventId.trim().isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: onOpenCampaign,
      icon: const Icon(Icons.map_outlined, size: 16),
      label: const Text('Chi tiết chiến dịch'),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: DauVietColors.heritageGreen,
        textStyle: DauVietTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLocationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ĐỊA ĐIỂM DI TÍCH ĐÃ MỞ',
          style: DauVietTypography.sectionEyebrow.copyWith(
            color: DauVietColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final loc in unlockedLocations)
              _LocationChip(
                location: loc,
                onTap: () => onOpenLocation?.call(loc),
              ),
          ],
        ),
      ],
    );
  }

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DauVietColors.paperDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DauVietColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final MapLocationDto location;
  final VoidCallback? onTap;

  const _LocationChip({required this.location, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Địa điểm ${location.title} — đã mở khóa',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (location.unlocked) ...[
                  const StampSealBadge.success('✓', size: 22),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: ClueTag(
                    location.title,
                    icon: Icons.place_rounded,
                    color: DauVietColors.jade,
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
