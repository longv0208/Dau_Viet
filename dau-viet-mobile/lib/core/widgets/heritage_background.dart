import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_state.dart';
import '../../features/learning/data/learning_providers.dart';
import '../../features/learning/presentation/renderers/learning_asset_image.dart';
import '../models/heritage_background_config.dart';
import '../theme/dau_viet_colors.dart';
import 'heritage_ornaments.dart';

/// Dynamic Heritage Background Renderer (`HeritageBackground` — Phần C1).
///
/// Biến một ảnh lịch sử/phong cảnh thông thường do Admin cấu hình thành lớp nền
/// chìm phong cách Vietnamese Heritage Modern, tự động hòa vào nền giấy dó kem
/// (`DauVietColors.paperBackground`) và bảo đảm độ tương phản cho chữ phía trên.
///
/// Khi không có ảnh, chế độ là `none`, hoặc tải ảnh lỗi: tự động hiển thị nền
/// giấy cổ kèm hoa văn Đông Sơn và mây truyền thống nhẹ.
class HeritageBackground extends ConsumerStatefulWidget {
  final HeritageBackgroundConfigDto config;

  /// Đường dẫn asset cục bộ tùy chọn (chỉ dùng khi nội dung có asset riêng đã biết).
  final String? fallbackBundledAssetPath;

  /// Chiều cao vùng hero hiển thị ảnh nền (mặc định 208px, giới hạn hợp lý 180–240px).
  final double heroHeight;

  /// Nội dung hiển thị bên trên nền (Header + danh sách cuộn bên dưới).
  final Widget child;

  const HeritageBackground({
    super.key,
    this.config = HeritageBackgroundConfigDto.paperDefault,
    this.fallbackBundledAssetPath,
    this.heroHeight = 208,
    required this.child,
  });

  /// Constructor tiện ích nhận trực tiếp từng tham số theo đặc tả C1.
  factory HeritageBackground.fromParams({
    Key? key,
    String? imageUrl,
    String? assetId,
    HeritageBackgroundMode backgroundMode = HeritageBackgroundMode.heritageFade,
    Alignment focusPoint = const Alignment(0.0, -0.3),
    double imageOpacity = 0.55,
    double fadeStrength = 0.8,
    HeritageTintPreset tintPreset = HeritageTintPreset.warm,
    bool enabled = true,
    String? fallbackBundledAssetPath,
    double heroHeight = 208,
    required Widget child,
  }) {
    final fx = ((focusPoint.x + 1.0) / 2.0).clamp(0.0, 1.0);
    final fy = ((focusPoint.y + 1.0) / 2.0).clamp(0.0, 1.0);
    return HeritageBackground(
      key: key,
      config: HeritageBackgroundConfigDto(
        backgroundAssetId: assetId,
        backgroundImageUrl: imageUrl,
        backgroundMode: backgroundMode,
        focusX: fx,
        focusY: fy,
        imageOpacity: imageOpacity.clamp(0.0, 1.0),
        fadeStrength: fadeStrength.clamp(0.0, 1.0),
        tintPreset: tintPreset,
        enabled: enabled,
      ),
      fallbackBundledAssetPath: fallbackBundledAssetPath,
      heroHeight: heroHeight,
      child: child,
    );
  }

  @override
  ConsumerState<HeritageBackground> createState() => _HeritageBackgroundState();
}

class _HeritageBackgroundState extends ConsumerState<HeritageBackground> {
  Future<List<int>>? _assetBytesFuture;

  @override
  void initState() {
    super.initState();
    _syncAssetFuture();
  }

