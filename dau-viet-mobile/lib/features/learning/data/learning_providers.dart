import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/auth/token_storage.dart';
import '../../auth/data/auth_api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import 'api_attempt_repository.dart';
import 'attempt_dtos.dart';
import 'attempt_repository.dart';
import 'learning_api_client.dart';
import 'learning_dtos.dart';
import 'mock_attempt_repository.dart';

/// Secure token storage singleton.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => AuthApiClient(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authApiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// Phiên đăng nhập hiện tại — Splash gọi [AuthSessionController.restore]
/// trước khi điều hướng.
final authSessionProvider = NotifierProvider<AuthSessionController, AuthState>(
  AuthSessionController.new,
);

/// Container toàn cục cho phép đọc provider ngoài widget tree (vd: GoRouter
/// redirect guard — router khởi tạo trước ProviderScope nên không `ref` được).
/// Được gán trong `main()` ngay khi tạo ProviderScope.
ProviderContainer? appContainer;

class AuthSessionController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.unknown();

  Future<void> restore() async {
    if (ApiConfig.useMock) {
      state = const AuthState.guest();
      return;
    }
    state = await ref.read(authRepositoryProvider).restore();
  }

  Future<void> login(String email, String password) async {
    state = await ref.read(authRepositoryProvider).login(email, password);
  }

  /// Demo mode chỉ hợp lệ khi USE_MOCK=true (theo quyết định brief).
  void enterGuest() {
    if (ApiConfig.useMock) {
      state = const AuthState.guest();
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = ApiConfig.useMock
        ? const AuthState.guest()
        : const AuthState.unauthenticated();
  }
}

final learningApiClientProvider = Provider<LearningApiClient>(
  (ref) => LearningApiClient(ref.watch(apiClientProvider)),
);

/// Điểm duy nhất chọn nguồn dữ liệu learning: USE_MOCK → demo repo;
/// real → ApiAttemptRepository. API lỗi KHÔNG tự động đổi sang mock.
final attemptRepositoryProvider = Provider<AttemptRepository>((ref) {
  if (ApiConfig.useMock) return MockAttemptRepository();
  return ApiAttemptRepository(ref.watch(learningApiClientProvider));
});

/// Không auto-retry: lỗi do người dùng quyết định thử lại (Riverpod 3
/// mặc định retry ngầm → vòng lặp ẩn).
Duration? _noRetry(int retryCount, Object error) => null;

/// Lessons published của một event — real mode cần auth (refresh-on-401).
final eventLessonsProvider =
    FutureProvider.family<List<LessonListItemDto>, String>(retry: _noRetry, (
      ref,
      eventId,
    ) {
      final repo = ref.watch(attemptRepositoryProvider);
      if (ApiConfig.useMock) return repo.listLessonsForEvent(eventId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.listLessonsForEvent(eventId));
    });

/// Tiến độ của learner hiện tại (IN_PROGRESS + completedCount).
final myProgressProvider = FutureProvider<MyProgressDto>(retry: _noRetry, (
  ref,
) {
  final repo = ref.watch(attemptRepositoryProvider);
  if (ApiConfig.useMock) return repo.myProgress();
  return ref.read(authRepositoryProvider).withAuth(repo.myProgress);
});
