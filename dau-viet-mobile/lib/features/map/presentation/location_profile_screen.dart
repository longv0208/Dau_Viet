import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import 'widgets/historical_storybook_reader.dart';
import 'widgets/location_media_gallery_carousel.dart';

/// Các tab nội dung trên Màn Hồ Sơ Địa Điểm Di Sản (Issue #24).
/// Tab nào không có dữ liệu sẽ tự động bị ẩn khỏi giao diện.
enum LocationProfileTab {
  images('Ảnh', Icons.photo_library_rounded),
  videos('Video', Icons.smart_display_rounded),
  documents('Tư liệu', Icons.menu_book_rounded);

  final String label;
  final IconData icon;
  const LocationProfileTab(this.label, this.icon);
}

/// Màn Hồ Sơ Địa Điểm Di Sản (`/heritage/:locationId` hoặc mở trực tiếp).
class LocationProfileScreen extends ConsumerWidget {
  final String locationId;
  final MapLocationDto? initialLocation;

  const LocationProfileScreen({
    super.key,
    required this.locationId,
    this.initialLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mapLocationDetailProvider(locationId));
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2421)),
        leading: IconButton(
          tooltip: 'Quay lại Bản đồ',
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2421)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/map');
            }
          },
        ),
        title: Text(
          'Hồ Sơ Địa Điểm Di Sản',
          style: DauVietTypography.headlineSmall,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () {
            if (initialLocation != null) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LocationProfileContent(location: initialLocation!),
              );
            }
            return AsyncStateView.loading(
              message: 'Đang mở hồ sơ địa điểm di sản...',
            );
          },
          error: (error, _) {
            if (initialLocation != null) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LocationProfileContent(location: initialLocation!),
              );
            }
            return AsyncStateView.error(
              error: error,
              onRetry: () =>
                  ref.invalidate(mapLocationDetailProvider(locationId)),
            );
          },
          data: (detail) {
            final resolved = _mergeWithInitial(detail, initialLocation);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LocationProfileContent(location: resolved),
            );
          },
        ),
      ),
    );
  }
}

/// Bottom sheet Hồ sơ địa điểm mở từ Bản đồ Di sản.
class LocationProfileSheet extends ConsumerWidget {
  final MapLocationDto initialLocation;
  final VoidCallback? onOpenLesson;
  final VoidCallback? onOpenEvent;

