import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';

const _readActivity = {
  'id': 'act-1',
  'type': 'READ',
  'instruction': 'Đọc rồi bấm tiếp.',
  'config': {'title': 'Bối cảnh', 'body': 'Nội dung'},
  'feedback': {},
};

const _mcqActivity = {
  'id': 'act-2',
  'type': 'MULTIPLE_CHOICE',
  'instruction': 'Chọn đáp án đúng.',
  'config': {
    'question': 'Câu hỏi?',
    'multiSelect': false,
    'options': [
      {'id': 'o1', 'label': 'Đúng'},
      {'id': 'o2', 'label': 'Sai'},
    ],
  },
  'feedback': {'correct': 'Chính xác!', 'wrong': 'Chưa đúng.'},
};

CurrentActivityDto _current(
  Map<String, dynamic> activity, {
  int done = 0,
  int total = 2,
}) => CurrentActivityDto(
  stage: const StageRefDto(id: 's1', type: 'CONTEXT', title: 'Bối cảnh'),
  activity: ActivityRefDto.fromJson(activity),
  progress: AttemptProgressDto(completedRequired: done, totalRequired: total),
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
  group('LessonPlayerScreen', () {
    testWidgets('render activity đầu theo server cursor + progress bar', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_readActivity);
      await _pump(tester, repo);
      expect(find.text('Đọc rồi bấm tiếp.'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'), findsOneWidget);
    });

    testWidgets('submit đúng → refetch current render activity kế', (
      tester,
    ) async {
      var submitted = false;
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () =>
          submitted ? _current(_mcqActivity, done: 1) : _current(_readActivity);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(outcome: 'CORRECT', completed: true),
        activityCompleted: true,
        progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
        completion: CompletionVerdictDto(complete: false),
      );
      await _pump(tester, repo);
      submitted = true;
      await tester.tap(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
      await tester.pumpAndSettle();
      expect(repo.submittedKeys.single, isNotNull);
      // Sau submit player refetch /current → activity MCQ render.
      expect(find.text('Câu hỏi?'), findsOneWidget);
    });

    testWidgets('feedbackCode resolve text từ activity.feedback', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(
          outcome: 'CORRECT',
          completed: true,
          feedbackCode: 'correct',
        ),
        activityCompleted: true,
        progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
        completion: CompletionVerdictDto(complete: true),
      );
      await _pump(tester, repo);
      await tester.tap(find.text('Đúng'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.text('Chính xác!'), findsOneWidget);
      // completion.complete → nút hoàn thành xuất hiện.
      expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
    });

    testWidgets('INCORRECT → feedback sai + giữ nguyên activity cho retry', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(
          outcome: 'INCORRECT',
          completed: false,
          feedbackCode: 'wrong',
        ),
        activityCompleted: false,
        progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
        completion: CompletionVerdictDto(complete: false),
      );
      await _pump(tester, repo);
      await tester.tap(find.text('Sai'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa đúng.'), findsOneWidget);
      expect(find.text('Câu hỏi?'), findsOneWidget); // vẫn ở activity cũ
    });

    testWidgets('hoàn thành: complete → getResult → điều hướng result', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => const CurrentActivityDto(
        progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
      );
      repo.result = const LessonResultDto(
        attemptId: 'a-1',
        lessonVersionId: 'v',
        status: 'COMPLETED',
        score: 100,
        result: {'summary': 'Xuất sắc'},
      );
      await _pump(tester, repo);
      // activity null → trạng thái hết required → nút hoàn thành.
      expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
      await tester.tap(find.text('HOÀN THÀNH BÀI HỌC'));
      await tester.pumpAndSettle();
      expect(repo.completeCalls, 1);
      // Result screen hiển thị score/summary thật.
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Xuất sắc'), findsOneWidget);
    });

    testWidgets('load error → error view + retry', (tester) async {
      final repo = FakeAttemptRepository()
        ..nextError = Exception('server down');
      await _pump(tester, repo);
      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
      expect(find.text('GỬI CÂU TRẢ LỜI'), findsNothing);
      expect(find.text('THỬ LẠI'), findsOneWidget);
    });
  });
}
