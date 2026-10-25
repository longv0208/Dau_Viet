import 'dart:math' as math;
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

/// Chế độ xem trong trung tâm Khám Phá Lịch Sử:
/// - [timeline]: Dòng thời gian các sự kiện sắp xếp theo niên đại (Hùng Vương -> 1954).
/// - [map]: Màn con bản đồ hành trình chi tiết của sự kiện với các mốc toạ độ.
enum ExploreViewMode { timeline, map }

/// Metadata niên đại cho sự kiện lịch sử chuẩn UI/UX Pro Max
class _EventChronologicalMeta {
  final String slugKey;
  final String era;
  final String period;
  final int startYear;
  final String subtitle;
  final String description;
  final String thumbnail;
  final String mapAsset;
  final String mapTitle;
  final String badgeText;

  const _EventChronologicalMeta({
    required this.slugKey,
    required this.era,
    required this.period,
    required this.startYear,
    required this.subtitle,
    required this.description,
    required this.thumbnail,
    required this.mapAsset,
    required this.mapTitle,
    required this.badgeText,
  });
}

final Map<String, _EventChronologicalMeta> _metaBySlugOrId = {
  'hung-vuong': const _EventChronologicalMeta(
    slugKey: 'hung-vuong',
    era: 'Thời Hùng Vương',
    period: 'Trước 258 TCN',
    startYear: -700,
    subtitle: '18 đời Vua Hùng dựng nước • Khởi dựng văn minh Văn Lang',
    description:
        'Khai hoang lập ấp, định đô tại Phong Châu, sáng tạo nền văn hóa Đông Sơn rực rỡ với trống đồng thiêng liêng.',
    thumbnail: 'assets/images/hung_king_temple.jpg',
    mapAsset: 'assets/images/map_van_lang.jpg',
    mapTitle: 'Bản Đồ Nước Văn Lang Thời Các Vua Hùng',
    badgeText: 'Bình minh lịch sử',
  ),
  'hai-ba-trung': const _EventChronologicalMeta(
    slugKey: 'hai-ba-trung',
    era: 'Bắc thuộc',
    period: 'Năm 40 – 43 SCN',
    startYear: 40,
    subtitle: 'Trưng Nữ Vương phất cờ tại Hát Môn • Đóng đô Mê Linh',
    description:
        'Cuộc khởi nghĩa quật khởi đầu tiên đánh đuổi thái thú Tô Định, giành lại 65 thành trì Lĩnh Ngoại, xưng vương dựng độc lập.',
    thumbnail: 'assets/images/landscape_hero_bg.jpg',
    mapAsset: 'assets/images/map_hai_ba_trung.jpg',
    mapTitle: 'Bản Đồ Khởi Nghĩa Hai Bà Trưng (Năm 40)',
    badgeText: 'Mê Linh quật khởi',
  ),
  'bach-dang': const _EventChronologicalMeta(
    slugKey: 'bach-dang',
    era: 'Ngô – Đinh – Tiền Lê',
    period: 'Mùa Đông 938 SCN',
    startYear: 938,
    subtitle: 'Tiền Ngô Vương Ngô Quyền & Bãi cọc ngầm bịt sắt',
    description:
        'Trận thủy chiến kinh điển lợi dụng con nước triều, tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, chấm dứt hơn 1.000 năm Bắc thuộc.',
    thumbnail: 'assets/images/bach_dang_938.jpg',
    mapAsset: 'assets/images/dv_MAP_ngoquyen_bachdang-base_v01.jpg',
    mapTitle: 'Bản Đồ Thủy Chiến Bạch Đằng Giang 938',
    badgeText: 'Chiến thắng Bạch Đằng',
  ),
  'nhu-nguyet': const _EventChronologicalMeta(
    slugKey: 'nhu-nguyet',
    era: 'Thời Lý – Trần',
    period: 'Mùa Xuân 1077 SCN',
    startYear: 1077,
    subtitle: 'Thái úy Lý Thường Kiệt & Bản thơ thần Nam Quốc Sơn Hà',
    description:
        'Phòng tuyến hiểm trở dài hàng trăm dặm trên sông Cầu chặn đứng 30 vạn quân Tống xâm lược, vang dội bản tuyên ngôn độc lập đầu tiên.',
    thumbnail: 'assets/images/vietnam_journey_map_bg.jpg',
    mapAsset: 'assets/images/map_nhu_nguyet.jpg',
    mapTitle: 'Bản Đồ Phòng Tuyến Sông Như Nguyệt 1077',
    badgeText: 'Phòng tuyến sông Cầu',
  ),
  'dien-bien': const _EventChronologicalMeta(
    slugKey: 'dien-bien',
    era: 'Hiện đại',
    period: 'Năm 1954',
    startYear: 1954,
    subtitle: 'Đại tướng Võ Nguyên Giáp & 56 ngày đêm chấn động địa cầu',
    description:
        'Chiến dịch tiến công quy mô lớn nhất kết thúc thắng lợi cuộc kháng chiến chống thực dân Pháp, buộc địch phải ký Hiệp định Genève.',
    thumbnail: 'assets/images/dau_viet_panoramic_landscape_1792867612895.jpg',
    mapAsset: 'assets/images/map_dien_bien_phu.jpg',
    mapTitle: 'Bản Đồ Chiến Dịch Điện Biên Phủ 1954',
    badgeText: 'Lừng lẫy năm châu',
  ),
};

