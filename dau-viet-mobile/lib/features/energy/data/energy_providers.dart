import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../island/data/island_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../rewards/data/reward_providers.dart';
import 'api_energy_repository.dart';
import 'energy_api_client.dart';
import 'energy_dto.dart';
import 'energy_repository.dart';
import 'mock_energy_repository.dart';

final energyApiClientProvider = Provider<EnergyApiClient>(
  (ref) => EnergyApiClient(ref.watch(apiClientProvider)),
);

/// USE_MOCK → demo repo; real → ApiEnergyRepository (không fallback).
final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  if (ApiConfig.useMock) return MockEnergyRepository();
  return ApiEnergyRepository(ref.watch(energyApiClientProvider));
});

/// Khóa phiên — đổi tài khoản/logout → notifier rebuild, không tái dùng
/// energy của phiên trước (cùng pattern reward_providers).
String _energySessionKey(AuthState auth) {
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

/// Không auto-retry: lỗi do UI quyết định (nút "THỬ LẠI") — Riverpod 3
/// mặc định retry ngầm → vòng lặp ẩn + future treo khi offline.
Duration? _noRetry(int retryCount, Object error) => null;

/// Trạng thái Thể lực thống nhất toàn app — Dashboard / EnergyPill /
/// Viện Thái Y / Lesson Player đọc cùng provider này.
///
/// - `build()` fetch GET /me/energy (qua withAuth ở real mode).
/// - `applySnapshot(dto)` cập nhật trực tiếp từ SubmitActivityResponse.energy
///   hoặc ENERGY_DEPLETED details — bỏ qua nếu phiên đã đổi giữa chừng
///   (chống response cũ ghi đè state mới).
/// - `refresh()` refetch chủ động (resume app, hết countdown, retry lỗi).
/// KHÔNG auto-poll mỗi giây — countdown chỉ là phần hiển thị phía UI.
final energyProvider = AsyncNotifierProvider<EnergyController, EnergyStateDto>(
  EnergyController.new,
  retry: _noRetry,
);

class EnergyController extends AsyncNotifier<EnergyStateDto> {
  /// Phiên mà notifier này đang phục vụ — applySnapshot kiểm để chống
  /// response trễ của user cũ ghi đè state user mới. Non-late: build()
  /// có thể chạy lại (invalidateSelf) nên gán lại mỗi lần.
  String _sessionKey = '';

  /// Đồng hồ server của state đang hiển thị — nguồn so "mới hơn/cũ hơn"
  /// (FIX-3). Null khi state hiện tại thiếu serverTime → fallback thứ tự
  /// đến (arrival).
  DateTime? _appliedServerTime;

  /// `incoming` có MỚI HƠN state hiện tại không — so theo đồng hồ tại lúc
  /// mỗi response được tạo (serverTime nếu có, device-fallback nếu không).
  /// Bằng nhau vẫn áp (thứ tự đến quyết định — tránh kẹt khi trùng mốc).
  bool _isFresher(EnergyStateDto incoming) {
    final DateTime? cur = _appliedServerTime;
    final DateTime? inc = incoming.serverTime;
    if (cur == null || inc == null) return true;
    return !inc.isBefore(cur);
  }

  /// Áp `dto` vào state nếu nó không cũ hơn state hiện tại. Trả true khi
  /// đã ghi.
  bool _applyIfFresher(EnergyStateDto dto) {
    if (!_isFresher(dto)) return false;
    if (dto.serverTime != null) {
      _appliedServerTime = dto.serverTime;
    }
    state = AsyncData(dto);
    return true;
  }

  /// State mặc định khi chưa đăng nhập — màn /auth / splash real-mode không
  /// bắn GET /me/energy (401 spam trên Console, Issue #41).
  static EnergyStateDto _anonymous() => EnergyStateDto(current: 0, max: 0);

  @override
  Future<EnergyStateDto> build() async {
    final auth = ref.watch(authSessionProvider);
    _sessionKey = _energySessionKey(auth);
    // Đã biết chắc chưa đăng nhập (unauthenticated/guest) → trả placeholder
    // rỗng, KHÔNG bắn GET /me/energy không có Bearer token (401 spam ở màn
    // /auth, Issue #41). `unknown` (đang restore) vẫn fetch như cũ.
    if (!ApiConfig.useMock &&
        (auth.status == AuthStatus.unauthenticated ||
         auth.status == AuthStatus.guest)) {
      return _anonymous();
    }
    final repo = ref.watch(energyRepositoryProvider);
    final String sess = _sessionKey;
    final EnergyStateDto dto;
    if (ApiConfig.useMock) {
      dto = await repo.getMyEnergy();
    } else {
      dto = await ref.read(authRepositoryProvider).withAuth(repo.getMyEnergy);
    }
    // Phiên đã đổi trong lúc fetch → response thuộc account cũ: KHÔNG áp,
    // trả state hiện tại (build của phiên mới sẽ fetch riêng).
    if (sess != _energySessionKey(ref.read(authSessionProvider))) {
      final cur = state;
      if (cur is AsyncData<EnergyStateDto>) return cur.value;
      return dto; // chưa có state — trả nhưng không chiếm mốc so.
    }
    // State hiện tại MỚI HƠN response GET này (snapshot tay hoặc GET khác
    // về trước) → nhường: giữ state, không ghi đè bằng dữ liệu cũ.
    if (!_isFresher(dto) && state is AsyncData<EnergyStateDto>) {
      return (state as AsyncData<EnergyStateDto>).value;
    }
    if (dto.serverTime != null) {
      _appliedServerTime = dto.serverTime;
    }
    return dto;
  }

  bool get _sessionAlive =>
      _energySessionKey(ref.read(authSessionProvider)) == _sessionKey;

  /// Ghi snapshot từ response server (submit/409 details). Snapshot được coi
  /// authoritative ngay lúc đó — không cần refetch.
  /// Bỏ qua khi: phiên đổi, HOẶC snapshot cũ hơn state hiện tại (serverTime
  /// nhỏ hơn) — response của submission cũ về muộn không được lùi balance.
  void applySnapshot(EnergyStateDto snapshot) {
    // build() có thể chưa chạy (provider vừa được tạo bởi read(.notifier))
    // → _sessionKey còn rỗng: gán key phiên hiện tại — snapshot này sinh
    // ra từ chính phiên đó nên hợp lệ.
    if (_sessionKey.isEmpty) {
      _sessionKey = _energySessionKey(ref.read(authSessionProvider));
    }
    if (!_sessionAlive) return;
    _applyIfFresher(snapshot);
  }

  /// Refetch chủ động — app resume, countdown chạm 0, retry sau lỗi.
  /// Lỗi được provider giữ trong AsyncError (UI hiển thị + nút thử lại);
  /// swallow ở đây để caller "fire-and-forget" không sinh unhandled error.
  Future<void> refresh() async {
    if (!_sessionAlive) return;
    ref.invalidateSelf();
    // invalidateSelf trigger rebuild async — future hoàn thành khi data mới.
    try {
      await future;
    } catch (_) {
      // AsyncError đã nằm trong state — UI tự hiển thị error view.
    }
  }

  /// GAME-07 (Issue #28): refill Thể lực bằng vật phẩm Viện Thái Y.
  ///
  /// Sinh `Idempotency-Key` (UUID v4) mỗi lần bấm để retry mạng không
  /// trừ Điểm Sử Ký/cộng energy hai lần phía server. Sau thành công:
  /// - `applySnapshot(result.energy)` cập nhật UI ngay (không cần GET lại).
  /// - Invalidate `rewardSummaryProvider` + `islandWalletProvider` để
  ///   ví Điểm Sử Ký trên Profile / Dashboard / Island đồng bộ (QA-19).
  Future<EnergyRefillResultDto> refillEnergy({
    required String remedyCode,
    String? idempotencyKey,
  }) async {
    if (!_sessionAlive) {
      throw StateError('energy session no longer active');
    }
    final key = idempotencyKey ?? const Uuid().v4();
    final repo = ref.read(energyRepositoryProvider);
    final result = ApiConfig.useMock
        ? await repo.refillEnergy(
            remedyCode: remedyCode, idempotencyKey: key)
        : await ref.read(authRepositoryProvider).withAuth(
            () => repo.refillEnergy(
                remedyCode: remedyCode, idempotencyKey: key));
    if (!_sessionAlive) return result;
    _applyIfFresher(result.energy);
    // Đồng bộ ví Điểm Sử Ký toàn app.
    ref.invalidate(rewardSummaryProvider);
    ref.invalidate(islandWalletProvider);
    return result;
  }
}
