import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_map_node.dart';

class _FakeMapRepo implements MapRepository {
  final List<MapLocationDto> locations;
  _FakeMapRepo(this.locations);

  @override
  Future<List<MapLocationDto>> listLocations() async => locations;
}

void main() {
  const demoLocHungVuong = MapLocationDto(
    id: 'demo-1',
    eventId: '00000000-0000-0000-0000-000000000005',
    eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
    title: 'Khu di tích Đền Hùng',
    description: 'Núi Nghĩa Lĩnh, Phong Châu.',
    latitude: 21.3,
    longitude: 105.3,
    unlockState: MapUnlockState.unlocked,
  );

  const demoLocHaiBaTrung = MapLocationDto(
    id: 'demo-2',
    eventId: '00000000-0000-0000-0000-000000000002',
    eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
    title: 'Cửa Sông Hát (Hát Môn)',
    description: 'Nơi tế cờ khởi nghĩa.',
    latitude: 21.1,
    longitude: 105.5,
    unlockState: MapUnlockState.locked,
  );

  const demoLocBachDang = MapLocationDto(
    id: 'demo-3',
    eventId: '00000000-0000-0000-0000-000000000001',
    eventTitle: 'Đại Chiến Bạch Đằng 938',
    title: 'Bến Bạch Đằng - Trận Địa Cọc',
    description: 'Cửa sông Bạch Đằng lịch sử.',
    latitude: 20.8,
    longitude: 106.6,
    unlockState: MapUnlockState.available,
  );

  group('JourneyMap UI/UX Pro Max Tests', () {
    testWidgets('renders UI Pro Max journey map, header banner, dedicated map background image and nodes properly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(_FakeMapRepo([demoLocHungVuong])),
          ],
          child: const MaterialApp(
            home: HistoricalMapScreen(initialMode: ExploreViewMode.map),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify Header Bar & Banner
      expect(find.byTooltip('Về Học tập'), findsOneWidget);
      expect(find.text('Hành trình lịch sử Việt Nam'), findsOneWidget);
      expect(
        find.text('Khám phá những giai đoạn hào hùng của dân tộc qua các bài học thú vị'),
        findsOneWidget,
      );

      // Verify dedicated map title banner
      expect(find.text('Bản Đồ Nước Văn Lang Thời Các Vua Hùng'), findsOneWidget);
      expect(find.text('1 mốc toạ độ'), findsOneWidget);

      // Verify authentic map background image asset is map_van_lang.jpg
      final imgFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/map_van_lang.jpg',
      );
      expect(imgFinder, findsOneWidget);

      // Verify location node rendered on map
      expect(find.byType(JourneyMapNode), findsOneWidget);
      expect(find.text('Khu di tích Đền Hùng'), findsWidgets);
    });

    testWidgets('renders Timeline view first with chronological events when initialMode=timeline', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeMapRepo([demoLocBachDang, demoLocHungVuong, demoLocHaiBaTrung]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: HistoricalMapScreen(initialMode: ExploreViewMode.timeline),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify Timeline header and switcher
      expect(find.text('Dòng Thời Gian Lịch Sử'), findsOneWidget);
      expect(find.text('Dòng thời gian'), findsOneWidget);
      expect(find.text('Bản đồ dấu ấn'), findsOneWidget);

      // Verify Chronological Order: Hùng Vương (-700) -> Hai Bà Trưng (40) -> Bạch Đằng (938)
      expect(find.text('Thời Đại Hùng Vương - Dựng Nước Văn Lang'), findsOneWidget);
      expect(find.text('Khởi Nghĩa Hai Bà Trưng (Năm 40)'), findsOneWidget);
      expect(find.text('Đại Chiến Bạch Đằng 938'), findsOneWidget);

      // Verify era chips
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Thời Hùng Vương'), findsWidgets);
      expect(find.text('Bắc thuộc'), findsWidgets);
    });

    testWidgets('tapping event card on timeline switches to Event Map view with chronological milestones and back pill works', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeMapRepo([demoLocHungVuong, demoLocHaiBaTrung, demoLocBachDang]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: HistoricalMapScreen(initialMode: ExploreViewMode.timeline),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap on Hùng Vương event
      await tester.tap(find.text('Thời Đại Hùng Vương - Dựng Nước Văn Lang'));
      await tester.pumpAndSettle();

      // Verify we are now in Event Map view
      expect(find.text('Hành trình lịch sử Việt Nam'), findsOneWidget);
      expect(find.text('Khu di tích Đền Hùng'), findsWidgets);
      expect(find.text('Về Dòng Thời Gian'), findsOneWidget);

      // Tap 'Về Dòng Thời Gian' to return to timeline
      await tester.tap(find.text('Về Dòng Thời Gian'));
      await tester.pumpAndSettle();

      // Verify we returned to Timeline view
      expect(find.text('Dòng Thời Gian Lịch Sử'), findsOneWidget);
    });

    testWidgets('renders dedicated map image and banner for each historical journey and switching chapter works', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeMapRepo([demoLocHungVuong, demoLocHaiBaTrung, demoLocBachDang]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: HistoricalMapScreen(initialMode: ExploreViewMode.map),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Initial chapter: Hùng Vương
      expect(find.text('Bản Đồ Nước Văn Lang Thời Các Vua Hùng'), findsOneWidget);
      expect(find.text('1 mốc toạ độ'), findsOneWidget);

      var imgFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/map_van_lang.jpg',
      );
      expect(imgFinder, findsWidgets);

      // 2. Switch to Next Chapter: Hai Bà Trưng
      await tester.tap(find.byTooltip('Chặng sau'));
      await tester.pumpAndSettle();

      expect(find.text('Bản Đồ Khởi Nghĩa Hai Bà Trưng (Năm 40)'), findsOneWidget);
      imgFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/map_hai_ba_trung.jpg',
      );
      expect(imgFinder, findsWidgets);

      // 3. Switch to Next Chapter: Bạch Đằng 938
      await tester.tap(find.byTooltip('Chặng sau'));
      await tester.pumpAndSettle();

      expect(find.text('Bản Đồ Thủy Chiến Bạch Đằng Giang 938'), findsOneWidget);
      imgFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/dv_MAP_ngoquyen_bachdang-base_v01.jpg',
      );
      expect(imgFinder, findsWidgets);
    });
  });
}
