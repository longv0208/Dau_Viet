import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiError.fromJson', () {
    test('parse envelope chuẩn {code,message,details,traceId}', () {
      final err = ApiError.fromJson({
        'code': 'EVENT_NOT_FOUND',
        'message': 'Không tìm thấy sự kiện.',
        'details': 'id=abc',
        'traceId': 't-123',
      });
      expect(err.code, 'EVENT_NOT_FOUND');
      expect(err.details, 'id=abc');
      expect(err.traceId, 't-123');
    });

    test('thiếu details/traceId vẫn parse (nullable)', () {
      final err = ApiError.fromJson({'code': 'X', 'message': 'm'});
      expect(err.details, isNull);
      expect(err.traceId, isNull);
    });

    test('envelope thiếu code/message → FormatException', () {
      expect(
        () => ApiError.fromJson({'foo': 'bar'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ApiException predicates', () {
    ApiException ex(String code, int? status) =>
        ApiException(ApiError(code: code, message: 'm'), statusCode: status);

    test('isNotFound / isUnauthorized / isBadRequest', () {
      expect(ex('EVENT_NOT_FOUND', 404).isNotFound, isTrue);
      expect(ex('UNAUTHORIZED', 401).isUnauthorized, isTrue);
      expect(ex('MALFORMED_ID', 400).isBadRequest, isTrue);
      expect(ex('X', 500).isNotFound, isFalse);
    });

    test('isNetworkError khi không có HTTP status', () {
      expect(ex('NETWORK_ERROR', null).isNetworkError, isTrue);
      expect(ex('TIMEOUT', null).isNetworkError, isTrue);
    });
  });
}
