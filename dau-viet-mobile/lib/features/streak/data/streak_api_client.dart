import '../../../core/api/api_client.dart';
import 'streak_dto.dart';

/// Client mỏng cho `GET /api/v1/me/streak` và `GET /api/v1/me/streak/calendar`
/// (STREAK-01). Read-only: ghi streak chỉ xảy ra server-side khi learner
/// hoàn thành bài — client KHÔNG có endpoint cộng/trừ chuỗi.
class StreakApiClient {
  final ApiClient _client;

  const StreakApiClient(this._client);

  Future<LearningStreakDto> getMyStreak() async {
    final json = await _client.get('/api/v1/me/streak');
    return LearningStreakDto.fromJson(json);
  }

  /// Lịch sử ngày đã học trong [from, to] (ISO yyyy-MM-dd) — backend giới
  /// hạn tối đa 92 ngày span.
  Future<LearningStreakCalendarDto> getCalendar(
    DateTime from,
    DateTime to,
  ) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final json = await _client.get(
      '/api/v1/me/streak/calendar?from=${fmt(from)}&to=${fmt(to)}',
    );
    return LearningStreakCalendarDto.fromJson(json);
  }
}