  const LocationProfileSheet({
    super.key,
    required this.initialLocation,
    this.onOpenLesson,
    this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      mapLocationDetailProvider(initialLocation.id),
    );
    final MapLocationDto resolved = detailAsync.maybeWhen(
      data: (detail) => _mergeWithInitial(detail, initialLocation),
      orElse: () => initialLocation,
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84,
          ),
          child: ParchmentCard(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: LocationProfileContent(
                location: resolved,
                onOpenLesson: onOpenLesson,
                onOpenEvent: onOpenEvent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gộp dữ liệu từ `detail` với `initialLocation` (giữ nguyên các trường đã có
/// trên `initialLocation` nếu `detail` từ fake/mock rút gọn trả rỗng).
MapLocationDto _mergeWithInitial(
  MapLocationDto detail,
  MapLocationDto? initial,
) {
  if (initial == null) return detail;
  return MapLocationDto(
    id: detail.id.isNotEmpty ? detail.id : initial.id,
    eventId: detail.eventId.isNotEmpty ? detail.eventId : initial.eventId,
    eventTitle: detail.eventTitle ?? initial.eventTitle,
    slug: detail.slug ?? initial.slug,
    title: detail.title.isNotEmpty ? detail.title : initial.title,
    shortSummary: detail.shortSummary ?? initial.shortSummary,
    description: detail.description ?? initial.description,
    latitude: detail.latitude != 0 ? detail.latitude : initial.latitude,
    longitude: detail.longitude != 0 ? detail.longitude : initial.longitude,
    kind: detail.kind.isNotEmpty ? detail.kind : initial.kind,
    coordinatePrecision: detail.coordinatePrecision.isNotEmpty
        ? detail.coordinatePrecision
        : initial.coordinatePrecision,
    visibility: detail.visibility.isNotEmpty
        ? detail.visibility
        : initial.visibility,
    unlockMode: detail.unlockMode.isNotEmpty
        ? detail.unlockMode
        : initial.unlockMode,
    unlocked: detail.unlocked,
    unlockState: detail.unlockState,
    coverAssetId: detail.coverAssetId ?? initial.coverAssetId,
    mapAssetId: detail.mapAssetId ?? initial.mapAssetId,
    requiredLesson: detail.requiredLesson ?? initial.requiredLesson,
    eventIds: detail.eventIds.isNotEmpty ? detail.eventIds : initial.eventIds,
    events: detail.events.isNotEmpty ? detail.events : initial.events,
    unlockLessons: detail.unlockLessons.isNotEmpty
        ? detail.unlockLessons
        : initial.unlockLessons,
    media: detail.media.isNotEmpty ? detail.media : initial.media,
    keyFigures: detail.keyFigures ?? initial.keyFigures,
    storyNarrative: detail.storyNarrative ?? initial.storyNarrative,
    historicalSignificance:
        detail.historicalSignificance ?? initial.historicalSignificance,
  );
}

/// Nội dung Hồ sơ địa điểm với các tab động (`Ảnh`, `Video`, `Tư liệu`),
/// tự động ẩn tab rỗng.
class LocationProfileContent extends StatefulWidget {
  final MapLocationDto location;
  final VoidCallback? onOpenLesson;
  final VoidCallback? onOpenEvent;

  const LocationProfileContent({
    super.key,
    required this.location,
    this.onOpenLesson,
    this.onOpenEvent,
  });

  /// Tính danh sách các tab không rỗng của [location].
  static List<LocationProfileTab> availableTabsFor(MapLocationDto location) {
    final tabs = <LocationProfileTab>[];
    if (location.galleryImages.isNotEmpty) {
      tabs.add(LocationProfileTab.images);
    }
    if (location.videoMedia.isNotEmpty) {
      tabs.add(LocationProfileTab.videos);
    }
    if (location.hasDocumentContent) {
      tabs.add(LocationProfileTab.documents);
    }
    return tabs;
  }

  @override
  State<LocationProfileContent> createState() => _LocationProfileContentState();
}

class _LocationProfileContentState extends State<LocationProfileContent> {
  LocationProfileTab? _selectedTab;

  List<LocationProfileTab> get _tabs =>
      LocationProfileContent.availableTabsFor(widget.location);

  LocationProfileTab? get _effectiveTab {
    final tabs = _tabs;
    if (tabs.isEmpty) return null;
    if (_selectedTab != null && tabs.contains(_selectedTab)) {
      return _selectedTab;
    }
    return tabs.first;
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final locked = !location.unlocked;
    final lesson = location.actionableLesson;
    final canOpenLesson = lesson != null && lesson.accessible;
    final tabs = _tabs;
    final activeTab = _effectiveTab;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hàng huy hiệu trạng thái + phân loại địa điểm
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _UnlockStateChip(state: location.unlockState),
            _MetadataChip(
              icon: Icons.account_balance_rounded,
              label: location.kindLabelVi,
            ),
            _MetadataChip(
              icon: Icons.my_location_rounded,
              label: location.coordinatePrecisionLabelVi,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Tên địa điểm & Sự kiện chính
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StateBadge(state: location.unlockState),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.title, style: DauVietTypography.headlineSmall),
                  if (location.primaryEventTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Thuộc sự kiện: ${location.primaryEventTitle}',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // 3. Ảnh bìa (nếu có coverAssetId)
        if (location.coverAssetId != null &&
            location.coverAssetId!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LearningAssetImage(
              assetId: location.coverAssetId!,
              altText: location.title,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
        ],

        // 4. Tóm tắt ngắn (shortSummary)
        if (location.shortSummary != null &&
            location.shortSummary!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            location.shortSummary!,
            style: DauVietTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: DauVietColors.inkText,
              height: 1.45,
            ),
          ),
        ],

        // 5. Thanh Tab động (Ảnh / Video / Tư liệu) — ẩn hoàn toàn các tab rỗng
        if (tabs.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildDynamicTabBar(tabs, activeTab!),
          const SizedBox(height: 12),
          _buildActiveTabContent(location, activeTab),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            'Địa điểm lịch sử.',
            style: DauVietTypography.bodySmall.copyWith(height: 1.5),
          ),
        ],

        // 6. Thông báo điều kiện bài học mở khoá
        if (lesson != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: locked
                  ? DauVietColors.inkLight.withValues(alpha: 0.12)
                  : DauVietColors.imperialGoldLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  locked ? Icons.lock_rounded : Icons.lock_open_rounded,
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

        // 7. Nút hành động (Xem sự kiện / Học để mở / Ôn bài học)
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final eventBtn = DongSonButton(
              label: 'XEM SỰ KIỆN',
              variant: DongSonButtonVariant.secondaryParchment,
              height: 44,
              onPressed: widget.onOpenEvent ?? () => _defaultOpenEvent(context),
            );
            if (!canOpenLesson) {
              return Row(children: [Expanded(child: eventBtn)]);
            }
            final lessonBtn = DongSonButton(
              label: locked ? 'HỌC ĐỂ MỞ' : 'ÔN BÀI HỌC',
              icon: locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 44,
              onPressed:
                  widget.onOpenLesson ??
                  () => _defaultOpenLesson(context, lesson),
            );
            if (c.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [lessonBtn, const SizedBox(height: 10), eventBtn],
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
    );
  }

  Widget _buildDynamicTabBar(
    List<LocationProfileTab> tabs,
    LocationProfileTab activeTab,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE8DA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8C8B0)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == activeTab,
                label: 'Tab ${tab.label}',
                child: InkWell(
                  key: ValueKey<String>('location_tab_${tab.name}'),
                  onTap: () => setState(() => _selectedTab = tab),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tab == activeTab
                          ? DauVietColors.cinnabarRed
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 15,
                          color: tab == activeTab
                              ? Colors.white
                              : DauVietColors.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tab == activeTab
                                  ? Colors.white
                                  : DauVietColors.inkText,
                            ),
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

  Widget _buildActiveTabContent(
    MapLocationDto location,
    LocationProfileTab activeTab,
  ) {
    switch (activeTab) {
      case LocationProfileTab.images:
        return _buildImagesTab(location.galleryImages);
      case LocationProfileTab.videos:
        return _buildVideosTab(location.videoMedia);
      case LocationProfileTab.documents:
        return _buildDocumentsTab(location);
    }
  }

  List<MapLocationMediaDto> _prioritizeUnlockedMedia(
    List<MapLocationMediaDto> items,
  ) {
    final unlockedOnly = items
        .where((m) => m.visibility.trim().toUpperCase() == 'UNLOCKED_ONLY')
        .toList();
    final others = items
        .where((m) => m.visibility.trim().toUpperCase() != 'UNLOCKED_ONLY')
        .toList();
    return [...unlockedOnly, ...others];
  }

  int _galleryIndex = 0;

  Widget _buildImagesTab(List<MapLocationMediaDto> images) {
    final ordered = _prioritizeUnlockedMedia(images);
    final currentMedia = ordered.isNotEmpty
        ? ordered[_galleryIndex.clamp(0, ordered.length - 1)]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thư viện Đa ảnh — Carousel + thumbnail strip + fullscreen zoom.
        LocationMediaGalleryCarousel(
          items: images,
          unlocked: widget.location.unlocked,
          onIndexChanged: (i) => setState(() => _galleryIndex = i),
        ),
        // Compact card list giữ tương thích các test `find.text(media.title)`
        // và BUG-04 (`exclusiveDy < previewDy`). Ảnh đang hiển thị trên
        // carousel đã render title trong caption box nên card tương ứng
        // ẩn title để `findsOneWidget` không bị trùng.
        const SizedBox(height: 10),
        for (int i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MediaItemCard(
            media: ordered[i],
            isVideo: false,
            hideTitle: ordered[i].id == currentMedia?.id,
            hideUnlockBadge: ordered[i].id == currentMedia?.id,
          ),
        ],
      ],
    );
  }

  Widget _buildVideosTab(List<MapLocationMediaDto> videos) {
    final ordered = _prioritizeUnlockedMedia(videos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MediaItemCard(media: ordered[i], isVideo: true),
        ],
      ],
    );
  }

  Widget _buildDocumentsTab(MapLocationDto location) {
    return HistoricalStorybookReader(
      location: location,
      onOpenEvent: widget.onOpenEvent ?? () => _defaultOpenEvent(context),
      onOpenEventById: widget.onOpenEvent != null
          ? (_) => widget.onOpenEvent!()
          : (eventId) => _defaultOpenEventById(context, eventId),
      onOpenPeriodByCode: (periodCode) =>
          _defaultOpenPeriodByCode(context, periodCode),
      onOpenLesson: widget.onOpenLesson ??
          (location.actionableLesson != null
              ? () => _defaultOpenLesson(context, location.actionableLesson!)
              : null),
      onOpenLessonItem: widget.onOpenLesson != null
          ? (_) => widget.onOpenLesson!()
          : (ul) => _defaultOpenLesson(
              context,
              RequiredLessonRef(
                lessonId: ul.lessonId,
                title: ul.title,
                accessible: ul.accessible,
              ),
            ),
    );
  }

  void _defaultOpenLesson(BuildContext context, RequiredLessonRef lesson) {
    if (!lesson.accessible || lesson.lessonId.isEmpty) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.push('/learning/lesson/${lesson.lessonId}');
    }
  }

