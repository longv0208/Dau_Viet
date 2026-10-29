import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import 'event_action_sheet.dart';
import 'journey_layout.dart';
import 'journey_path_painter.dart';
import 'location_profile_screen.dart';
import 'path_event_node.dart';

/// Giữ enum tương thích chữ ký với `router.dart` (`/map?view=timeline`).
enum ExploreViewMode { timeline, map }

/// Một "chặng" trên Bản Đồ Dấu Ấn = một `PERIOD` trong lộ trình học.
/// `eraTitle` phục vụ header (nhóm `ERA` cha).
class _PathChapter {
  final int index;
  final LearningPathChapterDto period;
  final String? eraTitle;

  const _PathChapter({
    required this.index,
    required this.period,
    required this.eraTitle,
  });

  String get title => period.title;
}

/// Bản Đồ Dấu Ấn — trục học chính (Issue #36).
///
/// - Đường đi lấy từ `GET /api/v1/me/learning-path` (PERIOD → EVENT → LESSON),
///   KHÔNG từ `map_locations` — bài học không gắn di tích vẫn hiện đầy đủ.
/// - Chạm nút sự kiện → [EventActionSheet] → "BẮT ĐẦU HỌC"/"TIẾP TỤC HỌC"
///   đi thẳng `/learning/lesson/:lessonId` (AC-1).
/// - Địa điểm di tích là LỚP PHỤ: ghim vệ tinh cạnh node sự kiện chỉ hiện
///   khi đã `unlocked` (mở sau khi học — AC-3) → `LocationProfileSheet`.
/// - Đổi chặng → `touchPeriod(periodCode)` để server cập nhật con trỏ.
class HistoricalMapScreen extends ConsumerStatefulWidget {
  final ExploreViewMode initialMode;

  /// `?period=<code>` — chọn sẵn chặng thời kỳ (deep-link từ
  /// `/journey/:periodCode` redirect hoặc dashboard CTA).
  final String? initialPeriodCode;

  /// Deprecated: `?eventId=<id>` giữ tương thích ngược — resolve period
  /// chứa sự kiện từ learning path nếu có.
  final String? initialEventId;

