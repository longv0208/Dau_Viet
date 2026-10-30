import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import 'api_reward_repository.dart';
import 'mock_reward_repository.dart';
import 'reward_api_client.dart';
import 'reward_dtos.dart';
import 'reward_repository.dart';

final rewardApiClientProvider = Provider<RewardApiClient>(
  (ref) => RewardApiClient(ref.watch(apiClientProvider)),
);

/// USE_MOCK → demo repo; real → ApiRewardRepository (không fallback).
final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  if (ApiConfig.useMock) return MockRewardRepository();
  return ApiRewardRepository(ref.watch(rewardApiClientProvider));
});

Duration? _noRetry(int retryCount, Object error) => null;

/// Khóa phiên — đổi tài khoản/logout → provider rebuild, không tái dùng
/// cache thưởng của phiên trước (cùng pattern collection_providers).
String _rewardSessionKey(AuthState auth) {
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

/// Tổng quan thưởng của learner hiện tại (EXP / Điểm Lịch sử / số bài /
/// số vật phẩm). Session-aware; caller gọi `ref.invalidate` sau khi
/// complete lesson / collect evidence để số liệu cập nhật.
final rewardSummaryProvider = FutureProvider.autoDispose<RewardSummaryDto>(
  retry: _noRetry,
  (ref) {
    final auth = ref.watch(authSessionProvider);
    final sessionKey = _rewardSessionKey(auth);
    assert(sessionKey.isNotEmpty);
    // Chưa đăng nhập (real mode) → không bắn /me/rewards/* không có Bearer
    // token — nguồn của 401 spam trên Console ở màn /auth (Issue #41).
    if (!ApiConfig.useMock &&
        (auth.status == AuthStatus.unauthenticated ||
         auth.status == AuthStatus.guest)) {
      return RewardSummaryDto.empty;
    }
    final repo = ref.watch(rewardRepositoryProvider);
    if (ApiConfig.useMock) return repo.summary();
    return ref.read(authRepositoryProvider).withAuth(repo.summary);
  },
);


/// Catalog vật phẩm đầy đủ: metadata + owned + requirement + progress —
/// nguồn duy nhất cho màn Túi Đồ (InventoryScreen). Session-aware.
final inventoryCatalogProvider =
    FutureProvider.autoDispose<List<CatalogItemDto>>(retry: _noRetry, (ref) {
      final auth = ref.watch(authSessionProvider);
      final sessionKey = _rewardSessionKey(auth);
      assert(sessionKey.isNotEmpty);
      if (!ApiConfig.useMock &&
          (auth.status == AuthStatus.unauthenticated ||
           auth.status == AuthStatus.guest)) {
        return const <CatalogItemDto>[];
      }
      final repo = ref.watch(rewardRepositoryProvider);
      if (ApiConfig.useMock) return repo.catalog();
      return ref.read(authRepositoryProvider).withAuth(repo.catalog);
    });

/// Vật phẩm đã sở hữu — dùng cho nơi chỉ cần danh sách owned (không
/// cần requirement/progress). Session-aware.
final inventoryItemsProvider =
    FutureProvider.autoDispose<List<InventoryItemDto>>(retry: _noRetry, (ref) {
      final auth = ref.watch(authSessionProvider);
      final sessionKey = _rewardSessionKey(auth);
      assert(sessionKey.isNotEmpty);
      if (!ApiConfig.useMock &&
          (auth.status == AuthStatus.unauthenticated ||
           auth.status == AuthStatus.guest)) {
        return const <InventoryItemDto>[];
      }
      final repo = ref.watch(rewardRepositoryProvider);
      if (ApiConfig.useMock) return repo.inventory();
      return ref.read(authRepositoryProvider).withAuth(repo.inventory);
    });

/// Lịch sử bút toán thưởng — một trang đầu (MVP: chưa cần load-more UI;
/// trang sau có thể thêm family theo page khi thiết kế yêu cầu).
final rewardTransactionsProvider =
    FutureProvider.autoDispose<RewardTransactionPageDto>(retry: _noRetry, (
      ref,
    ) {
      final auth = ref.watch(authSessionProvider);
      final sessionKey = _rewardSessionKey(auth);
      assert(sessionKey.isNotEmpty);
      if (!ApiConfig.useMock &&
          (auth.status == AuthStatus.unauthenticated ||
           auth.status == AuthStatus.guest)) {
        return const RewardTransactionPageDto(
            content: [], page: 0, size: 20, totalElements: 0, totalPages: 1);
      }
      final repo = ref.watch(rewardRepositoryProvider);
      if (ApiConfig.useMock) return repo.transactions();
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.transactions());
    });
