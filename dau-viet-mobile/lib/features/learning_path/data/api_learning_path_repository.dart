import 'learning_path_api_client.dart';
import 'learning_path_dto.dart';
import 'learning_path_repository.dart';

/// Repository kết nối backend thật qua [LearningPathApiClient].
/// Lỗi API ném thẳng [ApiException] lên UI; tuyệt đối không tự fallback sang mock.
class ApiLearningPathRepository extends LearningPathRepository {
  final LearningPathApiClient _api;

  ApiLearningPathRepository(this._api);

  @override
  Future<LearningPathDto> getMyLearningPath() => _api.getMyLearningPath();

  @override
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) =>
      _api.touchPeriod(periodCode);

  @override
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) => _api.getPublishedLearningPath(code: code);
}
