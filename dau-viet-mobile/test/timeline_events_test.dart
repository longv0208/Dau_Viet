import 'dart:async';

import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/events_repository.dart';
import 'package:dau_viet_mobile/features/timeline/presentation/timeline_screen.dart';
import 'package:dau_viet_mobile/mock/models/lesson_models.dart';
import 'package:dau_viet_mobile/mock/models/timeline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repo stub điều khiển được trạng thái cho widget test Timeline.
class _StubEventsRepository implements EventsRepository {
  EventsPageResult Function()? onGetEvents;
  HistoricalEventModel Function(String id)? onGetEventById;

  @override
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) => Future.value(onGetEvents!());

  @override
  Future<HistoricalEventModel> getEventById(String id) =>
      Future.value(onGetEventById!(id));
}

TimelineMilestoneModel _milestone({
  required String id,
  required String title,
  required String era,
  int year = 938,
  bool isActive = false,
  String? eventId,
}) => TimelineMilestoneModel(
  id: id,
  yearLabel: 'Năm $year',
  yearValue: year,
  title: title,
  subtitle: 'sub',
  description: 'desc',
  era: era,
  isActive: isActive,
  eventId: eventId,
  badgeText: 'badge',
);

void main() {
  Widget buildApp(_StubEventsRepository repo) {
    return ProviderScope(
      overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TimelineScreen()),
    );
  }

  testWidgets('loading → hiển thị spinner', (tester) async {
    // Dùng future không bao giờ resolve để giữ trạng thái loading.
    // Completer thay vì Timer để không để lại pending timer sau khi
    // widget tree dispose (test invariants).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsListProvider.overrideWith((ref) async {
            ref.keepAlive();
            await Completer<EventsPageResult>().future;
            return const EventsPageResult(
              milestones: [],
              page: 0,
              size: 0,
              totalElements: 0,
              totalPages: 0,
            );
          }),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('data → render milestone title + era chips từ dữ liệu', (
    tester,
  ) async {
    final repo = _StubEventsRepository()
      ..onGetEvents = () => EventsPageResult(
        milestones: [
          _milestone(
            id: 'a',
            title: 'Hai Bà Trưng',
            era: 'Bắc thuộc',
            year: 40,
          ),
          _milestone(
            id: 'b',
            title: 'Bạch Đằng',
            era: 'Ngô',
            year: 938,
            isActive: true,
            eventId: 'evt_x',
          ),
        ],
        page: 0,
        size: 2,
        totalElements: 2,
        totalPages: 1,
      );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hai Bà Trưng'), findsOneWidget);
    expect(find.text('Bạch Đằng'), findsOneWidget);
    // Era chips dựng từ dữ liệu: 'Tất cả' + 'Bắc thuộc' + 'Ngô'
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Bắc thuộc'), findsOneWidget);
    expect(find.text('Ngô'), findsOneWidget);
    // CTA chỉ trên milestone active
    expect(find.text('Khám phá Chiến dịch'), findsOneWidget);
  });

  testWidgets('error → hiển thị thẻ lỗi + nút THỬ LẠI gọi lại provider', (
    tester,
  ) async {
    int calls = 0;
    bool fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsListProvider.overrideWith((ref) async {
            calls++;
            if (fail) {
              throw const ApiException(
                ApiError(code: 'NETWORK_ERROR', message: 'down'),
              );
            }
            return EventsPageResult(
              milestones: [_milestone(id: 'a', title: 'OK', era: 'e', year: 1)],
              page: 0,
              size: 1,
              totalElements: 1,
              totalPages: 1,
            );
          }),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
    fail = false;
    calls = 0;
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('empty → hiển thị empty state', (tester) async {
    final repo = _StubEventsRepository()
      ..onGetEvents = () => const EventsPageResult(
        milestones: [],
        page: 0,
        size: 0,
        totalElements: 0,
        totalPages: 0,
      );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
  });
}
