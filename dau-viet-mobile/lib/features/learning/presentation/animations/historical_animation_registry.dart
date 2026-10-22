import 'historical_animation_definition.dart';
import 'content/bach_dang_938_tide_v1.dart';
import 'content/hai_ba_trung_40_uprising_v1.dart';
import 'content/ly_thai_to_1010_relocation_v1.dart';

/// ANIM-01/02 — Registry typed ánh xạ `config.animationKey` → scene đã
/// biên dịch. KHÔNG lookup theo lesson title/eventId/DB id; key lạ trả
/// null (caller render READ bình thường — không crash, không thay scene
/// khác). Điểm mở rộng duy nhất cho scene mới: thêm một
/// HistoricalAnimationDefinition vào map này.
class HistoricalAnimationRegistry {
  HistoricalAnimationRegistry._();

  static final Map<String, HistoricalAnimationDefinition> _scenes = {
    bachDang938TideV1.key: bachDang938TideV1,
    haiBaTrung40UprisingV1.key: haiBaTrung40UprisingV1,
    lyThaiTo1010RelocationV1.key: lyThaiTo1010RelocationV1,
  };

  /// Resolve key → definition; null nếu không hỗ trợ.
  static HistoricalAnimationDefinition? resolve(String? key) {
    if (key == null || key.isEmpty) return null;
    return _scenes[key];
  }
}