  @override
  void didUpdateWidget(covariant HeritageBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.resolvedAssetId != widget.config.resolvedAssetId ||
        oldWidget.config.backgroundImageUrl !=
            widget.config.backgroundImageUrl ||
        oldWidget.config.backgroundMode != widget.config.backgroundMode ||
        oldWidget.config.enabled != widget.config.enabled) {
      _syncAssetFuture();
    }
  }

  void _syncAssetFuture() {
    final cfg = widget.config;
    if (!cfg.enabled || cfg.backgroundMode == HeritageBackgroundMode.none) {
      _assetBytesFuture = null;
      return;
    }
    final assetId = cfg.resolvedAssetId;
    if (assetId != null && assetId.isNotEmpty) {
      _assetBytesFuture = fetchLearningAssetBytes(ref, assetId);
    } else {
      _assetBytesFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authSessionProvider, (prev, next) {
      if (prev?.profile?.id != next.profile?.id ||
          prev?.status != next.status) {
        setState(_syncAssetFuture);
      }
    });

    final double effectiveHeroHeight = widget.heroHeight.clamp(160.0, 260.0);

    return ColoredBox(
      color: DauVietColors.paperBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vùng Hero giới hạn chiều cao ở phần đầu màn hình, hòa mượt xuống nền giấy
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: effectiveHeroHeight,
            child: ClipRect(
              child: _buildHeroBackdrop(effectiveHeroHeight),
            ),
          ),

          // Nội dung màn hình luôn nằm phía trên lớp nền
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildHeroBackdrop(double height) {
    final cfg = widget.config;
    final bool modeAllowsImage =
        cfg.enabled && cfg.backgroundMode != HeritageBackgroundMode.none;

    if (!modeAllowsImage) {
      return _PaperDefaultHeroBackdrop(height: height);
    }

    final String? assetId = cfg.resolvedAssetId;
    if (assetId != null && assetId.isNotEmpty && _assetBytesFuture != null) {
      return FutureBuilder<List<int>>(
        future: _assetBytesFuture,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              bytes != null &&
              bytes.isNotEmpty) {
            return _ProcessedImageHeroBackdrop(
              config: cfg,
              height: height,
              imageChild: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.cover,
                alignment: cfg.focusAlignment,
                width: double.infinity,
                height: height,
                errorBuilder: (_, _, _) =>
                    _buildFallbackOrPaper(cfg: cfg, height: height),
              ),
            );
          }
          return _buildFallbackOrPaper(cfg: cfg, height: height);
        },
      );
    }

    final String? rawUrl = cfg.resolvedImageUrl;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final String? localAsset = _normalizeLocalAssetPath(rawUrl);
      if (localAsset != null) {
        return _ProcessedImageHeroBackdrop(
          config: cfg,
          height: height,
          imageChild: Image.asset(
            localAsset,
            fit: BoxFit.cover,
            alignment: cfg.focusAlignment,
            width: double.infinity,
            height: height,
            errorBuilder: (_, _, _) =>
                _buildFallbackOrPaper(cfg: cfg, height: height),
          ),
        );
      }
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        return _ProcessedImageHeroBackdrop(
          config: cfg,
          height: height,
          imageChild: Image.network(
            rawUrl,
            fit: BoxFit.cover,
            alignment: cfg.focusAlignment,
            width: double.infinity,
            height: height,
            errorBuilder: (_, _, _) =>
                _buildFallbackOrPaper(cfg: cfg, height: height),
          ),
        );
      }
    }

    return _buildFallbackOrPaper(cfg: cfg, height: height);
  }

  Widget _buildFallbackOrPaper({
    required HeritageBackgroundConfigDto cfg,
    required double height,
  }) {
    final bundled = widget.fallbackBundledAssetPath?.trim();
    if (bundled != null && bundled.isNotEmpty) {
      return _ProcessedImageHeroBackdrop(
        config: cfg,
        height: height,
        imageChild: Image.asset(
          bundled,
          fit: BoxFit.cover,
          alignment: cfg.focusAlignment,
          width: double.infinity,
          height: height,
          errorBuilder: (_, _, _) => _PaperDefaultHeroBackdrop(height: height),
        ),
      );
    }
    return _PaperDefaultHeroBackdrop(height: height);
  }

  static String? _normalizeLocalAssetPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('assets/')) {
      return trimmed;
    }
    if (trimmed.startsWith('/heritage/')) {
      return 'assets/images$trimmed';
    }
    return null;
  }
}

/// Hiển thị ảnh nền đã qua xử lý:
/// 1. Crop `BoxFit.cover` + định vị `focusAlignment`
/// 2. `ColorFiltered` theo `tintPreset` và `backgroundMode`
/// 3. `Opacity` (`imageOpacity`) + `ShaderMask` hòa dần vào nền giấy
/// 4. Lớp phủ kem & gradient đảm bảo tiêu đề luôn đọc rõ
class _ProcessedImageHeroBackdrop extends StatelessWidget {
  final HeritageBackgroundConfigDto config;
  final double height;
  final Widget imageChild;

