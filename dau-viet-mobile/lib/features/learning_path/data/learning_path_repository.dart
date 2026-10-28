import 'learning_path_dto.dart';

/// Hợp đồng nguồn dữ liệu Lộ Trình Học Tập — presentation chỉ phụ thuộc
/// interface này; provider chọn [ApiLearningPathRepository] (real) hoặc
/// [MockLearningPathRepository] (USE_MOCK=true).
abstract class LearningPathRepository {
  /// `GET /api/v1/me/learning-path` — lộ trình và tiến độ theo từng thời kỳ của learner.
  Future<LearningPathDto> getMyLearningPath();

  /// Alias tiện dụng cho [getMyLearningPath].
  Future<LearningPathDto> getLearningPath() => getMyLearningPath();

  /// `POST /api/v1/me/learning-path/periods/{periodCode}/touch` — cập nhật thời kỳ
  /// người học vừa chọn/vào xem.
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode);

  /// `GET /api/v1/learning-path?code=...` — cây lộ trình công khai.
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  });
}
