import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import 'api_collection_repository.dart';
import 'collection_api_client.dart';
import 'collection_dto.dart';
import 'collection_repository.dart';
import 'mock_collection_repository.dart';

final collectionApiClientProvider = Provider<CollectionApiClient>(
  (ref) => CollectionApiClient(ref.watch(apiClientProvider)),
);

/// USE_MOCK → demo repo; real → ApiCollectionRepository (không fallback).
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  if (ApiConfig.useMock) return MockCollectionRepository();
  return ApiCollectionRepository(ref.watch(collectionApiClientProvider));
});

Duration? _noRetry(int retryCount, Object error) => null;

/// Khóa phiên — đổi tài khoản/logout → provider rebuild, không tái dùng
/// cache bộ sưu tập của phiên trước.
String _collectionSessionKey(AuthState auth) {
  if (ApiConfig.useMock) return 'mock';
  switch (auth.status) {
    case AuthStatus.authenticated:
      return 'user:${auth.profile?.id ?? 'unknown'}';
    case AuthStatus.unknown:
      return 'restoring';
    case AuthStatus.guest:
      return 'guest';
    case AuthStatus.unauthenticated:
      return 'anon';
  }
}

/// Trạng thái danh sách phân trang tích lũy: items đã tải + trang kế.
class CollectionListState {
  final List<CollectionItemDto> items;
  final int nextPage;
  final bool hasMore;
  final bool isLoadingMore;
  final int totalElements;

  /// Lỗi load-more lần trước — UI hiện banner retry nhẹ thay vì nuốt lỗi.
  final Object? loadMoreError;

  const CollectionListState({
    this.items = const [],
    this.nextPage = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.totalElements = 0,
    this.loadMoreError,
  });

  CollectionListState copyLoadingMore() => CollectionListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: true,
    totalElements: totalElements,
    loadMoreError: loadMoreError,
  );

  CollectionListState copyLoadMoreError(Object error) => CollectionListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: false,
    totalElements: totalElements,
    loadMoreError: error,
  );

  CollectionListState copyClearError() => CollectionListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: false,
    totalElements: totalElements,
    loadMoreError: null,
  );
}

/// Bộ sưu tập theo filter loại — family key `String?` ('' = tất cả).
/// Session-aware: watch authSessionProvider buộc rebuild khi đổi phiên.
final collectionListProvider = AsyncNotifierProvider.autoDispose
    .family<CollectionListNotifier, CollectionListState, String?>(
      (arg) => CollectionListNotifier(arg),
    );

class CollectionListNotifier extends AsyncNotifier<CollectionListState> {
  CollectionListNotifier(this._typeKey);

  static const int _pageSize = 20;

  /// Arg truyền từ family — Riverpod 3 không còn FamilyAsyncNotifier nên
  /// arg đi qua constructor thay vì `this.arg`.
  final String? _typeKey;

  String? get _type => (_typeKey == null || _typeKey.isEmpty) ? null : _typeKey;

  /// Generation đổi mỗi lần session/filter đổi — chặn response trễ của request
  /// cũ ghi đè state của request mới (P1-B).
  int _generation = 0;

  /// Session key đã capture lúc `build()` — loadMore đối chiếu khi resolve.
  String? _sessionAtBuild;

  @override
  Future<CollectionListState> build() async {
    _generation++; // mỗi build (mới / rebuild sau session đổi) = thế hệ mới
    final sessionKey = _collectionSessionKey(ref.watch(authSessionProvider));
    _sessionAtBuild = sessionKey;
    assert(sessionKey.isNotEmpty);
    final repo = ref.watch(collectionRepositoryProvider);
    final page = ApiConfig.useMock
        ? await repo.list(type: _type, page: 0, size: _pageSize)
        : await ref
              .read(authRepositoryProvider)
              .withAuth(() => repo.list(type: _type, page: 0, size: _pageSize));
    return CollectionListState(
      items: page.content,
      nextPage: page.content.isEmpty ? 0 : 1,
      hasMore: page.hasMore,
      totalElements: page.totalElements,
    );
  }

  /// Tải trang kế (load-more). Chặn duplicate concurrent, stale session/
  /// generation, dispose. Lỗi trả về giữ items cũ + banner retry (P2-B).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    // Chống tap kép: flag trong state đã ngăn awaiter thứ hai vào đây vì
    // `current.isLoadingMore` đọc trước khi setState — dùng biến local.
    final int generation = _generation;
    final String? session = _sessionAtBuild;

    state = AsyncData(current.copyLoadingMore());
    try {
      final repo = ref.read(collectionRepositoryProvider);
      final page = ApiConfig.useMock
          ? await repo.list(
              type: _type,
              page: current.nextPage,
              size: _pageSize,
            )
          : await ref
                .read(authRepositoryProvider)
                .withAuth(
                  () => repo.list(
                    type: _type,
                    page: current.nextPage,
                    size: _pageSize,
                  ),
                );

      // Chặn response trễ: notifier đã dispose (autoDispose khi rời
      // màn), session đổi (đăng xuất / đổi tài khoản) hoặc provider đã
      // rebuild (filter khác) → bỏ qua kết quả. ref.mounted phải check
      // TRƯỚC mọi ref.read/set state sau await — đọc provider khi đã
      // unmounted ném StateError.
      if (!ref.mounted ||
          !identical(_sessionAtBuild, session) ||
          _generation != generation ||
          _collectionSessionKey(ref.read(authSessionProvider)) != session) {
        return;
      }
      state = AsyncData(
        CollectionListState(
          items: [...current.items, ...page.content],
          nextPage: current.nextPage + 1,
          hasMore: page.hasMore,
          totalElements: page.totalElements,
        ),
      );
    } catch (e) {
      // Giữ items + error state cho banner retry — KHÔNG advance nextPage.
      // Lỗi trễ sau dispose/session đổi cũng không được ghi vào state mới.
      if (ref.mounted &&
          _generation == generation &&
          identical(_sessionAtBuild, session)) {
        state = AsyncData(current.copyLoadMoreError(e));
      }
    }
  }

  /// Chỉ xoá cờ lỗi (banner) — KHÔNG tự retry; retry = người dùng bấm.
  void clearLoadMoreError() {
    final current = state.value;
    if (current == null || current.loadMoreError == null) return;
    state = AsyncData(current.copyClearError());
  }
}

/// Các evidence_type learner đã collect trên TOÀN collection — nguồn
/// filter chips đủ loại kể cả loại chỉ ở trang sau (P2-D). Session-aware:
/// rebuild khi đổi tài khoản; một call nhẹ, không tải toàn bộ items.
final collectionTypesProvider = FutureProvider.autoDispose<List<String>>(
  retry: _noRetry,
  (ref) {
    final sessionKey = _collectionSessionKey(ref.watch(authSessionProvider));
    assert(sessionKey.isNotEmpty);
    final repo = ref.watch(collectionRepositoryProvider);
    if (ApiConfig.useMock) return repo.availableTypes();
    return ref.read(authRepositoryProvider).withAuth(repo.availableTypes);
  },
);

/// Chi tiết một mục — family theo evidenceId, session-aware.
final collectionDetailProvider = FutureProvider.autoDispose
    .family<CollectionItemDto, String>(retry: _noRetry, (ref, evidenceId) {
      final sessionKey = _collectionSessionKey(ref.watch(authSessionProvider));
      assert(sessionKey.isNotEmpty);
      final repo = ref.watch(collectionRepositoryProvider);
      if (ApiConfig.useMock) return repo.detail(evidenceId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.detail(evidenceId));
    });
