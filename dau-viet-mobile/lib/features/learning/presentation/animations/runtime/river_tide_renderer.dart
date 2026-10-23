import '../historical_animation_definition.dart';
import 'animation_manifest_dto.dart';
import 'animation_scene_renderer.dart';

/// ANIM-03 — Renderer generic cho dạng scene "thủy triều + vật cản
/// ngầm". Toàn bộ nội dung (bãi cọc, bước, prediction) đến từ manifest —
/// KHÔNG có dữ liệu sự kiện hard-code ở đây.
class RiverTideRenderer extends AnimationSceneRenderer {
  const RiverTideRenderer();

  @override
  String get rendererCode => 'RIVER_TIDE';

  @override
  int get supportedRendererVersion => 1;

  @override
  bool canRender(AnimationManifestDto manifest) =>
      manifest.rendererCode == rendererCode && manifest.steps.isNotEmpty;

  @override
  HistoricalAnimationDefinition build(
    AnimationManifestDto manifest, {
    String playbackMode = 'AUTO',
  }) =>
      manifest.toDefinition(playbackMode: playbackMode);
}
