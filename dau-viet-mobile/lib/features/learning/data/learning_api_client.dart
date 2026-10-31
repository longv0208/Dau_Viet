import '../../../core/api/api_client.dart';
import 'attempt_dtos.dart';
import 'learning_dtos.dart';

/// Client mỏng cho nhóm learner endpoints `/api/v1` (lesson + attempt).
/// Không chứa business logic — parse DTO + truyền Idempotency-Key header.
class LearningApiClient {
  final ApiClient _client;

  const LearningApiClient(this._client);

  /* ---------- Lesson discovery ---------- */

  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId) async {
    // Backend trả top-level JSON array List<LearnerLessonListItem>.
    final List<dynamic> raw = await _client.getList(
      '/api/v1/events/$eventId/lessons',
    );
    return raw
        .whereType<Map>()
        .map((e) => LessonListItemDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<LessonMetadataDto> getLessonMetadata(String lessonId) async {
    final json = await _client.get('/api/v1/lessons/$lessonId');
    return LessonMetadataDto.fromJson(json);
  }

  Future<LessonContentDto> getLessonContent(String lessonId) async {
    final json = await _client.get('/api/v1/lessons/$lessonId/content');
    return LessonContentDto.fromJson(json);
  }

  /// TASK-0018: content của version PINNED bởi attempt — resume sau republish
  /// vẫn render đúng snapshot submissions được chấm.
  Future<LessonContentDto> getAttemptContent(String attemptId) async {
    final json = await _client.get('/api/v1/attempts/$attemptId/content');
    return LessonContentDto.fromJson(json);
  }

  /* ---------- Attempt lifecycle ---------- */

  Future<AttemptStartDto> startOrResumeAttempt(String lessonId) async {
    final json = await _client.post('/api/v1/lessons/$lessonId/attempts');
    return AttemptStartDto.fromJson(json);
  }

  Future<CurrentActivityDto> getCurrent(String attemptId, {String? activityId}) async {
    final qs = activityId != null ? '?activityId=${Uri.encodeComponent(activityId)}' : '';
    final json = await _client.get('/api/v1/attempts/$attemptId/current$qs');
    return CurrentActivityDto.fromJson(json);
  }

  /// Chọn dấu vết trong Bước 1 DISCOVERY hoặc quay lại giả thuyết để sửa.
  /// POST /attempts/{attemptId}/cursor — server kiểm quyền truy cập activity.
  Future<CurrentActivityDto> selectActivity(
    String attemptId,
    String activityId,
  ) async {
    final json = await _client.post(
      '/api/v1/attempts/$attemptId/cursor',
      body: {'activityId': activityId},
    );
    return CurrentActivityDto.fromJson(json);
  }

  Future<SubmitResultDto> submit(
    String attemptId,
    String activityId,
    Map<String, dynamic> answer, {
    String? idempotencyKey,
  }) async {
    final json = await _client.post(
      '/api/v1/attempts/$attemptId/activities/$activityId/submissions',
      body: {'answer': answer},
      headers: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return SubmitResultDto.fromJson(json);
  }

  Future<CompleteResultDto> complete(
    String attemptId, {
    String? idempotencyKey,
  }) async {
    final json = await _client.post(
      '/api/v1/attempts/$attemptId/complete',
      headers: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return CompleteResultDto.fromJson(json);
  }

  Future<LessonResultDto> getResult(String attemptId) async {
    final json = await _client.get('/api/v1/attempts/$attemptId/result');
    return LessonResultDto.fromJson(json);
  }

  /* ---------- Progress ---------- */

  Future<MyProgressDto> myProgress() async {
    final json = await _client.get('/api/v1/me/progress');
    return MyProgressDto.fromJson(json);
  }

  Future<List<AttemptSummaryDto>> myAttempts({String? status}) async {
    final json = await _client.get(
      '/api/v1/me/attempts',
      query: {'status': ?status, 'size': 50},
    );
    final List<dynamic> items =
        (json['items'] ?? json['content'] ?? const <dynamic>[])
            as List<dynamic>;
    return items
        .whereType<Map>()
        .map((e) => AttemptSummaryDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /* ---------- Learner media ---------- */

  /// GET /api/v1/assets/{id}/content — bytes ảnh có Bearer.
  Future<List<int>> getAssetBytes(String assetId) =>
      _client.getBytes('/api/v1/assets/$assetId/content');

  /// GET /api/v1/animation-versions/{versionId}/html — bytes HTML của
  /// scene version đã publish (Bearer trong header — WebView không bao
  /// giờ thấy token; bytes đi qua Dart rồi loadHtmlString).
  Future<List<int>> getAnimationHtmlBytes(String versionId) =>
      _client.getBytes('/api/v1/animation-versions/$versionId/html');
}
