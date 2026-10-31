import 'package:flutter/material.dart';

import 'island_visual_asset_manager.dart';

/// Kích thước scene + vùng cỏ đặt vật phẩm cho 3 layout đảo tham chiếu.
class IslandIllustratedLayout {
  const IslandIllustratedLayout._();

  static String assetForTier(int tier) {
    switch (tier) {
      case 1:
        return IslandVisualAssetManager.islandSmallArt;
      case 2:
        return IslandVisualAssetManager.islandMediumArt;
      case 3:
      default:
        return IslandVisualAssetManager.islandLargeArt;
    }
  }

  /// Padding quanh lưới ô để mép đá / cầu tàu / mặt nước của ảnh vẫn nhìn thấy.
  static ({double padX, double padTop, double padBottom}) paddingForTier({
    required int tier,
    required double tileW,
    required double tileH,
  }) {
    switch (tier) {
      case 1:
        return (
          padX: tileW * 2.65,
          padTop: tileH * 4.55,
          padBottom: tileH * 3.95,
        );
      case 2:
        return (
          padX: tileW * 2.15,
          padTop: tileH * 3.75,
          padBottom: tileH * 3.25,
        );
      case 3:
      default:
        return (
          padX: tileW * 1.85,
          padTop: tileH * 3.25,
          padBottom: tileH * 2.85,
        );
    }
  }
}

/// Nền đảo isometric minh họa theo đúng 3 ảnh tham chiếu.
class IslandIllustratedBackdrop extends StatelessWidget {
  final int previewTier;
  final bool isLockedPreview;

  const IslandIllustratedBackdrop({
    super.key,
    required this.previewTier,
    this.isLockedPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget art = Image.asset(
      IslandIllustratedLayout.assetForTier(previewTier),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );

    if (isLockedPreview) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.28, 0.42, 0.14, 0, 18,
          0.28, 0.42, 0.14, 0, 18,
          0.28, 0.42, 0.14, 0, 22,
          0, 0, 0, 0.92, 0,
        ]),
        child: art,
      );
    }

    art = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        return RadialGradient(
          center: const Alignment(0, 0.08),
          radius: 0.78,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.74, 1.0],
        ).createShader(rect);
      },
      child: art,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        if (isLockedPreview)
          const Align(
            alignment: Alignment(0, -0.08),
            child: _LockedIslandBadge(),
          ),
      ],
    );
  }
}

class _LockedIslandBadge extends StatelessWidget {
  const _LockedIslandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE62A241C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0AE45), width: 1.4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: Color(0xFFE0AE45), size: 16),
          SizedBox(width: 6),
          Text(
            'Chưa mở khóa',
            style: TextStyle(
              color: Color(0xFFF8F0E0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
