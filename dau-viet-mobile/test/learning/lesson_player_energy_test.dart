import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';
import '../fakes/fake_energy_repository.dart';

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
  'feedback': {'wrong': 'Sai rồi'},
};

CurrentActivityDto _cur() => CurrentActivityDto(
  stage: const StageRefDto(id: 's'),
  activity: ActivityRefDto.fromJson(_mcq),
  progress: const AttemptProgressDto(completedRequired: 0, totalRequired: 1),
);

Future<void> _pump(
  WidgetTester tester,
  FakeAttemptRepository repo, {
  FakeEnergyRepository? energyRepo,
}) async {
  final router = GoRouter(
    initialLocation: '/learning/attempt/a-1',
    routes: [
      GoRoute(
        path: '/learning/attempt/:id',
        builder: (context, state) =>
            LessonPlayerScreen(attemptId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/energy',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('VIỆN THÁI Y')),
          body: const Text('VIỆN THÁI Y SCREEN'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attemptRepositoryProvider.overrideWithValue(repo),
        if (energyRepo != null)
          energyRepositoryProvider.overrideWithValue(energyRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

SubmitResultDto _incorrect({int deducted = 10, EnergyStateDto? energy}) =>
    SubmitResultDto(
      status: 'ACCEPTED',
      evaluation: const EvaluationDto(
        outcome: 'INCORRECT',
        completed: false,
        feedbackCode: 'wrong',
      ),
      activityCompleted: false,
      progress: const AttemptProgressDto(
        completedRequired: 0,
        totalRequired: 1,
      ),
      completion: const CompletionVerdictDto(complete: false),
      energyDeducted: deducted,
      energy: energy,
    );

void main() {
  group('Lesson Player — energy integration (GAME-03)', () {
    testWidgets('INCORRECT + energyDeducted=10 → feedback nối "−10 Thể lực"', (
      tester,
    ) async {
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) => _incorrect(deducted: 10);
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('−10 Thể lực'), findsOneWidget);
      expect(find.textContaining('Sai rồi'), findsOneWidget);
    });

    testWidgets('INCORRECT + energyDeducted=5 (clamp) → hiện "−5 Thể lực"', (
      tester,
    ) async {
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) => _incorrect(deducted: 5);
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('−5 Thể lực'), findsOneWidget);
      expect(find.textContaining('−10'), findsNothing);
    });

    testWidgets('INCORRECT + energyDeducted=0 (flag tắt) → KHÔNG nối '
        'thông báo trừ', (tester) async {
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) => _incorrect(deducted: 0);
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thể lực'), findsNothing);
      expect(find.textContaining('Sai rồi'), findsOneWidget);
    });

    testWidgets('PARTIAL → không hiển thị phạt năng lượng', (tester) async {
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) => const SubmitResultDto(
          status: 'ACCEPTED',
          evaluation: EvaluationDto(
            outcome: 'PARTIAL',
            completed: false,
            feedbackCode: 'wrong',
          ),
          activityCompleted: false,
          progress: AttemptProgressDto(completedRequired: 0, totalRequired: 1),
          completion: CompletionVerdictDto(complete: false),
        );
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thể lực'), findsNothing);
    });

    testWidgets('energy snapshot trong response cập nhật provider — '
        'không cần GET /me/energy thêm', (tester) async {
      final energyRepo = FakeEnergyRepository()
        ..next = EnergyStateDto(current: 100, max: 100);
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) => _incorrect(
          deducted: 10,
          energy: EnergyStateDto(current: 90, max: 100, canSubmitGraded: true),
        );
      await _pump(tester, repo, energyRepo: energyRepo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LessonPlayerScreen)),
      );
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      final state = container.read(energyProvider).value;
      expect(state?.current, 90);
    });

    testWidgets('ENERGY_DEPLETED 409 → dialog + giữ input + provider '
        'đồng bộ currentEnergy=0', (tester) async {
      final energyRepo = FakeEnergyRepository()
        ..next = EnergyStateDto(current: 100, max: 100);
      var call = 0;
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) {
          call++;
          if (call == 1) {
            throw const ApiException(
              ApiError(
                code: 'ENERGY_DEPLETED',
                message: 'Hết thể lực',
                details: {
                  'currentEnergy': 0,
                  'nextRecoveryAt': '2026-10-25T10:15:00Z',
                  'serverTime': '2026-10-25T10:05:00Z',
                },
              ),
              statusCode: 409,
            );
          }
          return _incorrect(deducted: 10);
        };
      await _pump(tester, repo, energyRepo: energyRepo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();

      // Dialog hiện — không phải feedback lỗi mạng thông thường.
      expect(find.text('Hết Thể lực'), findsOneWidget);
      expect(find.text('VIỆN THÁI Y'), findsOneWidget);
      expect(find.text('Ở LẠI XEM TIẾP'), findsOneWidget);
      // Không mất input: activity vẫn còn, submit chưa được ghi nhận
      // (repo chỉ bị gọi 1 lần — không auto-resubmit).
      expect(call, 1);
      // Provider đã đồng bộ về 0 từ error details.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LessonPlayerScreen)),
      );
      expect(container.read(energyProvider).value?.current, 0);
    });

    testWidgets('ENERGY_DEPLETED → nút VIỆN THÁI Y điều hướng /energy', (
      tester,
    ) async {
      final repo = FakeAttemptRepository()
        ..onGetCurrent = _cur
        ..onSubmit = (_) {
          throw const ApiException(
            ApiError(
              code: 'ENERGY_DEPLETED',
              message: 'Hết thể lực',
              details: {'currentEnergy': 0},
            ),
            statusCode: 409,
          );
        };
      await _pump(tester, repo);
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIỆN THÁI Y'));
      await tester.pumpAndSettle();
      expect(find.text('VIỆN THÁI Y SCREEN'), findsOneWidget);
    });

    group('FIX-5 — giữ metadata + refresh khi thiếu state', () {
      ApiException depleted({Map<String, dynamic>? details}) => ApiException(
        ApiError(
          code: 'ENERGY_DEPLETED',
          message: 'Hết thể lực',
          details: details,
        ),
        statusCode: 409,
      );

      Future<void> submitOnce(WidgetTester tester) async {
        await tester.tap(find.text('A'));
        await tester.pump();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pumpAndSettle();
      }

      ProviderContainer containerOf(WidgetTester tester) =>
          ProviderScope.containerOf(
            tester.element(find.byType(LessonPlayerScreen)),
          );

      testWidgets('provider ĐÃ có state → giữ max/recovery* từ state cũ', (
        tester,
      ) async {
        final energyRepo = FakeEnergyRepository()
          ..next = EnergyStateDto(
            current: 5,
            max: 100,
            recoveryAmount: 5,
            recoveryIntervalSeconds: 900,
            canSubmitGraded: true,
          );
        final repo = FakeAttemptRepository()
          ..onGetCurrent = _cur
          ..onSubmit = (_) => throw depleted(
            details: const {
              'currentEnergy': 0,
              'nextRecoveryAt': '2026-10-25T10:15:00Z',
              'serverTime': '2026-10-25T10:05:00Z',
            },
          );
        await _pump(tester, repo, energyRepo: energyRepo);
        // Provider đã load: energy=5, recovery=5/900s.
        final c = containerOf(tester);
        await c.read(energyProvider.future);
        await submitOnce(tester);
        final st = c.read(energyProvider).value!;
        expect(st.current, 0); // từ details
        expect(st.max, 100); // giữ từ state cũ
        expect(st.recoveryAmount, 5); // giữ từ state cũ
        expect(st.recoveryIntervalSeconds, 900); // giữ từ state cũ
        expect(st.canSubmitGraded, isFalse);
      });

      testWidgets('details THIẾU trường → vẫn áp current=0, không crash', (
        tester,
      ) async {
        final energyRepo = FakeEnergyRepository()
          ..next = EnergyStateDto(current: 80, max: 100);
        final repo = FakeAttemptRepository()
          ..onGetCurrent = _cur
          ..onSubmit = (_) =>
              throw depleted(details: const {'currentEnergy': 0});
        await _pump(tester, repo, energyRepo: energyRepo);
        final c = containerOf(tester);
        await c.read(energyProvider.future);
        await submitOnce(tester);
        // Dialog vẫn hiện, provider cập nhật current=0.
        expect(find.text('Hết Thể lực'), findsOneWidget);
        expect(c.read(energyProvider).value?.current, 0);
      });

      testWidgets('details thiếu HOÀN TOÀN + provider chưa có state → '
          'fallback refresh GET /me/energy', (tester) async {
        final energyRepo = FakeEnergyRepository()
          ..next = EnergyStateDto(current: 0, max: 100);
        final repo = FakeAttemptRepository()
          ..onGetCurrent = _cur
          ..onSubmit = (_) => throw depleted(details: null); // không có details
        await _pump(tester, repo, energyRepo: energyRepo);
        // Provider chưa được ai watch → chưa có state.
        final callsBefore = energyRepo.calls;
        await submitOnce(tester);
        expect(find.text('Hết Thể lực'), findsOneWidget);
        await tester.pumpAndSettle();
        // refresh() được gọi → GET /me/energy chạy (calls tăng).
        expect(energyRepo.calls, greaterThan(callsBefore));
      });

      testWidgets('GET refresh sau 409 thất bại → provider giữ AsyncError, '
          'KHÔNG reset 100/100', (tester) async {
        final energyRepo = FakeEnergyRepository()..error = Exception('down');
        final repo = FakeAttemptRepository()
          ..onGetCurrent = _cur
          ..onSubmit = (_) => throw depleted(details: null);
        await _pump(tester, repo, energyRepo: energyRepo);
        final c = containerOf(tester);
        await submitOnce(tester);
        await tester.pumpAndSettle();
        // Refresh lỗi → AsyncError, không hiển thị số giả.
        expect(c.read(energyProvider).value, isNull);
        expect(c.read(energyProvider).hasError, isTrue);
      });

      testWidgets('VIỆN THÁI Y → pop quay lại bài, input/progress còn', (
        tester,
      ) async {
        final repo = FakeAttemptRepository()
          ..onGetCurrent = _cur
          ..onSubmit = (_) => throw depleted(
            details: const {
              'currentEnergy': 0,
              'nextRecoveryAt': '2026-10-25T10:15:00Z',
            },
          );
        await _pump(tester, repo);
        await submitOnce(tester);
        // Vào Viện Thái Y (push — giữ lesson trong stack).
        await tester.tap(find.text('VIỆN THÁI Y'));
        await tester.pumpAndSettle();
        expect(find.text('VIỆN THÁI Y SCREEN'), findsOneWidget);
        // Quay lại → LessonPlayer vẫn còn, activity chưa mất.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(LessonPlayerScreen), findsOneWidget);
        expect(find.text('GỬI CÂU TRẢ LỜI'), findsOneWidget);
      });
    });
  });
}
