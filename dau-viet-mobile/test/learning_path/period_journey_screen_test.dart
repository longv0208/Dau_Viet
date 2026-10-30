import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/campaign/presentation/campaign_detail_screen.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_providers.dart';
import 'package:dau_viet_mobile/features/collection/data/mock_collection_repository.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:dau_viet_mobile/features/learning_path/presentation/learning_path_presentation.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fakes/fake_attempt_repository.dart';

class _RecordingLearningPathRepository extends LearningPathRepository {
  LearningPathDto path;
  Object? error;
  int getCalls = 0;
  final List<String> touchedPeriods = [];

  _RecordingLearningPathRepository(this.path);

  @override
  Future<LearningPathDto> getMyLearningPath() async {
    getCalls++;
    if (error != null) throw error!;
    return path;
  }

  @override
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    touchedPeriods.add(periodCode);
    path = path.copyWith(lastPeriodCode: periodCode);
    return TouchPeriodResponseDto(
      periodCode: periodCode,
      chapterId: 'ch-$periodCode',
      touchedAt: DateTime.utc(2026, 10, 28),
    );
  }

  @override
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) async {
    return getMyLearningPath();
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
      title: 'Chiến dịch $id',
      era: 'Độc lập tự chủ',
      year: 938,
      heroBannerUrl: '',
      summary: 'Tóm tắt sự kiện $id',
      lessonIds: const [],
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group(
    'AC-1: PathStatusBadge — trạng thái có icon + nhãn, không chỉ dùng màu',
    () {
      testWidgets(
        'hiển thị đúng Icon + nhãn tiếng Việt cho cả 6 LearnerPathStatus',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    for (final s in LearnerPathStatus.values)
                      PathStatusBadge(key: Key('badge-${s.name}'), status: s),
                  ],
                ),
              ),
            ),
          );

          final expected = <(LearnerPathStatus, IconData, String)>[
            (LearnerPathStatus.locked, Icons.lock_rounded, 'Đang khóa'),
            (
              LearnerPathStatus.available,
              Icons.lock_open_rounded,
              'Sẵn sàng học',
            ),
            (LearnerPathStatus.inProgress, Icons.timelapse_rounded, 'Đang học'),
            (
              LearnerPathStatus.completed,
              Icons.check_circle_rounded,
              'Đã hoàn thành',
            ),
            (
              LearnerPathStatus.mastered,
              Icons.workspace_premium_rounded,
              'Đã tinh thông',
            ),
            (
              LearnerPathStatus.notReady,
              Icons.hourglass_empty_rounded,
              'Đang biên soạn',
            ),
          ];

          for (final (status, icon, label) in expected) {
            final badgeFinder = find.byKey(Key('badge-${status.name}'));
            expect(badgeFinder, findsOneWidget);
            expect(
              find.descendant(of: badgeFinder, matching: find.byIcon(icon)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: badgeFinder, matching: find.text(label)),
              findsOneWidget,
            );
          }
        },
      );
    },
  );

  group('PeriodSelectionScreen — nhóm theo ERA & ẩn tầng chỉ có 1 mục', () {
    testWidgets(
      'nhóm các PERIOD theo 3 ERA và hiển thị thời kỳ đang theo học',
      (tester) async {
        final mockRepo = MockLearningPathRepository();
        final snapshot = await mockRepo.getMyLearningPath();
        final repo = _RecordingLearningPathRepository(snapshot);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [learningPathRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: PeriodSelectionScreen(showBottomNav: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hiển thị đủ 3 nhóm ERA
        expect(
          find.byKey(const Key('era-header-ERA_ANCIENT_MEDIEVAL')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('era-header-ERA_EARLY_MODERN')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('era-header-ERA_MODERN')), findsOneWidget);
        expect(find.text('Thời kỳ Cổ – Trung đại'), findsOneWidget);
        expect(find.text('Thời kỳ Cận đại'), findsOneWidget);
        expect(find.text('Thời kỳ Hiện đại'), findsOneWidget);
        expect(
          find.byKey(const Key('period-card-FOUNDING_ERA')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('period-card-EARLY_INDEPENDENCE')),
          findsOneWidget,
        );
        // Nhãn thời kỳ đang theo học (lastPeriodCode = EARLY_INDEPENDENCE)
        expect(
          find.byKey(const Key('period-active-badge-EARLY_INDEPENDENCE')),
          findsOneWidget,
        );
        expect(find.text('Đang theo học'), findsOneWidget);
      },
    );

    testWidgets('ẩn tầng ERA khi lộ trình chỉ có 1 nhóm ERA duy nhất', (
      tester,
    ) async {
      const singleEraPath = LearningPathDto(
        pathCode: 'HISTORY_MAIN',
        pathVersion: 2,
        enrolled: true,
        chapters: [
          LearningPathChapterDto(
            chapterId: 'era-only',
            nodeType: PathNodeType.era,
            code: 'ERA_ONLY',
            title: 'Đại thời kỳ duy nhất',
            sortOrder: 1,
          ),
          LearningPathChapterDto(
            chapterId: 'period-1',
            parentId: 'era-only',
            nodeType: PathNodeType.period,
            code: 'PERIOD_1',
            title: 'Thời kỳ dựng nước',
            sortOrder: 1,
            events: [
              LearningPathEventNodeDto(
                eventNodeId: 'node-1',
                eventId: 'evt-1',
                title: 'Sự kiện mở đầu',
                yearLabel: 'Năm 938',
                sortOrder: 1,
                status: LearnerPathStatus.available,
              ),
            ],
          ),
        ],
      );
      final repo = _RecordingLearningPathRepository(singleEraPath);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [learningPathRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: PeriodSelectionScreen(showBottomNav: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tầng ERA chỉ có 1 mục -> bị ẩn, nhưng thẻ PERIOD vẫn hiển thị
      expect(find.byKey(const Key('era-header-ERA_ONLY')), findsNothing);
      expect(find.text('Đại thời kỳ duy nhất'), findsNothing);
      expect(find.byKey(const Key('period-card-PERIOD_1')), findsOneWidget);
      expect(find.text('Thời kỳ dựng nước'), findsOneWidget);
    });

    testWidgets(
      'bấm vào thời kỳ gọi touchPeriod và mở màn Hành trình thời kỳ',
      (tester) async {
        final mockRepo = MockLearningPathRepository();
        final snapshot = await mockRepo.getMyLearningPath();
        final repo = _RecordingLearningPathRepository(snapshot);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [learningPathRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: PeriodSelectionScreen(showBottomNav: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final periodFinder = find.byKey(
          const Key('period-card-EARLY_INDEPENDENCE'),
        );
        await tester.ensureVisible(periodFinder);
        await tester.pumpAndSettle();
        await tester.tap(periodFinder);
        await tester.pumpAndSettle();

        expect(repo.touchedPeriods, ['EARLY_INDEPENDENCE']);
        expect(find.byType(PeriodJourneyScreen), findsOneWidget);
        expect(find.text('HÀNH TRÌNH THỜI KỲ'), findsOneWidget);
        expect(find.text('Đại Chiến Bạch Đằng 938'), findsOneWidget);
      },
    );
  });

  group(
    'PeriodJourneyScreen — touch, ẩn tầng PHASE/LESSON 1 mục & mở CampaignDetailScreen',
    () {
      testWidgets(
        'vào thẳng PeriodJourneyScreen tự động gọi touchPeriod 1 lần',
        (tester) async {
          final mockRepo = MockLearningPathRepository();
          final snapshot = await mockRepo.getMyLearningPath();
          final repo = _RecordingLearningPathRepository(snapshot);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'LY_DYNASTY'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(repo.touchedPeriods, ['LY_DYNASTY']);
          expect(find.text('Lý Thái Tổ Dời Đô Về Thăng Long'), findsOneWidget);
          expect(find.text('Chiến Thắng Như Nguyệt 1077'), findsOneWidget);
        },
      );

      testWidgets(
        'ẩn tầng PHASE khi thời kỳ chỉ có 1 PHASE; hiện khi có >= 2 PHASE',
        (tester) async {
          const pathWithPhases = LearningPathDto(
            pathCode: 'HISTORY_MAIN',
            pathVersion: 2,
            enrolled: true,
            chapters: [
              // Thời kỳ A chỉ có 1 PHASE
              LearningPathChapterDto(
                chapterId: 'p-single',
                nodeType: PathNodeType.period,
                code: 'PERIOD_SINGLE_PHASE',
                title: 'Thời kỳ 1 giai đoạn',
                sortOrder: 1,
              ),
              LearningPathChapterDto(
                chapterId: 'ph-only',
                parentId: 'p-single',
                nodeType: PathNodeType.phase,
                code: 'PHASE_ONLY',
                title: 'Giai đoạn duy nhất (phải ẩn)',
                sortOrder: 1,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-1',
                    eventId: 'evt-1',
                    title: 'Sự kiện trong giai đoạn đơn',
                    yearLabel: 'Năm 938',
                    sortOrder: 1,
                    status: LearnerPathStatus.available,
                    lessons: [
                      LearningPathLessonNodeDto(
                        lessonId: 'les-only',
                        title: 'Bài học đơn lẻ',
                        sortOrder: 1,
                        status: LearnerPathStatus.available,
                      ),
                    ],
                  ),
                ],
              ),
              // Thời kỳ B có 2 PHASE
              LearningPathChapterDto(
                chapterId: 'p-multi',
                nodeType: PathNodeType.period,
                code: 'PERIOD_MULTI_PHASE',
                title: 'Thời kỳ 2 giai đoạn',
                sortOrder: 2,
              ),
              LearningPathChapterDto(
                chapterId: 'ph-1',
                parentId: 'p-multi',
                nodeType: PathNodeType.phase,
                code: 'PHASE_1',
                title: 'Giai đoạn Khởi đầu',
                sortOrder: 1,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-2',
                    eventId: 'evt-2',
                    title: 'Sự kiện Giai đoạn 1',
                    yearLabel: 'Năm 1010',
                    sortOrder: 1,
                    status: LearnerPathStatus.completed,
                  ),
                ],
              ),
              LearningPathChapterDto(
                chapterId: 'ph-2',
                parentId: 'p-multi',
                nodeType: PathNodeType.phase,
                code: 'PHASE_2',
                title: 'Giai đoạn Bảo vệ',
                sortOrder: 2,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-3',
                    eventId: 'evt-3',
                    title: 'Sự kiện Giai đoạn 2',
                    yearLabel: 'Năm 1077',
                    sortOrder: 2,
                    status: LearnerPathStatus.available,
                  ),
                ],
              ),
            ],
          );

          final repo = _RecordingLearningPathRepository(pathWithPhases);

          // 1) Kiểm tra PERIOD_SINGLE_PHASE: ẩn PHASE_ONLY và ẩn danh sách 1 bài học
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'PERIOD_SINGLE_PHASE'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('phase-header-PHASE_ONLY')),
            findsNothing,
          );
          expect(find.text('Giai đoạn duy nhất (phải ẩn)'), findsNothing);
          expect(find.text('Sự kiện trong giai đoạn đơn'), findsOneWidget);
          expect(find.byKey(const Key('event-lessons-evt-1')), findsNothing);

          // 2) Kiểm tra PERIOD_MULTI_PHASE: hiển thị cả PHASE_1 và PHASE_2
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'PERIOD_MULTI_PHASE'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('phase-header-PHASE_1')), findsOneWidget);
          expect(find.byKey(const Key('phase-header-PHASE_2')), findsOneWidget);
          expect(find.text('Giai đoạn Khởi đầu'), findsOneWidget);
          expect(find.text('Giai đoạn Bảo vệ'), findsOneWidget);
        },
      );

      testWidgets('bấm vào event mở CampaignDetailScreen với đúng eventId', (
        tester,
      ) async {
        final mockRepo = MockLearningPathRepository();
        final snapshot = await mockRepo.getMyLearningPath();
        final repo = _RecordingLearningPathRepository(snapshot);

        final router = GoRouter(
          initialLocation: '/journey/EARLY_INDEPENDENCE',
          routes: [
            GoRoute(
              path: '/journey/:periodCode',
              builder: (context, state) => PeriodJourneyScreen(
                periodCode: state.pathParameters['periodCode']!,
              ),
            ),
            GoRoute(
              path: '/campaign/:eventId',
              builder: (context, state) => CampaignDetailScreen(
                eventId: state.pathParameters['eventId']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningPathRepositoryProvider.overrideWithValue(repo),
              eventsRepositoryProvider.overrideWithValue(
                _StubEventsRepository(),
              ),
              attemptRepositoryProvider.overrideWithValue(
                FakeAttemptRepository(),
              ),
              collectionRepositoryProvider.overrideWithValue(
                MockCollectionRepository(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final eventCard = find.byKey(
          const Key('event-card-00000000-0000-0000-0000-000000000001'),
        );
        expect(eventCard, findsOneWidget);

        await tester.tap(eventCard);
        await tester.pumpAndSettle();

        expect(find.byType(CampaignDetailScreen), findsOneWidget);
        expect(find.text('CHI TIẾT CHIẾN DỊCH'), findsOneWidget);
      });

      testWidgets(
        'lỗi mạng hiển thị thẻ lỗi + nút THỬ LẠI tải lại thành công',
        (tester) async {
          final mockRepo = MockLearningPathRepository();
          final snapshot = await mockRepo.getMyLearningPath();
          final repo = _RecordingLearningPathRepository(snapshot)
            ..error = const ApiException(
              ApiError(code: 'NETWORK_ERROR', message: 'Mất kết nối'),
              statusCode: 503,
            );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodSelectionScreen(showBottomNav: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('THỬ LẠI'), findsOneWidget);

          repo.error = null;
          await tester.tap(find.text('THỬ LẠI'));
          await tester.pumpAndSettle();

          expect(find.text('Thời kỳ Cổ – Trung đại'), findsOneWidget);
        },
      );
    },
  );
}
