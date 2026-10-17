import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attempt lifecycle DTOs — khớp backend records', () {
    test('AttemptStartDto parse đủ field + resumed', () {
      final dto = AttemptStartDto.fromJson({
        'attemptId': 'a-1',
        'lessonVersionId': 'v-2',
        'status': 'IN_PROGRESS',
        'resumed': true,
        'currentStageId': 'st-1',
        'currentActivityId': 'act-1',
      });
      expect(dto.attemptId, 'a-1');
      expect(dto.lessonVersionId, 'v-2');
      expect(dto.resumed, isTrue);
      expect(dto.currentActivityId, 'act-1');
    });

    test('CurrentActivityDto activity null khi hết required', () {
      final dto = CurrentActivityDto.fromJson({
        'stage': null,
        'activity': null,
        'progress': {'completedRequired': 3, 'totalRequired': 3},
      });
      expect(dto.activity, isNull);
      expect(dto.progress.fraction, 1.0);
    });

    test('SubmitResultDto: next có learnerConfig', () {
      final dto = SubmitResultDto.fromJson({
        'status': 'ACCEPTED',
        'evaluation': {
          'outcome': 'CORRECT',
          'completed': true,
          'feedbackCode': 'correct',
        },
        'activityCompleted': true,
        'progress': {'completedRequired': 1, 'totalRequired': 4},
        'next': {
          'stageId': 'st-2',
          'activityId': 'act-2',
          'activityType': 'MATCHING',
          'learnerConfig': {'x': 1},
        },
        'completion': {'complete': false},
      });
      expect(dto.next!.activityType, 'MATCHING');
      expect(dto.next!.learnerConfig!['x'], 1);
      expect(dto.completion.complete, isFalse);
    });

    test('SubmitResultDto: next null + completion.complete', () {
      final dto = SubmitResultDto.fromJson({
        'status': 'ACCEPTED',
        'evaluation': {'outcome': 'CORRECT', 'completed': true},
        'activityCompleted': true,
        'progress': {'completedRequired': 4, 'totalRequired': 4},
        'next': null,
        'completion': {'complete': true, 'reason': 'ALL_REQUIRED'},
      });
      expect(dto.next, isNull);
      expect(dto.completion.complete, isTrue);
      expect(dto.completion.reason, 'ALL_REQUIRED');
    });

    test('CompleteResultDto + alreadyCompleted', () {
      final dto = CompleteResultDto.fromJson({
        'attemptId': 'a-1',
        'status': 'COMPLETED',
        'alreadyCompleted': true,
        'completedAt': '2026-10-17T10:00:00Z',
        'completion': {'complete': true},
        'progress': {'completedRequired': 2, 'totalRequired': 2},
      });
      expect(dto.alreadyCompleted, isTrue);
      expect(dto.status, 'COMPLETED');
    });

    test('LessonResultDto giữ result map free-form + score nullable', () {
      final dto = LessonResultDto.fromJson({
        'attemptId': 'a-1',
        'lessonVersionId': 'v-1',
        'status': 'COMPLETED',
        'score': 87.5,
        'result': {'summary': 'Tốt', 'correct': 7},
        'completedAt': 'x',
        'startedAt': 'y',
      });
      expect(dto.score, 87.5);
      expect(dto.result['correct'], 7);
    });

    test('MyProgressDto + AttemptSummaryDto', () {
      final dto = MyProgressDto.fromJson({
        'inProgress': [
          {
            'attemptId': 'a-9',
            'lessonId': 'l-1',
            'lessonVersionId': 'v-1',
            'status': 'IN_PROGRESS',
            'progress': {'completedRequired': 2, 'totalRequired': 5},
          },
        ],
        'completedCount': 3,
      });
      expect(dto.inProgress.single.attemptId, 'a-9');
      expect(dto.inProgress.single.progress.fraction, closeTo(0.4, 1e-9));
      expect(dto.completedCount, 3);
    });
  });

  group('ActivityRefDto.feedbackText', () {
    ActivityRefDto activity(Map<String, dynamic> feedback) =>
        ActivityRefDto.fromJson({'id': 'a', 'feedback': feedback});

    test('feedback String → trả nguyên text', () {
      expect(
        activity({'correct': 'Chính xác!'}).feedbackText('correct'),
        'Chính xác!',
      );
    });

    test('feedback Map → ưu tiên text/message/body', () {
      final a = activity({
        'wrong': {'text': 'Sai rồi', 'message': 'khác'},
      });
      expect(a.feedbackText('wrong'), 'Sai rồi');
      expect(a.feedbackText('missing'), isNull);
      expect(a.feedbackText(null), isNull);
    });
  });

  group('Lesson DTOs', () {
    test('LessonListItemDto + LessonMetadataDto parse', () {
      final item = LessonListItemDto.fromJson({
        'id': 'l-1',
        'title': 'Bí mật Bạch Đằng',
        'centralQuestion': 'Vì sao thắng?',
      });
      expect(item.title, 'Bí mật Bạch Đằng');

      final meta = LessonMetadataDto.fromJson({
        'id': 'l-1',
        'title': 'T',
        'eventId': 'e-1',
        'currentVersionId': 'v-3',
        'versionNo': 3,
        'publishedAt': '2026-01-01T00:00:00Z',
      });
      expect(meta.eventId, 'e-1');
      expect(meta.versionNo, 3);
    });

    test('LessonContentDto: stages/evidence/assets + lookup byId', () {
      final dto = LessonContentDto.fromJson({
        'lessonId': 'l-1',
        'lessonVersionId': 'v-1',
        'versionNo': 1,
        'content': {
          'stages': [
            {'id': 's1', 'type': 'CONTEXT'},
          ],
          'evidence': [
            {'id': 'ev1', 'title': 'Bia', 'description': 'd'},
          ],
          'assets': [
            {'id': 'as1', 'altText': 'ảnh'},
          ],
        },
      });
      expect(dto.stages.single['id'], 's1');
      expect(dto.evidenceById('ev1')!['title'], 'Bia');
      expect(dto.assetById('as1')!['altText'], 'ảnh');
      expect(dto.evidenceById('nope'), isNull);
    });
  });
}
