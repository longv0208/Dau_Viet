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
import 'package:dau_viet_mobile/features/map/presentation/journey_map_node.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_path_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeMapRepository implements MapRepository {
  List<MapLocationDto> locations = const [];
  Object? error;
  int calls = 0;

  @override
  Future<List<MapLocationDto>> listLocations() async {
    calls++;
    if (error != null) throw error!;
    return locations;
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

  group('HistoricalMapScreen — journey', () {
    testWidgets('hiển thị back "Về Học tập" + tiêu đề + legend + progress', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Về Học tập'), findsOneWidget);
      expect(find.text('Bản Đồ Dấu Ấn'), findsOneWidget);
      expect(find.text('Đã mở khoá'), findsOneWidget);
      expect(find.text('Sẵn sàng'), findsOneWidget);
      expect(find.text('Chưa mở'), findsOneWidget);
      // Progress chỉ đếm UNLOCKED (1/3).
      expect(find.textContaining('Đã khám phá 1 / 3 địa điểm'), findsOneWidget);
      // Disclaimer hành trình minh họa.
      expect(
        find.textContaining('không thể hiện tuyến đường thực tế'),
        findsOneWidget,
      );
      // Chapter header với tên sự kiện.
      expect(find.text('Trận Bạch Đằng 938'), findsOneWidget);
      expect(find.textContaining('Chặng 1 / 1'), findsOneWidget);
      // Tất cả 3 node render trên canvas.
      expect(find.byType(JourneyMapNode), findsNWidgets(3));
    });

    testWidgets(
      'back "Về Học tập" điều hướng /dashboard khi không có route trước',
      (tester) async {
        final repo = _FakeMapRepository()..locations = const [available];
        await tester.pumpWidget(buildRoutedApp(repo, initial: '/map'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Về Học tập'));
        await tester.pumpAndSettle();

        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.byType(HistoricalMapScreen), findsNothing);
      },
    );

    testWidgets('back "Về Học tập" hiện cả khi loading + error + empty', (
      tester,
    ) async {
      // Loading: repo chưa resolve — dùng completer thủ công thay vì delay.
      final slowRepo = _FakeMapRepository();
      // Đẩy pumpWidget trước khi repo trả data — loading state.
      await tester.pumpWidget(buildApp(slowRepo));
      expect(find.byTooltip('Về Học tập'), findsOneWidget);
      await tester.pumpAndSettle();

      // Error state.
      final errRepo = _FakeMapRepository()
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(buildApp(errRepo));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Về Học tập'), findsOneWidget);
      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);

      // Empty state.
      final emptyRepo = _FakeMapRepository()..locations = const [];
      await tester.pumpWidget(buildApp(emptyRepo));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Về Học tập'), findsOneWidget);
      expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
    });

    testWidgets('chạm node → sheet chi tiết với CTA "HỌC ĐỂ MỞ"', (
      tester,
    ) async {
      final repo = _FakeMapRepository()..locations = const [locked];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bến Bạch Đằng').first);
      await tester.pumpAndSettle();

      expect(find.text('HỌC ĐỂ MỞ'), findsOneWidget);
      expect(find.textContaining('Trận Bạch Đằng 938'), findsWidgets);
      expect(find.textContaining('Thuộc sự kiện'), findsOneWidget);
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

      await tester.tap(find.text('Điểm bị ẩn CTA').first);
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

      await tester.tap(find.text('Đồng bằng Bắc Bộ').first);
      await tester.pumpAndSettle();

      expect(find.text('XEM SỰ KIỆN'), findsOneWidget);
      expect(find.text('ÔN BÀI HỌC'), findsNothing);
      expect(find.text('HỌC ĐỂ MỞ'), findsNothing);
    });

    testWidgets('nhiều eventId → nhiều chặng, điều hướng prev/next đúng', (
      tester,
    ) async {
      const evt2Loc = MapLocationDto(
        id: 'loc-9',
        eventId: 'evt-2',
        eventTitle: 'Hai Bà Trưng 40',
        title: 'Mê Linh',
        latitude: 21.18,
        longitude: 105.72,
        unlockState: MapUnlockState.available,
      );
      final repo = _FakeMapRepository()..locations = const [locked, evt2Loc];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      // Chặng 1: evt-1 (Trận Bạch Đằng) — chỉ thấy Bến Bạch Đằng.
      expect(find.text('Chặng 1 / 2 • 1 địa điểm'), findsOneWidget);
      expect(find.text('Bến Bạch Đằng'), findsWidgets);
      expect(find.text('Mê Linh'), findsNothing);

      // Next → chặng 2.
      await tester.tap(find.byTooltip('Chặng sau'));
      await tester.pumpAndSettle();
      expect(find.text('Chặng 2 / 2 • 1 địa điểm'), findsOneWidget);
      expect(find.text('Hai Bà Trưng 40'), findsOneWidget);
      expect(find.text('Mê Linh'), findsWidgets);
      expect(find.text('Bến Bạch Đằng'), findsNothing);

      // Prev → lại chặng 1.
      await tester.tap(find.byTooltip('Chặng trước'));
      await tester.pumpAndSettle();
      expect(find.text('Bến Bạch Đằng'), findsWidgets);
    });

    testWidgets('chapter không có eventTitle → fallback "Chặng N"', (
      tester,
    ) async {
      const noTitle = MapLocationDto(
        id: 'loc-no-title',
        eventId: 'evt-x',
        title: 'Điểm không tên',
        latitude: 21.0,
        longitude: 106.0,
        unlockState: MapUnlockState.available,
      );
      final repo = _FakeMapRepository()..locations = const [noTitle];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chặng 1'), findsOneWidget);
      expect(find.text('Chặng 1 / 1 • 1 địa điểm'), findsOneWidget);
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

      expect(find.text('Đồng bằng Bắc Bộ'), findsWidgets);
    });

    testWidgets('danh sách rỗng → empty state thân thiện', (tester) async {
      final repo = _FakeMapRepository()..locations = const [];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
    });

    testWidgets('sheet scroll được với mô tả dài (không overflow)', (
      tester,
    ) async {
      final longDesc = MapLocationDto(
        id: 'loc-long',
        eventId: 'evt-1',
        title: 'Địa điểm mô tả rất dài',
        description: 'Nội dung dài. ' * 400,
        latitude: 20.9,
        longitude: 106.8,
        unlockState: MapUnlockState.unlocked,
      );
      tester.view.physicalSize = const Size(400, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeMapRepository()..locations = [longDesc];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(JourneyMapNode).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
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
      expect(find.byType(JourneyMapNode), findsNWidgets(3));
    });
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
