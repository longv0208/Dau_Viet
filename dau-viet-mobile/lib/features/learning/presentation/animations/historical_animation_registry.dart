import 'historical_animation_definition.dart';
import 'content/bach_dang_938_tide_v1.dart';

/// ANIM-01 — Registry typed ánh xạ `config.animationKey` → scene đã biên
/// dịch. KHÔNG lookup theo lesson title/eventId/DB id; key lạ trả null
/// (caller render READ bình thường — không crash, không thay scene khác).
class HistoricalAnimationRegistry {
  HistoricalAnimationRegistry._();

  static final Map<String, HistoricalAnimationDefinition> _scenes = {
    bachDang938TideV1.key: bachDang938TideV1,
  };

  /// Resolve key → definition; null nếu không hỗ trợ.
  static HistoricalAnimationDefinition? resolve(String? key) {
    if (key == null || key.isEmpty) return null;
    return _scenes[key];
  }
}