  const HistoricalMapScreen({
    super.key,
    this.initialMode = ExploreViewMode.map,
    this.initialPeriodCode,
    this.initialEventId,
  });

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  final ScrollController _scroll = ScrollController();
  int _chapterIndex = 0;
  int? _selectedIndex;
  bool _hasAppliedInitial = false;
  String? _touchedCode;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
        // Không chặn hiển thị bản đồ nếu mạng lỗi khi gọi touch.
      }
    });
  }

  /// Chọn chặng ban đầu theo thứ tự ưu tiên:
  /// `?period=` → `?eventId=` (resolve period chứa) → `lastPeriodCode` →
  /// `currentByPeriod` bất kỳ → chặng đầu tiên.
  int _resolveInitialChapterIndex(LearningPathDto path, List<_PathChapter> chapters) {
    String? wantedCode = widget.initialPeriodCode;
    if ((wantedCode == null || wantedCode.isEmpty) &&
        widget.initialEventId != null &&
        widget.initialEventId!.isNotEmpty) {
      final ev = path.findEventById(widget.initialEventId);
      if (ev != null) {
        final owner = chapters.indexWhere(
          (c) => path
              .eventsOfPeriod(c.period.chapterId)
              .any((e) => e.eventNodeId == ev.eventNodeId),
        );
        if (owner >= 0) return owner;
      }
    }
    wantedCode ??= path.lastPeriodCode;
    if (wantedCode != null && wantedCode.isNotEmpty) {
      final idx = chapters.indexWhere((c) => c.period.code == wantedCode);
      if (idx >= 0) return idx;
    }
    final effCurrent = path.effectiveCurrent;
    if (effCurrent != null) {
      final idx = chapters.indexWhere(
        (c) => c.period.chapterId == effCurrent.chapterId,
      );
      if (idx >= 0) return idx;
    }
    return 0;
  }

  Future<void> _openLesson(LearningPathLessonNodeDto lesson) async {
    if (lesson.lessonId.trim().isEmpty) return;
    await context.push('/learning/lesson/${lesson.lessonId}');
    if (mounted) {
      ref.invalidate(learningPathProvider);
      ref.invalidate(mapLocationsProvider);
    }
  }

  void _showEventSheet(LearningPathEventNodeDto event) {
    final unlockedLocs = ref
        .read(mapLocationsByEventProvider(event.eventId))
        .maybeWhen(
          data: (locs) => locs.where((l) => l.unlocked).toList(),
          orElse: () => const <MapLocationDto>[],
        );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EventActionSheet(
        event: event,
        unlockedLocations: unlockedLocs,
        onStartLesson: (lesson) {
          Navigator.of(ctx).pop();
          _openLesson(lesson);
        },
        onOpenCampaign: () {
          Navigator.of(ctx).pop();
          if (event.eventId.trim().isNotEmpty) {
            context.push('/campaign/${event.eventId}');
          }
        },
        onOpenLocation: (loc) {
          Navigator.of(ctx).pop();
          _showLocationSheet(loc);
        },
      ),
    );
  }

  void _showLocationSheet(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LocationProfileSheet(
        initialLocation: loc,
        onOpenLesson: () {
          Navigator.of(ctx).pop();
          final lesson = loc.actionableLesson;
          if (lesson != null && lesson.accessible) {
            context.push('/learning/lesson/${lesson.lessonId}').then((_) {
              if (mounted) {
                ref.invalidate(learningPathProvider);
                ref.invalidate(mapLocationsProvider);
              }
            });
          }
        },
        onOpenEvent: () {
          Navigator.of(ctx).pop();
          final targetEventId = loc.primaryEventId;
          if (targetEventId != null && targetEventId.isNotEmpty) {
            context.push('/campaign/$targetEventId');
          }
        },
      ),
    );
  }

  void _goChapter(int delta, int total, List<_PathChapter> chapters) {
    final next = (_chapterIndex + delta).clamp(0, total - 1);
    if (next == _chapterIndex) return;
    setState(() {
      _chapterIndex = next;
      _selectedIndex = null;
    });
    _scheduleTouch(chapters[next].period.code);
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
  Widget build(BuildContext context) {
    final asyncPath = ref.watch(learningPathProvider);
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2421)),
        leading: IconButton(
          tooltip: 'Về Học tập',
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2421)),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Bản Đồ Dấu Ấn', style: DauVietTypography.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại bản đồ',
            icon: const Icon(Icons.map_outlined, color: Color(0xFF5E6963)),
            onPressed: () {
              ref.invalidate(learningPathProvider);
              ref.invalidate(mapLocationsProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: asyncPath.when(
          loading: () =>
              AsyncStateView.loading(message: 'Đang mở tấm bản đồ cổ...'),
          error: (e, _) => AsyncStateView.error(
            error: e,
            onRetry: () => ref.read(learningPathProvider.notifier).refresh(),
          ),
          data: (path) => _buildPathBody(path),
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  Widget _buildPathBody(LearningPathDto path) {
    final chapters = _buildChapters(path);
    if (chapters.isEmpty) {
      return AsyncStateView.empty(
        message: 'Lộ trình học đang được biên soạn. Quay lại sau nhé.',
      );
    }

    if (!_hasAppliedInitial) {
      _chapterIndex = _resolveInitialChapterIndex(path, chapters);
      _hasAppliedInitial = true;
      _scheduleTouch(chapters[_chapterIndex].period.code);
    }
    if (_chapterIndex >= chapters.length) {
      _chapterIndex = 0;
      _selectedIndex = null;
    }
    final chapter = chapters[_chapterIndex];
    final events = path.eventsOfPeriod(chapter.period.chapterId);

    // Di tích đã mở của chặng (lớp phụ) — strip đáy màn.
    final unlockedLocs = ref
        .watch(mapLocationsByPeriodProvider(chapter.period.code))
        .maybeWhen(
          data: (locs) => locs.where((l) => l.unlocked).toList(),
          orElse: () => const <MapLocationDto>[],
        );

    return Column(
      children: [
        // 1. Header banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          color: const Color(0xFFFBF8F1),
          child: Column(
            children: [
              Text(
                'Bản Đồ Dấu Ấn Việt Nam',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Lướt trên bản đồ, chạm sự kiện để học trực tiếp',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF5E6963),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        // 2. Legend trạng thái lộ trình
        _buildLegend(path),

        // 3. Header chặng + prev/next
        _buildChapterHeader(chapter, chapters),

        // 4. Thanh trượt chọn chặng
        if (chapters.length > 1) _buildChapterSelector(chapters),

        const SizedBox(height: 2),

        // 5. Banner tên thời kỳ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3ECE0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD8C8B0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    size: 14,
                    color: DauVietColors.cinnabarRed,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      [
                        if (chapter.eraTitle != null) chapter.eraTitle,
                        chapter.title,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: const Color(0xFF1F2421),
                      ),
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
                      '${events.length} sự kiện',
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

        // 6. Canvas hành trình
        Expanded(child: _buildJourneyCanvas(events)),

        // 7. Di tích đã mở của chặng (lớp phụ)
        if (unlockedLocs.isNotEmpty) ...[
          const Divider(height: 1, color: DauVietColors.outlineVariant),
          _buildUnlockedStrip(unlockedLocs),
        ],
      ],
    );
  }

  List<_PathChapter> _buildChapters(LearningPathDto path) {
    final result = <_PathChapter>[];
    for (final group in path.eraGroups) {
      for (final period in group.periods) {
        result.add(
          _PathChapter(
            index: result.length,
            period: period,
            eraTitle: group.era?.title,
          ),
        );
      }
    }
    return result;
  }

  Widget _buildLegend(LearningPathDto path) {
    final summary = path.summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Wrap(
            spacing: 16,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _LegendDot(
                color: DauVietColors.imperialGold,
                label: 'Đã hoàn thành',
              ),
              _LegendDot(color: DauVietColors.natureGreen, label: 'Sẵn sàng'),
              _LegendDot(color: DauVietColors.inkLight, label: 'Đang khóa'),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Đã học ${summary.completedLessons} / ${summary.totalRequiredLessons} '
            'bài bắt buộc — Bản đồ hành trình minh họa, không thể hiện tuyến đường thực tế',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterHeader(_PathChapter chapter, List<_PathChapter> chapters) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          _navButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Chặng trước',
            onPressed: _chapterIndex > 0
                ? () => _goChapter(-1, chapters.length, chapters)
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.labelLarge.copyWith(
                    color: DauVietColors.inkText,
                  ),
                ),
                Text(
                  'Chặng ${chapter.index + 1} / ${chapters.length} • Thời kỳ',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          _navButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Chặng sau',
            onPressed: _chapterIndex < chapters.length - 1
                ? () => _goChapter(1, chapters.length, chapters)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 26),
      color: DauVietColors.woodBrown,
      disabledColor: DauVietColors.outlineVariant,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  Widget _buildChapterSelector(List<_PathChapter> chapters) {
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
              _scheduleTouch(ch.period.code);
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
                color: isSelected ? const Color(0xFFFBF8F1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? DauVietColors.cinnabarRed
                      : const Color(0xFFD8C8B0),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_rounded,
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
                          : const Color(0xFF1F2421),
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

  Widget _buildJourneyCanvas(List<LearningPathEventNodeDto> events) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double h = math.max(
          JourneyLayout.canvasHeight(events.length),
          constraints.maxHeight,
        );
        final centers = JourneyLayout.centers(events.length, w);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8C8B0), width: 1.5),
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
                    // 1. Nền bản đồ cổ
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/vietnam_journey_map_bg.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, _, _) =>
                            Container(color: const Color(0xFFF3ECE0)),
                      ),
                    ),
                    // 2. Lớp phủ giấy dó nhẹ
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFBF8F1).withValues(alpha: 0.06),
                              Colors.transparent,
                              Colors.transparent,
                              const Color(0xFFFBF8F1).withValues(alpha: 0.10),
                            ],
                            stops: const [0.0, 0.05, 0.95, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 3. Đường nối giữa các nút sự kiện
                    Positioned.fill(
                      child: CustomPaint(
                        painter: JourneyPathPainter(
                          centers: centers,
                          states: [
                            for (final e in events)
                              PathEventNode.toUnlockState(e.status),
                          ],
                          selectedIndex: _selectedIndex,
                          showProceduralBackground: false,
                        ),
                      ),
                    ),
                    // 4. Các nút sự kiện + ghim di tích vệ tinh
                    for (int i = 0; i < events.length; i++) ...[
                      Positioned(
                        left: centers[i].dx - 64,
                        top: centers[i].dy - 28,
                        child: PathEventNode(
                          event: events[i],
                          selected: _selectedIndex == i,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            _showEventSheet(events[i]);
                          },
                        ),
                      ),
                      // Ghim vệ tinh: địa điểm di tích đã mở của sự kiện.
                      _SatellitePins(
                        key: ValueKey('pins-${events[i].eventNodeId}'),
                        eventId: events[i].eventId,
                        center: centers[i],
                        onTapLocation: _showLocationSheet,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlockedStrip(List<MapLocationDto> locations) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final loc = locations[i];
          return InkWell(
            onTap: () => _showLocationSheet(loc),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGoldLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DauVietColors.imperialGold.withValues(alpha: 0.9),
                  width: 1.1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 15,
                    color: DauVietColors.woodBrown,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      loc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontSize: 11,
                        color: DauVietColors.inkText,
                      ),
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
}

/// Ghim di tích vệ tinh cạnh nút sự kiện (Issue #36 — Phase 3).
/// Chỉ render địa điểm `unlocked` liên kết [eventId]; địa điểm đang khóa
/// `HIDDEN_UNTIL_UNLOCKED` không hiện (không làm gián đoạn luồng học).
class _SatellitePins extends ConsumerWidget {
  final String eventId;
  final Offset center;
  final void Function(MapLocationDto location) onTapLocation;

  const _SatellitePins({
    super.key,
    required this.eventId,
    required this.center,
    required this.onTapLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId.trim().isEmpty) return const SizedBox.shrink();
    final async = ref.watch(mapLocationsByEventProvider(eventId));
    return async.maybeWhen(
      data: (locs) {
        final unlocked = locs.where((l) => l.unlocked).toList();
        if (unlocked.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            for (int i = 0; i < unlocked.length; i++)
              Positioned(
                left: center.dx + 30 + (i * 24.0),
                top: center.dy - 18,
                child: _SatellitePin(
                  location: unlocked[i],
                  onTap: () => onTapLocation(unlocked[i]),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SatellitePin extends StatelessWidget {
  final MapLocationDto location;
  final VoidCallback onTap;

  const _SatellitePin({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Địa điểm ${location.title} — đã mở khóa',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: location.title,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.imperialGoldLight,
              border: Border.all(
                color: DauVietColors.imperialGold,
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: const Icon(
              Icons.place_rounded,
              size: 16,
              color: DauVietColors.woodBrown,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: DauVietTypography.labelSmall.copyWith(
            fontSize: 10,
            color: DauVietColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
