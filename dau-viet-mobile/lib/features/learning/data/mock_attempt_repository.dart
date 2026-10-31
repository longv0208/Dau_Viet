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
      'stage': {'id': 'st-mcq', 'type': 'CONTEXT', 'title': 'Truyền thuyết'},
      'activity': {
        'id': 'act-mcq',
        'type': 'MULTIPLE_CHOICE',
        'instruction': 'Hãy suy nghĩ và chọn câu trả lời đúng nhất nhé!',
        'config': {
          'question':
              'Theo truyền thuyết, Lạc Long Quân và Âu Cơ sinh ra bọc trăm trứng, sau đó chia nhau đi đâu?',
          'multiSelect': false,
          'options': [
            {
              'id': 'o1',
              'label': '50 con theo mẹ lên núi, 50 con theo cha xuống biển',
            },
            {
              'id': 'o2',
              'label': 'Cùng nhau ở lại đồng bằng xây dựng xóm làng',
            },
            {'id': 'o3', 'label': 'Di cư sang phương Bắc để khai khẩn đất mới'},
            {
              'id': 'o4',
              'label': 'Đi khắp bốn phương tìm kiếm vùng đất trù phú',
            },
          ],
        },
        'feedback': {
          'correct':
              'Chính xác! Lạc Long Quân đưa 50 con xuống biển, Âu Cơ đưa 50 con lên núi.',
          'wrong': 'Chưa chính xác, hãy nhớ lại câu chuyện bọc trăm trứng nhé.',
        },
      },
    },
    {
      'stage': {'id': 'st-matching', 'type': 'EVIDENCE', 'title': 'Ghép cặp'},
      'activity': {
        'id': 'act-matching',
        'type': 'MATCHING',
        'instruction': 'Ghép mỗi nhân vật, hiện vật với thông tin phù hợp',
        'config': {
          'leftItems': [
            {'id': 'l1', 'label': 'Lạc Long Quân'},
            {'id': 'l2', 'label': 'Âu Cơ'},
            {'id': 'l3', 'label': 'Trống đồng'},
            {'id': 'l4', 'label': 'Văn Lang'},
          ],
          'rightItems': [
            {
              'id': 'r1',
              'label': 'Vua Rồng biển cả, tổ tiên truyền thuyết của người Việt',
            },
            {'id': 'r2', 'label': 'Mẹ Âu Cơ dẫn 50 con lên miền non cao'},
            {
              'id': 'r3',
              'label': 'Biểu tượng văn hoá đỉnh cao thời đại dựng nước',
            },
            {
              'id': 'r4',
              'label': 'Người đứng đầu nhà nước sơ khai của người Việt',
            },
          ],
        },
        'feedback': {
          'correct': 'Tuyệt vời! Bạn đã ghép chính xác toàn bộ tư liệu.',
        },
      },
    },
    {
      'stage': {
        'id': 'st-order',
        'type': 'RECONSTRUCTION',
        'title': 'Trình tự',
      },
      'activity': {
        'id': 'act-order',
        'type': 'DRAG_ORDER',
        'instruction':
            'Hãy sắp xếp các sự kiện theo đúng trình tự thời gian nhé!',
        'config': {
          'items': [
            {'id': 's1', 'label': 'Lạc Long Quân kết duyên cùng Âu Cơ'},
            {
              'id': 's2',
              'label': 'Sinh ra bọc trăm trứng nở thành trăm người con',
            },
            {'id': 's3', 'label': 'Chia 50 con lên núi, 50 con xuống biển'},
            {
              'id': 's4',
              'label': 'Người con trưởng lên ngôi, lập nên nhà nước Văn Lang',
            },
          ],
        },
        'feedback': {
          'correct': 'Chính xác! Trình tự thời gian đã hoàn toàn đúng.',
        },
      },
    },
    {
      'stage': {'id': 'st-tf', 'type': 'CONCLUSION', 'title': 'Đúng / Sai'},
      'activity': {
        'id': 'act-tf',
        'type': 'MULTIPLE_CHOICE',
        'instruction':
            'Quan sát tranh minh họa và nhận định xem đúng hay sai nhé!',
        'config': {
          'question':
              'Thời Hùng Vương, người Việt đã biết trồng lúa nước, làm nhà sàn và sống thành các làng bản.',
          'image': 'assets/images/lesson_scene_hung_kings_life.jpg',
          'multiSelect': false,
          'options': [
            {'id': 'opt-true', 'label': 'Đúng'},
            {'id': 'opt-false', 'label': 'Sai'},
          ],
        },
        'feedback': {
          'correct':
              'Chính xác! Nền văn minh sông Hồng gắn liền với nghề trồng lúa nước và nếp sống nhà sàn.',
        },
      },
    },
  ];

  CurrentActivityDto _current() {
    int cur = _cursor;
    try {
      final frag = Uri.base.fragment;
      if (frag.contains('step=')) {
        final val = int.tryParse(frag.split('step=')[1].split('&')[0]);
        if (val != null && val >= 0 && val < _activities.length) {
          cur = val;
        }
      }
    } catch (_) {}

    if (cur >= _activities.length) {
      return CurrentActivityDto(
        progress: AttemptProgressDto(
          completedRequired: _activities.length,
          totalRequired: _activities.length,
        ),
      );
    }
    final Map<String, dynamic> row = _activities[cur];
    return CurrentActivityDto(
      stage: StageRefDto.fromJson(
        (row['stage'] as Map).cast<String, dynamic>(),
      ),
      activity: ActivityRefDto.fromJson(
        (row['activity'] as Map).cast<String, dynamic>(),
      ),
      progress: AttemptProgressDto(
        completedRequired: cur,
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
  Future<CurrentActivityDto> getCurrent(String attemptId, {String? activityId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _current();
  }

  @override
  Future<CurrentActivityDto> selectActivity(
    String attemptId,
    String activityId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
    final bool firstComplete = !_completed;
    _completed = true;
    return CompleteResultDto(
      attemptId: _attemptId,
      status: 'COMPLETED',
      alreadyCompleted: !firstComplete,
      completion: const CompletionVerdictDto(complete: true),
      progress: const AttemptProgressDto(
        completedRequired: 3,
        totalRequired: 3,
      ),
      newlyUnlockedLocations: firstComplete
          ? const [
              UnlockedLocationCueDto(
                locationId: 'a0000000-0000-0000-0000-000000000004',
                slug: 'bai-coc-yen-giang',
                title: 'Bãi cọc Bạch Đằng (Yên Giang)',
                kind: 'HERITAGE_SITE',
                coverAssetId: 'd7a70000-0000-4000-8000-000000000003',
              ),
            ]
          : const [],
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
