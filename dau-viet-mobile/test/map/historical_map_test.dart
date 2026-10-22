import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/core/widgets/parchment_card.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Widget buildApp(_FakeMapRepository repo) {
    return ProviderScope(
      overrides: [mapRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: HistoricalMapScreen()),
    );
  }

  group('HistoricalMapScreen', () {
    testWidgets('hiển thị cả 3 trạng thái địa điểm trong danh sách', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bến Bạch Đằng'), findsWidgets);
      expect(find.text('Cửa Lạch Trường'), findsWidgets);
      expect(find.text('Đồng bằng Bắc Bộ'), findsWidgets);
      // Phụ đề trạng thái
      expect(find.text('Mở khoá bằng: Trận Bạch Đằng 938'), findsOneWidget);
      expect(find.text('Đã mở khoá — nhấn để xem chi tiết'), findsOneWidget);
      expect(find.text('Sẵn sàng khám phá'), findsOneWidget);
    });

    testWidgets('chạm địa điểm LOCKED → sheet hiện CTA "HỌC ĐỂ MỞ"', (
      tester,
    ) async {
      final repo = _FakeMapRepository()..locations = const [locked];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bến Bạch Đằng').first);
      await tester.pumpAndSettle();

      expect(find.text('HỌC ĐỂ MỞ'), findsOneWidget);
      expect(find.textContaining('Trận Bạch Đằng 938'), findsWidgets);
      // FR-38: event title hiển thị trong sheet.
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

      // Không có CTA "HỌC ĐỂ MỞ" giả — chỉ có giải thích.
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
      // Không có nút "ÔN BÀI HỌC" mờ/vô nghĩa cho AVAILABLE không lesson.
      expect(find.text('ÔN BÀI HỌC'), findsNothing);
      expect(find.text('HỌC ĐỂ MỞ'), findsNothing);
    });

    testWidgets('bản đồ pan/zoom được (InteractiveViewer) + nút reset', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('Về khung nhìn ban đầu'), findsOneWidget);

      // Pan canvas — không lỗi, marker vẫn render sau transform.
      await tester.drag(find.byType(InteractiveViewer), const Offset(60, 40));
      await tester.pump();
      expect(find.text('Bến Bạch Đằng'), findsWidgets);

      await tester.tap(find.byTooltip('Về khung nhìn ban đầu'));
      await tester.pumpAndSettle();
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

      // Chạm item trong danh sách fallback (marker có thể nằm ngoài
      // viewport của InteractiveViewer).
      await tester.tap(find.byType(ParchmentCard).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
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

        // User B với repo riêng — KHÔNG thấy cache UNLOCKED của A.
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

        // Phiên restoring → key 'restoring'.
        container.read(authSessionProvider.notifier).state =
            const AuthState.unknown();
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, 1);

        // Login user-a → phiên đổi → refetch (không dùng cache phiên trước).
        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('user-a'));
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(2));

        // Switch sang user-b → refetch lần nữa — state mới fetch riêng.
        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('user-b'));
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(3));

        // Logout → phiên 'anon' đổi lại → refetch, không giữ cache user.
        container.read(authSessionProvider.notifier).state =
            const AuthState.unauthenticated();
        await container.read(mapLocationsProvider.future);
        expect(repo.calls, greaterThanOrEqualTo(4));
      },
    );
  });
}