  const _ProcessedImageHeroBackdrop({
    required this.config,
    required this.height,
    required this.imageChild,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFadeMode =
        config.backgroundMode == HeritageBackgroundMode.heritageFade;
    final double opacity = config.imageOpacity.clamp(0.0, 1.0);
    final double fade = config.fadeStrength.clamp(0.0, 1.0);

    // Điểm bắt đầu mờ dần xuống nền giấy (fade càng cao thì hòa vào giấy càng sớm)
    final double fadeStartStop = (1.0 - (fade * 0.72)).clamp(0.18, 0.88);
    final double midWashAlpha = isFadeMode
        ? (0.28 + (fade * 0.42)).clamp(0.22, 0.78)
        : (0.10 + (fade * 0.25)).clamp(0.08, 0.45);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Nền giấy gốc phía dưới
        const ColoredBox(color: DauVietColors.paperBackground),

        // Ảnh đã lọc màu + điều chỉnh opacity + ShaderMask hòa vào nền giấy
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, fadeStartStop, 1.0],
              colors: [
                Colors.white.withValues(alpha: opacity),
                Colors.white.withValues(
                  alpha: (opacity * (1.0 - fade * 0.55)).clamp(0.08, 1.0),
                ),
                Colors.transparent,
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ColorFiltered(
            colorFilter: _buildColorFilter(
              config.backgroundMode,
              config.tintPreset,
            ),
            child: imageChild,
          ),
        ),

        // Lớp phủ màu tông di sản (Tint wash)
        DecoratedBox(
          decoration: BoxDecoration(
            color: _resolveTintOverlayColor(config.tintPreset, isFadeMode),
          ),
        ),

        // Lớp gradient kem giấy dó bảo vệ độ tương phản cho chữ tiêu đề
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.48, 0.82, 1.0],
              colors: [
                DauVietColors.paperBackground.withValues(
                  alpha: isFadeMode ? 0.26 : 0.14,
                ),
                DauVietColors.paperBackground.withValues(alpha: midWashAlpha),
                DauVietColors.paperBackground.withValues(
                  alpha: isFadeMode ? 0.88 : 0.72,
                ),
                DauVietColors.paperBackground,
              ],
            ),
          ),
        ),

        // Mây truyền thống nhẹ ở chân vùng Hero
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TraditionalCloudOrnament(height: 32, opacity: 0.18),
        ),
      ],
    );
  }

  static Color _resolveTintOverlayColor(
    HeritageTintPreset tint,
    bool isFadeMode,
  ) {
    final double mult = isFadeMode ? 1.0 : 0.6;
    switch (tint) {
      case HeritageTintPreset.warm:
        return DauVietColors.imperialGold.withValues(alpha: 0.14 * mult);
      case HeritageTintPreset.sepia:
        return DauVietColors.imperialGoldDark.withValues(alpha: 0.20 * mult);
      case HeritageTintPreset.cool:
        return DauVietColors.jade.withValues(alpha: 0.12 * mult);
      case HeritageTintPreset.neutral:
        return DauVietColors.paperCardHi.withValues(alpha: 0.18 * mult);
      case HeritageTintPreset.none:
        return DauVietColors.paperBackground.withValues(alpha: 0.06 * mult);
    }
  }

  static ColorFilter _buildColorFilter(
    HeritageBackgroundMode mode,
    HeritageTintPreset tint,
  ) {
    if (mode == HeritageBackgroundMode.normal &&
        tint == HeritageTintPreset.none) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }

    switch (tint) {
      case HeritageTintPreset.warm:
        // Giảm nhẹ độ bão hòa gắt và phủ sắc ấm giấy dó
        return const ColorFilter.matrix(<double>[
          0.92, 0.12, 0.02, 0, 8,
          0.06, 0.88, 0.04, 0, 4,
          0.02, 0.08, 0.76, 0, -4,
          0, 0, 0, 1, 0,
        ]);
      case HeritageTintPreset.sepia:
        return const ColorFilter.matrix(<double>[
          0.82, 0.24, 0.06, 0, 10,
          0.14, 0.78, 0.08, 0, 4,
          0.06, 0.14, 0.62, 0, -8,
          0, 0, 0, 1, 0,
        ]);
      case HeritageTintPreset.cool:
        return const ColorFilter.matrix(<double>[
          0.84, 0.08, 0.06, 0, 0,
          0.06, 0.90, 0.08, 0, 4,
          0.04, 0.10, 0.92, 0, 6,
          0, 0, 0, 1, 0,
        ]);
      case HeritageTintPreset.neutral:
        return const ColorFilter.matrix(<double>[
          0.82, 0.12, 0.06, 0, 4,
          0.08, 0.84, 0.08, 0, 4,
          0.08, 0.12, 0.80, 0, 4,
          0, 0, 0, 1, 0,
        ]);
      case HeritageTintPreset.none:
        return const ColorFilter.matrix(<double>[
          0.94, 0.04, 0.02, 0, 0,
          0.03, 0.94, 0.03, 0, 0,
          0.02, 0.04, 0.94, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }
}

/// Nền giấy cổ mặc định khi không có ảnh nền hoặc chế độ `none`:
/// Nền kem giấy dó + hoa văn Đông Sơn chìm + vân mây truyền thống nhẹ.
class _PaperDefaultHeroBackdrop extends StatelessWidget {
  final double height;

  const _PaperDefaultHeroBackdrop({required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DauVietColors.paperCardHi,
                DauVietColors.paperBackground.withValues(alpha: 0.96),
                DauVietColors.paperBackground,
              ],
              stops: const [0.0, 0.72, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: -28,
          right: -24,
          child: DongSonWatermark(size: 168, opacity: 0.11),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TraditionalCloudOrnament(height: 34, opacity: 0.20),
        ),
      ],
    );
  }
}
