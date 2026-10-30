import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../learning/presentation/renderers/learning_asset_image.dart';
import '../../data/map_location_dto.dart';

/// Thư viện Đa ảnh — Carousel `PageView` + Thumbnail Strip + Nguồn sử liệu.
/// - Badge trái: loại tư liệu + `MỞ KHÓA TỪ BÀI HỌC` nếu `UNLOCKED_ONLY`.
/// - Badge phải: bộ đếm `i/N` (`Key('gallery-counter-badge')`) và nút
///   phóng to (`Key('gallery-fullscreen-btn')`).
/// - Hộp chú thích + nguồn sử liệu (`Nguồn: ...`) ngay dưới khung ảnh.
/// - Dải thumbnail (`Key('gallery-thumbnail-strip')`, item
///   `Key('gallery-thumb-$i')`) cho phép chuyển nhanh trang.
/// - `UNLOCKED_ONLY` được xếp trước `PUBLIC_PREVIEW` khi `unlocked`.
class LocationMediaGalleryCarousel extends StatefulWidget {
  final List<MapLocationMediaDto> items;
  final bool unlocked;
  final double height;

  /// Báo index ảnh đang hiển thị (dùng để phối hợp với danh sách compact
  /// bên dưới, tránh render trùng `media.title` trong cùng cây widget).
  final ValueChanged<int>? onIndexChanged;

  const LocationMediaGalleryCarousel({
    super.key,
    required this.items,
    required this.unlocked,
    this.height = 165,
    this.onIndexChanged,
  });

  /// Sắp xếp `UNLOCKED_ONLY` lên trước khi địa điểm đã mở khóa.
  static List<MapLocationMediaDto> orderedForDisplay(
    List<MapLocationMediaDto> items,
    bool unlocked,
  ) {
    if (!unlocked) return items;
    final exclusive = items.where((m) => m.isUnlockedOnly).toList();
    final preview = items.where((m) => !m.isUnlockedOnly).toList();
    return [...exclusive, ...preview];
  }

  @override
  State<LocationMediaGalleryCarousel> createState() =>
      _LocationMediaGalleryCarouselState();
}

