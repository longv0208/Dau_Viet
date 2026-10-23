import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../data/learning_providers.dart';
import '../../renderers/learning_asset_image.dart' show fetchLearningAssetBytes;
import '../runtime/animation_manifest_dto.dart';

/// ANIM-03/P0-4 — Lớp ảnh manifest quanh canvas painter.
///
/// KHÔNG gắn vào painter (CustomPainter thuần vẽ, không fetch); widget này
/// đặt MỘT background image dưới painter + các object image lên trên, theo
/// tọa độ chuẩn hóa của manifest. Mỗi ảnh fetch đúng MỘT lần lúc mount qua
/// [fetchLearningAssetBytes] — cùng cache/auth/session-tag với
/// [LearningAssetImage] nên không có per-frame request và không dựa vào
/// storageKey ngoài (publish đã pin assetId + meta trong snapshot).
///
/// Lớp này KHÔNG tự resolve auth — chỉ khi manifest thực sự khai báo ảnh
/// mới mount [_ManifestImage] (widget đó tự check auth session). Manifest
/// không khai báo gì → trả `child` nguyên trạng, không đổi layout, không
/// cần ProviderScope (giữ tương thích widget test pump trực tiếp).
class ManifestAssetLayers extends StatelessWidget {
  final AnimationManifestDto manifest;
  final double aspectRatio;
  final Widget child;

  const ManifestAssetLayers({
    super.key,
    required this.manifest,
    required this.aspectRatio,
    required this.child,
  });

  /// assetId lớp nền — ưu tiên `map.backgroundAssetId`, sau đó assets[]
  /// đầu tiên role BACKGROUND.
  String? get _backgroundAssetId {
    final bg = manifest.backgroundAssetId;
    if (bg != null && bg.isNotEmpty) return bg;
    for (final a in manifest.assetRefs) {
      if (a.role == 'BACKGROUND') return a.assetId;
    }
    return null;
  }

  /// objects[] resolve được sang một assets[] entry role OBJECT — sort
  /// theo `layer` (ổn định) để thứ tự chồng lấp deterministic.
  List<_ResolvedObject> get _objectLayers {
    final byKey = {for (final a in manifest.assetRefs) a.id: a};
    final list = <_ResolvedObject>[];
    for (final o in manifest.objects) {
      if (!o.visible) continue;
      final ref = o.assetRef == null ? null : byKey[o.assetRef];
      if (ref == null || ref.role != 'OBJECT') continue;
      list.add(_ResolvedObject(o, ref));
    }
    list.sort((a, b) => a.object.layer.compareTo(b.object.layer));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundAssetId;
    final objects = _objectLayers;
    if (bg == null && objects.isEmpty) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bg != null)
              _ManifestImage(
                key: ValueKey('manifest_bg_$bg'),
                assetId: bg,
                altText: manifest.altTextOf(bg) ?? 'Nền minh họa',
                frame: false,
              ),
            child,
            for (final r in objects) _positioned(r, size),
          ],
        );
      },
    );
  }

  Widget _positioned(_ResolvedObject r, Size size) {
    final o = r.object;
    final diameter = (size.width * o.scale).clamp(24.0, size.width);
    final cx = o.position.dx * size.width;
    final cy = o.position.dy * size.height;
    return Positioned(
      left: cx - diameter / 2,
      top: cy - diameter / 2,
      width: diameter,
      height: diameter,
      child: _ManifestImage(
        key: ValueKey('manifest_obj_${o.id}_${r.ref.assetId}'),
        assetId: r.ref.assetId,
        altText: manifest.altTextOf(r.ref.assetId) ?? o.id,
        shape: o.shape,
      ),
    );
  }
}

class _ResolvedObject {
  final AnimationObjectDto object;
  final AnimationAssetRefDto ref;
  const _ResolvedObject(this.object, this.ref);
}

/// Một ảnh manifest — chỉ fetch khi auth session là `authenticated`
/// (Bearer hợp lệ); preview/chưa auth chỉ vẽ khung, KHÔNG phát request
/// (media security: asset endpoint yêu cầu auth — UUID khó đoán không
/// phải security boundary). Fetch MỘT lần lúc initState; lỗi/rỗng rơi
/// về icon mờ — không crash, không che scene.
class _ManifestImage extends ConsumerStatefulWidget {
  final String assetId;
  final String altText;
  final String shape;

  /// `frame=true` (object) bọc khung nhẹ; `false` (background) ảnh phủ
  /// kín, mờ — nằm dưới painter nên không chiếm sóng nội dung.
  final bool frame;

  const _ManifestImage({
    super.key,
    required this.assetId,
    required this.altText,
    this.shape = 'rect',
    this.frame = true,
  });

  @override
  ConsumerState<_ManifestImage> createState() => _ManifestImageState();
}

class _ManifestImageState extends ConsumerState<_ManifestImage> {
  Future<List<int>>? _future;

  bool get _authed {
    try {
      return ref.read(authSessionProvider).isAuthenticated;
    } catch (_) {
      return false; // không có ProviderScope → preview-only, không fetch
    }
  }

  @override
  void initState() {
    super.initState();
    if (_authed) _future = fetchLearningAssetBytes(ref, widget.assetId);
  }

  @override
  void didUpdateWidget(covariant _ManifestImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _future =
          _authed ? fetchLearningAssetBytes(ref, widget.assetId) : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return _placeholder();
    return FutureBuilder<List<int>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.frame ? _placeholder() : const SizedBox.shrink();
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return widget.frame ? _broken() : const SizedBox.shrink();
        }
        final img = Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          semanticLabel: widget.altText,
          errorBuilder: (_, e, st) =>
              widget.frame ? _broken() : const SizedBox.shrink(),
        );
        final clipped = widget.shape == 'circle'
            ? ClipOval(child: img)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: img,
              );
        // Background mờ để painter/label vẫn đọc được — ảnh là bối cảnh
        // minh họa, không phải nội dung chính.
        return widget.frame
            ? clipped
            : Opacity(opacity: 0.45, child: clipped);
      },
    );
  }

  Widget _placeholder() => widget.frame
      ? Container(
          decoration: BoxDecoration(
            color: DauVietColors.parchmentContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: DauVietColors.outlineVariant),
          ),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              color: DauVietColors.inkMuted,
              size: 20,
            ),
          ),
        )
      : const SizedBox.shrink();

  Widget _broken() => Container(
        decoration: BoxDecoration(
          color: DauVietColors.parchmentContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DauVietColors.outlineVariant),
        ),
        child: Tooltip(
          message: widget.altText,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: DauVietColors.inkMuted,
              size: 20,
            ),
          ),
        ),
      );
}