_EventChronologicalMeta _resolveMeta(JourneyChapter chapter) {
  final idLower = chapter.eventId.toLowerCase();
  final titleLower = chapter.title.toLowerCase();

  // 1. Thời Đại Hùng Vương - Dựng Nước Văn Lang (UUID: ...0005)
  if (idLower.endsWith('000000000005') ||
      idLower.contains('hung') ||
      idLower.contains('van-lang') ||
      titleLower.contains('hùng') ||
      titleLower.contains('văn lang') ||
      titleLower.contains('phong châu') ||
      chapter.locations.any((l) {
        final t = l.title.toLowerCase();
        return t.contains('hùng') || t.contains('văn lang') || t.contains('nghĩa lĩnh');
      })) {
    return _metaBySlugOrId['hung-vuong']!;
  }

  // 2. Khởi Nghĩa Hai Bà Trưng (Năm 40) (UUID: ...0002)
  if (idLower.endsWith('000000000002') ||
      idLower.contains('trung') ||
      idLower.contains('hai-ba') ||
      titleLower.contains('trưng') ||
      titleLower.contains('mê linh') ||
      titleLower.contains('hát môn') ||
      chapter.locations.any((l) {
        final t = l.title.toLowerCase();
        return t.contains('trưng') || t.contains('mê linh') || t.contains('hát môn') || t.contains('hát');
      })) {
    return _metaBySlugOrId['hai-ba-trung']!;
  }

  // 3. Đại Chiến Bạch Đằng 938 (UUID: ...0001)
  if (idLower.endsWith('000000000001') ||
      idLower.contains('bach-dang') ||
      idLower.contains('938') ||
      titleLower.contains('bạch đằng') ||
      titleLower.contains('ngô quyền') ||
      chapter.locations.any((l) {
        final t = l.title.toLowerCase();
        return t.contains('bạch đằng') || t.contains('yên giang') || t.contains('nam triệu') || t.contains('cọc');
      })) {
    return _metaBySlugOrId['bach-dang']!;
  }

  // 4. Chiến Thắng Như Nguyệt 1077 (UUID: ...0003)
  if (idLower.endsWith('000000000003') ||
      idLower.contains('nhu-nguyet') ||
      idLower.contains('1077') ||
      titleLower.contains('như nguyệt') ||
      titleLower.contains('sông cầu') ||
      titleLower.contains('lý thường kiệt') ||
      chapter.locations.any((l) {
        final t = l.title.toLowerCase();
        return t.contains('như nguyệt') || t.contains('sông cầu') || t.contains('đền xà') || t.contains('lý thường kiệt');
      })) {
    return _metaBySlugOrId['nhu-nguyet']!;
  }

  // 5. Chiến Dịch Điện Biên Phủ 1954 (UUID: ...0004)
  if (idLower.endsWith('000000000004') ||
      idLower.contains('dien-bien') ||
      idLower.contains('1954') ||
      titleLower.contains('điện biên') ||
      titleLower.contains('mường thanh') ||
      titleLower.contains('võ nguyên giáp') ||
      chapter.locations.any((l) {
        final t = l.title.toLowerCase();
        return t.contains('đồi a1') || t.contains('de castries') || t.contains('mường thanh') || t.contains('điện biên');
      })) {
    return _metaBySlugOrId['dien-bien']!;
  }

  return _EventChronologicalMeta(
    slugKey: chapter.eventId,
    era: 'Lịch sử Việt Nam',
    period: 'Thời kỳ lịch sử',
    startYear: 1000 + chapter.index,
    subtitle: chapter.title,
    description: chapter.locations.firstOrNull?.description ?? 'Khám phá các dấu ấn lịch sử hào hùng.',
    thumbnail: 'assets/images/vietnam_journey_map_bg.jpg',
    mapAsset: 'assets/images/vietnam_journey_map_bg.jpg',
    mapTitle: 'Bản Đồ Dấu Ấn: ${chapter.title}',
    badgeText: 'Dấu ấn lịch sử',
  );
}

