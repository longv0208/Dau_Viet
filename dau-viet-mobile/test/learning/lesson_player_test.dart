import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
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

    testWidgets(
      'submit đúng → giữ activity + feedback, bấm TIẾP TỤC mới refetch',
      (tester) async {
        var submitted = false;
        final repo = FakeAttemptRepository();
        repo.onGetCurrent = () => submitted
            ? _current(_mcqActivity, done: 1)
            : _current(_readActivity);
        repo.onSubmit = (a) => const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(outcome: 'COMPLETED', completed: true),
          activityCompleted: true,
          progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
          completion: CompletionVerdictDto(complete: false),
        );
        await _pump(tester, repo);
        final callsBefore = repo.getCurrentCalls;
        submitted = true;
        await tester.tap(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
        await tester.pumpAndSettle();
        expect(repo.submittedKeys.single, isNotNull);
        // Chưa refetch — vẫn ở activity cũ, feedback + nút TIẾP TỤC hiện.
        expect(repo.getCurrentCalls, callsBefore);
        expect(find.text('TIẾP TỤC ›'), findsOneWidget);
        expect(find.text('Câu hỏi?'), findsNothing);
        // Bấm TIẾP TỤC → refetch → render activity kế.
        await tester.tap(find.text('TIẾP TỤC ›'));
        await tester.pumpAndSettle();
        expect(find.text('Câu hỏi?'), findsOneWidget);
      },
    );

    testWidgets('PARTIAL → cảnh báo + giữ nguyên activity, không refetch', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(
          outcome: 'PARTIAL',
          completed: false,
          feedbackCode: 'wrong',
        ),
        activityCompleted: false,
        progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
        completion: CompletionVerdictDto(complete: false),
      );
      await _pump(tester, repo);
      final callsBefore = repo.getCurrentCalls;
      await tester.tap(find.text('Đúng'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      // PARTIAL → vẫn activity cũ, không nút TIẾP TỤC, không refetch.
      expect(repo.getCurrentCalls, callsBefore);
      expect(find.text('Chưa đúng.'), findsOneWidget);
      expect(find.text('Câu hỏi?'), findsOneWidget);
      expect(find.text('TIẾP TỤC ›'), findsNothing);
    });

    testWidgets('INCORRECT + exhausted → không hứa thử lại; TIẾP TỤC hiện', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(
          outcome: 'INCORRECT',
          completed: false,
          output: {'exhausted': true},
        ),
        activityCompleted: true,
        progress: AttemptProgressDto(completedRequired: 1, totalRequired: 2),
        completion: CompletionVerdictDto(complete: false),
      );
      await _pump(tester, repo);
      await tester.tap(find.text('Sai'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      // Feedback phải nói đã hết lượt thử — không "hãy thử lại".
      expect(find.textContaining('hết lượt thử'), findsOneWidget);
      expect(find.text('Chưa đúng, hãy thử lại.'), findsNothing);
      // Server đã advance cursor → nút Tiếp tục phải hiện.
      expect(find.text('TIẾP TỤC ›'), findsOneWidget);
    });

    testWidgets('feedbackCode resolve text từ activity.feedback', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      repo.onSubmit = (a) => const SubmitResultDto(
        status: 'ACCEPTED',
        evaluation: EvaluationDto(
          outcome: 'COMPLETED',
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

    testWidgets(
      'final activity: completionReady khóa renderer, không submit lại được',
      (tester) async {
        final repo = FakeAttemptRepository();
        repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
        repo.onSubmit = (a) => const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(
            outcome: 'COMPLETED',
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
        // Feedback + nút hoàn thành hiện; nút submit của renderer biến mất
        // (renderer bị disable) — không thể resubmit activity đã xong.
        expect(find.text('Chính xác!'), findsOneWidget);
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
        expect(find.text('GỬI CÂU TRẢ LỜI'), findsNothing);
        expect(find.text('TIẾP TỤC ›'), findsNothing);
        // Tap vào option khác cũng không gây submit thêm.
        final submitsBefore = repo.submittedAnswers.length;
        await tester.tap(find.text('Sai'));
        await tester.pumpAndSettle();
        expect(repo.submittedAnswers.length, submitsBefore);
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
      },
    );

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

    /* ================= P1-B: result fetch after completion ================= */

    testWidgets(
      'complete OK + result fail → acknowledged state, không re-POST complete',
      (tester) async {
        final repo = FakeAttemptRepository();
        repo.onGetCurrent = () => const CurrentActivityDto(
          progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
        );
        repo.resultError = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'timeout'),
        );
        await _pump(tester, repo);
        await tester.tap(find.text('HOÀN THÀNH BÀI HỌC'));
        await tester.pumpAndSettle();

        // Phase 1 đã xong — chỉ 1 POST complete.
        expect(repo.completeCalls, 1);
        expect(repo.getResultCalls, 1);
        // Trạng thái acknowledged: không nút HOÀN THÀNH, có nút retry result.
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
        expect(
          find.text('Bài học đã hoàn thành. Chưa tải được kết quả.'),
          findsOneWidget,
        );
        expect(find.text('THỬ TẢI KẾT QUẢ'), findsOneWidget);
      },
    );

    testWidgets(
      'retry result sau lỗi → chỉ gọi GET result, không re-POST complete',
      (tester) async {
        final repo = FakeAttemptRepository();
        repo.onGetCurrent = () => const CurrentActivityDto(
          progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
        );
        repo.resultError = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'timeout'),
        );
        await _pump(tester, repo);
        await tester.tap(find.text('HOÀN THÀNH BÀI HỌC'));
        await tester.pumpAndSettle();
        expect(repo.completeCalls, 1);
        expect(repo.getResultCalls, 1);

        // Sửa lỗi → retry chỉ gọi GET result.
        repo.resultError = null;
        repo.result = const LessonResultDto(
          attemptId: 'a-1',
          lessonVersionId: 'v',
          status: 'COMPLETED',
          score: 90,
          result: {'note': 'ok'},
        );
        await tester.tap(find.text('THỬ TẢI KẾT QUẢ'));
        await tester.pumpAndSettle();
        expect(repo.completeCalls, 1); // vẫn chỉ 1 POST
        expect(repo.getResultCalls, 2);
        expect(find.text('90'), findsOneWidget);
      },
    );

    testWidgets(
      'complete POST fail → không acknowledged, không unlock, giữ retry',
      (tester) async {
        final repo = FakeAttemptRepository();
        repo.onGetCurrent = () => const CurrentActivityDto(
          progress: AttemptProgressDto(completedRequired: 2, totalRequired: 2),
        );
        repo.completeError = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
        await _pump(tester, repo);
        await tester.tap(find.text('HOÀN THÀNH BÀI HỌC'));
        await tester.pumpAndSettle();

        // Không acknowledged → không invalidate map, không result call.
        expect(repo.completeCalls, 1);
        expect(repo.getResultCalls, 0);
        // Nút vẫn "HOÀN THÀNH BÀI HỌC" — chưa acknowledged.
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
        expect(find.text('THỬ TẢI KẾT QUẢ'), findsNothing);
      },
    );

    testWidgets('Back khi có input chưa gửi → Ở LẠI giữ nguyên selection', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      await _pump(tester, repo);
      await tester.tap(find.text('Đúng'));
      await tester.pump();

      // Nút back góc trên — dirty → hiện dialog, không thoát.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Thoát bài học?'), findsOneWidget);

      await tester.tap(find.text('Ở LẠI'));
      await tester.pumpAndSettle();
      // Vẫn ở activity, selection còn nguyên.
      expect(find.text('Câu hỏi?'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
    });

    testWidgets('Back khi có input chưa gửi → THOÁT rời màn hình', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      await _pump(tester, repo);
      await tester.tap(find.text('Đúng'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Thoát bài học?'), findsOneWidget);

      await tester.tap(find.text('THOÁT'));
      await tester.pumpAndSettle();
      // Pop thật → route player rời stack (initial route chỉ có 1 màn →
      // pop không được → fallback go('/dashboard')).
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Câu hỏi?'), findsNothing);
    });

    testWidgets('Back khi KHÔNG có input chưa gửi → thoát ngay không hỏi', (
      tester,
    ) async {
      final repo = FakeAttemptRepository();
      repo.onGetCurrent = () => _current(_mcqActivity, done: 1);
      await _pump(tester, repo);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Thoát bài học?'), findsNothing);
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('Back sau submit đã ghi nhận → thoát ngay không hỏi', (
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
      // Input đã được server ghi nhận → không còn dirty → không hỏi.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Thoát bài học?'), findsNothing);
      expect(find.text('DASHBOARD'), findsOneWidget);
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
