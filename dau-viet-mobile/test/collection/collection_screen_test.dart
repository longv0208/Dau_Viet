import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_dto.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_providers.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_repository.dart';
import 'package:dau_viet_mobile/features/collection/presentation/collection_screen.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCollectionRepository implements CollectionRepository {
  List<CollectionItemDto> items = const [];
  Object? error;
  int listCalls = 0;
  int detailCalls = 0;

  // Trang kế khi loadMore (tuỳ chọn); nếu null dùng `items` cho cả trang 0.
  List<CollectionItemDto>? pageTwo;

  @override
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    listCalls++;
    if (error != null) throw error!;
    final filtered = items
        .where((i) => type == null || i.evidenceType == type)
        .toList();
    if (page == 1) {
      return CollectionPageDto(
        content: pageTwo ?? const [],
        page: 1,
        size: size,
        totalElements: filtered.length + (pageTwo?.length ?? 0),
        totalPages: 2,
      );
    }
    final hasMore = pageTwo != null && pageTwo!.isNotEmpty;
    return CollectionPageDto(
      content: filtered,
      page: 0,
      size: size,
      totalElements: filtered.length + (pageTwo?.length ?? 0),
      totalPages: hasMore ? 2 : 1,
    );
  }

  @override
  Future<CollectionItemDto> detail(String evidenceId) async {
    detailCalls++;
    for (final i in items) {
      if (i.evidenceId == evidenceId) return i;
    }
    throw const ApiException(
      ApiError(
        code: 'COLLECTION_ITEM_NOT_FOUND',
        message: 'Không tìm thấy mục.',
      ),
      statusCode: 404,
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
  const item1 = CollectionItemDto(
    evidenceId: 'e1',
    evidenceType: 'ARTIFACT',
    collectedAt: '2025-10-20T10:00:00Z',
    eventId: 'evt-1',
    eventTitle: 'Bạch Đằng 938',
    lessonTitle: 'Cọc ngầm',
    evidence: EvidenceSnapshotDto(
      title: 'Bãi cọc Yên Giang',
      description: 'Di chỉ cọc ngầm niên đại C-14.',
      source: EvidenceSourceDto(title: 'Bảo tàng Lịch sử'),
    ),
  );
  const item2 = CollectionItemDto(
    evidenceId: 'e2',
    evidenceType: 'DOCUMENT',
    collectedAt: '2025-10-18T08:00:00Z',
    eventId: 'evt-1',
    eventTitle: 'Bạch Đằng 938',
    evidence: EvidenceSnapshotDto(title: 'Đại Việt sử ký toàn thư'),
  );

  UserProfileDto profile(String id) =>
      UserProfileDto(id: id, email: '$id@test.vn', role: 'LEARNER');

  Widget buildApp(_FakeCollectionRepository repo) {
    return ProviderScope(
      overrides: [collectionRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: CollectionScreen()),
    );
  }

  group('CollectionScreen', () {
    testWidgets('hiển thị danh sách bằng chứng + count từ API', (tester) async {
      final repo = _FakeCollectionRepository()..items = const [item1, item2];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bãi cọc Yên Giang'), findsOneWidget);
      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(find.text('2 bằng chứng đã sưu tầm'), findsOneWidget);
      // Type badge
      expect(find.text('HIỆN VẬT'), findsOneWidget);
      expect(find.text('TƯ LIỆU'), findsOneWidget);
    });

    testWidgets('filter DOCUMENT chỉ hiện đúng loại', (tester) async {
      final repo = _FakeCollectionRepository()..items = const [item1, item2];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tư liệu'));
      await tester.pumpAndSettle();

      expect(find.text('Đại Việt sử ký toàn thư'), findsOneWidget);
      expect(find.text('Bãi cọc Yên Giang'), findsNothing);
    });

    testWidgets('empty state khi chưa collect gì', (tester) async {
      final repo = _FakeCollectionRepository()..items = const [];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bộ sưu tập còn trống'), findsOneWidget);
      expect(find.textContaining('chọn bằng chứng'), findsOneWidget);
    });

    testWidgets('lỗi API → trạng thái lỗi + THỬ LẠI, không fallback', (
      tester,
    ) async {
      final repo = _FakeCollectionRepository()
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);

      repo.error = null;
      repo.items = const [item1];
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();

      expect(find.text('Bãi cọc Yên Giang'), findsOneWidget);
    });

    testWidgets('load-more khi hasMore — trang 2 append vào list', (
      tester,
    ) async {
      const item3 = CollectionItemDto(
        evidenceId: 'e3',
        evidenceType: 'LOCATION',
        evidence: EvidenceSnapshotDto(title: 'Đèo Ngang'),
      );
      final repo = _FakeCollectionRepository()
        ..items = const [item1]
        ..pageTwo = const [item3];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Xem thêm'), findsOneWidget);
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();

      expect(find.text('Đèo Ngang'), findsOneWidget);
      // pageTwo rỗng → hasMore=false sau khi load.
      expect(find.text('Xem thêm'), findsNothing);
    });

    // P2-B — lỗi load-more: items cũ giữ nguyên, banner lỗi + retry đúng
    // trang kế, không auto-retry, không mất items đã có.
    testWidgets('load-more lỗi → banner THỬ LẠI, items giữ, retry đúng trang', (
      tester,
    ) async {
      const item3 = CollectionItemDto(
        evidenceId: 'e3',
        evidenceType: 'LOCATION',
        evidence: EvidenceSnapshotDto(title: 'Đèo Ngang'),
      );
      final repo = _FakeCollectionRepository()
        ..items = const [item1]
        ..pageTwo = const [item3];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      // Inject lỗi cho trang 2.
      repo.error = const ApiException(
        ApiError(code: 'NETWORK_ERROR', message: 'down'),
      );
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();

      // Items trang 1 vẫn hiện, banner lỗi xuất hiện.
      expect(find.text('Bãi cọc Yên Giang'), findsOneWidget);
      expect(find.text('Đèo Ngang'), findsNothing);
      expect(
        find.text('Chưa tải thêm được. Kiểm tra kết nối rồi thử lại.'),
        findsOneWidget,
      );
      expect(find.text('THỬ LẠI'), findsOneWidget);
      // Không auto-retry: bấm "THỬ LẠI" mới đánh tiếp trang 2.
      repo.error = null;
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();

      expect(find.text('Đèo Ngang'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsNothing);
    });
  });

  group('collectionListProvider session scoping', () {
    test('đổi auth session → refetch, không lộ items giữa users', () async {
      final repoA = _FakeCollectionRepository()..items = const [item1];
      final containerA = ProviderContainer(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(repoA),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(AuthState.authenticated(profile('u-a'))),
          ),
        ],
      );
      addTearDown(containerA.dispose);

      final listA = await containerA.read(collectionListProvider('').future);
      expect(listA.items.single.evidenceId, 'e1');
      expect(repoA.listCalls, 1);

      final repoB = _FakeCollectionRepository()..items = const [item2];
      final containerB = ProviderContainer(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(repoB),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(AuthState.authenticated(profile('u-b'))),
          ),
        ],
      );
      addTearDown(containerB.dispose);

      final listB = await containerB.read(collectionListProvider('').future);
      expect(listB.items.single.evidenceId, 'e2');
      expect(repoB.listCalls, 1);
    });

    test(
      'auth status change trong cùng container → refetch đúng phiên',
      () async {
        final repo = _FakeCollectionRepository()..items = const [item1];
        final container = ProviderContainer(
          overrides: [
            collectionRepositoryProvider.overrideWithValue(repo),
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthState.authenticated(profile('u-a'))),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(collectionListProvider('').future);
        expect(repo.listCalls, 1);

        // Đổi phiên → rebuild → refetch.
        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('u-b'));
        await container.read(collectionListProvider('').future);
        expect(repo.listCalls, greaterThanOrEqualTo(2));
      },
    );
  });
}
