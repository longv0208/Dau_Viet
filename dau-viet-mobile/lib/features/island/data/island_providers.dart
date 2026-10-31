import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../rewards/data/reward_providers.dart';
import 'island_api_client.dart';
import 'island_dto.dart';
import 'island_repository.dart';
import 'mock_island_repository.dart';

Duration? _noRetry(int retryCount, Object error) => null;

final islandApiClientProvider = Provider<IslandApiClient>((ref) {
  return IslandApiClient(ref.watch(apiClientProvider));
});

/// Singleton repository cho Island.
final islandRepositoryProvider = Provider<IslandRepository>((ref) {
  if (ApiConfig.useMock) return MockIslandRepository();
  return ApiIslandRepository(ref.watch(islandApiClientProvider));
});

/// Khóa phiên auth — đổi tài khoản/logout thì tự động reset cache của Island.
String _islandSessionKey(AuthState auth) {
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

/// Provider quản lý toàn bộ trạng thái và mutations của Đảo Di Sản.
final islandControllerProvider =
    AsyncNotifierProvider<IslandController, IslandDto>(
      IslandController.new,
      retry: _noRetry,
    );

class IslandController extends AsyncNotifier<IslandDto> {
  String _sessionKey = '';

  @override
  Future<IslandDto> build() async {
    _sessionKey = _islandSessionKey(ref.watch(authSessionProvider));
    assert(_sessionKey.isNotEmpty);
    final repo = ref.watch(islandRepositoryProvider);
    final IslandDto island;
    if (ApiConfig.useMock) {
      island = await repo.getIsland();
    } else {
      island = await ref.read(authRepositoryProvider).withAuth(repo.getIsland);
      // GET /me/island cấp bộ starter — làm mới kho để khay khớp sở hữu thật.
      Future<void>.microtask(() {
        ref.invalidate(inventoryCatalogProvider);
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(islandShopItemsProvider);
      });
    }
    return island;
  }

  /// Tải lại dữ liệu đảo.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(islandRepositoryProvider);
      if (ApiConfig.useMock) return repo.getIsland();
      return ref.read(authRepositoryProvider).withAuth(repo.getIsland);
    });
  }

  /// Đặt vật phẩm vào slot, gửi kèm Idempotency-Key và expectedRevision.
  Future<IslandDto> placeItem({
    required String slotId,
    required String itemId,
    String? idempotencyKey,
  }) async {
    final current = state is AsyncData<IslandDto>
        ? (state as AsyncData<IslandDto>).value
        : null;
    final int revision = current?.revision ?? 0;
    final String key = idempotencyKey ?? const Uuid().v4();

    final repo = ref.read(islandRepositoryProvider);
    try {
      final updated = ApiConfig.useMock
          ? await repo.placeItem(
              slotId: slotId,
              itemId: itemId,
              expectedRevision: revision,
              idempotencyKey: key,
            )
          : await ref
                .read(authRepositoryProvider)
                .withAuth(
                  () => repo.placeItem(
                    slotId: slotId,
                    itemId: itemId,
                    expectedRevision: revision,
                    idempotencyKey: key,
                  ),
                );
      state = AsyncData(updated);
      ref.invalidate(inventoryCatalogProvider);
      ref.invalidate(inventoryItemsProvider);
      return updated;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        refresh();
      }
      rethrow;
    }
  }

  /// Gỡ vật phẩm khỏi slot và cất về kho.
  Future<IslandDto> removePlacement({
    required String slotId,
    String? idempotencyKey,
  }) async {
    final current = state is AsyncData<IslandDto>
        ? (state as AsyncData<IslandDto>).value
        : null;
    final int revision = current?.revision ?? 0;
    final String key = idempotencyKey ?? const Uuid().v4();

    final repo = ref.read(islandRepositoryProvider);
    try {
      final updated = ApiConfig.useMock
          ? await repo.removePlacement(
              slotId: slotId,
              expectedRevision: revision,
              idempotencyKey: key,
            )
          : await ref
                .read(authRepositoryProvider)
                .withAuth(
                  () => repo.removePlacement(
                    slotId: slotId,
                    expectedRevision: revision,
                    idempotencyKey: key,
                  ),
                );
      state = AsyncData(updated);
      ref.invalidate(inventoryCatalogProvider);
      ref.invalidate(inventoryItemsProvider);
      return updated;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        refresh();
      }
      rethrow;
    }
  }

  /// Nâng cấp đảo sang tier tiếp theo.
  Future<IslandDto> upgrade() async {
    final current = state is AsyncData<IslandDto>
        ? (state as AsyncData<IslandDto>).value
        : null;
    final int revision = current?.revision ?? 0;

    final repo = ref.read(islandRepositoryProvider);
    try {
      final updated = ApiConfig.useMock
          ? await repo.upgradeIsland(revision)
          : await ref
                .read(authRepositoryProvider)
                .withAuth(() => repo.upgradeIsland(revision));
      state = AsyncData(updated);
      return updated;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        refresh();
      }
      rethrow;
    }
  }
}

