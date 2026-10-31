import 'package:dau_viet_mobile/core/theme/dau_viet_colors.dart';
import 'package:dau_viet_mobile/core/widgets/dong_son_button.dart';
import 'package:dau_viet_mobile/core/widgets/gamification/gamification_widgets.dart';
import 'package:dau_viet_mobile/core/widgets/hero_paper_banner.dart';
import 'package:dau_viet_mobile/core/widgets/tactile_3d_button.dart';
import 'package:dau_viet_mobile/core/widgets/tactile_card.dart';
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
  group('LearnerDashboardScreen — Gamification Rhino Home Redesign', () {
    testWidgets(
      'renders new Rhino Hero, Folder-Tab Continue card, 4 Gamified cards, Map Banner, and Featured Carousel from currentByPeriod[lastPeriodCode]',
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

        // 1. Top Bar: giữ nguyên app_logo.png, 2 Gamified Pills & Chuông thông báo có badge "1"
        expect(find.text('Dấu Việt'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(2));

        // 2. Hero Greeting mới với linh vật Chú Tê Giác
        expect(find.text('Chào mừng\ntrở lại!'), findsOneWidget);
        expect(
          find.text(
            'Cùng khám phá những câu chuyện\nhào hùng của dân tộc Việt Nam nhé!',
          ),
          findsOneWidget,
        );

        // 3. Thẻ Folder-Tab "Tiếp tục hành trình" — lấy từ currentByPeriod[lastPeriodCode]
        expect(find.text('Tiếp tục hành trình'), findsOneWidget);
        expect(find.text('Đại Chiến Bạch Đằng 938'), findsWidgets);
        expect(
          find.text(
            'Buổi đầu độc lập tự chủ • Bí mật chiến thắng Bạch Đằng (Demo)',
          ),
          findsOneWidget,
        );
        expect(find.text('1/3 bài học'), findsOneWidget);

        // 4. Hàng 4 thẻ Gamification mới
        expect(find.text('Thời kỳ\nlịch sử'), findsOneWidget);
        expect(find.text('Bản đồ\ndi sản'), findsOneWidget);
        expect(find.text('Thành tựu'), findsOneWidget);
        expect(find.text('Kho báu'), findsOneWidget);

        // 5. Banner toàn cảnh "Khám phá bản đồ Việt Nam"
        expect(find.text('Khám phá bản đồ Việt Nam'), findsOneWidget);
        expect(
          find.text(
            'Mở khóa các địa danh lịch sử\ndọc theo hành trình thời gian',
          ),
          findsOneWidget,
        );

        // 6. Carousel ngang "Bài học nổi bật"
        expect(find.text('Bài học nổi bật'), findsOneWidget);
        expect(find.text('Xem tất cả'), findsOneWidget);
        expect(find.text('Mới'), findsOneWidget);
        expect(find.byType(FeaturedLessonCarouselCard), findsWidgets);
      },
    );

    testWidgets(
      'Thẻ Tiếp tục hành trình mở sự kiện từ currentByPeriod[lastPeriodCode] thay vì milestones.first',
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

        expect(find.text('Lý Thái Tổ Dời Đô Về Thăng Long'), findsWidgets);
        expect(
          find.text('Thời nhà Lý • Vì sao Lý Công Uẩn chọn thành Đại La?'),
          findsOneWidget,
        );
        expect(find.text('0/3 bài học'), findsOneWidget);
        expect(find.text('Sự kiện đầu danh sách cũ'), findsNothing);

        // Bấm nút Play tròn đỏ trên thẻ Tiếp tục hành trình -> điều hướng tới eventId của LY_DYNASTY
        await tester.tap(find.text('KHÁM PHÁ NGAY ›'));
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

        expect(find.text('Chào mừng\ntrở lại!'), findsOneWidget);
        expect(find.text('Tiếp tục học →'), findsOneWidget);
        expect(find.text('Bài học đang tiếp diễn'), findsOneWidget);
        expect(find.text('Giai đoạn: EVIDENCE'), findsOneWidget);
        expect(find.text('2/5 hoạt động'), findsOneWidget);
      },
    );

    testWidgets(
      'Điều hướng đầy đủ cho 4 thẻ Gamification, Banner Bản đồ và Carousel Bài học nổi bật',
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
            GoRoute(
              path: '/map',
              builder: (_, _) {
                visitedRoutes.add('/map');
                return const Scaffold(body: Text('MAP_ROOT'));
              },
            ),
            GoRoute(
              path: '/profile',
              builder: (_, _) {
                visitedRoutes.add('/profile');
                return const Scaffold(body: Text('PROFILE_ROOT'));
              },
            ),
            GoRoute(
              path: '/collection',
              builder: (_, _) {
                visitedRoutes.add('/collection');
                return const Scaffold(body: Text('COLLECTION_ROOT'));
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

        // 1. Bấm thân thẻ "Tiếp tục hành trình" -> /journey/EARLY_INDEPENDENCE
        await tester.tap(
          find.text(
            'Buổi đầu độc lập tự chủ • Bí mật chiến thắng Bạch Đằng (Demo)',
          ),
        );
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey/EARLY_INDEPENDENCE');

        // 2. Bấm thẻ "Thời kỳ lịch sử" -> /journey
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Thời kỳ\nlịch sử'));
        await tester.tap(find.text('Thời kỳ\nlịch sử'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey');

        // 3. Bấm thẻ "Bản đồ di sản" -> /map
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Bản đồ\ndi sản'));
        await tester.tap(find.text('Bản đồ\ndi sản'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/map');

        // 4. Bấm Banner "Khám phá bản đồ Việt Nam" -> /map
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Khám phá bản đồ Việt Nam'));
        await tester.tap(find.text('Khám phá bản đồ Việt Nam'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/map');

        // 5. Bấm "Xem tất cả" trên Bài học nổi bật -> /journey
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Xem tất cả'));
        await tester.tap(find.text('Xem tất cả'));
        await tester.pumpAndSettle();
        expect(visitedRoutes.last, '/journey');
      },
    );
  });

  group(
    'LearnerDashboardScreen — Đồng bộ Soft Heritage Card, Logo & 0 Overflow',
    () {
      testWidgets(
        'Logo dùng app_logo.png (height 38), không dùng pixelShadow cứng và hiển thị 0 overflow trên 360x800 & 390x844',
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
                path: '/energy',
                builder: (_, _) {
                  visitedRoutes.add('/energy');
                  return const Scaffold(body: Text('ENERGY_SCREEN'));
                },
              ),
              GoRoute(
                path: '/streak',
                builder: (_, _) {
                  visitedRoutes.add('/streak');
                  return const Scaffold(body: Text('STREAK_SCREEN'));
                },
              ),
            ],
          );

          for (final size in const [Size(360, 800), Size(390, 844)]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            await tester.pumpWidget(
              ProviderScope(
                key: ValueKey(size),
                overrides: [
                  attemptRepositoryProvider.overrideWithValue(
                    FakeAttemptRepository(),
                  ),
                  learningPathRepositoryProvider.overrideWithValue(
                    mockPathRepo,
                  ),
                  learnerLearningPathProvider.overrideWith(
                    () => _StubLearningPathController(mockPathRepo),
                  ),
                ],
                child: MaterialApp.router(routerConfig: router),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // Logo dùng app_logo.png (height 38)
          final logoImages = tester.widgetList<Image>(
            find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName ==
                      'assets/images/app_logo.png',
            ),
          );
          expect(logoImages.length, 1);
          expect(logoImages.single.height, 38);

          // Không còn DongSonButton / Tactile3DButton hay pixelShadow cứng
          expect(find.byType(DongSonButton), findsNothing);
          expect(find.byType(Tactile3DButton), findsNothing);

          final tactileCards = tester
              .widgetList<TactileCard>(find.byType(TactileCard))
              .toList();
          expect(tactileCards.length, greaterThanOrEqualTo(6));
          for (final card in tactileCards) {
            expect(card.usePixelShadow, isFalse);
            expect(card.borderWidth, closeTo(1.1, 0.05));
          }

          final heroBanners = tester
              .widgetList<HeroPaperBanner>(find.byType(HeroPaperBanner))
              .toList();
          expect(heroBanners.length, 1);
          expect(heroBanners.single.usePixelShadow, isFalse);

          final containers = tester.widgetList<Container>(
            find.byType(Container),
          );
          for (final c in containers) {
            final dec = c.decoration;
            if (dec is BoxDecoration && dec.boxShadow != null) {
              for (final shadow in dec.boxShadow!) {
                expect(
                  shadow.color == DauVietColors.pixelShadowColor &&
                      shadow.blurRadius == 0,
                  isFalse,
                );
              }
            }
          }

          // Bấm chuông thông báo -> hiện SnackBar
          await tester.tap(find.byIcon(Icons.notifications_none_rounded));
          await tester.pump();
          expect(find.text('Chưa có thông báo mới.'), findsOneWidget);

          // Bấm pill Năng lượng -> /energy
          await tester.tap(find.text('Năng lượng'));
          await tester.pumpAndSettle();
          expect(visitedRoutes.last, '/energy');

          // Bấm pill Chuỗi ngày -> /streak
          router.go('/dashboard');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chuỗi ngày'));
          await tester.pumpAndSettle();
          expect(visitedRoutes.last, '/streak');
        },
      );
    },
  );
}

class _StubLearningPathController extends LearningPathController {
  final MockLearningPathRepository _repo;

  _StubLearningPathController(this._repo);

  @override
  Future<LearningPathDto> build() => _repo.getMyLearningPath();
}
