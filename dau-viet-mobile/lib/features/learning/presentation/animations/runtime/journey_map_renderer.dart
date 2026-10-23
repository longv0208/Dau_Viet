import '../historical_animation_definition.dart';
import 'animation_manifest_dto.dart';
import 'animation_scene_renderer.dart';

/// ANIM-03 — Renderer generic cho dạng scene "hành trình trên bản đồ
/// schematic". Locations/routes/markers hoàn toàn từ manifest — không
/// hard-code địa danh hay sự kiện.
class JourneyMapRenderer extends AnimationSceneRenderer {
  const JourneyMapRenderer();

  @override
  String get rendererCode => 'JOURNEY_MAP';

  @override
  int get supportedRendererVersion => 1;

  @override
  bool canRender(AnimationManifestDto manifest) =>
      manifest.rendererCode == rendererCode &&
      manifest.rendererVersion <= supportedRendererVersion &&
      manifest.steps.isNotEmpty &&
      manifest.locations.isNotEmpty;

  @override
  HistoricalAnimationDefinition build(
    AnimationManifestDto manifest, {
    String playbackMode = 'AUTO',
  }) => manifest.toDefinition(playbackMode: playbackMode);
}
