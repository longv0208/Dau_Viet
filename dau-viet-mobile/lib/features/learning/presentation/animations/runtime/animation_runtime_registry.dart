import 'animation_manifest_dto.dart';
import 'animation_scene_renderer.dart';
import 'journey_map_renderer.dart';
import 'river_tide_renderer.dart';

/// Kết quả resolve animation cho READ — phân biệt 3 nhánh (FIX-P1):
///   none        — không có animationManifest, không có animationKey.
///   legacy      — chỉ có legacy animationKey → resolve qua registry cũ.
///   unsupported — có animationManifest nhưng invalid/unsupported →
///                 hiển thị notice rõ, KHÔNG rơi về animationKey khác
///                 (đó là scene khác, sai ngữ cảnh).
enum AnimationResolveKind { none, legacy, manifest, invalid, unsupported }

/// Typed parse result — giữ thông tin TẠI SAO manifest không render được
/// để caller hiển thị fallback đúng thay vì im lặng trả null.
class AnimationParseResult {
  /// Parse OK — dto hợp lệ (có rendererCode).
  final AnimationManifestDto? dto;

  /// embedded có `animationManifest` nhưng không parse được / hỏng shape.
  /// Khi này dto=null nhưng KHÔNG được coi là "không có animation".
  final bool present;

  const AnimationParseResult._(this.dto, this.present);

  /// Không có animationManifest trong config (hoặc null) — caller mới
  /// được phép thử legacy animationKey.
  static const absent = AnimationParseResult._(null, false);

  /// Có animationManifest nhưng parse fail / thiếu rendererCode →
  /// invalid manifest; KHÔNG silent fallback về animationKey.
  static const invalid = AnimationParseResult._(null, true);

  static AnimationParseResult ok(AnimationManifestDto dto) =>
      AnimationParseResult._(dto, true);
}

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
    final res = parseManifestDetailed(embedded);
    return res.dto;
  }

  /// FIX-P1 — typed parse: phân biệt `absent` (không có manifest →
  /// được phép thử legacy animationKey) khỏi `invalid` (có manifest nhưng
  /// hỏng → hiển thị unsupported-notice, KHÔNG rơi về animationKey).
  static AnimationParseResult parseManifestDetailed(Object? embedded) {
    if (embedded == null) return AnimationParseResult.absent;
    if (embedded is! Map) {
      // Có config.animationManifest nhưng sai shape (string/number/list)
      // → manifest invalid, không phải "không có animation".
      return AnimationParseResult.invalid;
    }
    final raw = embedded['manifest'] ?? embedded;
    if (raw is! Map) {
      // Envelope tồn tại nhưng không có manifest map bên trong.
      return AnimationParseResult.invalid;
    }
    try {
      final dto = AnimationManifestDto.fromJson(Map<String, dynamic>.from(raw));
      if (dto.rendererCode.isEmpty) return AnimationParseResult.invalid;
      return AnimationParseResult.ok(dto);
    } catch (_) {
      return AnimationParseResult.invalid; // parse fail → invalid, không crash
    }
  }
}
