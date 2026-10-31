import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_chapter.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_layout.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_path_painter.dart';
import 'package:dau_viet_mobile/features/map/presentation/widgets/heritage_map_marker.dart';
import 'package:dau_viet_mobile/features/map/presentation/widgets/vietnam_world_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeMapRepository implements MapRepository {
  List<MapLocationDto> locations = const [];
  Map<String, MapLocationDto> detailsById = const {};
  Object? error;
  int calls = 0;
  int detailCalls = 0;

  @override
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) async {
    calls++;
    if (error != null) throw error!;
    return locations;
  }

  @override
  Future<MapLocationDto> getLocationDetail(String locationId) async {
    detailCalls++;
    if (error != null) throw error!;
    final detail = detailsById[locationId];
    if (detail != null) return detail;
    return locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => throw const ApiException(
        ApiError(code: 'NOT_FOUND', message: 'Not found'),
      ),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._state);
  final AuthState _state;

  @override
  Future<T> withAuth<T>(Future<T> Function() action) => action();

  @override
  Future<AuthState> restore() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const locked = MapLocationDto(
    id: 'loc-1',
    eventId: 'evt-1',
    eventTitle: 'Trận Bạch Đằng 938',
    title: 'Bến Bạch Đằng',
    description: 'Bãi cọc ngầm.',
    latitude: 20.91,
    longitude: 106.82,
    unlockState: MapUnlockState.locked,
    requiredLesson: RequiredLessonRef(
      lessonId: 'les-1',
      title: 'Trận Bạch Đằng 938',
    ),
  );
  const unlocked = MapLocationDto(
    id: 'loc-2',
    eventId: 'evt-1',
    title: 'Cửa Lạch Trường',
    latitude: 20.95,
    longitude: 106.79,
    unlockState: MapUnlockState.unlocked,
  );
  const available = MapLocationDto(
    id: 'loc-3',
    eventId: 'evt-1',
    title: 'Đồng bằng Bắc Bộ',
    latitude: 21.02,
    longitude: 105.85,
    unlockState: MapUnlockState.available,
  );

  UserProfileDto profile(String id) => UserProfileDto(
    id: id,
    email: '$id@test.vn',
    displayName: id,
    role: 'LEARNER',
  );

  /// MaterialApp không GoRouter — dùng cho các test không cần nav.
  Widget buildApp(_FakeMapRepository repo) {
    return ProviderScope(
      overrides: [mapRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: HistoricalMapScreen()),
    );
  }

  /// GoRouter nhỏ chỉ có /dashboard + /map — đủ kiểm back-to-home.
  Widget buildRoutedApp(_FakeMapRepository repo, {String initial = '/map'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('DASHBOARD'))),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const HistoricalMapScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [mapRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('HistoricalMapScreen — world map', () {
    testWidgets('mở tab Bản đồ thấy World Map + tiêu đề + toàn cảnh', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.text('Bản đồ Di sản'), findsOneWidget);
      expect(find.text('Tất cả Việt Nam'), findsOneWidget);
      expect(find.byType(VietnamWorldMapView), findsOneWidget);
      expect(find.byTooltip('Về toàn cảnh'), findsOneWidget);
      expect(
        find.byType(HeritageMapMarker).evaluate().length +
            find.byType(HeritageMapCluster).evaluate().length,
        greaterThan(0),
      );
    });

    testWidgets(
      'nút Quay lại điều hướng /dashboard khi không có route trước',
      (tester) async {
        final repo = _FakeMapRepository()..locations = const [available];
        await tester.pumpWidget(buildRoutedApp(repo, initial: '/map'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();

        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.byType(HistoricalMapScreen), findsNothing);
      },
    );

    testWidgets('nút Quay lại hiện cả khi loading + error + empty', (
      tester,
    ) async {
      final slowRepo = _FakeMapRepository();
      await tester.pumpWidget(buildApp(slowRepo));
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      await tester.pumpAndSettle();

      final errRepo = _FakeMapRepository()
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(buildApp(errRepo));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);

      final emptyRepo = _FakeMapRepository()..locations = const [];
      await tester.pumpWidget(buildApp(emptyRepo));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
    });

    testWidgets('chạm marker → preview + hồ sơ với CTA HỌC ĐỂ MỞ', (
      tester,
    ) async {
      final repo = _FakeMapRepository()..locations = const [locked];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('heritage-marker-loc-1')));
      await tester.pumpAndSettle();
      expect(find.text('XEM HỒ SƠ'), findsOneWidget);
      expect(find.text('HỌC ĐỂ MỞ'), findsOneWidget);

      await tester.tap(find.text('XEM HỒ SƠ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trận Bạch Đằng 938'), findsWidgets);
    });

    testWidgets('lesson CTA ẩn khi requiredLesson.accessible=false', (
      tester,
    ) async {
      const inaccessible = MapLocationDto(
        id: 'loc-x',
        eventId: 'evt-1',
        title: 'Điểm bị ẩn CTA',
        latitude: 20.9,
        longitude: 106.8,
        unlockState: MapUnlockState.locked,
        requiredLesson: RequiredLessonRef(
          lessonId: 'les-9',
          title: 'Bài đang cập nhật',
          accessible: false,
        ),
      );
      final repo = _FakeMapRepository()..locations = const [inaccessible];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('heritage-marker-loc-x')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('XEM HỒ SƠ'));
      await tester.pumpAndSettle();

      expect(find.text('HỌC ĐỂ MỞ'), findsNothing);
      expect(find.text('ÔN BÀI HỌC'), findsNothing);
      expect(find.textContaining('đang được cập nhật'), findsOneWidget);
      expect(find.text('XEM SỰ KIỆN'), findsOneWidget);
    });

    testWidgets('địa điểm AVAILABLE không lesson → chỉ nút XEM SỰ KIỆN', (
      tester,
    ) async {
      final repo = _FakeMapRepository()..locations = const [available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('heritage-marker-loc-3')));
      await tester.pumpAndSettle();
      expect(find.text('XEM SỰ KIỆN'), findsOneWidget);
      expect(find.text('ÔN BÀI HỌC'), findsNothing);
      expect(find.text('HỌC ĐỂ MỞ'), findsNothing);
    });

    testWidgets('lọc sự kiện từ bộ lọc không đổi nền bản đồ', (tester) async {
      const evt2Loc = MapLocationDto(
        id: 'loc-9',
        eventId: 'evt-2',
        eventTitle: 'Khởi nghĩa Hai Bà Trưng',
        title: 'Mê Linh',
        latitude: 21.18,
        longitude: 105.72,
        unlockState: MapUnlockState.available,
      );
      final repo = _FakeMapRepository()..locations = const [locked, evt2Loc];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bộ lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khởi nghĩa Hai Bà Trưng').last);
      await tester.pumpAndSettle();

      expect(find.byType(VietnamWorldMapView), findsOneWidget);
      expect(find.text('Khởi nghĩa Hai Bà Trưng'), findsWidgets);
      expect(find.byKey(const Key('heritage-marker-loc-9')), findsOneWidget);
    });

    testWidgets('lỗi API → trạng thái lỗi + nút Thử lại, không fallback', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);

      repo.error = null;
      repo.locations = const [available];
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();

      expect(find.byType(VietnamWorldMapView), findsOneWidget);
    });

    testWidgets('danh sách rỗng → empty state thân thiện', (tester) async {
      final repo = _FakeMapRepository()..locations = const [];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
    });

    testWidgets('320px width không overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VietnamWorldMapView), findsOneWidget);
    });

    testWidgets(
      'AC-2: địa điểm khoá vẫn hiện ghim nếu visibility = PUBLIC',
      (tester) async {
        const lockedPublic = MapLocationDto(
          id: 'loc-pub-locked',
          eventId: 'evt-1',
          eventTitle: 'Khởi nghĩa Hai Bà Trưng',
          title: 'Đền Hát Môn (Đang khoá công khai)',
          visibility: 'PUBLIC',
          unlocked: false,
          unlockState: MapUnlockState.locked,
          latitude: 21.1,
          longitude: 105.5,
        );
        const lockedHidden = MapLocationDto(
          id: 'loc-hid-locked',
          eventId: 'evt-1',
          eventTitle: 'Khởi nghĩa Hai Bà Trưng',
          title: 'Mật khu ẩn đến khi mở',
          visibility: 'HIDDEN_UNTIL_UNLOCKED',
          unlocked: false,
          unlockState: MapUnlockState.locked,
          latitude: 21.2,
          longitude: 105.6,
        );
        final repo = _FakeMapRepository()
          ..locations = const [lockedPublic, lockedHidden];
        await tester.pumpWidget(buildApp(repo));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('heritage-marker-loc-pub-locked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('heritage-marker-loc-hid-locked')),
          findsNothing,
        );
      },
    );
  });

  group('MapLocationDto v2 contract parsing', () {
    test(
      'parse đầy đủ trường v2, events, unlockLessons và lọc media theo quyền',
      () {
        final dto = MapLocationDto.fromJson({
          'id': 'loc-v2',
          'eventId': 'evt-1',
          'eventTitle': 'Đại Chiến Bạch Đằng 938',
          'slug': 'bai-coc-bach-dang',
          'title': 'Bãi cọc Bạch Đằng',
          'shortSummary': 'Trận địa cọc ngầm cửa sông',
          'description': 'Mô tả chi tiết di tích bãi cọc.',
          'latitude': 20.85,
          'longitude': 106.68,
          'kind': 'BATTLEFIELD',
          'coordinatePrecision': 'EXACT',
          'visibility': 'PUBLIC',
          'unlockMode': 'ALL',
          'unlocked': false,
          'unlockState': 'LOCKED',
          'coverAssetId': 'asset-cover-1',
          'eventIds': ['evt-1', 'evt-2'],
          'events': [
            {
              'eventId': 'evt-1',
              'title': 'Đại Chiến Bạch Đằng 938',
              'yearLabel': 'Năm 938',
              'role': 'PRIMARY',
              'sortOrder': 0,
            },
          ],
          'unlockLessons': [
            {
              'lessonId': 'les-1',
              'title': 'Chiến thuật cọc ngầm',
              'completed': false,
              'accessible': true,
            },
          ],
          'media': [
            {
              'id': 'm1',
              'mediaType': 'IMAGE_2D',
              'title': 'Ảnh công khai',
              'caption': 'Xem trước',
              'visibility': 'PUBLIC_PREVIEW',
              'sortOrder': 0,
            },
            {
              'id': 'm2',
              'mediaType': 'DOCUMENTARY_CLIP',
              'title': 'Video bí mật',
              'visibility': 'UNLOCKED_ONLY',
              'sortOrder': 1,
            },
          ],
        });

        expect(dto.slug, 'bai-coc-bach-dang');
        expect(dto.kind, 'BATTLEFIELD');
        expect(dto.kindLabelVi, 'Chiến trường cổ');
        expect(dto.hasReliableGeographicCoordinate, isTrue);
        expect(dto.isPublicVisibility, isTrue);
        expect(dto.shouldDisplayOnMap, isTrue);
        expect(dto.unlocked, isFalse);
        expect(dto.events.single.yearLabel, 'Năm 938');
        expect(dto.unlockLessons.single.lessonId, 'les-1');
        // Khi đang khoá, chỉ media PUBLIC_PREVIEW được hiển thị.
        expect(dto.visibleMedia.length, 1);
        expect(dto.imageMedia.single.title, 'Ảnh công khai');
        expect(dto.videoMedia, isEmpty);
      },
    );
  });
  group('groupChapters', () {
    test('nhóm theo eventId, giữ input order, fallback title', () {
      const a = MapLocationDto(
        id: 'a',
        eventId: 'e1',
        eventTitle: 'Sự kiện 1',
        title: 'A',
        latitude: 0,
        longitude: 0,
        unlockState: MapUnlockState.available,
      );
      const b = MapLocationDto(
        id: 'b',
        eventId: 'e2',
        title: 'B',
        latitude: 0,
        longitude: 0,
        unlockState: MapUnlockState.available,
      );
      const c = MapLocationDto(
        id: 'c',
        eventId: 'e1',
        title: 'C',
        latitude: 0,
        longitude: 0,
        unlockState: MapUnlockState.locked,
      );
      final chapters = groupChapters(const [a, b, c]);
      expect(chapters.length, 2);
      expect(chapters[0].eventId, 'e1');
      expect(chapters[0].title, 'Sự kiện 1');
      expect(chapters[0].locations.map((l) => l.id), ['a', 'c']);
      expect(chapters[1].eventId, 'e2');
      // Fallback khi không có eventTitle.
      expect(chapters[1].title, 'Chặng 2');
      expect(chapters[1].locations.map((l) => l.id), ['b']);
    });

    test('dataset rỗng → không chapter', () {
      expect(groupChapters(const []), isEmpty);
    });
  });

  group('JourneyLayout', () {
    test('node xen kẽ trái/phải, trong bounds, không trùng', () {
      const w = 360.0;
      final centers = JourneyLayout.centers(4, w);
      expect(centers.length, 4);
      // Lane 0.28 / 0.72 xen kẽ.
      expect(centers[0].dx, closeTo(w * 0.28, 0.1));
      expect(centers[1].dx, closeTo(w * 0.72, 0.1));
      expect(centers[2].dx, closeTo(w * 0.28, 0.1));
      expect(centers[3].dx, closeTo(w * 0.72, 0.1));
      // Không 2 tâm nào trùng.
      final set = centers.map((o) => '${o.dx},${o.dy}').toSet();
      expect(set.length, 4);
      // Y tăng dần, trong canvas.
      for (int i = 0; i < 3; i++) {
        expect(centers[i].dy, lessThan(centers[i + 1].dy));
      }
      expect(centers.last.dy, lessThan(JourneyLayout.canvasHeight(4)));
    });

    test('canvasHeight tăng theo số node', () {
      expect(
        JourneyLayout.canvasHeight(1),
        lessThan(JourneyLayout.canvasHeight(5)),
      );
    });
  });

  group('JourneyPathPainter', () {
    test('không crash khi < 2 node', () {
      final p = JourneyPathPainter(
        centers: const [Offset(100, 100)],
        states: const [MapUnlockState.available],
      );
      // Không ném — repaint logic.
      expect(p.shouldRepaint(p), isFalse);
    });
  });

  group('mapLocationsProvider session scoping (P1)', () {
    test(
      'đổi auth session → provider refetch, không lộ state giữa users',
      () async {
        final repoA = _FakeMapRepository()..locations = const [unlocked];
        final containerA = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repoA),
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthState.authenticated(profile('user-a'))),
            ),
          ],
        );
        addTearDown(containerA.dispose);

        final listA = await containerA.read(mapLocationsProvider.future);
        expect(listA.single.unlockState, MapUnlockState.unlocked);
        expect(repoA.calls, 1);

        final repoB = _FakeMapRepository()..locations = const [locked];
        final containerB = ProviderContainer(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repoB),
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthState.authenticated(profile('user-b'))),
            ),
          ],
        );
        addTearDown(containerB.dispose);

        final listB = await containerB.read(mapLocationsProvider.future);
        expect(listB.single.unlockState, MapUnlockState.locked);
        expect(repoB.calls, 1);
      },
    );

    test(
      'auth status change trong cùng container → refetch đúng phiên',
      () async {
        final repo = _FakeMapRepository()..locations = const [locked];
        final container = ProviderContainer(
          overrides: [mapRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        container.read(authSessionProvider.notifier).state =
            const AuthState.unknown();
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, 1);

        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('user-a'));
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(2));

        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('user-b'));
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(3));

        container.read(authSessionProvider.notifier).state =
            const AuthState.unauthenticated();
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(4));
      },
    );
  });
}
