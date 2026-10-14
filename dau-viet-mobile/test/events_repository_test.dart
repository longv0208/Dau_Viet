import 'package:dau_viet_mobile/core/api/api_client.dart';
import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/core/assets/asset_resolver.dart';
import 'package:dau_viet_mobile/features/events/data/api_events_repository.dart';
import 'package:dau_viet_mobile/features/events/data/events_api_client.dart';
import 'package:dau_viet_mobile/features/events/data/historical_event_dto.dart';
import 'package:dau_viet_mobile/features/events/data/mock_events_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake `EventsApiClient` — inject kết quả định sẵn thay vì gọi HTTP.
/// Đủ cho AC-7 mà không cần mock server hay mockito (YAGNI).
class _StubEventsApiClient extends EventsApiClient {
  EventsPageDto Function({int page, int size, String sort})? onGetEvents;
  HistoricalEventDetailDto Function(String id)? onGetEventById;
  Map<String, dynamic>? lastQuery;

  _StubEventsApiClient() : super(ApiClient(Dio()));

  @override
  Future<EventsPageDto> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) {
    lastQuery = {'page': page, 'size': size, 'sort': sort};
    return Future.value(onGetEvents!(page: page, size: size, sort: sort));
  }

  @override
  Future<HistoricalEventDetailDto> getEventById(String id) {
    return Future.value(onGetEventById!(id));
  }
}

void main() {
  group('ApiEventsRepository', () {
    final stub = _StubEventsApiClient();
    final repo = ApiEventsRepository(stub, const AssetResolver());

    final summaryDto = HistoricalEventSummaryDto(
      id: 'uuid-1',
      slug: 'bach-dang-938',
      title: 'Đại Chiến Bạch Đằng 938',
      era: 'Thời Ngô',
      period: 'Mùa Đông 938',
      startYear: 938,
      summary: 'Trận thủy chiến kinh điển',
      coverAssetKey: 'events/bach-dang-938/hero.jpg',
      tags: const ['ngo-quyen', 'thuy-chien'],
    );

    test('getEvents map DTO → TimelineMilestoneModel đúng adapter', () async {
      stub.onGetEvents = ({int page = 0, int size = 20, String sort = ''}) =>
          EventsPageDto(
            content: [summaryDto],
            page: page,
            size: size,
            totalElements: 1,
            totalPages: 1,
          );
      final result = await repo.getEvents();
      expect(result.milestones, hasLength(1));
      final m = result.milestones.first;
      expect(m.id, 'uuid-1');
      expect(m.yearLabel, 'Mùa Đông 938');
      expect(m.yearValue, 938);
      expect(m.badgeText, 'ngo-quyen'); // tags.first
      expect(m.isActive, isTrue); // phần tử đầu = active
      expect(m.eventId, 'uuid-1');
    });

    test('getEvents truyền tham số phân trang xuống client', () async {
      stub.onGetEvents = ({int page = 0, int size = 20, String sort = ''}) =>
          const EventsPageDto(
            content: [],
            page: 2,
            size: 5,
            totalElements: 0,
            totalPages: 0,
          );
      await repo.getEvents(page: 2, size: 5, sort: 'title,desc');
      expect(stub.lastQuery, {'page': 2, 'size': 5, 'sort': 'title,desc'});
    });

    test('getEvents content rỗng → milestones rỗng, isActive không crash', () async {
      stub.onGetEvents = ({int page = 0, int size = 20, String sort = ''}) =>
          const EventsPageDto(
            content: [],
            page: 0,
            size: 20,
            totalElements: 0,
            totalPages: 0,
          );
      final result = await repo.getEvents();
      expect(result.milestones, isEmpty);
    });

    test('getEventById map detail + resolve cover asset', () async {
      stub.onGetEventById = (id) => HistoricalEventDetailDto(
            id: id,
            slug: 'bach-dang-938',
            title: 'Bạch Đằng',
            era: 'Ngô',
            period: '938',
            startYear: 938,
            summary: 'sum',
            coverAssetKey: 'events/bach-dang-938/hero.jpg',
            description: 'dài',
            location: 'Sông Bạch Đằng',
          );
      final event = await repo.getEventById('uuid-1');
      expect(event.title, 'Bạch Đằng');
      expect(event.year, 938);
      expect(event.heroBannerUrl,
          'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg');
    });

    test('getEventById ApiException 404 lan truyền nguyên vẹn', () async {
      stub.onGetEventById = (id) => throw const ApiException(
            ApiError(code: 'EVENT_NOT_FOUND', message: 'not found'),
            statusCode: 404,
          );
      expect(
        () => repo.getEventById('bad-id'),
        throwsA(isA<ApiException>().having(
          (e) => e.error.code,
          'code',
          'EVENT_NOT_FOUND',
        )),
      );
    });
  });

  group('MockEventsRepository', () {
    final repo = MockEventsRepository();

    test('getEvents trả đủ mock milestones, isActive chỉ Bạch Đằng', () async {
      final result = await repo.getEvents();
      expect(result.milestones, isNotEmpty);
      expect(result.milestones.where((m) => m.isActive), hasLength(1));
      expect(
        result.milestones.firstWhere((m) => m.isActive).eventId,
        'evt_bach_dang_938',
      );
    });

    test('getEventById nhận cả seed UUID lẫn legacy id', () async {
      final a = await repo.getEventById('00000000-0000-0000-0000-000000000001');
      final b = await repo.getEventById('evt_bach_dang_938');
      expect(a.id, 'evt_bach_dang_938');
      expect(b.id, 'evt_bach_dang_938');
    });

    test('getEventById id lạ → ApiException EVENT_NOT_FOUND 404', () {
      expect(
        () => repo.getEventById('uuid-la'),
        throwsA(isA<ApiException>()
            .having((e) => e.isNotFound, 'isNotFound', isTrue)),
      );
    });
  });
}
