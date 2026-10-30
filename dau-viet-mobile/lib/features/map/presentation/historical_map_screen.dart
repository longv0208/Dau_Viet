import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/paper_grain_overlay.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import 'journey_chapter.dart';
import 'journey_chapter_header.dart';
import 'journey_layout.dart';
import 'journey_location_list.dart';
import 'journey_map_node.dart';
import 'journey_path_painter.dart';
import 'journey_progress_legend.dart';
import 'location_profile_screen.dart';

/// Giữ enum tương thích chữ ký với `router.dart` (`/map?view=timeline`).
/// Chế độ timeline dựa trên map đã được gỡ bỏ (Issue #24) — lộ trình học
/// tập chuyển sang `/journey`.
enum ExploreViewMode { timeline, map }

/// Bản Đồ Dấu Ấn — trục ĐỊA ĐIỂM DI TÍCH (`map_locations`), bổ trợ bài học.
///
/// KHÔNG phải luồng học chính (đó là `/journey` — Issue #42). Màn này chỉ
/// hiển thị các địa điểm di tích mở khoá SAU khi người học hoàn thành sự
/// kiện/bài học gắn với chúng (`unlockRuleMode: ANY`/`ALL`):
/// - Địa điểm `LOCKED` vẫn hiển thị nếu `visibility` là `PUBLIC` /
///   `ALWAYS_VISIBLE` (ẩn `HIDDEN_UNTIL_UNLOCKED` khi đang khoá).
/// - Bấm ghim hoặc chip địa điểm → `LocationProfileSheet` (tab `Ảnh` /
///   `Video` / `Tư liệu`) — hồ sơ bổ trợ, có đường tắt sang bài học/sự
///   kiện liên kết nhưng bản đồ KHÔNG chứa cây lộ trình bài học.
class HistoricalMapScreen extends ConsumerStatefulWidget {
  final ExploreViewMode initialMode;
  final String? initialEventId;

  /// `?locationId=<id>` — mở thẳng hồ sơ một địa điểm (deep-link từ
  /// `UnlockedLocationBanner` "Xem địa điểm" sau khi hoàn thành bài học).
  final String? initialLocationId;

