import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../auth/data/auth_state.dart';
import '../../data/learning_providers.dart';

/// Cache bytes theo (sessionOwner, assetId) — fetch lỗi/rỗng KHÔNG được giữ
/// lại (để retry được sau khi có mạng lại); cache có bound nhỏ + chống trùng
/// request bay song song. Entry được gắn "session tag" ngay lúc tạo: đổi phiên
/// auth (logout / đổi tài khoản) khi không có widget nào mounted → tag tăng →
/// entry cũ lẫn request đang bay của phiên trước đều vô hiệu, không ghi đè được
/// cache của phiên mới.
const int _kMaxCachedAssets = 24;

class _AssetCacheEntry {
  final int sessionTag;
  final Future<List<int>> bytes;
  const _AssetCacheEntry(this.sessionTag, this.bytes);
}

final Map<String, _AssetCacheEntry> _assetByteCache = {};

/// Tag tăng mỗi lần owner đổi — kể cả khi không có LearningAssetImage nào
/// mounted (invalidate lười tại lần lookup kế tiếp).
int _assetCacheSessionTag = 0;
String? _cacheOwnerId;
bool _cacheOwnerInitialized = false;

/// Đồng bộ owner hiện tại TRƯỚC mỗi cache lookup. Trả tag của phiên đang
/// hoạt động; entry mang tag cũ coi như không tồn tại.
int _syncCacheSession(String? ownerId) {
  if (!_cacheOwnerInitialized || _cacheOwnerId != ownerId) {
    _cacheOwnerInitialized = true;
    _cacheOwnerId = ownerId;
    _assetCacheSessionTag++;
    _assetByteCache.clear(); // drop ảnh tải bằng credential phiên trước
  }
  return _assetCacheSessionTag;
}

void _evictIfOverflow() {
  while (_assetByteCache.length > _kMaxCachedAssets) {
    _assetByteCache.remove(_assetByteCache.keys.first); // FIFO đơn giản
  }
}

/// Gọi khi auth-session đổi (logout, đổi tài khoản, guest → user) — ví dụ từ
/// router/splash khi không có widget ảnh nào mounted. `ownerId` = định danh
/// ổn định của phiên (userId, hoặc `session:<status>` cho phiên chưa auth).
/// Đổi id → drop toàn bộ ảnh đã tải bằng credential của phiên trước.
void resetLearningAssetCacheForSession(String? ownerId) {
  _syncCacheSession(ownerId);
}

/// Chỉ cho test: xóa cache giữa các widget test độc lập.
void clearLearningAssetCacheForTest() {
  _assetByteCache.clear();
  _cacheOwnerId = null;
  _cacheOwnerInitialized = false;
  // Giữ nguyên tag — tag chỉ cần tăng khi owner đổi trong cùng một process.
}

String _sessionOwnerOf(AuthState s) =>
    s.profile?.id ?? 'session:${s.status.name}';

/// Fetch asset bytes đi qua cache trên — dùng chung cho mọi consumer
/// (renderer, zoom dialog, recap). Session được validate trước khi đọc cache
/// nên logout→login khi không có widget mounted vẫn fetch mới đúng credential.
/// Kết quả lỗi/rỗng tự evict để lần sau retry thật.
///
/// Public wrapper cho các lớp ảnh manifest (animation assets) — cùng cache,
/// auth (withAuth Bearer) và session-tag invalidation với [LearningAssetImage]
/// nên ảnh scene tải đúng endpoint `/api/v1/assets/{id}/content`, không qua
/// storageKey ngoài (an toàn media + pin đúng snapshot).
Future<List<int>> fetchLearningAssetBytes(WidgetRef ref, String assetId) =>
    _fetchAssetBytes(ref, assetId);

