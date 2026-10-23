import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../data/learning_providers.dart';
import '../../renderers/learning_asset_image.dart' show fetchLearningAssetBytes;
import '../effects/effect_painters.dart';
import '../effects/environment_overlay.dart';
import '../runtime/animation_manifest_dto.dart';
import '../runtime/cinematic_state.dart';

/// ANIM-03/P0-4/v2 — Lớp ảnh manifest quanh canvas painter + cinematic
/// transform (camera pan/zoom) + object visual state từ keyframe tracks
/// + typed effect overlays (WATER_RIPPLE/MIST/GLOW/FADE) + ambient
/// environment (mist/glow nền).
///
/// Z-order (trong cùng camera transform):
///   background image → EnvironmentOverlay (mist/glow) → painter child →
///   object images (sorted by layer) → EffectOverlay (typed effects)
///
/// Manifest không khai báo ảnh/object/effect/environment → trả `child`
/// nguyên trạng, không đổi layout, không cần ProviderScope.
class ManifestAssetLayers extends StatelessWidget {
  final AnimationManifestDto manifest;
  final double aspectRatio;
  final Widget child;

  /// Frame cinematic hiện tại (camera + object states + effects) —
  /// player phát qua [ValueListenable]; null → render tĩnh như v1
  /// (không camera/tracks/effects).
  final ValueListenable<CinematicFrame>? frameListenable;

  const ManifestAssetLayers({
    super.key,
    required this.manifest,
    required this.aspectRatio,
    required this.child,
    this.frameListenable,
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

  bool get _hasCinematic =>
      manifest.cinematic.cameraSteps.isNotEmpty ||
      manifest.cinematic.tracks.isNotEmpty ||
      manifest.cinematic.effects.isNotEmpty;

  bool get _hasEnvironment =>
      manifest.environment.mist > 0 || manifest.environment.glow > 0;

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundAssetId;
    final objects = _objectLayers;
    final listenable = frameListenable;
    final env = manifest.environment;
    if (bg == null && objects.isEmpty && !_hasCinematic && !_hasEnvironment) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Static path — không cinematic: v1 behavior + ambient env.
        final staticStack = _sceneStack(
          bg: bg,
          objects: objects,
          size: size,
          frame: null,
          env: env,
        );
        if (listenable == null || !_hasCinematic) {
          return _wrapEnvironment(staticStack, env);
        }
        // Cinematic path — toàn bộ scene trong camera transform;
        // objects đọc ObjectVisualState động; effects overlay trên cùng.
        return ClipRect(
          child: ValueListenableBuilder<CinematicFrame>(
            valueListenable: listenable,
            builder: (context, frame, _) => Transform(
              transform: frame.camera.transformFor(size),
              child: _wrapEnvironment(
                _sceneStack(
                  bg: bg,
                  objects: objects,
                  size: size,
                  frame: frame,
                  env: env,
                ),
                env,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sceneStack({
    required String? bg,
    required List<_ResolvedObject> objects,
    required Size size,
    required CinematicFrame? frame,
    required EnvironmentDto env,
  }) {
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
        // Painter canvas (map/river) — layer 0.
        child,
        // Object images — layer >= 0 sorted.
        for (final r in objects)
          _positioned(r, size, frame?.objects[r.object.id]),
        // Typed effect overlays — layer +inf (trên objects, dưới UI).
        if (frame != null)
          for (final e in frame.effects) _effectLayer(e, frame),
      ],
    );
  }

  /// Environment ambient (mist/glow) bọc toàn scene — nằm ngoài Stack
  /// chính nhưng vẫn trong camera transform (cinematic) hoặc trực tiếp
  /// (static). Mist vẽ đè lên mọi thứ nhẹ; glow đặt sát center.
  Widget _wrapEnvironment(Widget scene, EnvironmentDto env) {
    if (!_hasEnvironment) return scene;
    return EnvironmentOverlay(environment: env, child: scene);
  }

  Widget _positioned(_ResolvedObject r, Size size, ObjectVisualState? vs) {
    final o = r.object;
    final state = vs ??
        ObjectVisualState(
          position: o.position,
          scale: o.scale,
          rotation: o.rotation,
          opacity: o.opacity,
          visible: o.visible,
        );
    if (!state.visible || state.opacity <= 0) {
      return const SizedBox.shrink();
    }
    final diameter = (size.width * state.scale).clamp(24.0, size.width);
    final cx = state.position.dx * size.width;
    final cy = state.position.dy * size.height;
    return Positioned(
      left: cx - diameter / 2,
      top: cy - diameter / 2,
      width: diameter,
      height: diameter,
      child: Opacity(
        opacity: state.opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: state.rotation * 3.141592653589793 / 180,
          child: _ManifestImage(
            key: ValueKey('manifest_obj_${o.id}_${r.ref.assetId}'),
            assetId: r.ref.assetId,
            altText: manifest.altTextOf(r.ref.assetId) ?? o.id,
            shape: o.shape,
          ),
        ),
      ),
    );
  }

  /// Resolve một [ActiveEffect] → widget overlay. GLOW theo `objectId`
  /// lấy tâm từ ObjectVisualState hiện tại của frame (track đang chạy
  /// thì glow bám theo object, không dùng center cố định).
  Widget _effectLayer(ActiveEffect e, CinematicFrame frame) {
    // GLOW có objectId → tâm = vị trí object trong frame hiện tại.
    var center = e.center;
    if (e.type == 'GLOW' && e.objectId != null) {
      final obj = frame.objects[e.objectId];
      if (obj != null) center = obj.position;
    }
    final painter = switch (e.type) {
      'WATER_RIPPLE' => WaterRipplePainter(
          center: center,
          progress: e.progress,
        ),
      'MIST' => MistPainter(intensity: e.intensity),
      'GLOW' => GlowPainter(
          center: center,
          intensity: e.intensity,
        ),
      'FADE_IN' => FadePainter(opacity: 1 - e.progress),
      'FADE_OUT' => FadePainter(opacity: e.progress),
      // ROUTE_REVEAL: painter canvas tự xử lý qua routeProgress — không
      // overlay riêng; manifest vẫn khai báo để admin đánh dấu.
      _ => null,
    };
    if (painter == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: painter),
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