  const HistoricalMapScreen({
    super.key,
    this.initialMode = ExploreViewMode.map,
    this.initialEventId,
    this.initialLocationId,
  });

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  final ScrollController _scroll = ScrollController();
  int _chapterIndex = 0;
  int? _selectedIndex;
  bool _hasAppliedInitialEventId = false;
  bool _hasOpenedInitialLocation = false;
  bool _hasRedirectedTimeline = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRedirectedTimeline &&
        widget.initialMode == ExploreViewMode.timeline) {
      _hasRedirectedTimeline = true;
      final router = GoRouter.maybeOf(context);
      if (router != null && _hasJourneyRoute(router.configuration.routes)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/journey');
        });
      }
    }
  }

  bool _hasJourneyRoute(List<RouteBase> routes) {
    for (final r in routes) {
      if (r is GoRoute && (r.path == '/journey' || r.path == 'journey')) {
        return true;
      }
      if (_hasJourneyRoute(r.routes)) return true;
    }
    return false;
  }

  Future<void> _openLesson(MapLocationDto loc) async {
    final lesson = loc.actionableLesson;
    if (lesson == null || !lesson.accessible) return;
    await context.push('/learning/lesson/${lesson.lessonId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  Future<void> _openEvent(MapLocationDto loc) async {
    final targetEventId = loc.primaryEventId;
    if (targetEventId == null || targetEventId.isEmpty) return;
    await context.push('/campaign/$targetEventId');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  void _showDetail(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LocationProfileSheet(
        initialLocation: loc,
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
      backgroundColor: DauVietColors.paperBackground,
      appBar: AppBar(
        backgroundColor: DauVietColors.paperCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
        leading: IconButton(
          tooltip: 'Về Học tập',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: DauVietColors.inkText,
          ),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Bản Đồ Dấu Ấn', style: DauVietTypography.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại bản đồ',
            icon: const Icon(
              Icons.map_outlined,
              color: DauVietColors.inkMuted,
            ),
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
          data: (rawLocations) {
            // Chỉ hiển thị địa điểm đã mở khoá hoặc địa điểm có
            // visibility = PUBLIC / ALWAYS_VISIBLE (ẩn HIDDEN_UNTIL_UNLOCKED
            // khi đang khoá).
            final locations = rawLocations
                .where((l) => l.shouldDisplayOnMap)
                .toList();
            if (locations.isEmpty) {
              return AsyncStateView.empty(
                message:
                    'Chưa có địa điểm nào được mở trên bản đồ. Hoàn thành '
                    'bài học để khám phá thêm dấu ấn lịch sử.',
              );
            }
            final chapters = groupChapters(locations);

            if (!_hasAppliedInitialEventId && widget.initialEventId != null) {
              final found = chapters.indexWhere(
                (c) => c.eventId == widget.initialEventId,
              );
              if (found != -1) {
                _chapterIndex = found;
              }
              _hasAppliedInitialEventId = true;
            }

            if (_chapterIndex >= chapters.length) {
              _chapterIndex = 0;
              _selectedIndex = null;
            }
            final chapter = chapters[_chapterIndex];

            // `?locationId=` — mở thẳng hồ sơ địa điểm vừa mở khoá.
            if (!_hasOpenedInitialLocation &&
                widget.initialLocationId != null) {
              _hasOpenedInitialLocation = true;
              final id = widget.initialLocationId;
              MapLocationDto? target;
              for (final l in locations) {
                if (l.id == id) {
                  target = l;
                  break;
                }
              }
              if (target != null) {
                final loc = target;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showDetail(loc);
                });
              }
            }

            return _buildMapView(chapter, chapters, locations);
          },
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  Widget _buildMapView(
    JourneyChapter chapter,
    List<JourneyChapter> chapters,
    List<MapLocationDto> locations,
  ) {
    return Column(
      children: [
        // 1. Header Banner: Bản đồ Di sản Việt Nam
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          color: DauVietColors.paperCard,
          child: Column(
            children: [
              Text(
                'Bản đồ Di sản Lịch sử Việt Nam',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.inkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Khám phá các địa điểm di sản và hồ sơ tư liệu lịch sử',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: DauVietColors.inkMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        // 2. Thống kê tiến độ mở khoá
        JourneyProgressLegend(locations: locations),

        // 3. Header chặng sự kiện
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

        // 4. Thanh trượt chọn Chặng (nếu có nhiều chặng)
        if (chapters.length > 1) _buildJourneySelector(chapters),

        const SizedBox(height: 2),

        // 5. Banner tên chặng & số mốc toạ độ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DauVietColors.paperCardHi,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DauVietColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    size: 14,
                    color: DauVietColors.cinnabarRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bản Đồ Di Sản: ${chapter.title}',
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: DauVietColors.inkText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${chapter.locations.length} mốc toạ độ',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.cinnabarRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),

        // 6. Bản đồ cuộn dọc với các mốc địa điểm
        Expanded(child: _buildJourneyCanvas(chapter)),
        const Divider(height: 1, color: DauVietColors.outlineVariant),

        // 7. Danh sách mốc địa điểm dưới đáy
        JourneyLocationList(
          locations: chapter.locations,
          onTap: (loc) {
            final idx = chapter.locations.indexOf(loc);
            if (idx >= 0) setState(() => _selectedIndex = idx);
            _showDetail(loc);
          },
        ),
      ],
    );
  }

  Widget _buildJourneySelector(List<JourneyChapter> chapters) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chapters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final ch = chapters[idx];
          final isSelected = idx == _chapterIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _chapterIndex = idx;
                _selectedIndex = null;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scroll.hasClients) {
                  _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? DauVietColors.paperCard
                    : DauVietColors.paperBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? DauVietColors.cinnabarRed
                      : DauVietColors.outlineVariant,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: isSelected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.heritageGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chặng ${idx + 1}: ${ch.title}',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: isSelected
                          ? DauVietColors.cinnabarRed
                          : DauVietColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJourneyCanvas(JourneyChapter chapter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double h = math.max(
          JourneyLayout.canvasHeight(chapter.locations.length),
          constraints.maxHeight,
        );
        final centers = JourneyLayout.centers(chapter.locations.length, w);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: DauVietColors.outlineVariant,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    // 1. Nền bản đồ cổ chung (không hardcode theo slug sự kiện)
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/vietnam_journey_map_bg.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, _, _) =>
                            Container(color: DauVietColors.paperCardHi),
                      ),
                    ),

                    // 2. Lớp phủ giấy dó nhẹ (Design System v3)
                    const Positioned.fill(
                      child: IgnorePointer(child: PaperGrainOverlay()),
                    ),

                    // 3. Đường kết nối các mốc địa điểm
                    Positioned.fill(
                      child: CustomPaint(
                        painter: JourneyPathPainter(
                          centers: centers,
                          states: [
                            for (final l in chapter.locations) l.unlockState,
                          ],
                          selectedIndex: _selectedIndex,
                          showProceduralBackground: false,
                        ),
                      ),
                    ),

                    // 4. Các ghim địa điểm tương tác (kể cả LOCKED khi
                    //    visibility = PUBLIC)
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
            ),
          ),
        );
      },
    );
  }
}