Future<List<int>> _fetchAssetBytes(WidgetRef ref, String assetId) {
  final int tag = _syncCacheSession(
    _sessionOwnerOf(ref.read(authSessionProvider)),
  );
  final cached = _assetByteCache[assetId];
  if (cached != null && cached.sessionTag == tag) return cached.bytes;

  final repo = ref.read(attemptRepositoryProvider);
  final raw = ApiConfig.useMock
      ? repo.getAssetBytes(assetId)
      : ref
            .read(authRepositoryProvider)
            .withAuth(() => repo.getAssetBytes(assetId));

  // Self-evict khi kết quả lỗi/rỗng, hoặc khi phiên đã đổi lúc future resolve
  // (stale in-flight không được phủ cache của phiên mới). Identity-check tránh
  // xóa nhầm entry mới hơn nếu cùng assetId được fetch lại trong lúc future
  // cũ đang chạy.
  late final Future<List<int>> guarded;
  guarded = raw.then((bytes) {
    final entry = _assetByteCache[assetId];
    if (bytes.isEmpty && identical(entry?.bytes, guarded)) {
      _assetByteCache.remove(assetId);
    }
    return bytes;
  });
  _assetByteCache[assetId] = _AssetCacheEntry(tag, guarded);
  _evictIfOverflow();
  guarded.catchError((_) {
    final entry = _assetByteCache[assetId];
    if (identical(entry?.bytes, guarded)) {
      _assetByteCache.remove(assetId);
    }
    return <int>[];
  });
  return guarded;
}

/// Ảnh học liệu tải qua `GET /api/v1/assets/{id}/content` có Bearer.
/// Placeholder khi đang tải; fallback alt-text + nút "Thử tải lại" khi lỗi/
/// mất mạng — không crash. Tap → preview fullscreen với pinch-zoom.
class LearningAssetImage extends ConsumerStatefulWidget {
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
  ConsumerState<LearningAssetImage> createState() => _LearningAssetImageState();
}

class _LearningAssetImageState extends ConsumerState<LearningAssetImage> {
  Future<List<int>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAssetBytes(ref, widget.assetId);
  }

  @override
  void didUpdateWidget(LearningAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _future = _fetchAssetBytes(ref, widget.assetId);
    }
  }

  /// Retry thủ công sau khi fetch lỗi/rỗng — KHÔNG auto-retry: chỉ chạy khi
  /// người dùng bấm "Thử tải lại". Entry lỗi đã tự evict nên đây là fetch mới.
  void _retry() {
    setState(() {
      _future = _fetchAssetBytes(ref, widget.assetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Đổi phiên auth khi widget đang mounted → fetch lại bằng credential mới
    // (cache cũ đã vô hiệu theo tag). Trường hợp không có widget nào mounted
    // được xử lý tại _fetchAssetBytes: owner được sync trước mọi lookup.
    ref.listen(authSessionProvider, (prev, next) {
      final String? prevOwner = prev == null ? null : _sessionOwnerOf(prev);
      if (prevOwner != _sessionOwnerOf(next)) {
        _retry();
      }
    });
    return FutureBuilder<List<int>>(
      future: _future,
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
          return _frame(_Fallback(altText: widget.altText, onRetry: _retry));
        }
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            Uint8List.fromList(bytes),
            height: widget.height,
            width: double.infinity,
            fit: widget.fit,
            errorBuilder: (_, e, st) =>
                _frame(_Fallback(altText: widget.altText, onRetry: _retry)),
          ),
        );
        if (!widget.tappable) return image;
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
      builder: (ctx) =>
          _ImagePreviewDialog(bytes: bytes, altText: widget.altText),
    );
  }

  Widget _frame(Widget child) => Container(
    height: widget.height ?? 200,
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
  final VoidCallback onRetry;
  const _Fallback({this.altText, required this.onRetry});

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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử tải lại'),
              style: TextButton.styleFrom(
                foregroundColor: DauVietColors.cinnabarRed,
                minimumSize: const Size(120, 44),
                textStyle: DauVietTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
