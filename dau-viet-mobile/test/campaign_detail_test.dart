import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/campaign/presentation/campaign_detail_screen.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
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
    expect(find.text('CHI TIẾT CHIẾN DỊCH'), findsOneWidget);
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
}
