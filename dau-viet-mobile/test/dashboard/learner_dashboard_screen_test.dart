import 'package:dau_viet_mobile/core/widgets/dong_son_button.dart';
import 'package:dau_viet_mobile/features/dashboard/presentation/learner_dashboard_screen.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:dau_viet_mobile/mock/models/timeline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';

void main() {
  group('LearnerDashboardScreen — Tiếp tục hành trình (Issue #23)', () {
    testWidgets(
      'renders all 6 UI Pro Max homepage sections and uses currentByPeriod[lastPeriodCode]',
      (tester) async {
        final mockPathRepo = MockLearningPathRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attemptRepositoryProvider.overrideWithValue(
                FakeAttemptRepository(),
              ),
              learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
              learnerLearningPathProvider.overrideWith(
                () => _StubLearningPathController(mockPathRepo),
              ),
            ],
            child: const MaterialApp(home: LearnerDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Top Bar: Dấu Việt logo, chuông thông báo & avatar + tagline brand
        expect(find.text('Dấu Việt'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
        expect(
          find.text('— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —'),
          findsOneWidget,
        );

        // 2. Greeting & Status Row — pill có nhãn dưới số (mockup M-03)
        expect(find.text('Xin chào,'), findsOneWidget);
        expect(find.text('Năng lượng'), findsOneWidget);
        expect(find.text('Chuỗi ngày'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(2));

        // 3. Hero Banner Card — tagline mới theo mockup
        expect(find.text('Khám phá\nlịch sử Việt Nam'), findsOneWidget);
        expect(
          find.text('Những câu chuyện hào hùng\nđang chờ bạn khám phá!'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(DongSonButton, 'KHÁM PHÁ NGAY ›'),
          findsOneWidget,
        );

        // 4. Section: Bài học hôm nay — lấy từ currentByPeriod[lastPeriodCode]
        // (mặc định lastPeriodCode = 'EARLY_INDEPENDENCE' -> Đại Chiến Bạch Đằng 938, 1/3 bài học)
        expect(find.text('Bài học hôm nay'), findsOneWidget);
        expect(find.text('Đại Chiến Bạch Đằng 938'), findsOneWidget);
        expect(
          find.text(
            'Buổi đầu độc lập tự chủ • Bí mật chiến thắng Bạch Đằng (Demo)',
          ),
          findsOneWidget,
        );
        expect(find.text('1/3 bài học'), findsOneWidget);
        // 5. Section: Hành trình của bạn — 4 thẻ vuông 1 hàng (mockup)
        expect(find.text('Hành trình của bạn'), findsOneWidget);
        expect(find.text('Bài học'), findsOneWidget);
        expect(find.text('Ôn tập'), findsOneWidget);
        expect(find.text('Thành tích'), findsOneWidget);
        expect(find.text('Thư viện'), findsOneWidget);
        // 6. Section: Nhiệm vụ hôm nay & Sự kiện nổi bật (2 cột)
        expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
        expect(find.text('Hoàn thành bài học hôm nay'), findsOneWidget);
        expect(find.text('Ôn tập 3 câu hỏi'), findsOneWidget);
        expect(find.text('Sự kiện nổi bật'), findsOneWidget);
        expect(find.text('Khám phá ngay →'), findsOneWidget);
      },
    );

    testWidgets(
      'Hero Banner và Bài học hôm nay mở sự kiện từ currentByPeriod[lastPeriodCode] thay vì milestones.first',
      (tester) async {
        final mockPathRepo = MockLearningPathRepository();
        await mockPathRepo.touchPeriod('LY_DYNASTY');

        String? openedEventId;
        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const LearnerDashboardScreen(),
            ),
            GoRoute(
              path: '/campaign/:eventId',
              builder: (_, state) {
                openedEventId = state.pathParameters['eventId'];
                return Scaffold(body: Text('CAMPAIGN:$openedEventId'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attemptRepositoryProvider.overrideWithValue(
                FakeAttemptRepository(),
              ),
              // Gán milestones.first khác hẳn để chứng minh không dùng milestones.first
              eventsListProvider.overrideWith(
                (ref) async => const EventsPageResult(
                  milestones: [
                    TimelineMilestoneModel(
                      id: 'evt-wrong-first',
                      eventId: 'evt-wrong-first',
                      yearLabel: 'Năm 1',
                      yearValue: 1,
                      title: 'Sự kiện đầu danh sách cũ',
                      subtitle: '',
                      description: '',
                      era: 'Cũ',
                      isActive: true,
                    ),
                  ],
                  page: 0,
                  size: 1,
                  totalElements: 1,
                  totalPages: 1,
                ),
              ),
              learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
              learnerLearningPathProvider.overrideWith(
                () => _StubLearningPathController(mockPathRepo),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Hiển thị đúng sự kiện của LY_DYNASTY từ currentByPeriod['LY_DYNASTY']
        expect(find.text('Lý Thái Tổ Dời Đô Về Thăng Long'), findsOneWidget);
        expect(
          find.text('Thời nhà Lý • Vì sao Lý Công Uẩn chọn thành Đại La?'),
          findsOneWidget,
        );
        expect(find.text('0/3 bài học'), findsOneWidget);
        expect(find.text('Sự kiện đầu danh sách cũ'), findsNothing);

        // Bấm CTA Hero Banner -> điều hướng tới eventId của LY_DYNASTY
        await tester.tap(find.widgetWithText(DongSonButton, 'KHÁM PHÁ NGAY ›'));
        await tester.pumpAndSettle();

        expect(openedEventId, '00000000-0000-0000-0000-000000000003');
        expect(
          find.text('CAMPAIGN:00000000-0000-0000-0000-000000000003'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Khi có attempt đang IN_PROGRESS thì ưu tiên tiếp tục attempt trước con trỏ lộ trình',
      (tester) async {
        final mockPathRepo = MockLearningPathRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              myProgressProvider.overrideWith(
                (ref) async => const MyProgressDto(
                  inProgress: [
                    AttemptSummaryDto(
                      attemptId: 'att-resume-99',
                      lessonId: 'les-1',
                      lessonVersionId: 'ver-1',
                      status: 'IN_PROGRESS',
                      currentStageId: 'EVIDENCE',
                      progress: AttemptProgressDto(
                        completedRequired: 2,
                        totalRequired: 5,
                      ),
                    ),
                  ],
                  completedCount: 1,
                ),
              ),
              learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
              learnerLearningPathProvider.overrideWith(
                () => _StubLearningPathController(mockPathRepo),
              ),
            ],
            child: const MaterialApp(home: LearnerDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Hero giữ tiêu đề mockup; chỉ CTA đổi sang "Tiếp tục học →"
        expect(find.text('Khám phá\nlịch sử Việt Nam'), findsOneWidget);
        expect(
          find.widgetWithText(DongSonButton, 'Tiếp tục học →'),
          findsOneWidget,
        );
        expect(find.text('Bài học đang tiếp diễn'), findsOneWidget);
        expect(find.text('Giai đoạn: EVIDENCE'), findsOneWidget);
        expect(find.text('2/5 hoạt động'), findsOneWidget);
      },
    );

    testWidgets(
      'Các CTA hành trình học tập điều hướng tới /journey hoặc /journey/:periodCode thay vì /map',
      (tester) async {
        final mockPathRepo = MockLearningPathRepository();
        final visitedRoutes = <String>[];

        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const LearnerDashboardScreen(),
            ),
            GoRoute(
              path: '/journey',
              builder: (_, _) {
                visitedRoutes.add('/journey');
                return const Scaffold(body: Text('JOURNEY_ROOT'));
              },
            ),
            GoRoute(
              path: '/journey/:periodCode',
              builder: (_, state) {
                final code = state.pathParameters['periodCode'] ?? '';
                visitedRoutes.add('/journey/$code');
                return Scaffold(body: Text('JOURNEY_PERIOD:$code'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attemptRepositoryProvider.overrideWithValue(
                FakeAttemptRepository(),
              ),
              learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
              learnerLearningPathProvider.overrideWith(
                () => _StubLearningPathController(mockPathRepo),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Bấm thẻ "Bài học hôm nay" -> /journey/EARLY_INDEPENDENCE
        await tester.ensureVisible(find.text('Đại Chiến Bạch Đằng 938'));
        await tester.tap(find.text('Đại Chiến Bạch Đằng 938'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey/EARLY_INDEPENDENCE');

        // 2. Bấm "Xem hành trình →" -> /journey
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Xem hành trình →'));
        await tester.tap(find.text('Xem hành trình →'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey');

        // 3. Bấm thẻ "Bài học" -> /journey
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Bài học'));
        await tester.tap(find.text('Bài học'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey');

        // 4. Bấm Quest 1 "Hoàn thành bài học hôm nay" -> /journey
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Hoàn thành bài học hôm nay'));
        await tester.tap(find.text('Hoàn thành bài học hôm nay'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey');
      },
    );
  });
}

class _StubLearningPathController extends LearningPathController {
  final MockLearningPathRepository _repo;

  _StubLearningPathController(this._repo);

  @override
  Future<LearningPathDto> build() => _repo.getMyLearningPath();
}
