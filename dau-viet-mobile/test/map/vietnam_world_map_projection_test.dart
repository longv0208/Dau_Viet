import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/geo/vietnam_world_map_projection.dart';
import 'package:dau_viet_mobile/features/map/presentation/widgets/vietnam_world_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VietnamWorldMapProjection', () {
    test('geoToWorld / worldToGeo khứ hồi tại Hà Nội và Cà Mau', () {
      const samples = [
        (21.0285, 105.8542),
        (10.0452, 105.7469),
        (16.0544, 108.2022),
        (22.8026, 104.9784),
      ];
      for (final s in samples) {
        final world = VietnamWorldMapProjection.geoToWorld(s.$1, s.$2);
        final geo = VietnamWorldMapProjection.worldToGeo(world);
        expect(geo.lat, closeTo(s.$1, 0.0001));
        expect(geo.lng, closeTo(s.$2, 0.0001));
      }
    });

    test('Đền Hùng và Bạch Đằng không trùng world point', () {
      final hung = VietnamWorldMapProjection.geoToWorld(21.3653, 105.3262);
      final bachDang = VietnamWorldMapProjection.geoToWorld(20.8492, 106.6891);
      expect((hung - bachDang).distance, greaterThan(80));
    });

    test('phân loại tọa độ địa lý vs phần trăm ảnh', () {
      expect(
        VietnamWorldMapProjection.isReliableGeographic(21.3, 105.3),
        isTrue,
      );
      expect(VietnamWorldMapProjection.isReliableGeographic(42, 58), isFalse);
      expect(VietnamWorldMapProjection.isReliableGeographic(0, 0), isFalse);
    });

    test('fitLocations với 1 điểm focus, nhiều điểm ôm cụm', () {
      const vp = Size(360, 640);
      const one = MapLocationDto(
        id: 'a',
        title: 'A',
        latitude: 21.02,
        longitude: 105.85,
        unlockState: MapUnlockState.available,
      );
      const two = MapLocationDto(
        id: 'b',
        title: 'B',
        latitude: 20.85,
        longitude: 106.69,
        unlockState: MapUnlockState.available,
      );
      final single = VietnamWorldMapProjection.focusLocation(one, vp);
      expect(single.getMaxScaleOnAxis(), greaterThan(2));
      final both = VietnamWorldMapProjection.fitLocations([one, two], vp);
      expect(both.getMaxScaleOnAxis(), lessThan(single.getMaxScaleOnAxis()));
    });

    test('cluster gom điểm gần, tách điểm xa ở zoom toàn quốc', () {
      const nearA = MapLocationDto(
        id: 'n1',
        title: 'Bến Bạch Đằng',
        latitude: 20.91,
        longitude: 106.82,
        unlockState: MapUnlockState.available,
      );
      const nearB = MapLocationDto(
        id: 'n2',
        title: 'Cửa Lạch',
        latitude: 20.95,
        longitude: 106.79,
        unlockState: MapUnlockState.available,
      );
      const far = MapLocationDto(
        id: 'f1',
        title: 'Hà Nội',
        latitude: 21.02,
        longitude: 105.85,
        unlockState: MapUnlockState.available,
      );
      final clusters = clusterLocations(
        locations: const [nearA, nearB, far],
        scale: 0.3,
      );
      expect(clusters.length, 2);
      expect(
        clusters.map((c) => c.members.length).toList()..sort(),
        [1, 2],
      );
    });
  });
}
