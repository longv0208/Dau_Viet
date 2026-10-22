import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../auth/data/auth_state.dart';
import 'api_map_repository.dart';
import 'map_api_client.dart';
import 'map_location_dto.dart';
import 'map_repository.dart';
import 'mock_map_repository.dart';

final mapApiClientProvider = Provider<MapApiClient>(
  (ref) => MapApiClient(ref.watch(apiClientProvider)),
);

/// USE_MOCK → demo repo; real → ApiMapRepository (không fallback mock).
final mapRepositoryProvider = Provider<MapRepository>((ref) {
  if (ApiConfig.useMock) return MockMapRepository();
  return ApiMapRepository(ref.watch(mapApiClientProvider));
});

/// Không auto-retry — lỗi do người dùng bấm "Thử lại".
Duration? _noRetry(int retryCount, Object error) => null;

/// Khóa phiên hiện tại cho dữ liệu phụ thuộc learner: đổi tài khoản /
/// logout / restore → khóa đổi → provider rebuild và KHÔNG tái dùng cache
/// của phiên trước (tránh lộ unlockState giữa các tài khoản).
String _mapSessionKey(AuthState auth) {
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

/// Danh sách địa điểm hiển thị trên bản đồ — keepAlive để quay lại từ
/// lesson không mất state, nhưng invalidate khi muốn refresh sau khi
/// hoàn thành bài học mở khoá. `ref.watch(authSessionProvider)` buộc
/// fetch gắn với đúng phiên: đổi user → state phiên cũ bị huỷ và request
/// đang bay của phiên cũ không bao giờ lọt vào phiên mới.
final mapLocationsProvider = FutureProvider<List<MapLocationDto>>(
  retry: _noRetry,
  (ref) async {
    ref.keepAlive();
    final sessionKey = _mapSessionKey(ref.watch(authSessionProvider));
    final repo = ref.watch(mapRepositoryProvider);
    if (ApiConfig.useMock) return repo.listLocations();
    // Server tự suy ra learner từ JWT — không gửi userId. sessionKey chỉ
    // để buộc rebuild đúng phiên, không nằm trong payload.
    assert(sessionKey.isNotEmpty);
    return ref.read(authRepositoryProvider).withAuth(repo.listLocations);
  },
);