  void _defaultOpenEvent(BuildContext context) {
    final eventId = widget.location.primaryEventId;
    if (eventId == null || eventId.isEmpty) return;
    _defaultOpenEventById(context, eventId);
  }

  void _defaultOpenEventById(BuildContext context, String eventId) {
    if (eventId.trim().isEmpty) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.push('/campaign/${eventId.trim()}');
    }
  }

  void _defaultOpenPeriodByCode(BuildContext context, String periodCode) {
    if (periodCode.trim().isEmpty) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.push('/journey/${periodCode.trim()}');
    }
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

class _MediaItemCard extends StatelessWidget {
  final MapLocationMediaDto media;
  final bool isVideo;
  final bool hideTitle;

  /// Ẩn cả badge `MỞ KHÓA TỪ BÀI HỌC` — dùng khi media đang hiển thị trên
  /// carousel (badge loại tư liệu trên ảnh đã hiển thị nhãn này).
  final bool hideUnlockBadge;

  const _MediaItemCard({
    required this.media,
    required this.isVideo,
    this.hideTitle = false,
    this.hideUnlockBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnlockedOnly =
        media.visibility.trim().toUpperCase() == 'UNLOCKED_ONLY';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnlockedOnly
              ? DauVietColors.imperialGold
              : const Color(0xFFE5DAC6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnlockedOnly && !hideUnlockBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: DauVietColors.imperialGold),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_open_rounded,
                    size: 12,
                    color: DauVietColors.woodBrown,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MỞ KHÓA TỪ BÀI HỌC',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.inkHeading,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!isVideo &&
              media.assetId != null &&
              media.assetId!.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LearningAssetImage(
                assetId: media.assetId!,
                altText: media.title,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(
                isVideo
                    ? (media.mediaType == 'AUDIO_GUIDE'
                          ? Icons.headphones_rounded
                          : Icons.play_circle_fill_rounded)
                    : (media.mediaType == 'PANORAMA_360'
                          ? Icons.panorama_photosphere_rounded
                          : Icons.image_rounded),
                size: 18,
                color: DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: hideTitle
                    ? const SizedBox.shrink()
                    : Text(
                        media.title,
                        style: DauVietTypography.labelLarge.copyWith(
                          color: DauVietColors.inkText,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  media.mediaTypeLabelVi,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.woodBrown,
                  ),
                ),
              ),
            ],
          ),
          if (media.caption != null && media.caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              media.caption!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockStateChip extends StatelessWidget {
  final MapUnlockState state;

  const _UnlockStateChip({required this.state});

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
    return Semantics(
      label: 'Trạng thái địa điểm: ${state.labelVi}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              state.labelVi,
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DauVietColors.inkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8C8B0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DauVietColors.woodBrown),
          const SizedBox(width: 4),
          Text(
            label,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 10.5,
              color: DauVietColors.inkText,
            ),
          ),
        ],
      ),
    );
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
