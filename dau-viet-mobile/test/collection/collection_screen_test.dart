import 'dart:async';

import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/core/theme/dau_viet_colors.dart';
import 'package:dau_viet_mobile/core/widgets/stamp_seal_badge.dart';
import 'package:dau_viet_mobile/core/widgets/tactile_card.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_dto.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_providers.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_repository.dart';
import 'package:dau_viet_mobile/features/collection/data/dossier_dto.dart';
import 'package:dau_viet_mobile/features/collection/data/event_progress_dto.dart';
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

  /// Types tự suy ra từ items (giả lập endpoint /types). Test nào cần
  /// loại ở trang sau set `extraTypes`.
  List<String>? extraTypes;

  @override
  Future<List<String>> availableTypes() async {
    if (extraTypes != null) return extraTypes!;
    return items
        .map((i) => i.evidenceType)
        .whereType<String>()
        .toSet()
        .toList();
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

  // GAME-04 — dossier/progress endpoints; màn này test tab Dấu nên mặc
  // định trả rỗng, test riêng cho dossier tab sẽ override.
  List<DossierSummaryDto> dossierItems = const [];

  @override
  Future<DossierPageDto> listDossiers({
    String? type,
    String? eventId,
    bool? unlocked,
    int page = 0,
    int size = 20,
  }) async {
    if (error != null) throw error!;
    final filtered = dossierItems
        .where((d) => type == null || d.dossierType == type)
        .toList();
    return DossierPageDto(
      content: filtered,
      page: page,
      size: size,
      totalElements: filtered.length,
      totalPages: 1,
    );
  }

  @override
  Future<DossierDetailDto> dossierDetail(String dossierId) async {
    if (error != null) throw error!;
    throw const ApiException(
      ApiError(code: 'DOSSIER_NOT_FOUND', message: 'Không tìm thấy hồ sơ.'),
      statusCode: 404,
    );
  }

  @override
  Future<EventProgressDto> eventProgress(String eventId) async {
    if (error != null) throw error!;
    return const EventProgressDto(
      eventId: '',
      status: 'NOT_CONFIGURED',
      requiredLessonsTotal: 0,
      requiredLessonsCompleted: 0,
      eventCompleted: false,
      eventMastered: false,
      requiredLessons: [],
      unlockedDossiersCount: 0,
    );
  }
}

/// Repo cho phép delay response trang kế bằng Completer — test dispose/
/// switch-session giữa chừng request (§2).
class _DelayedCollectionRepository extends _FakeCollectionRepository {
  /// Khi non-null, request `list` trang ≥1 chờ Completer này resolve.
  Completer<CollectionPageDto>? pendingPage;

  @override
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    if (page >= 1 && pendingPage != null) return pendingPage!.future;
    return super.list(type: type, eventId: eventId, page: page, size: size);
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

    // §3 — chip cho loại chỉ có ở trang sau: server /types trả đủ loại
    // nên chip hiện ngay dù trang 1 không chứa item đó.
    testWidgets('loại chỉ ở trang sau vẫn có chip nhờ endpoint types', (
      tester,
    ) async {
      final repo = _FakeCollectionRepository()
        ..items = const [item1]
        ..extraTypes = const ['ARTIFACT', 'FOLKLORE'];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      // FOLKLORE không có trong trang 1 nhưng chip vẫn render.
      expect(find.text('FOLKLORE'), findsOneWidget);
    });