/// FR-35..38 — Trung tâm Khám Phá Lịch Sử Việt Nam:
/// Tích hợp Dòng Thời Gian Niên Biểu (Timeline) và Bản Đồ Dấu Ấn (Map).
/// Sự kiện và địa điểm sắp xếp nghiêm ngặt theo trình tự thời gian.
class HistoricalMapScreen extends ConsumerStatefulWidget {
  final ExploreViewMode initialMode;
  final String? initialEventId;

  const HistoricalMapScreen({
    super.key,
    this.initialMode = ExploreViewMode.map,
    this.initialEventId,
  });

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  final ScrollController _scroll = ScrollController();
  late ExploreViewMode _viewMode;
  String _selectedEra = 'Tất cả';
  int _chapterIndex = 0;
  int? _selectedIndex;
  bool _hasAppliedInitialEventId = false;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialMode;
  }

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

  void _selectEventAndOpenMap(int chapterIndex) {
    setState(() {
      _chapterIndex = chapterIndex;
      _selectedIndex = null;
      _viewMode = ExploreViewMode.map;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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

            // Bản sao sắp xếp theo trình tự thời gian cho Dòng thời gian
            final timelineChapters = List<JourneyChapter>.from(chapters);
            timelineChapters.sort((a, b) {
              final metaA = _resolveMeta(a);
              final metaB = _resolveMeta(b);
              return metaA.startYear.compareTo(metaB.startYear);
            });

            // Áp dụng initialEventId nếu có và chưa áp dụng
            if (!_hasAppliedInitialEventId && widget.initialEventId != null) {
              final found = chapters.indexWhere((c) => c.eventId == widget.initialEventId);
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

            return Column(
              children: [
                // Bộ chuyển đổi chế độ xem: Dòng Thời Gian <-> Bản Đồ Dấu Ấn
                _buildViewModeSwitcher(),

                // Nội dung theo chế độ xem đã chọn
                Expanded(
                  child: _viewMode == ExploreViewMode.timeline
                      ? _buildTimelineView(timelineChapters, chapters)
                      : _buildMapView(chapter, chapters, locations),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  /// Bộ chuyển đổi chế độ xem Dòng thời gian / Bản đồ chuẩn UI/UX Pro Max
  Widget _buildViewModeSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE8DA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8C8B0), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = ExploreViewMode.timeline),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == ExploreViewMode.timeline
                      ? DauVietColors.cinnabarRed
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _viewMode == ExploreViewMode.timeline
                      ? [
                          BoxShadow(
                            color: DauVietColors.cinnabarRed.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        size: 15,
                        color: _viewMode == ExploreViewMode.timeline
                            ? Colors.white
                            : DauVietColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Dòng thời gian',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: _viewMode == ExploreViewMode.timeline
                              ? Colors.white
                              : DauVietColors.inkText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = ExploreViewMode.map),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == ExploreViewMode.map
                      ? DauVietColors.cinnabarRed
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _viewMode == ExploreViewMode.map
                      ? [
                          BoxShadow(
                            color: DauVietColors.cinnabarRed.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 15,
                        color: _viewMode == ExploreViewMode.map
                            ? Colors.white
                            : DauVietColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bản đồ dấu ấn',
                        style: DauVietTypography.labelSmall.copyWith(
                              color: _viewMode == ExploreViewMode.map
                                  ? Colors.white
                                  : DauVietColors.inkText,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// GIAO DIỆN 1: Dòng Thời Gian Các Sự Kiện Lịch Sử (UI/UX Pro Max)
  Widget _buildTimelineView(List<JourneyChapter> timelineChapters, List<JourneyChapter> allChapters) {
    final eras = <String>{
      'Tất cả',
      for (final ch in timelineChapters) _resolveMeta(ch).era,
    }.toList();

    final filteredChapters = _selectedEra == 'Tất cả'
        ? timelineChapters
        : timelineChapters.where((ch) => _resolveMeta(ch).era == _selectedEra).toList();

    return Column(
      children: [
        // Banner tiêu đề dòng thời gian
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          color: const Color(0xFFFBF8F1),
          child: Column(
            children: [
              Text(
                'Dòng Thời Gian Lịch Sử',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Chọn sự kiện để mở bản đồ hành trình và các mốc toạ độ chiến trường',
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

        // Bộ lọc thời kỳ ngang
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: eras.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final era = eras[idx];
              final isSelected = era == _selectedEra;
              return ChoiceChip(
                label: Text(
                  era,
                  style: DauVietTypography.labelSmall.copyWith(
                    color: isSelected ? Colors.white : DauVietColors.inkText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                selected: isSelected,
                selectedColor: DauVietColors.cinnabarRed,
                backgroundColor: const Color(0xFFF3ECE0),
                side: BorderSide(
                  color: isSelected
                      ? DauVietColors.cinnabarRed
                      : const Color(0xFFD8C8B0),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedEra = era);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        // Trục thời gian dọc các sự kiện lịch sử sắp xếp theo thời gian
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            itemCount: filteredChapters.length,
            itemBuilder: (context, index) {
              final ch = filteredChapters[index];
              final meta = _resolveMeta(ch);
              final isLast = index == filteredChapters.length - 1;
              final foundIdx = allChapters.indexOf(ch);
              final originalIndex = foundIdx != -1 ? foundIdx : index;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột trục son + điểm mốc
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFFDF9),
                              border: Border.all(
                                color: DauVietColors.imperialGold,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: DauVietColors.imperialGold.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFA51F18),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2.5,
                                color: DauVietColors.imperialGold.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Thẻ sự kiện lịch sử chuẩn UI Pro Max
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => _selectEventAndOpenMap(originalIndex),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5DAC6),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B4513).withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hàng huy hiệu thời kỳ & niên đại
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: DauVietColors.cinnabarRed,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        meta.era,
                                        style: DauVietTypography.labelSmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5EEDB),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFD8C8B0)),
                                      ),
                                      child: Text(
                                        meta.period,
                                        style: DauVietTypography.labelSmall.copyWith(
                                          color: const Color(0xFFB45309),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Color(0xFFB45309),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Thông tin & Ảnh thumbnail
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: Image.asset(
                                          meta.thumbnail,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFF3ECE0),
                                            child: const Icon(
                                              Icons.account_balance_rounded,
                                              color: DauVietColors.heritageGreen,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ch.title,
                                            style: DauVietTypography.headlineMedium.copyWith(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF1F2421),
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            meta.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: DauVietTypography.bodySmall.copyWith(
                                              fontSize: 10.5,
                                              color: const Color(0xFF5E6963),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meta.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: DauVietTypography.bodySmall.copyWith(
                                              fontSize: 11,
                                              color: const Color(0xFF3D4842),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Color(0xFFEDE4CE)),
                                const SizedBox(height: 8),

                                // Chân thẻ: số địa điểm và nút mở bản đồ
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBF8F1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE5DAC6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 13,
                                            color: Color(0xFFC2410C),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${ch.locations.length} mốc toạ độ chiến trường',
                                            style: DauVietTypography.bodySmall.copyWith(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1F2421),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Khám phá Bản Đồ ›',
                                      style: DauVietTypography.labelSmall.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFA51F18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// GIAO DIỆN 2: Màn Con Khám Phá Bản Đồ Của Sự Kiện (UI/UX Pro Max)
  /// Mỗi hành trình lịch sử là một nền bản đồ chiến dịch/phong thổ chuyên biệt,
  /// hiển thị rõ ràng, chân thực không bị che khuất bởi các thẻ giai đoạn.
  Widget _buildMapView(
    JourneyChapter chapter,
    List<JourneyChapter> chapters,
    List<MapLocationDto> locations,
  ) {
    final meta = _resolveMeta(chapter);
    return Column(
      children: [
        // 1. Header Banner: Hành trình lịch sử Việt Nam
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          color: const Color(0xFFFBF8F1),
          child: Column(
            children: [
              Text(
                'Hành trình lịch sử Việt Nam',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Khám phá những giai đoạn hào hùng của dân tộc qua các bài học thú vị',
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

        // 2. Thống kê tiến độ mở khoá
        JourneyProgressLegend(locations: locations),

        // 3. Nút quay lại Dòng Thời Gian
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _viewMode = ExploreViewMode.timeline),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3ECE0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8C8B0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF1F2421)),
                      const SizedBox(width: 4),
                      Text(
                        'Về Dòng Thời Gian',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2421),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Header chặng sự kiện
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

        // 5. Thanh trượt chọn Chặng Hành Trình Lịch Sử (UI/UX Pro Max)
        // Hiển thị trực quan từng chặng với thumbnail bản đồ riêng biệt
        if (chapters.length > 1) _buildJourneySelector(chapters),

        const SizedBox(height: 2),

        // 6. Banner tên bản đồ chuyên biệt của sự kiện (Mỗi hành trình là 1 bản đồ khác nhau)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
                  const Icon(Icons.map_rounded, size: 14, color: DauVietColors.cinnabarRed),
                  const SizedBox(width: 6),
                  Text(
                    meta.mapTitle,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: const Color(0xFF1F2421),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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

        // 7. Bản đồ non nước cuộn dọc với các mốc toạ độ sắp xếp theo trình tự thời gian
        Expanded(child: _buildJourneyCanvas(chapter, meta)),
        const Divider(height: 1, color: DauVietColors.outlineVariant),

        // 8. Danh sách mốc toạ độ dưới đáy
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

  /// Thanh trượt ngang chuyển nhanh giữa các bản đồ hành trình lịch sử
  Widget _buildJourneySelector(List<JourneyChapter> chapters) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chapters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final ch = chapters[idx];
          final meta = _resolveMeta(ch);
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFBF8F1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? DauVietColors.cinnabarRed : const Color(0xFFD8C8B0),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: DauVietColors.cinnabarRed.withValues(alpha: 0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      meta.mapAsset,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 38,
                        height: 38,
                        color: const Color(0xFFF3ECE0),
                        child: const Icon(Icons.map_rounded, size: 20, color: DauVietColors.heritageGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Chặng ${idx + 1}: ${meta.badgeText}',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: isSelected ? DauVietColors.cinnabarRed : const Color(0xFF1F2421),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta.period,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 9.5,
                          color: const Color(0xFF75807A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Canvas cuộn dọc chứa painter nền + đường + node — cao thích ứng
  /// theo số địa điểm trong chặng. Nền bản đồ chiến dịch sắc nét, không bị che khuất.
  Widget _buildJourneyCanvas(JourneyChapter chapter, _EventChronologicalMeta meta) {
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
                    // 1. Tranh bản đồ chuyên biệt của hành trình lịch sử (Mỗi sự kiện 1 ảnh map riêng)
                    Positioned.fill(
                      child: Image.asset(
                        meta.mapAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/vietnam_journey_map_bg.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),

                    // 2. Viền mờ vignette góc cạnh giữ phong cách cổ kính giấy dó, KHÔNG che mặt tranh
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

                    // 3. Đường uốn lượn hành trình kết nối các mốc toạ độ
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

                    // 4. Các Node địa điểm tương tác của chặng
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
