/// Ánh xạ `coverAssetKey`/slug từ backend sang đường dẫn asset bundle cục bộ.
///
/// TUYỆT ĐỐI không suy diễn key thành public URL (AC-6) — key chỉ là
/// định danh logic; về sau nếu đổi sang asset service chỉ sửa bảng này.
class AssetResolver {
  const AssetResolver();

  /// Bảng slug → file asset trong `assets/images/` (hiện flat).
  /// Thêm dòng mới khi backend publish thêm sự kiện có cover.
  static const Map<String, String> _eventCoverBySlug = {
    'bach-dang-938': 'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
  };

  /// Trả về asset path đã bundle hoặc `null` khi không nhận diện được key.
  /// Ưu tiên tra theo [slug]; khi thiếu slug, thử trích slug từ
  /// `coverAssetKey` dạng `events/<slug>/<file>`.
  String? resolveEventCover(String? coverAssetKey, String? slug) {
    final String? effectiveSlug = slug ?? _slugFromKey(coverAssetKey);
    if (effectiveSlug == null) {
      return null;
    }
    return _eventCoverBySlug[effectiveSlug];
  }

  String? _slugFromKey(String? coverAssetKey) {
    if (coverAssetKey == null) {
      return null;
    }
    final List<String> parts = coverAssetKey.split('/');
    // Kỳ vọng 'events/<slug>/<filename>'.
    if (parts.length == 3 && parts.first == 'events' && parts[1].isNotEmpty) {
      return parts[1];
    }
    return null;
  }
}
