import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../learning/data/learning_providers.dart';
import 'collection_providers.dart';
import 'dossier_dto.dart';
import 'event_progress_dto.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// Khóa phiên — đổi tài khoản/logout → provider rebuild, không tái dùng
/// cache dossier/progress của phiên trước (giống _collectionSessionKey).
String _dossierSessionKey(AuthState auth) {
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

/// Filter dossier list — record gọn, hashCode ổn định cho family key.
/// eventId null = toàn collection; unlocked null = cả hai trạng thái.
typedef DossierFilter = ({String? type, String? eventId, bool? unlocked});

/// Trạng thái dossier list phân trang — mirror CollectionListState.
class DossierListState {
  final List<DossierSummaryDto> items;
  final int nextPage;
  final bool hasMore;
  final bool isLoadingMore;
  final int totalElements;
  final Object? loadMoreError;

  const DossierListState({
    this.items = const [],
    this.nextPage = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.totalElements = 0,
    this.loadMoreError,
  });

  DossierListState copyLoadingMore() => DossierListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: true,
    totalElements: totalElements,
    loadMoreError: loadMoreError,
  );

  DossierListState copyLoadMoreError(Object error) => DossierListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: false,
    totalElements: totalElements,
    loadMoreError: error,
  );

  DossierListState copyClearError() => DossierListState(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    isLoadingMore: false,
    totalElements: totalElements,
    loadMoreError: null,
  );
}

/// Dossier list theo filter — family key DossierFilter. Session-aware.
final dossierListProvider = AsyncNotifierProvider.autoDispose
    .family<DossierListNotifier, DossierListState, DossierFilter>(
      (arg) => DossierListNotifier(arg),
    );

class DossierListNotifier extends AsyncNotifier<DossierListState> {
  DossierListNotifier(this._filter);

  static const int _pageSize = 20;
  final DossierFilter _filter;

  int _generation = 0;
  String? _sessionAtBuild;

  @override
  Future<DossierListState> build() async {
    _generation++;
    final sessionKey = _dossierSessionKey(ref.watch(authSessionProvider));
    _sessionAtBuild = sessionKey;
    final repo = ref.watch(collectionRepositoryProvider);
    final page = ApiConfig.useMock
        ? await repo.listDossiers(
            type: _filter.type,
            eventId: _filter.eventId,
            unlocked: _filter.unlocked,
            page: 0,
            size: _pageSize,
          )
        : await ref
              .read(authRepositoryProvider)
              .withAuth(
                () => repo.listDossiers(
                  type: _filter.type,
                  eventId: _filter.eventId,
                  unlocked: _filter.unlocked,
                  page: 0,
                  size: _pageSize,
                ),
              );
    return DossierListState(
      items: page.content,
      nextPage: page.content.isEmpty ? 0 : 1,
      hasMore: page.hasMore,
      totalElements: page.totalElements,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final int generation = _generation;
    final String? session = _sessionAtBuild;

    state = AsyncData(current.copyLoadingMore());
    try {
      final repo = ref.read(collectionRepositoryProvider);
      final page = ApiConfig.useMock
          ? await repo.listDossiers(
              type: _filter.type,
              eventId: _filter.eventId,
              unlocked: _filter.unlocked,
              page: current.nextPage,
              size: _pageSize,
            )
          : await ref
                .read(authRepositoryProvider)
                .withAuth(
                  () => repo.listDossiers(
                    type: _filter.type,
                    eventId: _filter.eventId,
                    unlocked: _filter.unlocked,
                    page: current.nextPage,
                    size: _pageSize,
                  ),
                );

      if (!ref.mounted ||
          !identical(_sessionAtBuild, session) ||
          _generation != generation ||
          _dossierSessionKey(ref.read(authSessionProvider)) != session) {
        return;
      }
      state = AsyncData(
        DossierListState(
          items: [...current.items, ...page.content],
          nextPage: current.nextPage + 1,
          hasMore: page.hasMore,
          totalElements: page.totalElements,
        ),
      );
    } catch (e) {
      if (ref.mounted &&
          _generation == generation &&
          identical(_sessionAtBuild, session)) {
        state = AsyncData(current.copyLoadMoreError(e));
      }
    }
  }

  void clearLoadMoreError() {
    final current = state.value;
    if (current == null || current.loadMoreError == null) return;
    state = AsyncData(current.copyClearError());
  }
}

/// Chi tiết dossier — family theo dossierId, session-aware.
final dossierDetailProvider = FutureProvider.autoDispose
    .family<DossierDetailDto, String>(retry: _noRetry, (ref, dossierId) {
      _dossierSessionKey(ref.watch(authSessionProvider));
      final repo = ref.watch(collectionRepositoryProvider);
      if (ApiConfig.useMock) return repo.dossierDetail(dossierId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.dossierDetail(dossierId));
    });

/// Tiến độ event của learner — invalidate sau khi complete lesson.
final eventProgressProvider = FutureProvider.autoDispose
    .family<EventProgressDto, String>(retry: _noRetry, (ref, eventId) {
      _dossierSessionKey(ref.watch(authSessionProvider));
      final repo = ref.watch(collectionRepositoryProvider);
      if (ApiConfig.useMock) return repo.eventProgress(eventId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.eventProgress(eventId));
    });
