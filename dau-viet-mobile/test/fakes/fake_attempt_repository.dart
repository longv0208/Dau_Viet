import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';

/// Scripted repo cho widget/provider test — KHÔNG phải mock repo của app
/// (MockAttemptRepository chỉ phục vụ demo USE_MOCK). Class này ghi lại mọi
/// submit (answer + idempotency key) để test verify contract.
class FakeAttemptRepository implements AttemptRepository {
  List<LessonListItemDto> lessons = const [];
  LessonMetadataDto? metadata;
  LessonContentDto content = const LessonContentDto(
    lessonId: 'l',
    lessonVersionId: 'v',
    content: {},
  );

  CurrentActivityDto Function()? onGetCurrent;
  SubmitResultDto Function(Map<String, dynamic> answer)? onSubmit;
  LessonResultDto? result;
  Object? nextError;
  bool throwOnGetContent = false;

  final List<Map<String, dynamic>> submittedAnswers = [];
  final List<String?> submittedKeys = [];
  int completeCalls = 0;
  int getCurrentCalls = 0;

  @override
  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId) async =>
      lessons;

  @override
  Future<LessonMetadataDto> getLessonMetadata(String lessonId) async =>
      metadata ?? const LessonMetadataDto(id: 'l', title: 'T', eventId: 'e');

  @override
  Future<LessonContentDto> getAttemptContent(String attemptId) async {
    if (throwOnGetContent) {
      throw Exception('content unavailable');
    }
    return content;
  }

  @override
  Future<AttemptStartDto> startOrResume(String lessonId) async =>
      const AttemptStartDto(
        attemptId: 'a-1',
        lessonVersionId: 'v',
        status: 'IN_PROGRESS',
        resumed: false,
      );

  @override
  Future<CurrentActivityDto> getCurrent(String attemptId) async {
    getCurrentCalls++;
    if (nextError != null) throw nextError!;
    return onGetCurrent?.call() ??
        const CurrentActivityDto(progress: AttemptProgressDto.empty);
  }

  @override
  Future<SubmitResultDto> submit(
    String attemptId,
    String activityId,
    Map<String, dynamic> answer, {
    String? idempotencyKey,
  }) async {
    submittedAnswers.add(answer);
    submittedKeys.add(idempotencyKey);
    if (nextError != null) throw nextError!;
    return onSubmit?.call(answer) ??
        const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(outcome: 'CORRECT', completed: true),
          activityCompleted: true,
          progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
          completion: CompletionVerdictDto(complete: false),
        );
  }

  @override
  Future<CompleteResultDto> complete(
    String attemptId, {
    String? idempotencyKey,
  }) async {
    completeCalls++;
    return const CompleteResultDto(
      attemptId: 'a-1',
      status: 'COMPLETED',
      alreadyCompleted: false,
      completion: CompletionVerdictDto(complete: true),
      progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
    );
  }

  @override
  Future<LessonResultDto> getResult(String attemptId) async =>
      result ??
      const LessonResultDto(
        attemptId: 'a-1',
        lessonVersionId: 'v',
        status: 'COMPLETED',
        score: 80,
        result: {},
      );

  @override
  Future<MyProgressDto> myProgress() async =>
      const MyProgressDto(inProgress: [], completedCount: 0);

  @override
  Future<List<int>> getAssetBytes(String assetId) async => const <int>[];
}