/// Provider lấy số dư ví của learner (Điểm Sử Ký).
final islandWalletProvider = FutureProvider.autoDispose<WalletDto>(
  retry: _noRetry,
  (ref) async {
    final sessionKey = _islandSessionKey(ref.watch(authSessionProvider));
    assert(sessionKey.isNotEmpty);
    final repo = ref.watch(islandRepositoryProvider);
    if (ApiConfig.useMock) {
      return repo.getWallet();
    }
    // Không fallback sang rewardSummary: historyPoints trong summary là giá
    // trị tích lũy suốt đời, không phải số dư hiện có trong ví. Nếu
    // /me/wallet thất bại thì rethrow để UI hiển thị trạng thái lỗi.
    return ref.read(authRepositoryProvider).withAuth(repo.getWallet);
  },
);

/// Provider danh sách mặt hàng trang trí trong Shop.
/// Tự động đối chiếu với inventoryItemsProvider để xác định trạng thái ĐÃ SỞ HỮU.
final islandShopItemsProvider = FutureProvider.autoDispose<List<ShopItemDto>>(
  retry: _noRetry,
  (ref) async {
    final sessionKey = _islandSessionKey(ref.watch(authSessionProvider));
    assert(sessionKey.isNotEmpty);
    final repo = ref.watch(islandRepositoryProvider);
    if (ApiConfig.useMock || repo is MockIslandRepository) {
      return repo.getShopItems();
    }
    final items = await ref
        .read(authRepositoryProvider)
        .withAuth(repo.getShopItems);
    try {
      final ownedInventory = await ref.watch(inventoryItemsProvider.future);
      final ownedIds = ownedInventory.map((e) => e.itemId).toSet();
      final ownedCodes = ownedInventory.map((e) => e.code).toSet();
      return items
          .map(
            (item) => item.copyWith(
              owned:
                  item.owned ||
                  ownedIds.contains(item.itemId) ||
                  ownedCodes.contains(item.code),
              ownershipVerified: true,
            ),
          )
          .toList();
    } catch (_) {
      return items
          .map(
            (item) => item.copyWith(
              owned: item.owned,
              ownershipVerified: false,
            ),
          )
          .toList();
    }
  },
);

/// Mua một vật phẩm trong Shop với Idempotency-Key và đồng bộ mọi providers.
Future<Map<String, dynamic>> purchaseIslandShopItem(
  WidgetRef ref,
  String itemId, {
  String? idempotencyKey,
}) async {
  final repo = ref.read(islandRepositoryProvider);
  final key = idempotencyKey ?? const Uuid().v4();

  final result = ApiConfig.useMock
      ? await repo.purchaseItem(itemId: itemId, idempotencyKey: key)
      : await ref
            .read(authRepositoryProvider)
            .withAuth(
              () => repo.purchaseItem(itemId: itemId, idempotencyKey: key),
            );

  // Invalidate và cập nhật các providers liên quan
  ref.invalidate(islandWalletProvider);
  ref.invalidate(rewardSummaryProvider);
  ref.invalidate(islandShopItemsProvider);
  ref.invalidate(inventoryCatalogProvider);
  ref.invalidate(inventoryItemsProvider);
  ref.invalidate(islandControllerProvider);

  return result;
}
