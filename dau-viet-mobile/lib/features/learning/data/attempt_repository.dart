import 'attempt_dtos.dart';
import 'learning_dtos.dart';

/// Hợp đồng nguồn dữ liệu learning — presentation chỉ phụ thuộc interface
/// này; provider chọn Api (real) hay Mock (demo) theo USE_MOCK.
abstract class AttemptRepository {
  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId);
  Future<LessonMetadataDto> getLessonMetadata(String lessonId);

  /// Content theo version PINNED của attempt (real: /attempts/{id}/content).
  Future<LessonContentDto> getAttemptContent(String attemptId);

  Future<AttemptStartDto> startOrResume(String lessonId);
  Future<CurrentActivityDto> getCurrent(String attemptId, {String? activityId});

  /// Chọn dấu vết ở Bước 1 DISCOVERY hoặc quay lại giả thuyết để sửa.
  /// Backend kiểm quyền: chỉ cho phép trong unordered stage (clue grid) hoặc
  /// bước lùi từ VERIFICATION sang HYPOTHESIS.
  Future<CurrentActivityDto> selectActivity(String attemptId, String activityId);
  Future<SubmitResultDto> submit(
    String attemptId,
    String activityId,
    Map<String, dynamic> answer, {
    String? idempotencyKey,
  });
  Future<CompleteResultDto> complete(
    String attemptId, {
    String? idempotencyKey,
  });
  Future<LessonResultDto> getResult(String attemptId);
  Future<MyProgressDto> myProgress();
  Future<List<int>> getAssetBytes(String assetId);
}
