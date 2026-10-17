import 'attempt_dtos.dart';
import 'attempt_repository.dart';
import 'learning_dtos.dart';

/// Repository demo cho USE_MOCK=true — chạy journey Bạch Đằng mẫu bằng cùng
/// DTO shape của backend thật để Lesson Player render giống hệt real mode.
/// KHÔNG giả lập server: submit luôn trả completed, cursor tự tăng trong bộ
/// nhớ; rõ ràng là demo (UI hiển thị nhãn demo).
///
/// Lưu ý: các màn mock cũ dưới /learning/* vẫn hoạt động độc lập — repo này
/// chỉ phục vụ lesson player mới trong chế độ demo.
class MockAttemptRepository implements AttemptRepository {
  static const _attemptId = 'demo-attempt-0001';

  int _cursor = 0;
  bool _completed = false;

  static const List<Map<String, dynamic>> _activities = [
    {
      'stage': {'id': 'st-context', 'type': 'CONTEXT', 'title': 'Bối cảnh'},
      'activity': {
        'id': 'act-read',
        'type': 'READ',
        'instruction': 'Đọc bối cảnh trận Bạch Đằng 938 rồi bấm Tiếp tục.',
        'config': {
          'title': 'Bối cảnh năm 938',
          'body':
              'Năm 938, quân Nam Hán kéo thủy quân vào cửa sông Bạch Đằng. '
              'Ngô Quyền cho đóng cọc gỗ ngầm dưới lòng sông, lợi dụng triều '
              'lên xuống để mai phục — đòn then chốt của chiến thắng.',
        },
        'feedback': {},
      },
    },
    {
      'stage': {'id': 'st-evidence', 'type': 'EVIDENCE', 'title': 'Bằng chứng'},
      'activity': {
        'id': 'act-mcq',
        'type': 'MULTIPLE_CHOICE',
        'instruction': 'Đòn then chốt của Ngô Quyền là gì?',
        'config': {
          'question': 'Yếu tố quyết định chiến thắng Bạch Đằng 938?',
          'multiSelect': false,
          'options': [
            {'id': 'o1', 'label': 'Cọc gỗ ngầm + thủy triều'},
            {'id': 'o2', 'label': 'Quân số đông gấp ba'},
            {'id': 'o3', 'label': 'Hỏa công ban đêm'},
          ],
        },
        'feedback': {'correct': 'Chính xác!', 'wrong': 'Chưa đúng, thử lại.'},
      },
    },
    {
      'stage': {
        'id': 'st-order',
        'type': 'RECONSTRUCTION',
        'title': 'Dựng lại',
      },
      'activity': {
        'id': 'act-order',
        'type': 'DRAG_ORDER',
        'instruction': 'Sắp xếp lại trình tự chiến dịch.',
        'config': {
          'items': [
            {'id': 's2', 'label': 'Triều lên — quân Nam Hán tiến vào bãi cọc'},
            {'id': 's1', 'label': 'Ngô Quyền đóng cọc ngầm trước trận'},
            {'id': 's3', 'label': 'Triều rút — thuyền giặc mắc cọc, chìm'},
          ],
        },
        'feedback': {},
      },
    },
  ];

  CurrentActivityDto _current() {
    if (_cursor >= _activities.length) {
      return const CurrentActivityDto(
        progress: AttemptProgressDto(completedRequired: 3, totalRequired: 3),
      );
    }
    final Map<String, dynamic> row = _activities[_cursor];
    return CurrentActivityDto(
      stage: StageRefDto.fromJson(
        (row['stage'] as Map).cast<String, dynamic>(),
      ),
      activity: ActivityRefDto.fromJson(
        (row['activity'] as Map).cast<String, dynamic>(),
      ),
      progress: AttemptProgressDto(
        completedRequired: _cursor,
        totalRequired: _activities.length,
      ),
    );
  }

