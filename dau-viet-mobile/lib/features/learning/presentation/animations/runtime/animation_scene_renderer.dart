import '../historical_animation_definition.dart';
import 'animation_manifest_dto.dart';

/// ANIM-03 — Một renderer biết cách biến manifest data → definition
/// typed của engine. Key theo `rendererCode`, KHÔNG BAO GIỜ theo
/// eventId — renderer generic, scene data hoàn toàn từ manifest.
abstract class AnimationSceneRenderer {
  const AnimationSceneRenderer();

  /// `RIVER_TIDE`, `JOURNEY_MAP`, … — khớp whitelist backend.
  String get rendererCode;

  /// RendererVersion tối đa hiểu — manifest mới hơn vẫn parse được phần
  /// đã biết (DTO bỏ qua field lạ) nhưng caller có thể cảnh báo.
  int get supportedRendererVersion;

  /// SchemaVersion tối đa renderer này hiểu (whitelist `{camera, tracks,
  /// effects, audio, environment}` = v2). Manifest v3+ → canRender false
  /// → explicit `_UnsupportedAnimationNotice` thay vì silently drop
  /// features — đúng versioning contract: rendererVersion=1 KHÔNG có
  /// nghĩa renderer hiểu mọi schemaVersion.
  int get supportedSchemaVersion => 2;

  /// Manifest hợp lệ tối thiểu để renderer vận hành (vd: map cần
  /// locations; river không bắt buộc stakes vì có field mặc định).
  bool canRender(AnimationManifestDto manifest);

  /// Build definition cho [HistoricalAnimationPlayer]. `playbackMode`
  /// đến từ READ config (AUTO/STEPPED/INTERACTIVE), không nằm trong
  /// manifest — renderer truyền thẳng cho definition.
  HistoricalAnimationDefinition build(
    AnimationManifestDto manifest, {
    String playbackMode = 'AUTO',
  });
}
