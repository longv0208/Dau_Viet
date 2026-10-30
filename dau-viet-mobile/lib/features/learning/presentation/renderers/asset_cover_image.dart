import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learning_asset_image.dart';

/// Ảnh bìa/thumbnail tải từ backend `GET /api/v1/assets/{id}/content` qua
/// cache chung [fetchLearningAssetBytes]; khi [assetId] rỗng tự rơi về
/// [bundledPath] (asset bundle cục bộ) rồi mới tới [placeholder].
///
/// Dùng chung cho hero banner sự kiện, thumbnail lộ trình — nơi `coverAssetKey`
/// của backend có thể là UUID asset, URL `/api/v1/assets/{id}/content`, hoặc
/// key logic `events/<slug>/<file>` map sang bundled asset.
class AssetCoverImage extends ConsumerWidget {
  /// UUID asset trên backend (đã resolve từ key/URL bởi caller).
  final String? assetId;

  /// Đường dẫn `assets/...` cục bộ dùng khi không có [assetId].
  final String? bundledPath;

  /// Hiển thị khi không có ảnh nào khả dụng hoặc tải lỗi.
  final Widget placeholder;

  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  const AssetCoverImage({
    super.key,
    this.assetId,
    this.bundledPath,
    required this.placeholder,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? remoteId =
        (assetId != null && assetId!.trim().isNotEmpty) ? assetId!.trim() : null;
    if (remoteId != null) {
      return FutureBuilder<List<int>>(
        future: fetchLearningAssetBytes(ref, remoteId),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              bytes != null &&
              bytes.isNotEmpty) {
            return Image.memory(
              Uint8List.fromList(bytes),
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              errorBuilder: (_, _, _) => placeholder,
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            // Lỗi/rỗng: rơi về bundled rồi placeholder — giữ layout ổn định.
            return _bundledOrPlaceholder();
          }
          return placeholder;
        },
      );
    }
    return _bundledOrPlaceholder();
  }

  Widget _bundledOrPlaceholder() {
    final String? path = (bundledPath != null && bundledPath!.trim().isNotEmpty)
        ? bundledPath!.trim()
        : null;
    if (path == null) return placeholder;
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
