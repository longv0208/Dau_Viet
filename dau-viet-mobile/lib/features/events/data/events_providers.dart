import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/assets/asset_resolver.dart';
import '../../../mock/models/lesson_models.dart';
import 'api_events_repository.dart';
import 'events_api_client.dart';
import 'events_repository.dart';
import 'mock_events_repository.dart';

/// `AssetResolver` chung — tách bảng ánh xạ asset khỏi repository để
/// dễ mở rộng khi đổi storage backend.
final assetResolverProvider = Provider<AssetResolver>(
  (ref) => const AssetResolver(),
);

/// HTTP client chung cho các API client feature.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.fromConfig());

/// Client REST `/api/v1/events`.
final eventsApiClientProvider = Provider<EventsApiClient>(
  (ref) => EventsApiClient(ref.watch(apiClientProvider)),
);

/// Điểm duy nhất quyết định nguồn dữ liệu:
/// `USE_MOCK=true` → `MockEventsRepository`; mặc định → `ApiEventsRepository`.
/// API lỗi KHÔNG tự động đổi sang mock (AC-5).
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (ApiConfig.useMock) {
    return MockEventsRepository();
  }
  return ApiEventsRepository(
    ref.watch(eventsApiClientProvider),
    ref.watch(assetResolverProvider),
  );
});

/// Không auto-retry: lỗi hiển thị để người dùng quyết định bấm "THỬ LẠI"
/// (Riverpod 3 mặc định retry 10 lần exponential backoff → vòng lặp ngầm).
Duration? _noRetry(int retryCount, Object error) => null;

/// Danh sách mốc sự kiện cho Trục Thời Gian.
/// `keepAlive` giữ state khi điều hướng — không gọi lại API vô cớ (AC-3).
final eventsListProvider = FutureProvider<EventsPageResult>(retry: _noRetry, (
  ref,
) async {
  ref.keepAlive();
  return ref.watch(eventsRepositoryProvider).getEvents();
});

/// Chi tiết một sự kiện theo id (UUID backend trong chế độ thật).
final eventDetailProvider = FutureProvider.family<HistoricalEventModel, String>(
  retry: _noRetry,
  (ref, eventId) async {
    ref.keepAlive();
    return ref.watch(eventsRepositoryProvider).getEventById(eventId);
  },
);
