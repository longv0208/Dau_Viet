import 'package:dau_viet_mobile/core/assets/asset_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = AssetResolver();

  group('AssetResolver.resolveEventCover', () {
    test('slug đã biết → asset path đã bundle', () {
      expect(
        resolver.resolveEventCover('events/bach-dang-938/hero.jpg', 'bach-dang-938'),
        'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
      );
    });

    test('không có slug → trích slug từ coverAssetKey dạng events/<slug>/<file>', () {
      expect(
        resolver.resolveEventCover('events/bach-dang-938/hero.jpg', null),
        'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
      );
    });

    test('slug lạ → null (UI dùng placeholder, không vỡ layout)', () {
      expect(resolver.resolveEventCover('events/hai-ba-trung/x.jpg', 'hai-ba-trung'), isNull);
      expect(resolver.resolveEventCover(null, 'slug-la'), isNull);
    });

    test('cả hai null → null, KHÔNG BAO GIỜ trả key thành URL', () {
      expect(resolver.resolveEventCover(null, null), isNull);
      expect(resolver.resolveEventCover('https://evil.example/x.jpg', null), isNull);
    });
  });
}
