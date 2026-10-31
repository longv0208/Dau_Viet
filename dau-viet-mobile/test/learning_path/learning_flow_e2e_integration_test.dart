import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/core/widgets/main_bottom_nav.dart';
import 'package:dau_viet_mobile/features/campaign/presentation/campaign_detail_screen.dart';
import 'package:dau_viet_mobile/features/dashboard/presentation/learner_dashboard_screen.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:dau_viet_mobile/features/learning_path/presentation/period_journey_screen.dart';
import 'package:dau_viet_mobile/features/learning_path/presentation/period_selection_screen.dart';
import 'package:dau_viet_mobile/features/learning_path/presentation/widgets/bottom_floating_summary_card.dart';
import 'package:dau_viet_mobile/features/learning_path/presentation/widgets/winding_landscape_journey_canvas.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fakes/fake_attempt_repository.dart';

class _StatefulLearningPathRepository extends LearningPathRepository {
  final MockLearningPathRepository _delegate = MockLearningPathRepository();
  bool shouldFail = false;
  final List<String> touchedPeriods = [];

  @override
  Future<LearningPathDto> getMyLearningPath() async {
    if (shouldFail) {
      throw ApiException(
        const ApiError(
          code: 'NETWORK_ERROR',
          message: 'Mất kết nối máy chủ lộ trình',
        ),
      );
    }
    return _delegate.getMyLearningPath();
  }

  @override
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) => _delegate.getPublishedLearningPath(code: code);

  @override
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    touchedPeriods.add(periodCode);
    return _delegate.touchPeriod(periodCode);
  }
}

