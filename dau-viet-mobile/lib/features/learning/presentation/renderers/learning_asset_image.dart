import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/learning_providers.dart';

/// Cache bytes theo assetId — fetch lỗi/rỗng KHÔNG được giữ lại (để retry
/// được sau khi có mạng lại); cache có bound nhỏ + chống trùng request bay
/// song song. Xóa khi đổi phiên auth (logout / đổi tài khoản) để ảnh có
/// Bearer không lọt sang user khác.
const int _kMaxCachedAssets = 24;
final Map<String, Future<List<int>>> _assetByteCache = {};
String? _cacheOwnerId; // user/session id đang sở hữu cache — đổi → xóa hết

void _evictIfOverflow() {
  while (_assetByteCache.length > _kMaxCachedAssets) {
    _assetByteCache.remove(_assetByteCache.keys.first); // FIFO đơn giản
  }
}

/// Gọi khi auth-session đổi (logout, đổi tài khoản, guest → user).
/// `ownerId` = bất kỳ định danh ổn định nào của phiên hiện tại (vd userId,
/// hoặc 'guest'/'anon' cho phiên chưa auth). Đổi id → drop toàn bộ ảnh đã
/// tải bằng credential của phiên trước.
void resetLearningAssetCacheForSession(String? ownerId) {
  if (_cacheOwnerId == ownerId) return;
  _cacheOwnerId = ownerId;
  _assetByteCache.clear();
}

/// Chỉ cho test: xóa cache giữa các widget test độc lập.
void clearLearningAssetCacheForTest() {
  _assetByteCache.clear();
  _cacheOwnerId = null;
}

/// Provider lấy asset bytes đi qua cache trên — dùng chung cho mọi
/// consumer (renderer, zoom dialog, recap). Fetch lỗi hoặc trả rỗng sẽ bị
/// evict khỏi cache để lần rebuild sau retry lại thật (tránh kẹt trạng
/// thái lỗi tạm thời của mạng/auth).
Future<List<int>> _fetchAssetBytes(WidgetRef ref, String assetId) {
  final cached = _assetByteCache[assetId];
  if (cached != null) return cached;

  final repo = ref.read(attemptRepositoryProvider);
  final raw = ApiConfig.useMock
      ? repo.getAssetBytes(assetId)
      : ref
            .read(authRepositoryProvider)
            .withAuth(() => repo.getAssetBytes(assetId));

  // Self-evict khi kết quả lỗi/rỗng; identity-check tránh xóa nhầm entry
  // mới hơn nếu cùng assetId được fetch lại trong lúc future cũ đang chạy.
  late final Future<List<int>> guarded;
  guarded = raw.then((bytes) {
    if (bytes.isEmpty && identical(_assetByteCache[assetId], guarded)) {
      _assetByteCache.remove(assetId);
    }
    return bytes;
  });
  _assetByteCache[assetId] = guarded;
  _evictIfOverflow();
  guarded.catchError((_) {
    if (identical(_assetByteCache[assetId], guarded)) {
      _assetByteCache.remove(assetId);
    }
    return <int>[];
  });
  return guarded;
}

/// Ảnh học liệu tải qua `GET /api/v1/assets/{id}/content` có Bearer.
/// Placeholder khi đang tải; fallback alt-text khi lỗi/mất mạng — không crash.
/// Tap → preview fullscreen với pinch-zoom (InteractiveViewer).
class LearningAssetImage extends ConsumerWidget {
  final String assetId;
  final String? altText;
  final double? height;
  final BoxFit fit;

  /// Bật/tắt mở fullscreen khi chạm (mặc định bật).
  final bool tappable;

  const LearningAssetImage({
    super.key,
    required this.assetId,
    this.altText,
    this.height,
    this.fit = BoxFit.contain,
    this.tappable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Đổi phiên auth (logout / đổi tài khoản / guest → user) → drop ảnh
    // đã tải bằng credential phiên trước. profile.id ổn định theo user;
    // các phiên chưa auth quy về status name.
    ref.listen(authSessionProvider, (prev, next) {
      final String owner = next.profile?.id ?? 'session:${next.status.name}';
      resetLearningAssetCacheForSession(owner);
    });
    return FutureBuilder<List<int>>(
      future: _fetchAssetBytes(ref, assetId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _frame(
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return _frame(_Fallback(altText: altText));
        }
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            Uint8List.fromList(bytes),
            height: height,
            width: double.infinity,
            fit: fit,
            errorBuilder: (_, e, st) => _frame(_Fallback(altText: altText)),
          ),
        );
        if (!tappable) return image;
        return Stack(
          children: [
            image,
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openPreview(context, bytes),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPreview(BuildContext context, List<int> bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ImagePreviewDialog(bytes: bytes, altText: altText),
    );
  }

  Widget _frame(Widget child) => Container(
    height: height ?? 200,
    width: double.infinity,
    decoration: BoxDecoration(
      color: DauVietColors.parchmentContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: DauVietColors.outlineVariant),
    ),
    child: child,
  );
}

/// Dialog fullscreen + pinch-zoom cho ảnh học liệu (không thêm dependency —
/// InteractiveViewer của framework đủ dùng).
class _ImagePreviewDialog extends StatelessWidget {
  final List<int> bytes;
  final String? altText;

  const _ImagePreviewDialog({required this.bytes, this.altText});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.contain,
                  semanticLabel: altText,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          if (altText != null && altText!.isNotEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    altText!,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String? altText;
  const _Fallback({this.altText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: DauVietColors.inkMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              (altText != null && altText!.isNotEmpty)
                  ? altText!
                  : 'Không tải được hình ảnh.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
