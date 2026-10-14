import 'package:dau_viet_mobile/features/events/data/historical_event_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoricalEventSummaryDto', () {
    Map<String, dynamic> validJson() => {
          'id': '00000000-0000-0000-0000-000000000001',
          'slug': 'bach-dang-938',
          'title': 'Đại Chiến Bạch Đằng 938',
          'era': 'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
          'period': 'Mùa Đông 938 SCN',
          'startYear': 938,
          'summary': 'Trận thủy chiến kinh điển...',
          'coverAssetKey': 'events/bach-dang-938/hero.jpg',
          'tags': ['ngo-quyen', 'thuy-chien', 'bac-thuoc'],
        };

    test('parse đầy đủ field chuẩn contract §1', () {
      final dto = HistoricalEventSummaryDto.fromJson(validJson());
      expect(dto.id, '00000000-0000-0000-0000-000000000001');
      expect(dto.slug, 'bach-dang-938');
      expect(dto.startYear, 938);
      expect(dto.tags, hasLength(3));
      expect(dto.coverAssetKey, 'events/bach-dang-938/hero.jpg');
    });

    test('coverAssetKey/tags nullable vẫn parse', () {
      final json = validJson()
        ..remove('coverAssetKey')
        ..remove('tags');
      final dto = HistoricalEventSummaryDto.fromJson(json);
      expect(dto.coverAssetKey, isNull);
      expect(dto.tags, isEmpty);
    });

    test('thiếu field bắt buộc → ném TypeError, không nuốt im lặng', () {
      final json = validJson()..remove('title');
      expect(
        () => HistoricalEventSummaryDto.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('HistoricalEventDetailDto', () {
    test('parse description/location/publishedAt nullable', () {
      final dto = HistoricalEventDetailDto.fromJson({
        'id': 'u1',
        'slug': 's1',
        'title': 't',
        'era': 'e',
        'period': 'p',
        'startYear': 938,
        'summary': 'sum',
        'description': 'mô tả dài',
        'location': 'Cửa sông Bạch Đằng',
        'publishedAt': null,
      });
      expect(dto.description, 'mô tả dài');
      expect(dto.location, 'Cửa sông Bạch Đằng');
      expect(dto.publishedAt, isNull);
    });
  });

  group('EventsPageDto', () {
    test('parse envelope phân trang + content', () {
      final page = EventsPageDto.fromJson({
        'content': [
          {
            'id': 'a',
            'slug': 's',
            'title': 't',
            'era': 'e',
            'period': 'p',
            'startYear': 100,
            'summary': 'x',
          }
        ],
        'page': 0,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
      });
      expect(page.content, hasLength(1));
      expect(page.totalElements, 1);
      expect(page.page, 0);
    });

    test('content rỗng → danh sách rỗng, không crash', () {
      final page = EventsPageDto.fromJson({
        'content': <Map<String, dynamic>>[],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      });
      expect(page.content, isEmpty);
      expect(page.totalElements, 0);
    });
  });
}
