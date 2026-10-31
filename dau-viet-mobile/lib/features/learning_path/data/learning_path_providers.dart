import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import 'api_learning_path_repository.dart';
import 'learning_path_api_client.dart';
import 'learning_path_dto.dart';
import 'learning_path_repository.dart';
import 'mock_learning_path_repository.dart';

export 'event_rewards_provider.dart';

/// Không auto-retry — lỗi hiển thị rõ để người dùng bấm "Thử lại".
Duration? _noRetry(int retryCount, Object error) => null;

final learningPathApiClientProvider = Provider<LearningPathApiClient>(
  (ref) => LearningPathApiClient(ref.watch(apiClientProvider)),
);

/// Điểm duy nhất chọn nguồn dữ liệu lộ trình:
/// `USE_MOCK=true` → [MockLearningPathRepository];
/// mặc định → [ApiLearningPathRepository] (không tự fallback mock khi lỗi mạng).
final learningPathRepositoryProvider = Provider<LearningPathRepository>((ref) {
  if (ApiConfig.useMock) {
    return MockLearningPathRepository();
  }
  return ApiLearningPathRepository(ref.watch(learningPathApiClientProvider));
});

/// Khóa phiên hiện tại cho dữ liệu lộ trình cá nhân: đổi tài khoản / logout /
/// restore → khóa đổi → provider rebuild và không lộ tiến độ giữa các tài khoản.
String learningPathSessionKeyOf(AuthState auth) {
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

/// Trạng thái Lộ Trình Học Tập cá nhân (`GET /api/v1/me/learning-path`).
/// Hỗ trợ cả `ref.watch(learningPathProvider)` (trả `AsyncValue<LearningPathDto>`)
/// lẫn `ref.read(learningPathProvider.notifier).touchPeriod(periodCode)`.
final learningPathProvider =
    AsyncNotifierProvider<LearningPathController, LearningPathDto>(
      LearningPathController.new,
      retry: _noRetry,
    );

/// Alias tương thích cho các màn hình/widget gọi theo tên đầy đủ.
final learnerLearningPathProvider = learningPathProvider;
final myLearningPathProvider = learningPathProvider;

class LearningPathController extends AsyncNotifier<LearningPathDto> {
  String _sessionKey = '';

  @override
  Future<LearningPathDto> build() async {
    _sessionKey = learningPathSessionKeyOf(ref.watch(authSessionProvider));
    assert(_sessionKey.isNotEmpty);
    final repo = ref.watch(learningPathRepositoryProvider);
    if (ApiConfig.useMock) {
      return repo.getMyLearningPath();
    }
    return ref.read(authRepositoryProvider).withAuth(repo.getMyLearningPath);
  }

  /// Tải lại lộ trình từ repository.
  Future<void> refresh() async {
    final String sess = _sessionKey;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final repo = ref.read(learningPathRepositoryProvider);
      if (ApiConfig.useMock) return repo.getMyLearningPath();
      return ref.read(authRepositoryProvider).withAuth(repo.getMyLearningPath);
    });
    if (sess != learningPathSessionKeyOf(ref.read(authSessionProvider))) {
      return;
    }
    state = next;
  }

  /// Gọi `POST /api/v1/me/learning-path/periods/{periodCode}/touch` và đồng bộ
  /// ngay `lastPeriodCode` + `current` trong state hiện tại.
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    final String sess = _sessionKey;
    final repo = ref.read(learningPathRepositoryProvider);
    final TouchPeriodResponseDto res = ApiConfig.useMock
        ? await repo.touchPeriod(periodCode)
        : await ref
              .read(authRepositoryProvider)
              .withAuth(() => repo.touchPeriod(periodCode));

    if (sess == learningPathSessionKeyOf(ref.read(authSessionProvider))) {
      final cur = state;
      if (cur is AsyncData<LearningPathDto>) {
        final existing = cur.value;
        final nextCurrent =
            existing.currentByPeriod[res.periodCode] ?? existing.current;
        state = AsyncData(
          existing.copyWith(
            lastPeriodCode: res.periodCode,
            current: nextCurrent,
          ),
        );
      }
    }
    return res;
  }
}

/// Cây lộ trình xuất bản công khai (`GET /api/v1/learning-path?code=HISTORY_MAIN`).
final publishedLearningPathProvider = FutureProvider<LearningPathDto>(
  retry: _noRetry,
  (ref) async {
    ref.keepAlive();
    final repo = ref.watch(learningPathRepositoryProvider);
    return repo.getPublishedLearningPath();
  },
);

/// Con trỏ học tập hiện hành (`currentByPeriod[lastPeriodCode] ?? current`)
/// phục vụ khối "Tiếp tục hành trình" trên Trang chủ (E3).
final currentPeriodPointerProvider =
    Provider<AsyncValue<LearningPathCurrentDto?>>(
      (ref) =>
          ref.watch(learningPathProvider).whenData((p) => p.effectiveCurrent),
    );

/// Tra cứu nút sự kiện trong lộ trình theo `eventId` hoặc `slug` (phục vụ E2/E3).
final eventPathNodeProvider =
    Provider.family<AsyncValue<LearningPathEventNodeDto?>, String>(
      (ref, eventId) => ref
          .watch(learningPathProvider)
          .whenData((p) => p.findEventById(eventId)),
    );

/// Tra cứu trạng thái `LearnerPathStatus?` của một `lessonId` trong lộ trình
/// (`null` khi bài học không thuộc lộ trình — được phép học tự do theo A1).
final lessonPathStatusProvider =
    Provider.family<AsyncValue<LearnerPathStatus?>, String>(
      (ref, lessonId) => ref
          .watch(learningPathProvider)
          .whenData((p) => p.lessonStatusOf(lessonId)),
    );