  @override
  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const [
      LessonListItemDto(
        id: 'demo-lesson-bach-dang',
        title: 'Bí mật chiến thắng Bạch Đằng (Demo)',
        centralQuestion:
            'Vì sao bãi cọc Bạch Đằng đánh bại được thủy quân Nam Hán?',
      ),
    ];
  }

  @override
  Future<LessonMetadataDto> getLessonMetadata(String lessonId) async =>
      const LessonMetadataDto(
        id: 'demo-lesson-bach-dang',
        title: 'Bí mật chiến thắng Bạch Đằng (Demo)',
        centralQuestion:
            'Vì sao bãi cọc Bạch Đằng đánh bại được thủy quân Nam Hán?',
        eventId: 'demo-event',
        currentVersionId: 'demo-v1',
        versionNo: 1,
      );

  @override
  Future<LessonContentDto> getAttemptContent(String attemptId) async {
    return LessonContentDto.fromJson(const {
      'lessonId': 'demo-lesson-bach-dang',
      'lessonVersionId': 'demo-v1',
      'versionNo': 1,
      'content': {
        'stages': [
          {'id': 'st-context', 'type': 'CONTEXT', 'title': 'Bối cảnh'},
          {'id': 'st-evidence', 'type': 'EVIDENCE', 'title': 'Bằng chứng'},
          {'id': 'st-order', 'type': 'RECONSTRUCTION', 'title': 'Dựng lại'},
        ],
        'evidence': [],
        'assets': [],
      },
    });
  }

  @override
  Future<AttemptStartDto> startOrResume(String lessonId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return AttemptStartDto(
      attemptId: _attemptId,
      lessonVersionId: 'demo-v1',
      status: 'IN_PROGRESS',
      resumed: _cursor > 0,
      currentStageId: _cursor < _activities.length
          ? (_activities[_cursor]['stage'] as Map)['id'] as String?
          : null,
      currentActivityId: _cursor < _activities.length
          ? (_activities[_cursor]['activity'] as Map)['id'] as String?
          : null,
    );
  }

  @override
  Future<CurrentActivityDto> getCurrent(String attemptId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _current();
  }

  @override
  Future<SubmitResultDto> submit(
    String attemptId,
    String activityId,
    Map<String, dynamic> answer, {
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _cursor++;
    final next = _cursor < _activities.length
        ? NextRefDto.fromJson({
            'stageId': (_activities[_cursor]['stage'] as Map)['id'],
            'activityId': (_activities[_cursor]['activity'] as Map)['id'],
            'activityType': (_activities[_cursor]['activity'] as Map)['type'],
            'learnerConfig':
                (_activities[_cursor]['activity'] as Map)['config'],
          })
        : null;
    return SubmitResultDto(
      status: 'ACCEPTED',
      evaluation: const EvaluationDto(outcome: 'COMPLETED', completed: true),
      activityCompleted: true,
      progress: AttemptProgressDto(
        completedRequired: _cursor,
        totalRequired: _activities.length,
      ),
      next: next,
      completion: CompletionVerdictDto(complete: _cursor >= _activities.length),
    );
  }

  @override
  Future<CompleteResultDto> complete(
    String attemptId, {
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _completed = true;
    return const CompleteResultDto(
      attemptId: _attemptId,
      status: 'COMPLETED',
      alreadyCompleted: false,
      completion: CompletionVerdictDto(complete: true),
      progress: AttemptProgressDto(completedRequired: 3, totalRequired: 3),
    );
  }

  @override
  Future<LessonResultDto> getResult(String attemptId) async {
    return const LessonResultDto(
      attemptId: _attemptId,
      lessonVersionId: 'demo-v1',
      status: 'COMPLETED',
      score: 100,
      result: {'reason': 'demo', 'completedRequired': 3, 'totalRequired': 3},
    );
  }

  @override
  Future<MyProgressDto> myProgress() async => MyProgressDto(
    inProgress: _completed
        ? const []
        : const [
            AttemptSummaryDto(
              attemptId: _attemptId,
              lessonId: 'demo-lesson-bach-dang',
              lessonVersionId: 'demo-v1',
              status: 'IN_PROGRESS',
              progress: AttemptProgressDto(
                completedRequired: 0,
                totalRequired: 3,
              ),
            ),
          ],
    completedCount: _completed ? 1 : 0,
  );

  @override
  Future<List<int>> getAssetBytes(String assetId) async => const <int>[];
}
