import 'package:flutter/material.dart';

/// Ảnh bìa sự kiện lịch sử render từ asset bundle.
/// Khi [assetPath] null/rỗng hoặc load lỗi → hiển thị placeholder thương
/// hiệu (không vỡ layout, AC-6).
class EventCoverImage extends StatelessWidget {
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const EventCoverImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final String? path = (assetPath != null && assetPath!.isNotEmpty)
        ? assetPath
        : null;
    if (path == null) {
      return _buildPlaceholder();
    }
    return Image.asset(
      path,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
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
