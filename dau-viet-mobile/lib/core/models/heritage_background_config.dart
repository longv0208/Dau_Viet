import 'package:flutter/material.dart';

enum HeritageBackgroundMode {
  heritageFade('heritage_fade'),
  normal('normal'),
  none('none');

  final String wireValue;
  const HeritageBackgroundMode(this.wireValue);

  static HeritageBackgroundMode parse(
    String? raw, {
    required bool hasImage,
  }) {
    switch (raw?.trim().toLowerCase()) {
      case 'heritage_fade':
        return HeritageBackgroundMode.heritageFade;
      case 'normal':
        return HeritageBackgroundMode.normal;
      case 'none':
        return HeritageBackgroundMode.none;
      default:
        return hasImage
            ? HeritageBackgroundMode.heritageFade
            : HeritageBackgroundMode.none;
    }
  }
}

enum HeritageTintPreset {
  warm('warm'),
  sepia('sepia'),
  cool('cool'),
  neutral('neutral'),
  none('none');

  final String wireValue;
  const HeritageTintPreset(this.wireValue);

  static HeritageTintPreset parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'warm':
        return HeritageTintPreset.warm;
      case 'sepia':
        return HeritageTintPreset.sepia;
      case 'cool':
        return HeritageTintPreset.cool;
      case 'neutral':
        return HeritageTintPreset.neutral;
      case 'none':
        return HeritageTintPreset.none;
      default:
        return HeritageTintPreset.warm;
    }
  }
}

/// Cấu hình Dynamic Heritage Background dùng chung cho Thời kỳ, Sự kiện và Bài học.
/// Tách biệt rõ với ảnh đại diện/thumbnail (`coverImageKey` / `coverAssetKey`).
class HeritageBackgroundConfigDto {
  final String? backgroundAssetId;
  final String? backgroundImageUrl;
  final HeritageBackgroundMode backgroundMode;
  final double focusX;
  final double focusY;
  final double imageOpacity;
  final double fadeStrength;
  final HeritageTintPreset tintPreset;
  final bool enabled;

  const HeritageBackgroundConfigDto({
    this.backgroundAssetId,
    this.backgroundImageUrl,
    this.backgroundMode = HeritageBackgroundMode.none,
    this.focusX = 0.5,
    this.focusY = 0.35,
    this.imageOpacity = 0.55,
    this.fadeStrength = 0.8,
    this.tintPreset = HeritageTintPreset.warm,
    this.enabled = true,
  });

  static const HeritageBackgroundConfigDto paperDefault =
      HeritageBackgroundConfigDto();

  static final RegExp _uuidRegExp = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static final RegExp _assetContentUrlRegExp = RegExp(
    r'/api/v1/(?:admin/)?assets/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/content$',
    caseSensitive: false,
  );

  static String? extractAssetId(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (_uuidRegExp.hasMatch(trimmed)) return trimmed;
    final match = _assetContentUrlRegExp.firstMatch(trimmed);
    return match?.group(1);
  }

  /// Asset UUID nếu ảnh nền trỏ tới bảng `assets` trên backend (`/api/v1/assets/{id}/content`).
  String? get resolvedAssetId =>
      extractAssetId(backgroundAssetId) ?? extractAssetId(backgroundImageUrl);

  /// URL/key ảnh nền đã chuẩn hóa (nếu có).
  String? get resolvedImageUrl {
    final id = resolvedAssetId;
    if (id != null && id.isNotEmpty) {
      return '/api/v1/assets/$id/content';
    }
    final url = backgroundImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return null;
  }

  bool get hasImage => resolvedImageUrl != null;

  bool get shouldRenderImage =>
      enabled && backgroundMode != HeritageBackgroundMode.none && hasImage;

  Alignment get focusAlignment => Alignment(
        (focusX.clamp(0.0, 1.0) * 2.0) - 1.0,
        (focusY.clamp(0.0, 1.0) * 2.0) - 1.0,
      );

  static double _clampUnit(num? value, double fallback) {
    if (value == null) return fallback;
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite) return fallback;
    return d.clamp(0.0, 1.0);
  }

  factory HeritageBackgroundConfigDto.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return paperDefault;
    }
    final String? rawAssetId = json['backgroundAssetId']?.toString();
    final String? rawUrl = json['backgroundImageUrl']?.toString();
    final String? assetId =
        extractAssetId(rawAssetId) ?? extractAssetId(rawUrl);
    final String? resolvedUrl = assetId != null
        ? '/api/v1/assets/$assetId/content'
        : (rawUrl != null && rawUrl.trim().isNotEmpty ? rawUrl.trim() : null);
    final bool hasImg = resolvedUrl != null;

    final mode = HeritageBackgroundMode.parse(
      json['backgroundMode'] as String?,
      hasImage: hasImg,
    );

    return HeritageBackgroundConfigDto(
      backgroundAssetId: assetId,
      backgroundImageUrl: resolvedUrl,
      backgroundMode: mode,
      focusX: _clampUnit(json['focusX'] as num?, 0.5),
      focusY: _clampUnit(json['focusY'] as num?, 0.35),
      imageOpacity: _clampUnit(
        json['imageOpacity'] as num?,
        mode == HeritageBackgroundMode.normal ? 0.85 : 0.55,
      ),
      fadeStrength: _clampUnit(
        json['fadeStrength'] as num?,
        mode == HeritageBackgroundMode.normal ? 0.35 : 0.8,
      ),
      tintPreset: HeritageTintPreset.parse(json['tintPreset'] as String?),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (backgroundAssetId != null) 'backgroundAssetId': backgroundAssetId,
        if (backgroundImageUrl != null)
          'backgroundImageUrl': backgroundImageUrl,
        'backgroundMode': backgroundMode.wireValue,
        'focusX': focusX,
        'focusY': focusY,
        'imageOpacity': imageOpacity,
        'fadeStrength': fadeStrength,
        'tintPreset': tintPreset.wireValue,
        'enabled': enabled,
      };
}
