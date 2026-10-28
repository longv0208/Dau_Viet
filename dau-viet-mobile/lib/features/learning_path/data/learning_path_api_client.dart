import '../../../core/api/api_client.dart';
import 'learning_path_dto.dart';

/// HTTP client mỏng cho các endpoint Lộ Trình Học Tập (Contract A2):
/// - `GET /api/v1/me/learning-path`
/// - `POST /api/v1/me/learning-path/periods/{periodCode}/touch`
/// - `GET /api/v1/learning-path?code=HISTORY_MAIN`
class LearningPathApiClient {
  final ApiClient _client;

  const LearningPathApiClient(this._client);

  /// `GET /api/v1/me/learning-path` — lộ trình kèm tiến độ cá nhân theo từng thời kỳ.
  Future<LearningPathDto> getMyLearningPath() async {
    final json = await _client.get('/api/v1/me/learning-path');
    return LearningPathDto.fromJson(json);
  }

  /// Alias cho [getMyLearningPath].
  Future<LearningPathDto> getLearnerLearningPath() => getMyLearningPath();

  /// `POST /api/v1/me/learning-path/periods/{periodCode}/touch` — ghi nhận
  /// thời kỳ người học tương tác gần nhất để đồng bộ `lastPeriodCode` và `current`.
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    final encoded = Uri.encodeComponent(periodCode.trim());
    final json = await _client.post(
      '/api/v1/me/learning-path/periods/$encoded/touch',
    );
    return TouchPeriodResponseDto.fromJson(json);
  }

  /// `GET /api/v1/learning-path` — cây lộ trình xuất bản công khai.
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) async {
    final json = await _client.get(
      '/api/v1/learning-path',
      query: {'code': code},
    );
    return LearningPathDto.fromJson(json);
  }
}
