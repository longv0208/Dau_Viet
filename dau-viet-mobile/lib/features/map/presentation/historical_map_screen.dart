import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/parchment_card.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import 'journey_chapter.dart';
import 'journey_chapter_header.dart';
import 'journey_layout.dart';
import 'journey_location_list.dart';
import 'journey_map_node.dart';
import 'journey_path_painter.dart';
import 'journey_progress_legend.dart';

/// FR-35..38 — Bản đồ hành trình minh họa: nhóm địa điểm theo eventId
/// thành "chặng", vẽ đường uốn zigzag nối node theo thứ tự server trả.
/// UNLOCKED vàng đặc / AVAILABLE xanh-son / LOCKED xám — server tính,
/// client KHÔNG tự mở khoá. Back → `/dashboard` tường minh (route
/// top-level không có parent để pop).
class HistoricalMapScreen extends ConsumerStatefulWidget {
  const HistoricalMapScreen({super.key});

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  final ScrollController _scroll = ScrollController();
  int _chapterIndex = 0;
  int? _selectedIndex;

  /// Sau khi hoàn thành bài học và quay lại, refresh trạng thái mở khoá.
  /// (Hoàn thành thật cũng invalidate trong lesson_player, đây là lớp
  /// dự phòng khi quay lại từ bất kỳ điều hướng nào.)
  Future<void> _openLesson(MapLocationDto loc) async {
    final lesson = loc.requiredLesson;
    if (lesson == null || !lesson.accessible) return;
    await context.push('/learning/lesson/${lesson.lessonId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  Future<void> _openEvent(MapLocationDto loc) async {
    await context.push('/campaign/${loc.eventId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  void _showDetail(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LocationDetailSheet(
        location: loc,
        onOpenLesson: () {
          Navigator.of(ctx).pop();
          _openLesson(loc);
        },
        onOpenEvent: () {
          Navigator.of(ctx).pop();
          _openEvent(loc);
        },
      ),
    );
  }

