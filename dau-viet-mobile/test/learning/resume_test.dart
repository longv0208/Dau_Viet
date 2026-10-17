import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';

/// Attempt đã học dở: cursor server trỏ activity giữa bài (2/5 xong).
const _midLessonActivity = {
  'id': 'act-3',
  'type': 'READ',
  'instruction': 'Đọc đoạn tiếp theo của bài đang học dở.',
  'config': {'title': 'Stage 2', 'body': 'Nội dung giữa bài'},
  'feedback': {},
};

void main() {
  group('AttemptStartDto — resume contract', () {
    test('resumed:true + cursor giữa bài parse đúng từ backend', () {
      final dto = AttemptStartDto.fromJson(const {
        'attemptId': 'a-9',
        'lessonVersionId': 'v-2',
        'status': 'IN_PROGRESS',
        'resumed': true,
        'currentStageId': 's-2',
        'currentActivityId': 'act-3',
      });
      expect(dto.resumed, isTrue);
      expect(dto.currentStageId, 's-2');
      expect(dto.currentActivityId, 'act-3');
    });

    test('resumed:false khi attempt mới — không có cursor', () {
      final dto = AttemptStartDto.fromJson(const {
        'attemptId': 'a-1',
        'lessonVersionId': 'v-1',
        'status': 'IN_PROGRESS',
        'resumed': false,
      });
      expect(dto.resumed, isFalse);
      expect(dto.currentStageId, isNull);
      expect(dto.currentActivityId, isNull);
    });
  });

  group('LessonPlayerScreen — resume mid-lesson', () {
    Future<void> pump(WidgetTester tester, FakeAttemptRepository repo) async {
      final router = GoRouter(
        initialLocation: '/learning/attempt/a-9',
        routes: [
          GoRoute(
            path: '/learning/attempt/:id',
            builder: (context, state) =>
                LessonPlayerScreen(attemptId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/learning/result/:id',
            builder: (context, state) => LessonResultScreen(
              attemptId: state.pathParameters['id']!,
              initialResult: state.extra is LessonResultDto
                  ? state.extra as LessonResultDto
                  : null,
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Text('DASHBOARD')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cursor server giữa bài → player render đúng activity đó '
        '(không reset về đầu)', (tester) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => CurrentActivityDto(
        stage: const StageRefDto(
          id: 's-2',
          type: 'ANALYSIS',
          title: 'Phân tích',
        ),
        activity: ActivityRefDto.fromJson(_midLessonActivity),
        progress: const AttemptProgressDto(
          completedRequired: 2,
          totalRequired: 5,
        ),
      );
      await pump(tester, repo);

      // Activity giữa bài render thẳng — không qua act-1/act-2.
      expect(
        find.text('Đọc đoạn tiếp theo của bài đang học dở.'),
        findsOneWidget,
      );
      // Progress bar phản ánh cursor server: 2/5.
      expect(find.text('2/5'), findsOneWidget);
      // Stage title từ cursor (không phải stage đầu).
      expect(find.text('Phân tích'), findsOneWidget);
    });

    testWidgets('myProgress provider trả attempt IN_PROGRESS để resume', (
      tester,
    ) async {
      final repo = _ProgressRepo()
        ..progress = const MyProgressDto(
          inProgress: [
            AttemptSummaryDto(
              attemptId: 'a-9',
              lessonId: 'l-1',
              lessonVersionId: 'v-2',
              status: 'IN_PROGRESS',
              currentStageId: 's-2',
              currentActivityId: 'act-3',
              progress: AttemptProgressDto(
                completedRequired: 2,
                totalRequired: 5,
              ),
            ),
          ],
          completedCount: 1,
        );
      final container = ProviderContainer(
        overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final progress = await container.read(myProgressProvider.future);
      expect(progress.inProgress.single.attemptId, 'a-9');
      expect(progress.inProgress.single.currentActivityId, 'act-3');
      expect(progress.inProgress.single.progress.fraction, closeTo(0.4, 1e-9));
      expect(progress.completedCount, 1);
    });
  });
}

class _ProgressRepo extends FakeAttemptRepository {
  MyProgressDto progress = const MyProgressDto(
    inProgress: [],
    completedCount: 0,
  );

  @override
  Future<MyProgressDto> myProgress() async => progress;
}
