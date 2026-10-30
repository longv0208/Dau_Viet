import 'package:flutter/material.dart';

import '../../features/learning/presentation/renderers/asset_cover_image.dart';

/// Ảnh bìa sự kiện lịch sử.
///
/// Ưu tiên [assetId] (ảnh upload trên backend, tải qua
/// `/api/v1/assets/{id}/content` có Bearer); sau đó [assetPath] (asset bundle
/// cục bộ). Khi cả hai null/rỗng hoặc load lỗi → placeholder thương hiệu
/// (không vỡ layout, AC-6).
class EventCoverImage extends StatelessWidget {
  final String? assetId;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const EventCoverImage({
    super.key,
    this.assetId,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      child: AssetCoverImage(
        assetId: assetId,
        bundledPath: assetPath,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2D38), Color(0xFF3E4D55)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sailing_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
