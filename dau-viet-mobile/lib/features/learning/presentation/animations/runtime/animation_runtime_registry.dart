import 'animation_manifest_dto.dart';
import 'animation_scene_renderer.dart';
import 'journey_map_renderer.dart';
import 'river_tide_renderer.dart';

/// ANIM-03 — Registry của runtime data-driven: rendererCode → renderer.
/// KHÁC HistoricalAnimationRegistry (key → scene hard-code): registry
/// này KHÔNG biết gì về sự kiện/lesson — chỉ biết renderer generic.
/// RendererCode lạ → resolve trả null, caller fallback an toàn.
class AnimationRuntimeRegistry {
  AnimationRuntimeRegistry._();

  static const List<AnimationSceneRenderer> _renderers = [
    RiverTideRenderer(),
    JourneyMapRenderer(),
  ];

  /// Danh sách rendererCode hỗ trợ — admin builder đọc để chỉ cho chọn
  /// template mà app hiện render được.
  static List<String> get supportedCodes =>
      _renderers.map((r) => r.rendererCode).toList(growable: false);

  static AnimationSceneRenderer? resolve(String? rendererCode) {
    if (rendererCode == null || rendererCode.isEmpty) return null;
    for (final r in _renderers) {
      if (r.rendererCode == rendererCode) return r;
    }
    return null;
  }

  /// Parse embedded manifest JSON (`config.animationManifest.manifest`)
  /// → DTO; null khi payload không phải map / parse không được.
  static AnimationManifestDto? parseManifest(Object? embedded) {
    if (embedded is! Map) return null;
    final raw = embedded['manifest'] ?? embedded;
    if (raw is! Map) return null;
    try {
      final dto = AnimationManifestDto.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return dto.rendererCode.isEmpty ? null : dto;
    } catch (_) {
      return null; // manifest hỏng → fallback, không crash
    }
  }
}
