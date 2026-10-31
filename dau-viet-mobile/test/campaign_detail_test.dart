import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/campaign/presentation/campaign_detail_screen.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_attempt_repository.dart';

class _StubEventsRepository implements EventsRepository {
  HistoricalEventModel Function(String id)? onGetEventById;

  @override
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) => Future.value(
    const EventsPageResult(
      milestones: [],
      page: 0,
      size: 0,
      totalElements: 0,
      totalPages: 0,
    ),
  );

  @override
  Future<HistoricalEventModel> getEventById(String id) =>
      Future.value(onGetEventById!(id));
}

void main() {
  Widget buildApp(_StubEventsRepository repo, String eventId) {
    return ProviderScope(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(repo),
        // LessonListSection gọi attemptRepositoryProvider — stub để test
        // không phụ thuộc network/mock seam.
        attemptRepositoryProvider.overrideWithValue(FakeAttemptRepository()),
      ],
      child: MaterialApp(home: CampaignDetailScreen(eventId: eventId)),
    );
  }

  testWidgets('hero EventCoverImage render asset path đã resolve', (
    tester,
  ) async {
    final repo = _StubEventsRepository()
      ..onGetEventById = (id) => const HistoricalEventModel(
        id: 'u1',
        title: 'Bạch Đằng',
        era: 'Ngô',
        year: 938,
        heroBannerUrl: 'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
        summary: 'sum',
        lessonIds: [],
      );
    await tester.pumpWidget(buildApp(repo, 'u1'));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT SỰ KIỆN'), findsOneWidget);
    // Nếu asset tồn tại trong test bundle, Image sẽ hiển thị; kiểm tra
    // widget EventCoverImage tồn tại là đủ (asset jpg thật có trong assets).
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('coverAssetKey lạ → heroBannerUrl rỗng → placeholder render', (
    tester,
  ) async {
    final repo = _StubEventsRepository()
      ..onGetEventById = (id) => const HistoricalEventModel(
        id: 'u2',
        title: 'Sự kiện không ảnh',
        era: 'X',
        year: 100,
        heroBannerUrl: '', // AssetResolver trả null → adapter để rỗng
        summary: 'sum',
        lessonIds: [],
      );
    await tester.pumpWidget(buildApp(repo, 'u2'));
    await tester.pumpAndSettle();
    // Placeholder icon sailboat — AC-6 không vỡ layout.
    expect(find.byIcon(Icons.sailing_rounded), findsOneWidget);
  });

  testWidgets('error → hiển thị thẻ lỗi + THỬ LẠI', (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventDetailProvider('bad-id').overrideWith((ref) async {
            calls++;
            throw const ApiException(
              ApiError(code: 'EVENT_NOT_FOUND', message: '404'),
              statusCode: 404,
            );
          }),
          // LessonListSection gọi attemptRepositoryProvider — stub để
          // test không phụ thuộc network/mock seam.
          attemptRepositoryProvider.overrideWithValue(FakeAttemptRepository()),
        ],
        child: const MaterialApp(home: CampaignDetailScreen(eventId: 'bad-id')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
    expect(find.text('Không tìm thấy hồ sơ sự kiện này.'), findsOneWidget);
    calls = 0; // đếm lại từ đầu — chỉ quan tâm retry sau tap
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
    'danh sách bài học hiển thị đúng trạng thái từ lộ trình và bài ngoài lộ trình (Issue #23)',
    (tester) async {
      const eventId = '00000000-0000-0000-0000-000000000001';
      final eventsRepo = _StubEventsRepository()
        ..onGetEventById = (id) => const HistoricalEventModel(
          id: eventId,
          title: 'Đại Chiến Bạch Đằng 938',
          era: 'Buổi đầu độc lập tự chủ',
          year: 938,
          heroBannerUrl: '',
          summary: 'Chiến thắng trên sông Bạch Đằng',
          lessonIds: [],
        );
      final attemptRepo = FakeAttemptRepository()
        ..lessons = const [
          LessonListItemDto(
            id: 'demo-lesson-bach-dang-intro',
            title: 'Bối cảnh sông Bạch Đằng & Quân Nam Hán',
          ),
          LessonListItemDto(
            id: 'demo-lesson-bach-dang',
            title: 'Bí mật chiến thắng Bạch Đằng (Demo)',
            centralQuestion:
                'Vì sao bãi cọc Bạch Đằng đánh bại được thủy quân Nam Hán?',
          ),
          LessonListItemDto(
            id: 'demo-lesson-bach-dang-cer',
            title: 'Lập luận CER: Thủy triều & Bãi cọc gỗ lim',
          ),
          LessonListItemDto(
            id: 'lesson-out-of-path',
            title: 'Tư liệu mở rộng ngoài lộ trình',
          ),
        ];
      final mockPathRepo = MockLearningPathRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(eventsRepo),
            attemptRepositoryProvider.overrideWithValue(attemptRepo),
            learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
            learnerLearningPathProvider.overrideWith(
              () => _StubPathController(mockPathRepo),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDetailScreen(eventId: eventId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bối cảnh sông Bạch Đằng & Quân Nam Hán'),
        findsOneWidget,
      );
      expect(find.text('Đã hoàn thành'), findsOneWidget);

      expect(find.text('Bí mật chiến thắng Bạch Đằng (Demo)'), findsOneWidget);
      expect(find.text('Đang học'), findsOneWidget);

      expect(
        find.text('Lập luận CER: Thủy triều & Bãi cọc gỗ lim'),
        findsOneWidget,
      );
      expect(find.text('Đang khóa'), findsOneWidget);

      expect(find.text('Tư liệu mở rộng ngoài lộ trình'), findsOneWidget);
      expect(find.text('Tự do khám phá'), findsOneWidget);
    },
  );

  testWidgets(
    'bấm bài LOCKED hiện SnackBar và không điều hướng; bấm bài mở điều hướng tới /learning/lesson/:id',
    (tester) async {
      const eventId = '00000000-0000-0000-0000-000000000001';
      final eventsRepo = _StubEventsRepository()
        ..onGetEventById = (id) => const HistoricalEventModel(
          id: eventId,
          title: 'Đại Chiến Bạch Đằng 938',
          era: 'Buổi đầu độc lập tự chủ',
          year: 938,
          heroBannerUrl: '',
          summary: 'Chiến thắng trên sông Bạch Đằng',
          lessonIds: [],
        );
      final attemptRepo = FakeAttemptRepository()
        ..lessons = const [
          LessonListItemDto(
            id: 'demo-lesson-bach-dang',
            title: 'Bí mật chiến thắng Bạch Đằng (Demo)',
          ),
          LessonListItemDto(
            id: 'demo-lesson-bach-dang-cer',
            title: 'Lập luận CER: Thủy triều & Bãi cọc gỗ lim',
          ),
        ];
      final mockPathRepo = MockLearningPathRepository();

      String? openedLessonId;
      final router = GoRouter(
        initialLocation: '/campaign/$eventId',
        routes: [
          GoRoute(
            path: '/campaign/:eventId',
            builder: (_, state) =>
                CampaignDetailScreen(eventId: state.pathParameters['eventId']!),
          ),
          GoRoute(
            path: '/learning/lesson/:lessonId',
            builder: (_, state) {
              openedLessonId = state.pathParameters['lessonId'];
              return Scaffold(body: Text('LESSON:$openedLessonId'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(eventsRepo),
            attemptRepositoryProvider.overrideWithValue(attemptRepo),
            learningPathRepositoryProvider.overrideWithValue(mockPathRepo),
            learnerLearningPathProvider.overrideWith(
              () => _StubPathController(mockPathRepo),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Bấm bài LOCKED -> hiện SnackBar, không điều hướng
      await tester.ensureVisible(
        find.text('Lập luận CER: Thủy triều & Bãi cọc gỗ lim'),
      );
      await tester.tap(find.text('Lập luận CER: Thủy triều & Bãi cọc gỗ lim'));
      await tester.pump();

      expect(find.textContaining('Bài học đang khóa'), findsOneWidget);
      expect(openedLessonId, isNull);

      // 2. Bấm bài IN_PROGRESS -> điều hướng sang /learning/lesson/demo-lesson-bach-dang
      await tester.ensureVisible(
        find.text('Bí mật chiến thắng Bạch Đằng (Demo)'),
      );
      await tester.tap(find.text('Bí mật chiến thắng Bạch Đằng (Demo)'));
      await tester.pumpAndSettle();

      expect(openedLessonId, 'demo-lesson-bach-dang');
      expect(find.text('LESSON:demo-lesson-bach-dang'), findsOneWidget);
    },
  );
}

class _StubPathController extends LearningPathController {
  final MockLearningPathRepository _repo;

  _StubPathController(this._repo);

  @override
  Future<LearningPathDto> build() => _repo.getMyLearningPath();
}
