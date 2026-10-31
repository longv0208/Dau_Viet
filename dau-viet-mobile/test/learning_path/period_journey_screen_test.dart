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
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/rewards/data/reward_dtos.dart';
import 'package:dau_viet_mobile/features/rewards/data/reward_providers.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      testWidgets(
        'Phần E: Đồng bộ HeritageBackground (có ảnh riêng, không ảnh, tên dài trên màn nhỏ, điểm lấy nét khác nhau & khóa bài học)',
        (tester) async {
          tester.view.physicalSize = const Size(340, 680);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const syncedPath = LearningPathDto(
            pathCode: 'HISTORY_MAIN',
            pathVersion: 3,
            enrolled: true,
            periodProgress: [
              PeriodProgressDto(
                chapterId: 'p-ly',
                code: 'LY_DYNASTY',
                title: 'Thời nhà Lý — Kỷ nguyên Văn hiến Đại Việt rực rỡ tại kinh thành Thăng Long',
                completedEvents: 0,
                requiredEvents: 2,
                completedLessons: 1,
                requiredLessons: 3,
                percent: 0,
              ),
            ],
            currentByPeriod: {
              'LY_DYNASTY': LearningPathCurrentDto(
                chapterId: 'p-ly',
                eventNodeId: 'en-1010',
                lessonId: 'les-1010-2',
              ),
            },
            chapters: [
              LearningPathChapterDto(
                chapterId: 'era-feudal',
                nodeType: PathNodeType.era,
                code: 'ERA_FEUDAL',
                title: 'Thời kỳ Phong kiến Độc lập Tự chủ',
                sortOrder: 1,
              ),
              LearningPathChapterDto(
                chapterId: 'p-ly',
                parentId: 'era-feudal',
                nodeType: PathNodeType.period,
                code: 'LY_DYNASTY',
                title:
                    'Thời nhà Lý — Kỷ nguyên Văn hiến Đại Việt rực rỡ tại kinh thành Thăng Long',
                periodLabel: 'Năm 1009 – năm 1225',
                description: 'Khởi đầu kỷ nguyên độc lập lâu dài tại Thăng Long.',
                sortOrder: 1,
                backgroundConfig: HeritageBackgroundConfigDto(
                  backgroundImageUrl:
                      'assets/images/heritage/hoang-thanh-thang-long.jpg',
                  backgroundMode: HeritageBackgroundMode.heritageFade,
                  focusX: 0.65,
                  focusY: 0.25,
                  imageOpacity: 0.6,
                  fadeStrength: 0.85,
                  tintPreset: HeritageTintPreset.warm,
                  enabled: true,
                ),
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-1010',
                    eventId: 'evt-1010',
                    slug: 'thang-long-1010',
                    title: 'Dời đô ra Thăng Long năm 1010',
                    yearLabel: 'Năm 1010',
                    coverAssetKey: 'events/bach-dang-938/hero.jpg',
                    sortOrder: 1,
                    participationType: ParticipationType.required,
                    status: LearnerPathStatus.available,
                    lessons: [
                      LearningPathLessonNodeDto(
                        lessonId: 'les-1010-1',
                        title: 'Vì sao dời đô?',
                        sortOrder: 1,
                        status: LearnerPathStatus.completed,
                      ),
                      LearningPathLessonNodeDto(
                        lessonId: 'les-1010-2',
                        title: 'Dấu tích đô thành qua thời gian',
                        sortOrder: 2,
                        status: LearnerPathStatus.available,
                      ),
                      LearningPathLessonNodeDto(
                        lessonId: 'les-1010-3',
                        title: 'Quy hoạch kinh thành Thăng Long',
                        sortOrder: 3,
                        status: LearnerPathStatus.locked,
                      ),
                    ],
                  ),
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-1077',
                    eventId: 'evt-1077',
                    title: 'Chiến thắng Như Nguyệt 1077',
                    yearLabel: 'Năm 1077',
                    sortOrder: 2,
                    participationType: ParticipationType.required,
                    status: LearnerPathStatus.locked,
                  ),
                ],
              ),
              LearningPathChapterDto(
                chapterId: 'p-no-bg',
                parentId: 'era-feudal',
                nodeType: PathNodeType.period,
                code: 'TRAN_DYNASTY_NEW',
                title: 'Thời nhà Trần (Không có ảnh nền riêng)',
                sortOrder: 2,
                backgroundConfig: HeritageBackgroundConfigDto.paperDefault,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-1288',
                    eventId: 'evt-1288',
                    title: 'Chiến thắng Bạch Đằng 1288',
                    yearLabel: 'Năm 1288',
                    sortOrder: 1,
                    status: LearnerPathStatus.available,
                  ),
                ],
              ),
            ],
          );

          final repo = _RecordingLearningPathRepository(syncedPath);
          LearningPathEventNodeDto? selectedEvent;

          // 1) Thời kỳ có ảnh nền riêng + tên dài + mốc tiếp theo + bài học khóa
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: MaterialApp(
                home: PeriodJourneyScreen(
                  periodCode: 'LY_DYNASTY',
                  onEventSelected: (evt) => selectedEvent = evt,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(HeritageBackground), findsOneWidget);
          expect(find.text('Thời kỳ Phong kiến Độc lập Tự chủ'), findsOneWidget);
          expect(
            find.text('Tiến độ thời kỳ: 0/2 sự kiện • 1/3 bài học'),
            findsOneWidget,
          );
          expect(find.text('33%'), findsOneWidget);
          // Mốc sự kiện render dạng nhãn pill gọn (mockup đường đi): chỉ có
          // tên + niên đại, không bung thẻ đầy đủ che tranh nền.
          expect(find.text('Dời đô ra Thăng Long năm 1010'), findsOneWidget);
          expect(find.text('Năm 1010'), findsWidgets);
          expect(find.text('Chiến thắng Như Nguyệt 1077'), findsOneWidget);

          // Nhấn nhãn sự kiện đang khóa -> vẫn gọi onEventSelected (màn chiến
          // dịch quyết định chặn/gợi ý), khớp hành vi thẻ đầy đủ trước đây.
          await tester.ensureVisible(
            find.byKey(const Key('event-card-evt-1077')),
          );
          await tester.tap(find.byKey(const Key('event-card-evt-1077')));
          await tester.pump();
          expect(selectedEvent?.eventId, 'evt-1077');

          // 2) Thời kỳ mới không có ảnh nền riêng -> vẫn render nền giấy cổ bình thường
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'TRAN_DYNASTY_NEW'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Chiến thắng Bạch Đằng 1288'), findsOneWidget);
        },
      );
    },
  );
  group(
    'Issue #48 — Đường đi Phong cảnh 2.5D, tự do chọn thời kỳ & Thẻ tổng quan nổi',
    () {
      testWidgets(
        'AC-1/AC-2: /journey hiển thị WindingLandscapeJourneyCanvas, tab ERA, '
        'không có thời kỳ nào bị khóa và BottomFloatingSummaryCard đúng X/Y + %',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final mockRepo = MockLearningPathRepository();
          final snapshot = await mockRepo.getMyLearningPath();
          final repo = _RecordingLearningPathRepository(snapshot);

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

          // Canvas đường đi phong cảnh + thẻ tổng quan nổi ở chân màn hình.
          expect(
            find.byType(WindingLandscapeJourneyCanvas),
            findsOneWidget,
          );
          expect(
            find.byType(BottomFloatingSummaryCard),
            findsOneWidget,
          );
          // Header theo mockup.
          expect(find.text('Hành trình'), findsOneWidget);
          expect(
            find.text('Khám phá dòng chảy lịch sử Việt Nam'),
            findsOneWidget,
          );
          // Tab Đại thời kỳ (3 ERA + tab "Tất cả").
          expect(find.text('Tất cả'), findsOneWidget);
          expect(
            find.byKey(const Key('era-tab-ERA_ANCIENT_MEDIEVAL')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('era-tab-ERA_EARLY_MODERN')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('era-tab-ERA_MODERN')), findsOneWidget);

          // AC-2: Không có nút mốc PERIOD nào hiển thị icon khóa.
          for (final code in [
            'FOUNDING_ERA',
            'NORTHERN_DOMINATION',
            'EARLY_INDEPENDENCE',
            'LY_DYNASTY',
            'PATRIOTIC_MOVEMENTS',
            'ANTI_FRENCH_RESISTANCE',
          ]) {
            final card = find.byKey(Key('period-card-$code'));
            await tester.ensureVisible(card);
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: card,
                matching: find.byIcon(Icons.lock_rounded),
              ),
              findsNothing,
            );
            expect(
              find.descendant(
                of: card,
                matching: find.byIcon(Icons.lock_outline_rounded),
              ),
              findsNothing,
            );
          }
        },
      );

      testWidgets(
        'AC-2: bấm tự do thời kỳ chưa học (ANTI_FRENCH_RESISTANCE) điều hướng '
        'vào PeriodJourneyScreen mà không bị chặn',
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
                home: PeriodSelectionScreen(showBottomNav: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final periodCard = find.byKey(
            const Key('period-card-ANTI_FRENCH_RESISTANCE'),
          );
          await tester.ensureVisible(periodCard);
          await tester.pumpAndSettle();
          await tester.tap(periodCard);
          await tester.pumpAndSettle();

          expect(repo.touchedPeriods, contains('ANTI_FRENCH_RESISTANCE'));
          expect(find.byType(PeriodJourneyScreen), findsOneWidget);
          expect(find.text('Chiến Dịch Điện Biên Phủ 1954'), findsOneWidget);
          // Thanh chuyển nhanh thời kỳ + thẻ tổng quan nổi trên màn thời kỳ.
          expect(find.byType(WindingLandscapeJourneyCanvas), findsOneWidget);
          expect(find.byType(BottomFloatingSummaryCard), findsOneWidget);
        },
      );

      testWidgets(
        'AC-1: /journey/:periodCode chỉ hiển thị nội dung thời kỳ đã chọn '
        '(không có thanh chip chuyển thời kỳ khác)',
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

          expect(find.byType(WindingLandscapeJourneyCanvas), findsOneWidget);
          expect(find.byType(BottomFloatingSummaryCard), findsOneWidget);
          // Tiến độ LY_DYNASTY trong mock: 0/2 sự kiện • 0/3 bài học • 0%.
          expect(
            find.text('Tiến độ thời kỳ: 0/2 sự kiện • 0/3 bài học'),
            findsOneWidget,
          );
          // Nút mốc khóa tuần tự vẫn hiển thị ổ khóa xám như mockup.
          expect(find.byIcon(Icons.lock_rounded), findsWidgets);
          // Không còn thanh chip chuyển sang thời kỳ khác trên màn Hành trình.
          final antiFrenchTab = find.text('Kháng chiến chống thực dân Pháp');
          expect(antiFrenchTab, findsNothing);
          expect(find.text('Buổi đầu dựng nước'), findsNothing);
        },
      );

      testWidgets(
        'Showcase NORTHERN_DOMINATION: cấu hình ảnh nền riêng từ DB, 2 PHASE, '
        '3 nhãn sự kiện, 6 mốc bài học, mốc rương từ API và Bottom Sheet Địa điểm + Vật phẩm',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          const showcasePath = LearningPathDto(
            pathCode: 'HISTORY_MAIN',
            pathVersion: 3,
            enrolled: true,
            chapters: [
              LearningPathChapterDto(
                chapterId: 'era-1',
                nodeType: PathNodeType.era,
                code: 'ERA_ANCIENT_MEDIEVAL',
                title: 'Thời kỳ Cổ – Trung đại',
                sortOrder: 1,
              ),
              LearningPathChapterDto(
                chapterId: 'p-nd',
                parentId: 'era-1',
                nodeType: PathNodeType.period,
                code: 'NORTHERN_DOMINATION',
                title: 'Bắc thuộc và đấu tranh giành độc lập',
                periodLabel: 'Năm 179 TCN – năm 938',
                sortOrder: 2,
                backgroundConfig: HeritageBackgroundConfigDto(
                  backgroundAssetId: 'd7a90000-0000-4000-8000-000000000007',
                  backgroundImageUrl:
                      '/api/v1/assets/d7a90000-0000-4000-8000-000000000007/content',
                  backgroundMode: HeritageBackgroundMode.heritageFade,
                  enabled: true,
                ),
              ),
              LearningPathChapterDto(
                chapterId: 'ph-nd-1',
                parentId: 'p-nd',
                nodeType: PathNodeType.phase,
                code: 'PHASE_ND_EARLY',
                title: 'Giai đoạn I: Ngọn lửa khởi nghĩa đầu Công nguyên',
                periodLabel: 'Năm 40 – năm 248',
                sortOrder: 1,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-hbt',
                    eventId: 'd7b00000-0000-4000-8000-000000000002',
                    slug: 'hai-ba-trung-40',
                    title: 'Khởi Nghĩa Hai Bà Trưng (40 – 43)',
                    yearLabel: 'Năm 40 – 43',
                    sortOrder: 1,
                    status: LearnerPathStatus.completed,
                    backgroundConfig: HeritageBackgroundConfigDto(
                      focusX: 0.26,
                      focusY: 0.28,
                      enabled: true,
                    ),
                    lessons: [
                      LearningPathLessonNodeDto(
                        lessonId: '63100000-0000-4000-8000-000000000001',
                        title: 'Lời thề Hát Môn & Tiếng trống Mê Linh',
                        sortOrder: 1,
                        status: LearnerPathStatus.completed,
                      ),
                      LearningPathLessonNodeDto(
                        lessonId: '63100000-0000-4000-8000-000000000002',
                        title: 'Thu phục 65 thành Lĩnh Ngoại & Quốc đô Mê Linh',
                        sortOrder: 2,
                        status: LearnerPathStatus.completed,
                      ),
                    ],
                  ),
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-bt',
                    eventId: '1f01f2e5-ee07-4b86-a534-061dcad8134f',
                    slug: 'history-ba-trieu',
                    title: 'Khởi Nghĩa Bà Triệu (248)',
                    yearLabel: 'Năm 248',
                    sortOrder: 2,
                    status: LearnerPathStatus.available,
                    backgroundConfig: HeritageBackgroundConfigDto(
                      focusX: 0.74,
                      focusY: 0.32,
                      enabled: true,
                    ),
                    lessons: [
                      LearningPathLessonNodeDto(
                        lessonId: 'b2222222-2222-2222-2222-222222222201',
                        title: 'Khởi nghĩa Bà Triệu — Khí phách cưỡi sóng dữ',
                        sortOrder: 1,
                        status: LearnerPathStatus.available,
                      ),
                      LearningPathLessonNodeDto(
                        lessonId: '63100000-0000-4000-8000-000000000004',
                        title: 'Căn cứ Núi Nưa & Làn sóng khởi nghĩa Cửu Chân',
                        sortOrder: 2,
                        status: LearnerPathStatus.locked,
                      ),
                    ],
                  ),
                ],
              ),
              LearningPathChapterDto(
                chapterId: 'ph-nd-2',
                parentId: 'p-nd',
                nodeType: PathNodeType.phase,
                code: 'PHASE_ND_LATE',
                title: 'Giai đoạn II: Khúc tráng ca tự chủ & Đại thắng Bạch Đằng 938',
                periodLabel: 'Năm 544 – năm 938',
                sortOrder: 2,
                events: [
                  LearningPathEventNodeDto(
                    eventNodeId: 'en-bd',
                    eventId: '635d6143-ffe1-4770-91e4-a4e4194fb1b7',
                    slug: 'history-bach-dang-938',
                    title: 'Chiến Thắng Bạch Đằng Năm 938',
                    yearLabel: 'Năm 938',
                    sortOrder: 3,
                    status: LearnerPathStatus.locked,
                    backgroundConfig: HeritageBackgroundConfigDto(
                      focusX: 0.28,
                      focusY: 0.30,
                      enabled: true,
                    ),
                    lessons: [
                      LearningPathLessonNodeDto(
                        lessonId: 'b2222222-2222-2222-2222-222222222202',
                        title: 'Bạch Đằng 938 — Trận địa cọc ngầm phá quân Nam Hán',
                        sortOrder: 1,
                        status: LearnerPathStatus.locked,
                      ),
                      LearningPathLessonNodeDto(
                        lessonId: '63100000-0000-4000-8000-000000000006',
                        title: 'Ngô Quyền xưng Vương & Kinh đô Cổ Loa độc lập',
                        sortOrder: 2,
                        status: LearnerPathStatus.locked,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          final repo = _RecordingLearningPathRepository(showcasePath);

          final testCatalog = <CatalogItemDto>[
            const CatalogItemDto(
              itemId: 'item-hbt',
              code: 'HUY_HIEU_TRONG_DONG_ME_LINH',
              name: 'Huy hiệu Tiếng Trống Mê Linh',
              description: 'Kỷ vật đồng khắc hình Trống đồng Mê Linh.',
              category: 'HUY_HIEU',
              itemType: 'BADGE',
              rarity: 'RARE',
              owned: true,
              requirement: ItemRequirementDto(
                type: 'EVENT_COMPLETED',
                eventId: 'd7b00000-0000-4000-8000-000000000002',
                satisfied: true,
                status: 'SATISFIED',
              ),
            ),
            const CatalogItemDto(
              itemId: 'item-bt',
              code: 'HUY_HIEU_LENH_CO_BA_TRIEU',
              name: 'Huy hiệu Lệnh Cờ Bà Triệu 248',
              description: 'Huy hiệu chiến tượng Cửu Chân năm 248.',
              category: 'HUY_HIEU',
              itemType: 'BADGE',
              rarity: 'RARE',
              owned: false,
              requirement: ItemRequirementDto(
                operator: 'ALL',
                conditions: [
                  ItemRequirementDto(
                    type: 'EVENT_COMPLETED',
                    eventId: '1f01f2e5-ee07-4b86-a534-061dcad8134f',
                    satisfied: false,
                    status: 'PENDING',
                  ),
                ],
              ),
            ),
          ];

          final testLocations = <MapLocationDto>[
            const MapLocationDto(
              id: '63200000-0000-4000-8000-000000000001',
              eventId: 'd7b00000-0000-4000-8000-000000000002',
              eventIds: ['d7b00000-0000-4000-8000-000000000002'],
              title: 'Kinh đô Mê Linh & Đền Hát Môn',
              latitude: 21.18,
              longitude: 105.71,
              unlocked: true,
              unlockState: MapUnlockState.unlocked,
            ),
            const MapLocationDto(
              id: '63200000-0000-4000-8000-000000000002',
              eventId: '1f01f2e5-ee07-4b86-a534-061dcad8134f',
              eventIds: ['1f01f2e5-ee07-4b86-a534-061dcad8134f'],
              title: 'Căn cứ Núi Nưa & Đền Bà Triệu',
              latitude: 19.80,
              longitude: 105.62,
              unlocked: false,
              unlockState: MapUnlockState.locked,
            ),
          ];

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
                inventoryCatalogProvider.overrideWith((ref) async => testCatalog),
                mapLocationsProvider.overrideWith((ref) async => testLocations),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'NORTHERN_DOMINATION'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final canvas = tester.widget<WindingLandscapeJourneyCanvas>(
            find.byType(WindingLandscapeJourneyCanvas),
          );
          expect(
            canvas.backgroundAssetId,
            'd7a90000-0000-4000-8000-000000000007',
          );
          expect(
            canvas.backgroundAsset,
            'assets/images/journey/heritage_scroll_bg.jpg',
          );

          // Hiển thị 2 PHASE headers gọn gàng
          expect(
            find.byKey(const Key('phase-header-PHASE_ND_EARLY')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('phase-header-PHASE_ND_LATE')),
            findsOneWidget,
          );

          // 3 nhãn sự kiện + 6 mốc bài học
          expect(find.text('Khởi Nghĩa Hai Bà Trưng (40 – 43)'), findsOneWidget);
          expect(find.text('Khởi Nghĩa Bà Triệu (248)'), findsOneWidget);
          expect(find.text('Chiến Thắng Bạch Đằng Năm 938'), findsOneWidget);
          for (final lessonId in const [
            '63100000-0000-4000-8000-000000000001',
            '63100000-0000-4000-8000-000000000002',
            'b2222222-2222-2222-2222-222222222201',
            '63100000-0000-4000-8000-000000000004',
            'b2222222-2222-2222-2222-222222222202',
            '63100000-0000-4000-8000-000000000006',
          ]) {
            expect(
              find.byKey(Key('lesson-milestone-$lessonId')),
              findsOneWidget,
            );
          }

          // Mốc rương chỉ xuất hiện cho 2 sự kiện có phần thưởng từ API; sự kiện thứ 3 không có phần thưởng thì ẩn rương.
          expect(
            find.byKey(
              const Key('event-chest-d7b00000-0000-4000-8000-000000000002'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const Key('event-chest-1f01f2e5-ee07-4b86-a534-061dcad8134f'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const Key('event-chest-635d6143-ffe1-4770-91e4-a4e4194fb1b7'),
            ),
            findsNothing,
          );

          // Trạng thái rương: Sự kiện 1 đã xong + chưa xem -> "Rương di sản • Chạm để mở!"
          // Sự kiện 2 chưa xong -> "Rương di sản • Đang khóa"
          expect(find.text('Rương di sản • Chạm để mở!'), findsOneWidget);
          expect(find.text('Rương di sản • Đang khóa'), findsOneWidget);

          // Bấm vào rương sáng của Sự kiện 1 -> chạy hiệu ứng ăn mừng rồi mở Bottom Sheet và đổi thành "Đã mở"
          final chest1 = find.byKey(
            const Key('event-chest-d7b00000-0000-4000-8000-000000000002'),
          );
          await tester.ensureVisible(chest1);
          await tester.tap(chest1);
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            find.byKey(const Key('chest-celebration-overlay')),
            findsOneWidget,
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const Key(
                'event-details-sheet-d7b00000-0000-4000-8000-000000000002',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text('ĐÃ MỞ KHÓA ĐỊA ĐIỂM'), findsOneWidget);
          expect(find.text('ĐÃ NHẬN KỶ VẬT'), findsOneWidget);
          expect(find.text('Kinh đô Mê Linh & Đền Hát Môn'), findsWidgets);
          expect(find.text('Huy hiệu Tiếng Trống Mê Linh'), findsWidgets);

          // Đóng Bottom Sheet -> rương đã chuyển sang trạng thái "Rương di sản • Đã mở"
          Navigator.of(
            tester.element(
              find.byKey(
                const Key(
                  'event-details-sheet-d7b00000-0000-4000-8000-000000000002',
                ),
              ),
            ),
          ).pop();
          await tester.pumpAndSettle();
          expect(find.text('Rương di sản • Đã mở'), findsOneWidget);
        },
      );

      testWidgets(
        'Khi thời kỳ có nhiều mốc sự kiện/bài học vượt quá chiều cao 1 khung ảnh, '
        'nền tranh tự động nối dài nhiều đoạn mà không vỡ bố cục',
        (tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final manyEvents = List.generate(
            12,
            (idx) => LearningPathEventNodeDto(
              eventNodeId: 'node-$idx',
              eventId: 'evt-long-$idx',
              title: 'Mốc lịch sử thứ ${idx + 1}: Chiến công giữ nước vẻ vang',
              yearLabel: 'Năm ${100 + idx * 50}',
              sortOrder: idx + 1,
              status: idx == 0
                  ? LearnerPathStatus.available
                  : LearnerPathStatus.locked,
            ),
          );

          final longPath = LearningPathDto(
            pathCode: 'HISTORY_MAIN',
            pathVersion: 3,
            enrolled: true,
            chapters: [
              LearningPathChapterDto(
                chapterId: 'p-long',
                nodeType: PathNodeType.period,
                code: 'LONG_PERIOD',
                title: 'Thời kỳ có nhiều bài học kéo dài',
                sortOrder: 1,
                events: manyEvents,
              ),
            ],
          );

          final repo = _RecordingLearningPathRepository(longPath);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'LONG_PERIOD'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Mốc lịch sử thứ 1: Chiến công giữ nước vẻ vang'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Mốc lịch sử thứ 12: Chiến công giữ nước vẻ vang'),
            250,
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Mốc lịch sử thứ 12: Chiến công giữ nước vẻ vang'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Bấm bài học khóa hiện thông báo không điều hướng; bấm bài sẵn sàng điều hướng vào đúng lessonId',
        (tester) async {
          final mockRepo = MockLearningPathRepository();
          final snapshot = await mockRepo.getMyLearningPath();
          final repo = _RecordingLearningPathRepository(snapshot);
          String? openedLessonId;

          final router = GoRouter(
            initialLocation: '/journey/LY_DYNASTY',
            routes: [
              GoRoute(
                path: '/journey/:periodCode',
                builder: (context, state) => PeriodJourneyScreen(
                  periodCode: state.pathParameters['periodCode']!,
                ),
              ),
              GoRoute(
                path: '/learning/lesson/:lessonId',
                builder: (context, state) {
                  openedLessonId = state.pathParameters['lessonId'];
                  return Scaffold(
                    body: Center(child: Text('LESSON:$openedLessonId')),
                  );
                },
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();

          // Bấm bài học khóa trong LY_DYNASTY ('demo-lesson-nhu-nguyet-1') -> hiện SnackBar, không điều hướng
          final lockedLesson = find.byKey(
            const Key('lesson-milestone-demo-lesson-nhu-nguyet-1'),
          );
          await tester.ensureVisible(lockedLesson);
          await tester.tap(lockedLesson);
          await tester.pump();
          expect(openedLessonId, isNull);
          expect(
            find.text('Hoàn thành bài học đứng trước để mở khóa bài học này.'),
            findsOneWidget,
          );

          // Bấm bài học sẵn sàng ('demo-lesson-thang-long-1') -> điều hướng sang /learning/lesson/demo-lesson-thang-long-1
          final unlockedLesson = find.byKey(
            const Key('lesson-milestone-demo-lesson-thang-long-1'),
          );
          await tester.ensureVisible(unlockedLesson);
          await tester.tap(unlockedLesson);
          await tester.pumpAndSettle();
          expect(openedLessonId, 'demo-lesson-thang-long-1');
          expect(find.text('LESSON:demo-lesson-thang-long-1'), findsOneWidget);
        },
      );

      testWidgets(
        'Khi API phần thưởng lỗi thì ẩn rương; khi bật giảm chuyển động thì mở thẳng Bottom Sheet không chạy pháo hoa',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final mockRepo = MockLearningPathRepository();
          final snapshot = await mockRepo.getMyLearningPath();
          final repo = _RecordingLearningPathRepository(snapshot);

          // 1) API lỗi -> ẩn mốc rương, màn vẫn chạy bình thường
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
                inventoryCatalogProvider.overrideWith(
                  (ref) async => throw Exception('API 500'),
                ),
                mapLocationsProvider.overrideWith(
                  (ref) async => throw Exception('API 500'),
                ),
              ],
              child: const MaterialApp(
                home: PeriodJourneyScreen(periodCode: 'FOUNDING_ERA'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              const Key('event-chest-00000000-0000-0000-0000-000000000005'),
            ),
            findsNothing,
          );
          expect(
            find.text('Văn minh lúa nước & Trống đồng Đông Sơn'),
            findsOneWidget,
          );

          // 2) Khi có phần thưởng nhưng bật disableAnimations -> bấm rương mở thẳng Bottom Sheet, không hiện overlay pháo hoa
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                learningPathRepositoryProvider.overrideWithValue(repo),
                inventoryCatalogProvider.overrideWith(
                  (ref) async => const [
                    CatalogItemDto(
                      itemId: 'item-vl',
                      code: 'TRONG_DONG',
                      name: 'Trống đồng Đông Sơn',
                      category: 'MO_HINH',
                      itemType: 'REPLICA',
                      rarity: 'RARE',
                      owned: true,
                      requirement: ItemRequirementDto(
                        type: 'EVENT_COMPLETED',
                        eventId: '00000000-0000-0000-0000-000000000005',
                        satisfied: true,
                        status: 'SATISFIED',
                      ),
                    ),
                  ],
                ),
                mapLocationsProvider.overrideWith((ref) async => const []),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: const PeriodJourneyScreen(periodCode: 'FOUNDING_ERA'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final chest = find.byKey(
            const Key('event-chest-00000000-0000-0000-0000-000000000005'),
          );
          expect(chest, findsOneWidget);
          await tester.tap(chest);
          await tester.pump();
          expect(
            find.byKey(const Key('chest-celebration-overlay')),
            findsNothing,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              const Key(
                'event-details-sheet-00000000-0000-0000-0000-000000000005',
              ),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Tab lọc Đại thời kỳ (ERA) ở PeriodSelectionScreen có cỡ chữ 13 và không nằm trong FittedBox',
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
                home: PeriodSelectionScreen(showBottomNav: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final allTab = find.byKey(const Key('era-tab-ALL'));
          expect(allTab, findsOneWidget);
          expect(
            find.ancestor(of: allTab, matching: find.byType(FittedBox)),
            findsNothing,
          );

          final textWidget = tester.widget<Text>(
            find.descendant(of: allTab, matching: find.byType(Text)),
          );
          expect(textWidget.style?.fontSize, 13);
        },
      );

      test(
        'WindingStonePathPainter.buildCatmullRomPath hoạt động đúng với 1, 2 và 20 điểm',
        () {
          final path1 = WindingStonePathPainter.buildCatmullRomPath(
            const [Offset(100, 120)],
          );
          expect(path1.computeMetrics().toList(), isNotEmpty);

          final path2 = WindingStonePathPainter.buildCatmullRomPath(
            const [Offset(80, 100), Offset(220, 220)],
          );
          final metrics2 = path2.computeMetrics().toList();
          expect(metrics2.length, 1);
          expect(metrics2.first.length, greaterThan(150));

          final points20 = List<Offset>.generate(
            20,
            (i) => Offset(i.isEven ? 90.0 : 250.0, 80.0 + i * 95.0),
          );
          final path20 = WindingStonePathPainter.buildCatmullRomPath(points20);
          final metrics20 = path20.computeMetrics().toList();
          expect(metrics20.length, 1);
          expect(metrics20.first.length, greaterThan(1800));
        },
      );
    },
  );
}