    // §3 — label count khi đang filter phải nói rõ là số của loại,
    // không hiển thị như tổng collection.
    testWidgets('count label khi filter ghi rõ là của loại đó', (tester) async {
      final repo = _FakeCollectionRepository()..items = const [item1, item2];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('2 bằng chứng đã sưu tầm'), findsOneWidget);

      await tester.tap(find.text('Tư liệu'));
      await tester.pumpAndSettle();
      expect(find.text('1 bằng chứng thuộc loại này'), findsOneWidget);
    });

    testWidgets('empty state khi chưa collect gì', (tester) async {
      final repo = _FakeCollectionRepository()..items = const [];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có dấu vết'), findsOneWidget);
      expect(find.textContaining('bài học'), findsOneWidget);
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

    testWidgets(
      'Soft Heritage Card UI: đồng bộ bóng mềm, viền mảnh 1.1px, không còn pixelShadowSm/StampSealBadge và 0 overflow trên 360x800 & 390x844',
      (tester) async {
        final repo = _FakeCollectionRepository()
          ..items = const [item1, item2]
          ..dossierItems = const [
            DossierSummaryDto(
              dossierId: 'd1',
              canonicalCode: 'person-ngo-quyen',
              dossierType: 'PERSON',
              title: 'Ngô Quyền',
              summary: 'Tiền Ngô Vương người lãnh đạo trận Bạch Đằng 938.',
              unlocked: true,
              preview: false,
            ),
          ];

        for (final size in const [Size(360, 800), Size(390, 844)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey(size),
              overrides: [collectionRepositoryProvider.overrideWithValue(repo)],
              child: const MaterialApp(home: CollectionScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        expect(find.byType(StampSealBadge), findsNothing);
        final cards = tester
            .widgetList<TactileCard>(find.byType(TactileCard))
            .toList();
        expect(cards.length, greaterThanOrEqualTo(2));
        for (final card in cards) {
          expect(card.usePixelShadow, isFalse);
          expect(card.borderWidth, closeTo(1.1, 0.05));
        }

        final containers = tester.widgetList<Container>(find.byType(Container));
        for (final c in containers) {
          final dec = c.decoration;
          if (dec is BoxDecoration && dec.boxShadow != null) {
            for (final shadow in dec.boxShadow!) {
              expect(
                shadow.color == DauVietColors.pixelShadowColor &&
                    shadow.blurRadius == 0,
                isFalse,
              );
            }
          }
        }

        // Chuyển sang tab Nhân vật -> DossierCard cũng hiển thị theo Soft Heritage Card
        await tester.tap(find.widgetWithText(Tab, 'Nhân vật'));
        await tester.pumpAndSettle();
        expect(find.text('Ngô Quyền'), findsOneWidget);
        final dossierCards = tester
            .widgetList<TactileCard>(find.byType(TactileCard))
            .toList();
        expect(dossierCards, isNotEmpty);
        for (final card in dossierCards) {
          expect(card.usePixelShadow, isFalse);
          expect(card.borderWidth, closeTo(1.1, 0.05));
        }
      },
    );
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

    // §2 — loadMore await xong SAU KHI provider dispose: không setState,
    // không ném lỗi (ref.mounted guard).
    test(
      'dispose giữa loadMore → response trễ bị bỏ qua, không crash',
      () async {
        const item3 = CollectionItemDto(
          evidenceId: 'e3',
          evidenceType: 'LOCATION',
          evidence: EvidenceSnapshotDto(title: 'Đèo Ngang'),
        );
        final completer = Completer<CollectionPageDto>();
        final repo = _DelayedCollectionRepository()
          ..items = const [item1]
          ..pageTwo = const [item3]
          ..pendingPage = completer;
        final container = ProviderContainer(
          overrides: [
            collectionRepositoryProvider.overrideWithValue(repo),
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(AuthState.authenticated(profile('u-a'))),
            ),
          ],
        );

        await container.read(collectionListProvider('').future);
        // Giữ sub để loadMore chạy được, rồi gọi loadMore và dispose giữa chừng.
        final sub = container.listen(collectionListProvider(''), (_, _) {});
        final pending = container
            .read(collectionListProvider('').notifier)
            .loadMore();

        // Dispose provider (huỷ listen → autoDispose unmount).
        sub.close();
        completer.complete(
          const CollectionPageDto(
            content: [item3],
            page: 1,
            size: 20,
            totalElements: 2,
            totalPages: 2,
          ),
        );
        await pending; // không ném — ref.mounted=false → bỏ qua kết quả.
        container.dispose();
      },
    );

    // §2 — switch A→B giữa request trang 2: B không nhận items của A.
    test(
      'đổi user giữa loadMore → phiên mới không lẫn items phiên cũ',
      () async {
        const itemB = CollectionItemDto(
          evidenceId: 'eB',
          evidenceType: 'DOCUMENT',
          evidence: EvidenceSnapshotDto(title: 'Của B'),
        );
        final completer = Completer<CollectionPageDto>();
        final repoA = _DelayedCollectionRepository()
          ..items = const [item1]
          ..pageTwo = const [item1]
          ..pendingPage = completer;
        final auth = _FakeAuthRepository(
          AuthState.authenticated(profile('u-a')),
        );
        final container = ProviderContainer(
          overrides: [
            collectionRepositoryProvider.overrideWithValue(repoA),
            authRepositoryProvider.overrideWithValue(auth),
          ],
        );
        addTearDown(container.dispose);

        final listA = await container.read(collectionListProvider('').future);
        expect(listA.items.single.evidenceId, 'e1');

        // Bắt đầu loadMore của phiên A (pending).
        final pending = container
            .read(collectionListProvider('').notifier)
            .loadMore();

        // Đổi sang user B TRƯỚC KHI response về.
        container.read(authSessionProvider.notifier).state =
            AuthState.authenticated(profile('u-b'));
        // Repo giờ trả data B cho page 0 của phiên mới.
        repoA.items = const [itemB];
        completer.complete(
          const CollectionPageDto(
            content: [item1], // response trễ của A
            page: 1,
            size: 20,
            totalElements: 2,
            totalPages: 2,
          ),
        );
        await pending;

        final listB = await container.read(collectionListProvider('').future);
        // B chỉ thấy items của B — page-2 response của A không lẫn vào.
        expect(listB.items.map((i) => i.evidenceId), ['eB']);
      },
    );

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
