import 'dart:convert';
import 'dart:typed_data';

import 'package:dau_viet_mobile/core/api/api_client.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter giả: trả status + body điều khiển được, ghi lại request cuối.
class _StubAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? body;
  bool throwNetworkError = false;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (throwNetworkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'socket fail',
      );
    }
    final String text = body is String ? body as String : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _StubAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = _StubAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    client = ApiClient(dio);
    ApiClient.authTokenProvider = null;
  });

  group('error envelope → ApiException', () {
    Future<ApiException> catchErr(Future<dynamic> f) async {
      try {
        await f;
        fail('phải ném ApiException');
      } on ApiException catch (e) {
        return e;
      }
    }

    test('400 + envelope → code/message/status giữ nguyên', () async {
      adapter
        ..statusCode = 400
        ..body = {
          'code': 'VALIDATION_FAILED',
          'message': 'answer sai định dạng',
          'details': {
            'errors': ['selectedOptionIds rỗng'],
          },
          'traceId': 'tr-1',
        };
      final e = await catchErr(client.get('/x'));
      expect(e.statusCode, 400);
      expect(e.isBadRequest, isTrue);
      expect(e.error.code, 'VALIDATION_FAILED');
      expect(e.error.details, isA<Map>());
      expect(e.error.traceId, 'tr-1');
    });

    test('401 → isUnauthorized; 403 → isForbidden; 404 → isNotFound', () async {
      adapter.body = {'code': 'X', 'message': 'm'};
      adapter.statusCode = 401;
      expect((await catchErr(client.get('/x'))).isUnauthorized, isTrue);
      adapter.statusCode = 403;
      expect((await catchErr(client.get('/x'))).isForbidden, isTrue);
      adapter.statusCode = 404;
      expect((await catchErr(client.get('/x'))).isNotFound, isTrue);
    });

    test('409 IDEMPOTENCY_CONFLICT → envelope giữ code', () async {
      adapter
        ..statusCode = 409
        ..body = {
          'code': 'IDEMPOTENCY_CONFLICT',
          'message': 'Key đã dùng với payload khác',
        };
      final e = await catchErr(client.post('/submit', body: {}));
      expect(e.statusCode, 409);
      expect(e.error.code, 'IDEMPOTENCY_CONFLICT');
    });

    test('500 → statusCode giữ, code từ envelope', () async {
      adapter
        ..statusCode = 500
        ..body = {'code': 'INTERNAL_ERROR', 'message': 'boom'};
      final e = await catchErr(client.get('/x'));
      expect(e.statusCode, 500);
      expect(e.error.code, 'INTERNAL_ERROR');
    });

    test('lỗi mạng không response → NETWORK_ERROR, statusCode null', () async {
      adapter.throwNetworkError = true;
      final e = await catchErr(client.get('/x'));
      expect(e.isNetworkError, isTrue);
      expect(e.statusCode, isNull);
      expect(e.error.code, 'NETWORK_ERROR');
    });

    test(
      'body JSON nhưng thiếu code/message → UNKNOWN_ERROR fallback, giữ status',
      () async {
        adapter
          ..statusCode = 502
          ..body = {'error': 'upstream', 'detail': 'không phải envelope chuẩn'};
        // ApiError.fromJson ném FormatException → _parseErrorBody fallback.
        final e = await catchErr(client.get('/x'));
        expect(e.statusCode, 502);
        expect(e.error.code, 'UNKNOWN_ERROR');
      },
    );
  });

  group('request shape', () {
    test('POST gửi body JSON + Bearer header khi có token', () async {
      ApiClient.authTokenProvider = () => 'tok-123';
      adapter.body = {'ok': true};
      await client.post('/submit', body: {'a': 1});
      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok-123');
    });

    test('POST 204 rỗng → trả {} không crash', () async {
      adapter
        ..statusCode = 204
        ..body = null;
      final res = await client.post('/logout', body: {});
      expect(res, isA<Map<String, dynamic>>());
    });

    test('getList parse top-level array', () async {
      adapter.body = [
        {'id': 'l1', 'title': 'Bài 1'},
        {'id': 'l2', 'title': 'Bài 2'},
      ];
      final res = await client.getList('/events/e/lessons');
      expect(res, hasLength(2));
    });
  });
}
