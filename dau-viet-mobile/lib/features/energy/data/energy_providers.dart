import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
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
final energyProvider =
    AsyncNotifierProvider<EnergyController, EnergyStateDto>(
      EnergyController.new,
      retry: _noRetry,
    );

class EnergyController extends AsyncNotifier<EnergyStateDto> {
  /// Phiên mà notifier này đang phục vụ — applySnapshot kiểm để chống
  /// response trễ của user cũ ghi đè state user mới. Non-late: build()
  /// có thể chạy lại (invalidateSelf) nên gán lại mỗi lần.
  String _sessionKey = '';

  /// Tăng mỗi khi applySnapshot ghi state trực tiếp — build() đang chờ
  /// fetch phải nhường snapshot (snapshot đến SAU khi GET bắt đầu nên
  /// mới hơn dữ liệu GET sắp trả về).
  int _applySeq = 0;

  @override
  Future<EnergyStateDto> build() async {
    _sessionKey = _energySessionKey(ref.watch(authSessionProvider));
    final repo = ref.watch(energyRepositoryProvider);
    final int seq = _applySeq;
    final EnergyStateDto dto;
    if (ApiConfig.useMock) {
      dto = await repo.getMyEnergy();
    } else {
      dto = await ref.read(authRepositoryProvider).withAuth(repo.getMyEnergy);
    }
    // Snapshot tay (submit/409) đã ghi trong lúc fetch → nó MỚI HƠN dữ
    // liệu GET này; trả lại snapshot thay vì ghi đè bằng dữ liệu cũ.
    if (_applySeq != seq && state is AsyncData<EnergyStateDto>) {
      return (state as AsyncData<EnergyStateDto>).value;
    }
    return dto;
  }

  bool get _sessionAlive =>
      _energySessionKey(ref.read(authSessionProvider)) == _sessionKey;

  /// Ghi snapshot từ response server (submit/409 details). Snapshot được coi
  /// authoritative ngay lúc đó — không cần refetch. Bỏ qua khi phiên đổi.
  void applySnapshot(EnergyStateDto snapshot) {
    // build() có thể chưa chạy (provider vừa được tạo bởi read(.notifier))
    // → _sessionKey còn rỗng: gán key phiên hiện tại — snapshot này sinh
    // ra từ chính phiên đó nên hợp lệ.
    if (_sessionKey.isEmpty) {
      _sessionKey = _energySessionKey(ref.read(authSessionProvider));
    }
    if (!_sessionAlive) return;
    _applySeq++;
    state = AsyncData(snapshot);
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
}