class _LocationMediaGalleryCarouselState
    extends State<LocationMediaGalleryCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  List<MapLocationMediaDto> get _ordered => LocationMediaGalleryCarousel
      .orderedForDisplay(widget.items, widget.unlocked);

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final items = _ordered;
    if (items.isEmpty) return;
    final target = index.clamp(0, items.length - 1);
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    if (_currentIndex != target) {
      setState(() => _currentIndex = target);
      widget.onIndexChanged?.call(target);
    }
  }

  void _openLightbox() {
    final items = _ordered;
    if (items.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => LocationFullscreenLightbox(
        items: items,
        initialIndex: _currentIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _ordered;
    if (items.isEmpty) return const SizedBox.shrink();
    final current = items[_currentIndex.clamp(0, items.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Khung ảnh chính (carousel) + badge + mũi tên
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: items.length,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  widget.onIndexChanged?.call(i);
                },
                itemBuilder: (_, i) => GestureDetector(
                  onTap: _openLightbox,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD5B886)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GalleryMediaImage(
                      media: items[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // Badge trái: loại tư liệu (+ MỞ KHÓA TỪ BÀI HỌC)
              Positioned(
                left: 8,
                top: 8,
                child: _GalleryTypeBadge(media: current),
              ),

              // Badge phải: 1/N + phóng to
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      key: const Key('gallery-counter-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex.clamp(0, items.length - 1) + 1}/${items.length}',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: const Key('gallery-fullscreen-btn'),
                        onTap: _openLightbox,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mũi tên trái/phải
              if (items.length > 1) ...[
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _goTo(_currentIndex - 1),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _goTo(_currentIndex + 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Hộp chú thích & nguồn sử liệu
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5DAC6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current.title,
                style: DauVietTypography.labelLarge.copyWith(
                  color: DauVietColors.inkText,
                ),
              ),
              if (current.caption != null &&
                  current.caption!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  current.caption!,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
              if (current.sourceCitation != null &&
                  current.sourceCitation!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 12,
                      color: DauVietColors.woodBrown,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Nguồn: ${current.sourceCitation}',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: DauVietColors.woodBrown,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // 3. Dải thumbnail
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            key: const Key('gallery-thumbnail-strip'),
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final m = items[i];
                final selected = i == _currentIndex;
                return GestureDetector(
                  key: Key('gallery-thumb-$i'),
                  onTap: () => _goTo(i),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: selected ? 1.0 : 0.65,
                    child: Container(
                      width: 68,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? DauVietColors.cinnabarRed
                              : const Color(0xFFD8C8B0),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GalleryMediaImage(
                        media: m,
                        fit: BoxFit.cover,
                        showFallback: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Ảnh tư liệu trong Carousel/Lightbox: hỗ trợ `assetId`
/// (`LearningAssetImage`), `assetUrl`, và `externalUrl`
/// (`/heritage/<name>.jpg` → `assets/images/heritage/<name>.jpg`,
/// URL mạng qua `Image.network`); fallback minh họa khi lỗi tải.
class GalleryMediaImage extends StatelessWidget {
  final MapLocationMediaDto media;
  final BoxFit fit;
  final bool showFallback;

  const GalleryMediaImage({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.showFallback = true,
  });

  static String? bundledAssetFor(MapLocationMediaDto media) {
    final raw = (media.externalUrl ?? media.assetUrl ?? '').trim();
    if (raw.startsWith('assets/')) return raw;
    if (raw.startsWith('/heritage/')) {
      return 'assets/images$raw';
    }
    return null;
  }

  bool get _hasNetworkUrl {
    final raw = (media.externalUrl ?? media.assetUrl ?? '').trim();
    return raw.startsWith('http://') || raw.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (media.assetId != null && media.assetId!.trim().isNotEmpty) {
      return LearningAssetImage(
        assetId: media.assetId!,
        altText: media.title,
        fit: fit,
        tappable: false,
      );
    }
    final bundled = bundledAssetFor(media);
    if (bundled != null) {
      return Image.asset(
        bundled,
        fit: fit,
        errorBuilder: (_, _, _) =>
            showFallback ? _MediaFallback(media: media) : const SizedBox(),
      );
    }
    if (_hasNetworkUrl) {
      return Image.network(
        (media.externalUrl ?? media.assetUrl)!.trim(),
        fit: fit,
        errorBuilder: (_, _, _) =>
            showFallback ? _MediaFallback(media: media) : const SizedBox(),
      );
    }
    return showFallback
        ? _MediaFallback(media: media)
        : const SizedBox.shrink();
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _GalleryTypeBadge extends StatelessWidget {
  final MapLocationMediaDto media;
  const _GalleryTypeBadge({required this.media});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            media.mediaTypeLabelVi,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (media.isUnlockedOnly) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: DauVietColors.imperialGold.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_open_rounded,
                  size: 11,
                  color: DauVietColors.inkHeading,
                ),
                const SizedBox(width: 4),
                Text(
                  'MỞ KHÓA TỪ BÀI HỌC',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkHeading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaFallback extends StatelessWidget {
  final MapLocationMediaDto media;
  const _MediaFallback({required this.media});

  @override
  Widget build(BuildContext context) {
    // Fallback chỉ là minh họa placeholder — cố ý KHÔNG render
    // `media.title` để tránh trùng text với caption box / card title
    // trong các test dùng `find.text(media.title)`.
    return Container(
      color: const Color(0xFFEFE4CE),
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_rounded,
                  size: 32,
                  color: DauVietColors.woodBrown,
                ),
                SizedBox(height: 4),
                Icon(
                  Icons.landscape_rounded,
                  size: 18,
                  color: DauVietColors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightbox toàn màn hình xem từng ảnh với pinch-to-zoom
/// (`InteractiveViewer` `minScale 1.0` → `maxScale 4.0`), bộ đếm `1/N`,
/// caption + nguồn sử liệu và dải thumbnail điều hướng.
class LocationFullscreenLightbox extends StatefulWidget {
  final List<MapLocationMediaDto> items;
  final int initialIndex;

  const LocationFullscreenLightbox({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<LocationFullscreenLightbox> createState() =>
      _LocationFullscreenLightboxState();
}

class _LocationFullscreenLightboxState
    extends State<LocationFullscreenLightbox> {
  late final PageController _pageController;
  final TransformationController _zoomController = TransformationController();
  late int _index;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
    _zoomController.addListener(_handleZoomChanged);
  }

  void _handleZoomChanged() {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _isZoomed && mounted) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  void dispose() {
    _zoomController.removeListener(_handleZoomChanged);
    _zoomController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final target = index.clamp(0, widget.items.length - 1);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    setState(() => _index = target);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final current = items[_index];
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Ảnh chính với pinch-to-zoom
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: items.length,
                    onPageChanged: (i) {
                      _zoomController.value = Matrix4.identity();
                      setState(() {
                        _index = i;
                        _isZoomed = false;
                      });
                    },
                    itemBuilder: (_, i) => InteractiveViewer(
                      transformationController:
                          i == _index ? _zoomController : null,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: GalleryMediaImage(
                          media: items[i],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Caption + nguồn sử liệu
                if (current.title.isNotEmpty ||
                    (current.caption?.trim().isNotEmpty ?? false) ||
                    (current.sourceCitation?.trim().isNotEmpty ?? false))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current.title,
                          style: DauVietTypography.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        if (current.caption != null &&
                            current.caption!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            current.caption!,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        if (current.sourceCitation != null &&
                            current.sourceCitation!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Nguồn: ${current.sourceCitation}',
                            style: DauVietTypography.bodySmall.copyWith(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: DauVietColors.imperialGoldLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Dải thumbnail
                if (items.length > 1)
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final selected = i == _index;
                        return GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: selected ? 1.0 : 0.55,
                            child: Container(
                              width: 64,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selected
                                      ? DauVietColors.imperialGold
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: GalleryMediaImage(
                                media: items[i],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // Nút đóng + bộ đếm
            Positioned(
              right: 10,
              top: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_index + 1}/${items.length}',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('lightbox-close-btn'),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
