import 'streak_dto.dart';
import 'streak_repository.dart';

/// Repository demo (USE_MOCK=true) — chuỗi cố định 5 ngày để UI demo
/// hiển thị đầy đủ. KHÔNG gọi backend; không giả lập ghi ngày học.
class MockStreakRepository implements StreakRepository {
  @override
  Future<LearningStreakDto> getMyStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return LearningStreakDto(
      currentStreak: 5,
      longestStreak: 9,
      completedToday: true,
      streakAlive: true,
      lastQualifiedDate: today,
      today: today,
      serverTime: now.toUtc(),
    );
  }

  @override
  Future<LearningStreakCalendarDto> getCalendar(
    DateTime from,
    DateTime to,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 5 ngày liên tiếp kết thúc hôm nay — khớp currentStreak=5 ở trên.
    final days = List.generate(5, (i) => today.subtract(Duration(days: 4 - i)));
    return LearningStreakCalendarDto(
      from: from,
      to: to,
      days: days,
      serverTime: now.toUtc(),
    );
  }
}
