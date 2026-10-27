import 'streak_api_client.dart';
import 'streak_dto.dart';
import 'streak_repository.dart';

/// Repository thật — gọi Spring Boot qua [StreakApiClient].
/// API lỗi ném thẳng ApiException lên UI; KHÔNG fallback mock.
class ApiStreakRepository implements StreakRepository {
  final StreakApiClient _api;

  const ApiStreakRepository(this._api);

  @override
  Future<LearningStreakDto> getMyStreak() => _api.getMyStreak();

  @override
  Future<LearningStreakCalendarDto> getCalendar(DateTime from, DateTime to) =>
      _api.getCalendar(from, to);
}
