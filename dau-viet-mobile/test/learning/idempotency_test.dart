import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';

const _mcq = {
  'id': 'act-1',
  'type': 'MULTIPLE_CHOICE',
  'config': {
    'question': 'Q?',
    'multiSelect': false,
    'options': [
      {'id': 'o1', 'label': 'A'},
      {'id': 'o2', 'label': 'B'},
    ],
  },
  'feedback': {'wrong': 'Sai'},
};

CurrentActivityDto _cur() => CurrentActivityDto(
  stage: const StageRefDto(id: 's'),
  activity: ActivityRefDto.fromJson(_mcq),
  progress: const AttemptProgressDto(completedRequired: 0, totalRequired: 1),
);

Future<void> _pump(WidgetTester tester, FakeAttemptRepository repo) async {
  final router = GoRouter(
    initialLocation: '/learning/attempt/a-1',
    routes: [
      GoRoute(
        path: '/learning/attempt/:id',
        builder: (context, state) =>
            LessonPlayerScreen(attemptId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
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

void main() {
  group('Idempotency-Key rules', () {
    testWidgets('network fail rồi retry CÙNG answer → CÙNG key', (
      tester,
    ) async {
      var failFirst = true;
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = _cur;
      repo.onSubmit = (a) {
        if (failFirst) {
          throw const ApiException(
            ApiError(code: 'NETWORK_ERROR', message: 'lost'),
          );
        }
        return const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(outcome: 'CORRECT', completed: true),
          activityCompleted: true,
          progress: AttemptProgressDto(completedRequired: 1, totalRequired: 1),
          completion: CompletionVerdictDto(complete: true),
        );
      };
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được. Thử lại.'), findsOneWidget);

      // Retry cùng answer → cùng key.
      failFirst = false;
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(repo.submittedKeys.length, 2);
      expect(repo.submittedKeys[0], repo.submittedKeys[1]);
      expect(repo.submittedKeys[0], isNotNull);
    });

    testWidgets('answer ĐỔI sau fail → key MỚI', (tester) async {
      var call = 0;
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = _cur;
      repo.onSubmit = (a) {
        call++;
        if (call == 1) {
          throw const ApiException(
            ApiError(code: 'NETWORK_ERROR', message: 'lost'),
          );
        }
        return const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(outcome: 'CORRECT', completed: true),
          activityCompleted: true,
          progress: AttemptProgressDto(completedRequired: 1, totalRequired: 1),
          completion: CompletionVerdictDto(complete: true),
        );
      };
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();

      // Đổi answer sang B rồi retry → key phải khác.
      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(repo.submittedKeys.length, 2);
      expect(repo.submittedKeys[0], isNot(repo.submittedKeys[1]));
      expect(repo.submittedAnswers[1], {
        'selectedOptionIds': ['o2'],
      });
    });

    testWidgets('IDEMPOTENCY_CONFLICT → mint key mới + retry 1 lần tự động', (
      tester,
    ) async {
      var call = 0;
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = _cur;
      repo.onSubmit = (a) {
        call++;
        if (call == 1) {
          throw const ApiException(
            ApiError(code: 'IDEMPOTENCY_CONFLICT', message: 'key reused'),
          );
        }
        return const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(outcome: 'COMPLETED', completed: true),
          activityCompleted: true,
          progress: AttemptProgressDto(completedRequired: 1, totalRequired: 1),
          completion: CompletionVerdictDto(complete: true),
        );
      };
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      // 2 lần gọi submit từ 1 lần bấm; key thứ hai là key mới.
      expect(repo.submittedKeys.length, 2);
      expect(repo.submittedKeys[0], isNotNull);
      expect(repo.submittedKeys[1], isNotNull);
      expect(repo.submittedKeys[0], isNot(repo.submittedKeys[1]));
    });
  });
}
