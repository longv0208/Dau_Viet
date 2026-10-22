import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
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

/// Danh sách địa điểm hiển thị trên bản đồ — keepAlive để quay lại từ
/// lesson không mất state, nhưng invalidate khi muốn refresh sau khi
/// hoàn thành bài học mở khoá.
final mapLocationsProvider = FutureProvider<List<MapLocationDto>>(
  retry: _noRetry,
  (ref) async {
    ref.keepAlive();
    final repo = ref.watch(mapRepositoryProvider);
    if (ApiConfig.useMock) return repo.listLocations();
    return ref.read(authRepositoryProvider).withAuth(repo.listLocations);
  },
);
