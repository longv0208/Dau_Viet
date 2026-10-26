import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import 'api_streak_repository.dart';
import 'streak_api_client.dart';
import 'streak_dto.dart';
import 'streak_repository.dart';
import 'mock_streak_repository.dart';

final streakApiClientProvider = Provider<StreakApiClient>(
  (ref) => StreakApiClient(ref.watch(apiClientProvider)),
);

/// USE_MOCK → demo repo; real → ApiStreakRepository (không fallback).
final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  if (ApiConfig.useMock) return MockStreakRepository();
  return ApiStreakRepository(ref.watch(streakApiClientProvider));
});

/// Khóa phiên — đổi tài khoản/logout → notifier rebuild, không tái dùng
/// streak của phiên trước (cùng pattern energy_providers).
String _streakSessionKey(AuthState auth) {
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

/// Không auto-retry: lỗi do UI quyết định (nút "THỬ LẠI") — tránh vòng
/// lặp ẩn + future treo khi offline.
Duration? _noRetry(int retryCount, Object error) => null;

/// Trạng thái Chuỗi Ngày Học thống nhất toàn app — Dashboard pill /
/// Streak detail / Profile đọc cùng provider này.
///
/// - `build()` fetch GET /me/streak (qua withAuth ở real mode).
/// - `applySnapshot(dto)` cập nhật trực tiếp sau khi CompleteAttemptResponse
///   mang StreakInfo — bỏ qua nếu phiên đã đổi giữa chừng.
/// - `refresh()` refetch chủ động (resume app, retry lỗi, sau khi hoàn
///   thành bài mà muốn đồng bộ đầy đủ).
final streakProvider =
    AsyncNotifierProvider<StreakController, LearningStreakDto>(
      StreakController.new,
      retry: _noRetry,
    );

class StreakController extends AsyncNotifier<LearningStreakDto> {
  /// Phiên mà notifier này đang phục vụ — applySnapshot kiểm để chống
  /// response trễ của user cũ ghi đè state user mới.
  String _sessionKey = '';

  /// Đồng hồ server của state đang hiển thị — nguồn so "mới hơn/cũ hơn".
  /// Null khi state hiện tại thiếu serverTime → fallback thứ tự đến.
  DateTime? _appliedServerTime;

  static DateTime _stampOf(LearningStreakDto d) =>
      d.serverTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  bool _isFresher(LearningStreakDto incoming) {
    final DateTime? cur = _appliedServerTime;
    if (cur == null) return true;
    return !_stampOf(incoming).isBefore(cur);
  }

  @override
  Future<LearningStreakDto> build() async {
    _sessionKey = _streakSessionKey(ref.watch(authSessionProvider));
    final repo = ref.watch(streakRepositoryProvider);
    final String sess = _sessionKey;
    final LearningStreakDto dto;
    if (ApiConfig.useMock) {
      dto = await repo.getMyStreak();
    } else {
      dto = await ref.read(authRepositoryProvider).withAuth(repo.getMyStreak);
    }
    // Phiên đã đổi trong lúc fetch → response thuộc account cũ: KHÔNG áp.
    if (sess != _streakSessionKey(ref.read(authSessionProvider))) {
      final cur = state;
      if (cur is AsyncData<LearningStreakDto>) return cur.value;
      return dto;
    }
    // State hiện tại MỚI HƠN response GET này (snapshot tay từ complete)
    // → nhường: giữ state, không ghi đè bằng dữ liệu cũ.
    if (!_isFresher(dto) && state is AsyncData<LearningStreakDto>) {
      return (state as AsyncData<LearningStreakDto>).value;
    }
    _appliedServerTime = _stampOf(dto);
    return dto;
  }

  bool get _sessionAlive =>
      _streakSessionKey(ref.read(authSessionProvider)) == _sessionKey;

  /// Áp StreakInfo từ CompleteAttemptResponse — server vừa công nhận một
  /// ngày học mới nên state cũ chắc chắn lạc hậu; ghi đè trực tiếp và đẩy
  /// mốc serverTime lên "bây giờ" để các GET trễ không lùi lại.
  /// Bỏ qua khi phiên đổi.
  void applyStreakInfo(StreakInfoDto info) {
    if (_sessionKey.isEmpty) {
      _sessionKey = _streakSessionKey(ref.read(authSessionProvider));
    }
    if (!_sessionAlive) return;
    final cur = state is AsyncData<LearningStreakDto>
        ? (state as AsyncData<LearningStreakDto>).value
        : null;
    final dto = LearningStreakDto(
      currentStreak: info.currentStreak,
      longestStreak: info.longestStreak,
      completedToday: true,
      streakAlive: true,
      lastQualifiedDate: info.studyDate,
      today: cur?.today ?? info.studyDate,
      timezone: cur?.timezone ?? 'Asia/Ho_Chi_Minh',
      serverTime: DateTime.now().toUtc(),
    );
    _appliedServerTime = dto.serverTime;
    state = AsyncData(dto);
  }

  /// Refetch chủ động — app resume, retry sau lỗi.
  Future<void> refresh() async {
    if (!_sessionAlive) return;
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // AsyncError đã nằm trong state — UI tự hiển thị error view.
    }
  }
}

/// Lịch sử ngày học theo tháng cho màn hình chi tiết — family theo
/// (year, month) để mỗi tháng cache riêng, invalidate không ảnh hưởng
/// tháng khác.
final streakCalendarProvider = FutureProvider.autoDispose
    .family<LearningStreakCalendarDto, ({int year, int month})>((
      ref,
      ym,
    ) async {
      final from = DateTime(ym.year, ym.month, 1);
      final to = DateTime(ym.year, ym.month + 1, 0); // ngày cuối tháng
      final repo = ref.watch(streakRepositoryProvider);
      if (ApiConfig.useMock) {
        return repo.getCalendar(from, to);
      }
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getCalendar(from, to));
    });
