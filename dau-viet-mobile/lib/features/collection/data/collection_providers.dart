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

  const CollectionListState({
    this.items = const [],
    this.nextPage = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.totalElements = 0,
  });

  CollectionListState copyLoadingMore() => CollectionListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: true,
    totalElements: totalElements,
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

  @override
  Future<CollectionListState> build() async {
    final sessionKey = _collectionSessionKey(ref.watch(authSessionProvider));
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

  /// Tải trang kế (load-more). Không-op nếu đang tải / hết trang.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
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
      state = AsyncData(
        CollectionListState(
          items: [...current.items, ...page.content],
          nextPage: current.nextPage + 1,
          hasMore: page.hasMore,
          totalElements: page.totalElements,
        ),
      );
    } catch (_) {
      state = AsyncData(current); // giữ items cũ — UI hiện snackbar nếu cần
      rethrow;
    }
  }
}

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
