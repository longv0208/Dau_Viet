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

  /// Bảng `chapter.code` → file asset trong `assets/images/` cho thumbnail
  /// trên thẻ thời kỳ của màn `PeriodSelectionScreen`.
  ///
  /// Admin có thể cấu hình `coverImageKey` (dạng `periods/<code>/<file>`) tại
  /// ChapterForm trong `dau-viet-admin`; khi vắng mặt ta rơi về `code` để giữ
  /// cùng một file hiển thị cho các thời kỳ đã biết.
  static const Map<String, String> _periodCoverByCode = {
    'FOUNDING_ERA': 'assets/images/hung_vuong_village.jpg',
    'NORTHERN_DOMINATION': 'assets/images/map_hai_ba_trung.jpg',
    'EARLY_INDEPENDENCE':
        'assets/images/heritage/hoang-thanh-thang-long.jpg',
    'LY_DYNASTY': 'assets/images/section_pagoda_icon.png',
    'ANTI_FRENCH_RESISTANCE':
        'assets/images/heritage/doi-a1-dien-bien-phu.jpg',
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

  /// Trả về asset path hiển thị thumbnail trên thẻ thời kỳ.
  ///
  /// Ưu tiên `coverImageKey` do admin cấu hình (trích `code` từ
  /// `periods/<code>/<file>`); khi không khai báo ta rơi về tra bảng theo
  /// [chapterCode] để giữ hiển thị ổn định cho các thời kỳ đã được biết.
  String? resolvePeriodCover(String? coverImageKey, String? chapterCode) {
    final String? keyCode = _periodCodeFromKey(coverImageKey);
    final String? effectiveCode =
        keyCode ?? (chapterCode?.trim().isEmpty ?? true ? null : chapterCode);
    if (effectiveCode == null) {
      return null;
    }
    return _periodCoverByCode[effectiveCode];
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

  /// Trích `code` từ `coverImageKey` dạng `periods/<code>/<file>`; trả `null`
  /// nếu key không đúng cấu trúc (admin có thể gõ bất kỳ string).
  String? _periodCodeFromKey(String? coverImageKey) {
    if (coverImageKey == null) {
      return null;
    }
    final List<String> parts = coverImageKey.split('/');
    if (parts.length == 3 && parts.first == 'periods' && parts[1].isNotEmpty) {
      return parts[1];
    }
    return null;
  }
}
