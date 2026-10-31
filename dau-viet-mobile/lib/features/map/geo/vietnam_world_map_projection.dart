import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/map_location_dto.dart';

/// Hệ chiếu World Map Việt Nam — dùng chung nguyên tắc với Admin.
///
/// Asset: `Vietnam_relief_location_map` (Wikimedia Commons, Uwe Dedering,
/// CC BY-SA 3.0). Khung địa lý khớp template Location map Vietnam:
/// 23.393°N–8.179°N, 102.144°E–109.464°E.
///
/// Equirectangular trên khung đã địa lý hóa — không suy từ kích thước ảnh.
class VietnamWorldMapProjection {
  const VietnamWorldMapProjection._();

  static const double designWidth = 1458.101;
  static const double designHeight = 2838.058;

  static const double northLat = 23.393;
  static const double southLat = 8.179;
  static const double westLng = 102.144;
  static const double eastLng = 109.464;

  static const String rasterAsset =
      'assets/maps/vietnam_relief_location_map.png';
  static const String attribution =
      'Bản đồ địa hình Việt Nam — Wikimedia Commons, Uwe Dedering (CC BY-SA 3.0)';

  static const Size designSize = Size(designWidth, designHeight);

  static bool isReliableGeographic(double lat, double lng) {
    return lat >= 6.0 && lat <= 24.5 && lng > 100.0 && lng <= 112.0;
  }

  static bool isInsideMapFrame(double lat, double lng) {
    return lat >= southLat &&
        lat <= northLat &&
        lng >= westLng &&
        lng <= eastLng;
  }

  static Offset geoToWorld(double lat, double lng) {
    final x = ((lng - westLng) / (eastLng - westLng)) * designWidth;
    final y = ((northLat - lat) / (northLat - southLat)) * designHeight;
    return Offset(x, y);
  }

  static ({double lat, double lng}) worldToGeo(Offset world) {
    final lng = westLng + (world.dx / designWidth) * (eastLng - westLng);
    final lat = northLat - (world.dy / designHeight) * (northLat - southLat);
    return (lat: lat, lng: lng);
  }

  static Offset worldToScreen(Offset world, Matrix4 camera) {
    return MatrixUtils.transformPoint(camera, world);
  }

  static Offset screenToWorld(Offset screen, Matrix4 camera) {
    final inverse = Matrix4.tryInvert(camera);
    if (inverse == null) return screen;
    return MatrixUtils.transformPoint(inverse, screen);
  }

  static Rect boundsOf(Iterable<Offset> worlds) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in worlds) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (!minX.isFinite) {
      return Offset.zero & designSize;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Matrix4 fitRect(Rect worldRect, Size viewport, {double padding = 48}) {
    final safe = worldRect.inflate(math.max(24, worldRect.shortestSide * 0.12));
    final availW = math.max(1.0, viewport.width - padding * 2);
    final availH = math.max(1.0, viewport.height - padding * 2);
    final scale = math
        .min(availW / math.max(safe.width, 1), availH / math.max(safe.height, 1))
        .clamp(0.18, 6.0);
    final dx =
        (viewport.width - safe.width * scale) / 2 - safe.left * scale;
    final dy =
        (viewport.height - safe.height * scale) / 2 - safe.top * scale;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  static Matrix4 fitVietnam(Size viewport) {
    return fitRect(Offset.zero & designSize, viewport, padding: 8);
  }

  static Matrix4 fitLocations(
    Iterable<MapLocationDto> locations,
    Size viewport, {
    double padding = 56,
  }) {
    final worlds = <Offset>[
      for (final loc in locations)
        if (loc.hasReliableGeographicCoordinate)
          geoToWorld(loc.latitude, loc.longitude),
    ];
    if (worlds.isEmpty) return fitVietnam(viewport);
    if (worlds.length == 1) {
      return focusWorld(worlds.first, viewport: viewport, scale: 3.2);
    }
    return fitRect(boundsOf(worlds), viewport, padding: padding);
  }

  static Matrix4 focusWorld(
    Offset world, {
    required Size viewport,
    double scale = 3.4,
  }) {
    final clamped = scale.clamp(0.18, 6.0);
    final dx = viewport.width / 2 - world.dx * clamped;
    final dy = viewport.height / 2 - world.dy * clamped;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(clamped, clamped, 1, 1);
  }

  static Matrix4 focusLocation(
    MapLocationDto location,
    Size viewport, {
    double scale = 3.4,
  }) {
    if (!location.hasReliableGeographicCoordinate) {
      return fitVietnam(viewport);
    }
    return focusWorld(
      geoToWorld(location.latitude, location.longitude),
      viewport: viewport,
      scale: scale,
    );
  }
}