  void _goChapter(int delta, int total) {
    final next = (_chapterIndex + delta).clamp(0, total - 1);
    if (next == _chapterIndex) return;
    setState(() {
      _chapterIndex = next;
      _selectedIndex = null;
    });
    // Cuộn về đầu canvas khi đổi chặng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapLocationsProvider);
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: DauVietColors.parchmentSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
        leading: IconButton(
          tooltip: 'Về Học tập',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Bản Đồ Dấu Ấn', style: DauVietTypography.headlineSmall),
        actions: [
          IconButton(
            tooltip: 'Tải lại bản đồ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(mapLocationsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              AsyncStateView.loading(message: 'Đang mở tấm bản đồ cổ...'),
          error: (e, _) => AsyncStateView.error(
            error: e,
            onRetry: () => ref.invalidate(mapLocationsProvider),
          ),
          data: (locations) {
            if (locations.isEmpty) {
              return AsyncStateView.empty(
                message:
                    'Chưa có địa điểm nào được mở trên bản đồ. Hoàn thành '
                    'bài học để khám phá thêm dấu ấn lịch sử.',
              );
            }
            final chapters = groupChapters(locations);
            // Reset chapter khi dataset đổi (refresh/remove).
            if (_chapterIndex >= chapters.length) {
              _chapterIndex = 0;
              _selectedIndex = null;
            }
            final chapter = chapters[_chapterIndex];
            return Column(
              children: [
                JourneyProgressLegend(locations: locations),
                JourneyChapterHeader(
                  chapter: chapter,
                  totalChapters: chapters.length,
                  onPrev: _chapterIndex > 0
                      ? () => _goChapter(-1, chapters.length)
                      : null,
                  onNext: _chapterIndex < chapters.length - 1
                      ? () => _goChapter(1, chapters.length)
                      : null,
                ),
                const SizedBox(height: 2),
                Expanded(child: _buildJourneyCanvas(chapter)),
                const Divider(height: 1, color: DauVietColors.outlineVariant),
                JourneyLocationList(
                  locations: chapter.locations,
                  onTap: _showDetail,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  /// Canvas cuộn dọc chứa painter nền + đường + node — cao thích ứng
  /// theo số địa điểm trong chặng (không còn khung trống cố định).
  Widget _buildJourneyCanvas(JourneyChapter chapter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = JourneyLayout.canvasHeight(chapter.locations.length);
        final centers = JourneyLayout.centers(chapter.locations.length, w);
        return SingleChildScrollView(
          controller: _scroll,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: JourneyPathPainter(
                      centers: centers,
                      states: [
                        for (final l in chapter.locations) l.unlockState,
                      ],
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
                for (int i = 0; i < chapter.locations.length; i++)
                  Positioned(
                    left: centers[i].dx - 64,
                    top: centers[i].dy - 28,
                    child: JourneyMapNode(
                      location: chapter.locations[i],
                      selected: _selectedIndex == i,
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        _showDetail(chapter.locations[i]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationDetailSheet extends StatelessWidget {
  final MapLocationDto location;
  final VoidCallback onOpenLesson;
  final VoidCallback onOpenEvent;

  const _LocationDetailSheet({
    required this.location,
    required this.onOpenLesson,
    required this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final locked = location.unlockState == MapUnlockState.locked;
    final lesson = location.requiredLesson;
    // CTA bài học chỉ hiện khi có link VÀ lesson vẫn mở được cho learner
    // (server cờ accessible=false khi lesson bị draft/archived sau đó).
    final canOpenLesson = lesson != null && lesson.accessible;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: ParchmentCard(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StateBadge(state: location.unlockState),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          location.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: DauVietTypography.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (location.eventTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Thuộc sự kiện: ${location.eventTitle}',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    location.description ?? 'Địa điểm lịch sử.',
                    style: DauVietTypography.bodySmall.copyWith(height: 1.5),
                  ),
                  if (lesson != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: locked
                            ? DauVietColors.inkLight.withValues(alpha: 0.12)
                            : DauVietColors.imperialGoldLight.withValues(
                                alpha: 0.35,
                              ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 16,
                            color: locked
                                ? DauVietColors.inkMuted
                                : DauVietColors.woodBrown,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lessonBlurb(locked, lesson),
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 12,
                                color: DauVietColors.inkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final eventBtn = DongSonButton(
                        label: 'XEM SỰ KIỆN',
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 44,
                        onPressed: onOpenEvent,
                      );
                      if (!canOpenLesson) {
                        return Row(children: [Expanded(child: eventBtn)]);
                      }
                      final lessonBtn = DongSonButton(
                        label: locked ? 'HỌC ĐỂ MỞ' : 'ÔN BÀI HỌC',
                        icon: locked
                            ? Icons.lock_rounded
                            : Icons.play_arrow_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 44,
                        onPressed: onOpenLesson,
                      );
                      if (c.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            lessonBtn,
                            const SizedBox(height: 10),
                            eventBtn,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: eventBtn),
                          const SizedBox(width: 12),
                          Expanded(child: lessonBtn),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _lessonBlurb(bool locked, RequiredLessonRef lesson) {
    if (locked) {
      return lesson.accessible
          ? 'Hoàn thành bài học "${lesson.title}" để mở khoá'
          : 'Địa điểm này yêu cầu bài học "${lesson.title}" — bài học '
                'đang được cập nhật, quay lại sau';
    }
    return 'Đã mở qua bài học "${lesson.title}"';
  }
}

class _StateBadge extends StatelessWidget {
  final MapUnlockState state;
  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      MapUnlockState.unlocked => (
        DauVietColors.imperialGold,
        Icons.lock_open_rounded,
      ),
      MapUnlockState.available => (
        DauVietColors.natureGreen,
        Icons.explore_rounded,
      ),
      MapUnlockState.locked => (DauVietColors.inkLight, Icons.lock_rounded),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.4),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
