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
/// Session key public cho màn hình truyền vào streakCalendarProvider —
/// cùng hàm _streakSessionKey nhưng expose để UI đóng gói vào family key.
String streakSessionKeyOf(AuthState auth) => _streakSessionKey(auth);

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

/// Mốc freshness của streak state — sống NGOÀI notifier (keepAlive) nên
/// vẫn còn khi invalidateSelf() hủy + dựng lại notifier. Đây là chìa khóa
/// chống GET-refresh trễ ghi đè snapshot mới: notifier mới đọc lại mốc
/// serverTime + cờ fromComplete của lần áp trước, key theo session để
/// không dùng nhầm mốc của account cũ.
final _streakFreshnessProvider =
    Provider<
      Map<
        String,
        ({DateTime stamp, bool fromComplete, LearningStreakDto? keep})
      >
    >(
      (ref) =>
          <
            String,
            ({DateTime stamp, bool fromComplete, LearningStreakDto? keep})
          >{},
    );

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

  /// Đọc mốc freshness đã lưu (keepAlive) cho session hiện tại — sống sót
  /// qua invalidateSelf/rebuild. `keep` = giá trị mới nhất đã áp, để khi một
  /// GET cũ hơn về sau invalidateSelf ta trả lại đúng state mới thay vì
  /// để UI nhảy về số cũ. Null khi chưa áp state nào.
  ({DateTime stamp, bool fromComplete, LearningStreakDto? keep})?
  get _freshness => ref.read(_streakFreshnessProvider)[_sessionKey];

  static DateTime _epoch() =>
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime _stampOf(LearningStreakDto d) => d.serverTime ?? _epoch();

  /// Quyết định `incoming` (GET response) có được phép ghi đè mốc state đã
  /// lưu không. Quy tắc:
  ///   1. State vừa ghi tay từ complete (fromComplete) → chỉ cho GET CÓ
  ///      serverTime MỚI HƠN mốc đó ghi đè; GET thiếu/bằng/cũ hơn → bỏ
  ///      (response trễ của trạng thái trước complete).
  ///   2. Còn lại so serverTime; thiếu → epoch (luôn thua mốc thật).
  bool _accepts(LearningStreakDto incoming) {
    final f = _freshness;
    if (f == null) return true;
    if (f.fromComplete) {
      return _stampOf(incoming).isAfter(f.stamp);
    }
    return !_stampOf(incoming).isBefore(f.stamp);
  }

  void _markApplied(LearningStreakDto dto, {required bool fromComplete}) {
    ref.read(_streakFreshnessProvider)[_sessionKey] = (
      stamp: _stampOf(dto),
      fromComplete: fromComplete,
      keep: dto,
    );
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
      final kept = _freshness?.keep;
      if (kept != null) return kept;
      final cur = state;
      if (cur is AsyncData<LearningStreakDto>) return cur.value;
      return dto;
    }
    // State đã lưu MỚI HƠN response GET này (snapshot tay từ complete, hoặc
    // GET khác đã về trước) → trả lại giá trị mới nhất đã giữ, không ghi đè
    // bằng dữ liệu cũ (sau invalidateSelf state AsyncData đã mất).
    if (!_accepts(dto)) {
      final kept = _freshness?.keep;
      if (kept != null) return kept;
      final cur = state;
      if (cur is AsyncData<LearningStreakDto>) return cur.value;
    }
    _markApplied(dto, fromComplete: false);
    return dto;
  }

  bool get _sessionAlive =>
      _streakSessionKey(ref.read(authSessionProvider)) == _sessionKey;

  /// Áp StreakInfo từ CompleteAttemptResponse — server vừa công nhận một
  /// ngày học mới nên state cũ chắc chắn lạc hậu. Dùng `info.serverTime`
  /// (đồng hồ SERVER lúc ghi) làm mốc freshness — KHÔNG dùng DateTime.now()
  /// của thiết bị, nên đồng hồ điện thoại chạy trước/sau không ảnh hưởng
  /// thứ tự snapshot. Bỏ qua khi phiên đổi.
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
      // Mốc freshness thật từ server — null-safe về epoch nếu backend cũ
      // chưa trả field này.
      serverTime: info.serverTime ?? cur?.serverTime,
    );
    _markApplied(dto, fromComplete: true);
    state = AsyncData(dto);
  }

  /// Refetch chủ động — app resume, retry sau lỗi. Gọi repo trực tiếp rồi
  /// áp nếu response MỚI HƠN mốc hiện tại — deterministic hơn invalidateSelf
  /// (vốn có thể coalesce với build đang chạy và trả future cũ). Response
  /// trễ/cũ hơn mốc bị bỏ; lỗi để AsyncError cho UI hiển thị.
  Future<void> refresh() async {
    if (!_sessionAlive) return;
    final repo = ref.read(streakRepositoryProvider);
    final String sess = _sessionKey;
    try {
      final LearningStreakDto dto = ApiConfig.useMock
          ? await repo.getMyStreak()
          : await ref.read(authRepositoryProvider).withAuth(repo.getMyStreak);
      // Phiên đổi giữa fetch hoặc response cũ hơn mốc → bỏ.
      if (sess != _streakSessionKey(ref.read(authSessionProvider))) return;
      if (!_accepts(dto)) return;
      _markApplied(dto, fromComplete: false);
      state = AsyncData(dto);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Lịch sử ngày học theo tháng cho màn hình chi tiết — family theo
/// (year, month, sessionKey). sessionKey đổi theo user đăng nhập → cache
/// tháng của user A KHÔNG bị user B đọc nhầm; autoDispose giải phóng khi
/// không còn ai watch.
final streakCalendarProvider = FutureProvider.autoDispose
    .family<LearningStreakCalendarDto, ({int year, int month, String sess})>((
      ref,
      key,
    ) async {
      // Re-derive session trong fetch — nếu auth đổi giữa chừng thì key.sess
      // lệch thực tế → trả rỗng thay vì lộ lịch của user cũ.
      final live = _streakSessionKey(ref.watch(authSessionProvider));
      if (live != key.sess) {
        return const LearningStreakCalendarDto(days: []);
      }
      final from = DateTime(key.year, key.month, 1);
      final to = DateTime(key.year, key.month + 1, 0); // ngày cuối tháng
      final repo = ref.watch(streakRepositoryProvider);
      if (ApiConfig.useMock) {
        return repo.getCalendar(from, to);
      }
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getCalendar(from, to));
    });