class _StubEventsRepository implements EventsRepository {
  @override
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) async {
    return const EventsPageResult(
      milestones: [],
      page: 0,
      size: 0,
      totalElements: 0,
      totalPages: 0,
    );
  }

  @override
  Future<HistoricalEventModel> getEventById(String id) async {
    return HistoricalEventModel(
      id: id,
      title: 'Chiếu Dời Đô & Kinh Đô Thăng Long',
      era: 'Nhà Lý (1009 - 1225)',
      year: 1010,
      heroBannerUrl: '',
      summary: 'Lý Thái Tổ dời đô từ Hoa Lư về Đại La.',
      lessonIds: const ['les-ly-thai-to-1010'],
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('F1 (Issue #26) — Tích hợp End-to-End, UX States & Đổi thời kỳ', () {
    test(
      'MainBottomNav maps /island to tab 2 (Đảo) and /map+/heritage to tab 3 (Bản đồ)',
      () {
        expect(MainBottomNav.tabForLocation('/journey'), 1);
        expect(MainBottomNav.tabForLocation('/journey/EARLY_INDEPENDENCE'), 1);
        expect(MainBottomNav.tabForLocation('/island'), 2);
        expect(MainBottomNav.tabForLocation('/island/shop'), 2);
        expect(MainBottomNav.tabForLocation('/map'), 3);
        expect(MainBottomNav.tabForLocation('/heritage/loc-1'), 3);
      },
    );

    testWidgets(
      'AC-1 & AC-3: Luồng Trang chủ -> Chọn thời kỳ -> Hành trình thời kỳ -> Sự kiện -> Bài học & Đổi thời kỳ không mất tiến độ',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pathRepo = _StatefulLearningPathRepository();
        final eventsRepo = _StubEventsRepository();
        String? enteredLessonId;

        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const LearnerDashboardScreen(),
            ),
            GoRoute(
              path: '/journey',
              builder: (_, _) => const PeriodSelectionScreen(),
              routes: [
                GoRoute(
                  path: ':periodCode',
                  builder: (_, state) => PeriodJourneyScreen(
                    periodCode: state.pathParameters['periodCode'] ?? '',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/campaign/:eventId',
              builder: (_, state) => CampaignDetailScreen(
                eventId: state.pathParameters['eventId'] ?? '',
              ),
            ),
            GoRoute(
              path: '/learning/lesson/:lessonId',
              builder: (_, state) {
                enteredLessonId = state.pathParameters['lessonId'];
                return Scaffold(body: Text('LESSON:$enteredLessonId'));
              },
            ),
            GoRoute(
              path: '/map',
              builder: (_, state) => Scaffold(
                body: Text(
                  'MAP:${state.uri.queryParameters['locationId'] ?? 'ALL'}',
                ),
              ),
            ),
            GoRoute(
              path: '/heritage/:locationId',
              redirect: (_, state) {
                final id = state.pathParameters['locationId'] ?? '';
                return '/map?locationId=${Uri.encodeComponent(id)}';
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
              eventsRepositoryProvider.overrideWithValue(eventsRepo),
              learningPathRepositoryProvider.overrideWithValue(pathRepo),
              eventLessonsProvider.overrideWith((ref, id) async {
                return const [
                  LessonListItemDto(
                    id: 'demo-lesson-thang-long-1',
                    title: 'Vì sao Lý Công Uẩn chọn thành Đại La?',
                    centralQuestion: 'Tại sao chọn Đại La?',
                  ),
                  LessonListItemDto(
                    id: 'demo-lesson-thang-long-2',
                    title: 'Dấu tích Hoàng thành Thăng Long',
                    centralQuestion: 'Hoàng thành có gì?',
                  ),
                ];
              }),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Trang chủ mặc định hiển thị thời kỳ đang theo học (EARLY_INDEPENDENCE - Bạch Đằng 938, 1/3 bài học)
        expect(find.text('Đại Chiến Bạch Đằng 938'), findsOneWidget);
        expect(find.text('1/3 bài học'), findsOneWidget);

        // 2. Điều hướng sang màn Chọn thời kỳ (/journey)
        router.go('/journey');
        await tester.pumpAndSettle();
        expect(find.text('CHỌN THỜI KỲ LỊCH SỬ'), findsOneWidget);
        expect(find.text('Buổi đầu độc lập tự chủ'), findsOneWidget);
        expect(find.text('Thời nhà Lý'), findsOneWidget);
        // Issue #48 (AC-1/AC-2): canvas đường đi phong cảnh 2.5D + thẻ tổng
        // quan nổi; không có nút thời kỳ nào hiển thị icon khóa.
        expect(find.byType(WindingLandscapeJourneyCanvas), findsOneWidget);
        expect(find.byType(BottomFloatingSummaryCard), findsOneWidget);
        final lyPeriodCard = find.byKey(const Key('period-card-LY_DYNASTY'));
        expect(
          find.descendant(
            of: lyPeriodCard,
            matching: find.byIcon(Icons.lock_rounded),
          ),
          findsNothing,
        );
        // Tiến độ Buổi đầu độc lập tự chủ: 0/1 sự kiện • 1/3 bài học (33%)
        expect(find.text('0/1 sự kiện • 1/3 bài học'), findsOneWidget);

        // 3. Đổi sang thời kỳ "Thời nhà Lý" (LY_DYNASTY) -> gọi touchPeriod và mở PeriodJourneyScreen
        await tester.scrollUntilVisible(find.text('Thời nhà Lý'), 150);
        await tester.tap(find.text('Thời nhà Lý'));
        await tester.pumpAndSettle();

        expect(pathRepo.touchedPeriods, contains('LY_DYNASTY'));
        expect(find.text('HÀNH TRÌNH THỜI KỲ'), findsOneWidget);
        expect(find.text('Lý Thái Tổ Dời Đô Về Thăng Long'), findsOneWidget);
        expect(find.text('Chiến Thắng Như Nguyệt 1077'), findsOneWidget);

        // 4. Quay lại màn Chọn thời kỳ -> kiểm tra tiến độ Buổi đầu độc lập tự chủ không bị mất
        await tester.tap(find.byTooltip('Chọn thời kỳ khác'));
        await tester.pumpAndSettle();
        expect(find.text('CHỌN THỜI KỲ LỊCH SỬ'), findsOneWidget);
        expect(find.text('0/1 sự kiện • 1/3 bài học'), findsOneWidget);

        // 5. Chọn lại Thời nhà Lý -> bấm sự kiện Chiếu Dời Đô -> mở Bottom Sheet thông tin sự kiện -> bấm bài học mở trực tiếp /learning/lesson/{id}
        await tester.scrollUntilVisible(find.text('Thời nhà Lý'), 150);
        await tester.tap(find.text('Thời nhà Lý'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lý Thái Tổ Dời Đô Về Thăng Long'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const Key(
              'event-details-sheet-00000000-0000-0000-0000-000000000003',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('CHI TIẾT SỰ KIỆN'), findsNothing);

        // Đóng Bottom Sheet bằng nút Đóng để tiếp tục bấm bài học trên canvas
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();

        // Bấm bài học "Đang khóa" trực tiếp trên canvas -> hiện SnackBar, không điều hướng
        await tester.scrollUntilVisible(
          find.byKey(const Key('lesson-milestone-demo-lesson-thang-long-2')),
          150,
        );
        await tester.tap(
          find.byKey(const Key('lesson-milestone-demo-lesson-thang-long-2')),
        );
        await tester.pump();
        expect(enteredLessonId, isNull);

        // Bấm bài học Sẵn sàng học -> điều hướng sang /learning/lesson/demo-lesson-thang-long-1
        await tester.scrollUntilVisible(
          find.byKey(const Key('lesson-milestone-demo-lesson-thang-long-1')),
          -150,
        );
        await tester.tap(
          find.byKey(const Key('lesson-milestone-demo-lesson-thang-long-1')),
        );
        await tester.pumpAndSettle();
        expect(enteredLessonId, 'demo-lesson-thang-long-1');
        // 6. Kiểm tra route /heritage/:locationId chuyển hướng sang Bản đồ Di sản kèm locationId
        router.go('/heritage/loc-bach-dang');
        await tester.pumpAndSettle();
        expect(find.text('MAP:loc-bach-dang'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-2: Đủ trạng thái đang tải (loading), lỗi (error + retry), rỗng (empty) và khóa (locked)',
      (tester) async {
        final flakyRepo = _StatefulLearningPathRepository()..shouldFail = true;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningPathRepositoryProvider.overrideWithValue(flakyRepo),
            ],
            child: const MaterialApp(home: PeriodSelectionScreen()),
          ),
        );

        // 1. Trạng thái đang tải (loading)
        expect(
          find.text('Đang mở cuộn thư lộ trình lịch sử...'),
          findsOneWidget,
        );
        await tester.pumpAndSettle();

        // 2. Trạng thái lỗi (error) + nút THỬ LẠI
        expect(find.text('THỬ LẠI'), findsOneWidget);

        // Khôi phục kết nối và bấm THỬ LẠI -> phục hồi thành công
        flakyRepo.shouldFail = false;
        await tester.tap(find.text('THỬ LẠI'));
        await tester.pumpAndSettle();

        expect(find.text('Buổi đầu dựng nước'), findsOneWidget);
        // 3. Trạng thái đang khóa (locked) và đang biên soạn (notReady) có đủ icon + nhãn
        expect(find.text('Đang khóa'), findsWidgets);
        expect(find.text('Đang biên soạn'), findsWidgets);

        // 4. Trạng thái rỗng khi mở mã thời kỳ không tồn tại
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningPathRepositoryProvider.overrideWithValue(flakyRepo),
            ],
            child: const MaterialApp(
              home: PeriodJourneyScreen(periodCode: 'EMPTY_UNKNOWN_PERIOD'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Không tìm thấy thời kỳ'), findsOneWidget);
      },
    );
  });
}
