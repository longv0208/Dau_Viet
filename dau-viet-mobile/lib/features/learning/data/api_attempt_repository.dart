import 'attempt_dtos.dart';
import 'attempt_repository.dart';
import 'learning_api_client.dart';
import 'learning_dtos.dart';

/// Repository thật — gọi Spring Boot qua [LearningApiClient].
/// API lỗi ném thẳng [ApiException] lên UI; KHÔNG fallback mock (AC).
class ApiAttemptRepository implements AttemptRepository {
  final LearningApiClient _api;

  const ApiAttemptRepository(this._api);

  @override
  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId) =>
      _api.listLessonsForEvent(eventId);

  @override
  Future<LessonMetadataDto> getLessonMetadata(String lessonId) =>
      _api.getLessonMetadata(lessonId);

  @override
  Future<LessonContentDto> getAttemptContent(String attemptId) =>
      _api.getAttemptContent(attemptId);

  @override
  Future<AttemptStartDto> startOrResume(String lessonId) =>
      _api.startOrResumeAttempt(lessonId);

  @override
  Future<CurrentActivityDto> getCurrent(String attemptId, {String? activityId}) =>
      _api.getCurrent(attemptId, activityId: activityId);

  @override
  Future<CurrentActivityDto> selectActivity(String attemptId, String activityId) =>
      _api.selectActivity(attemptId, activityId);

  @override
  Future<SubmitResultDto> submit(
    String attemptId,
    String activityId,
    Map<String, dynamic> answer, {
    String? idempotencyKey,
  }) => _api.submit(
    attemptId,
    activityId,
    answer,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<CompleteResultDto> complete(
    String attemptId, {
    String? idempotencyKey,
  }) => _api.complete(attemptId, idempotencyKey: idempotencyKey);

  @override
  Future<LessonResultDto> getResult(String attemptId) =>
      _api.getResult(attemptId);

  @override
  Future<MyProgressDto> myProgress() => _api.myProgress();

  @override
  Future<List<int>> getAssetBytes(String assetId) =>
      _api.getAssetBytes(assetId);
}
