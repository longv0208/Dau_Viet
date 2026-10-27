import 'package:dau_viet_mobile/features/streak/data/streak_dto.dart';
import 'package:dau_viet_mobile/features/streak/data/streak_repository.dart';

/// Scripted repo cho provider test — KHÔNG phải MockStreakRepository của app
/// (mock chỉ phục vụ USE_MOCK). Đếm số lần fetch để test không vô tình poll
/// API; cho phép xếp hàng response để mô phỏng request đến sai thứ tự.
class FakeStreakRepository implements StreakRepository {
  LearningStreakDto next = LearningStreakDto(
    currentStreak: 0,
    longestStreak: 0,
    completedToday: false,
    streakAlive: false,
    serverTime: DateTime.utc(2020, 1, 1),
  );

  Object? error;
  int calls = 0;

  /// Trả response khác nhau mỗi lần (queue) — để test GET trễ/đảo thứ tự.
  final List<LearningStreakDto> queue = [];

  LearningStreakCalendarDto calendar = const LearningStreakCalendarDto(
    days: [],
  );

  @override
  Future<LearningStreakDto> getMyStreak() async {
    calls++;
    if (error != null) throw error!;
    if (queue.isNotEmpty) return queue.removeAt(0);
    return next;
  }

  @override
  Future<LearningStreakCalendarDto> getCalendar(
    DateTime from,
    DateTime to,
  ) async {
    return calendar;
  }
}
