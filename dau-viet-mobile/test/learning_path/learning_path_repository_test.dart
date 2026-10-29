import 'package:dau_viet_mobile/core/api/api_client.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/learning_path/data/api_learning_path_repository.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_api_client.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApiClient extends ApiClient {
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic> nextResponse = const {};

  _RecordingApiClient() : super(Dio());

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query;
    return nextResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastQuery = query;
    return nextResponse;
  }
}

void main() {
  group('MockLearningPathRepository (AC-2)', () {
    test(
      'has 3 ERAs, multiple PERIODs, and all 6 LearnerPathStatus values',
      () async {
        final repo = MockLearningPathRepository();
        final path = await repo.getMyLearningPath();

        // 3 ERAs
        expect(path.eras.length, 3);
        expect(path.eras.map((e) => e.code).toList(), [
          'ERA_ANCIENT_MEDIEVAL',
          'ERA_EARLY_MODERN',
          'ERA_MODERN',
        ]);

        // Multiple PERIODs across the 3 ERAs
        expect(path.periods.length, greaterThanOrEqualTo(5));
        expect(path.eraGroups.length, 3);
        expect(path.eraGroups[0].periods.length, 4);
        expect(path.eraGroups[0].hasSinglePeriod, isFalse);
        expect(path.eraGroups[1].periods.length, 1);
        expect(path.eraGroups[1].hasSinglePeriod, isTrue);
        expect(path.eraGroups[2].periods.length, 1);
        expect(path.eraGroups[2].hasSinglePeriod, isTrue);

        // Collect all statuses from events + lessons
        final statuses = <LearnerPathStatus>{};
        for (final ch in path.chapters) {
          for (final ev in ch.events) {
            statuses.add(ev.status);
            for (final les in ev.lessons) {
              statuses.add(les.status);
            }
          }
        }

        expect(
          statuses,
          containsAll(<LearnerPathStatus>[
            LearnerPathStatus.completed,
            LearnerPathStatus.mastered,
            LearnerPathStatus.inProgress,
            LearnerPathStatus.available,
            LearnerPathStatus.locked,
            LearnerPathStatus.notReady,
          ]),
        );

        // Period progress & pointers
        expect(path.periodProgress.length, path.periods.length);
        expect(path.lastPeriodCode, 'EARLY_INDEPENDENCE');
        expect(path.effectiveCurrent?.lessonId, 'demo-lesson-bach-dang');
      },
    );

    test(
      'touchPeriod updates lastPeriodCode and rejects non-PERIOD codes with 404',
      () async {
        final repo = MockLearningPathRepository();

        final touched = await repo.touchPeriod('LY_DYNASTY');
        expect(touched.periodCode, 'LY_DYNASTY');
        expect(touched.chapterId, MockLearningPathRepository.periodLyDynastyId);
        expect(touched.touchedAt, isNotNull);

        final updated = await repo.getMyLearningPath();
        expect(updated.lastPeriodCode, 'LY_DYNASTY');
        expect(updated.effectiveCurrent?.lessonId, 'demo-lesson-thang-long-1');

        expect(
          () => repo.touchPeriod('ERA_MODERN'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
        expect(
          () => repo.touchPeriod('NON_EXISTENT'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
      },
    );
  });

  group('LearningPathApiClient & Riverpod Providers', () {
    test('calls expected backend endpoints', () async {
      final client = _RecordingApiClient();
      final api = LearningPathApiClient(client);
      final repo = ApiLearningPathRepository(api);

      client.nextResponse = {
        'pathCode': 'HISTORY_MAIN',
        'pathVersion': 2,
        'enrolled': true,
        'chapters': [],
      };
      final myPath = await repo.getMyLearningPath();
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/api/v1/me/learning-path');
      expect(myPath.pathVersion, 2);

      client.nextResponse = {
        'periodCode': 'LY_DYNASTY',
        'chapterId': 'ch-ly',
        'touchedAt': '2026-10-28T10:00:00Z',
      };
      final touchRes = await repo.touchPeriod('LY_DYNASTY');
      expect(client.lastMethod, 'POST');
      expect(
        client.lastPath,
        '/api/v1/me/learning-path/periods/LY_DYNASTY/touch',
      );
      expect(touchRes.periodCode, 'LY_DYNASTY');

      client.nextResponse = {
        'pathCode': 'HISTORY_MAIN',
        'pathVersion': 2,
        'chapters': [],
      };
      await repo.getPublishedLearningPath(code: 'HISTORY_MAIN');
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/api/v1/learning-path');
      expect(client.lastQuery, {'code': 'HISTORY_MAIN'});
    });

    test(
      'learningPathProvider builds from repository and updates state on touchPeriod',
      () async {
        final mockRepo = MockLearningPathRepository();
        final container = ProviderContainer(
          overrides: [
            learningPathRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final initial = await container.read(learningPathProvider.future);
        expect(initial.lastPeriodCode, 'EARLY_INDEPENDENCE');
        expect(
          container.read(currentPeriodPointerProvider).value?.lessonId,
          'demo-lesson-bach-dang',
        );
        expect(
          container
              .read(lessonPathStatusProvider('demo-lesson-bach-dang'))
              .value,
          LearnerPathStatus.inProgress,
        );
        expect(
          container
              .read(eventPathNodeProvider('evt_bach_dang_938'))
              .value
              ?.slug,
          'bach-dang-938',
        );

        await container
            .read(learningPathProvider.notifier)
            .touchPeriod('LY_DYNASTY');

        final afterTouch = container.read(learningPathProvider).value!;
        expect(afterTouch.lastPeriodCode, 'LY_DYNASTY');
        expect(
          container.read(currentPeriodPointerProvider).value?.lessonId,
          'demo-lesson-thang-long-1',
        );
      },
    );
  });
}
