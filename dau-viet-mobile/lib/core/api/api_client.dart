import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_error.dart';
import 'api_exception.dart';

/// HTTP client chung cho toàn app — bọc Dio với timeout rõ ràng,
/// map envelope lỗi `{code,message,details,traceId}` sang [ApiException].
/// Không retry ngầm: mỗi request là một lần gọi duy nhất, UI tự quyết
/// định có cho người dùng bấm "Thử lại" hay không (AC-1).
///
/// Bearer token: gán qua [authTokenProvider] — client đọc token ngay trước
/// mỗi request nên refresh token xong là request sau tự động dùng token mới.
/// Không nhúng logic refresh vào đây (AuthRepository lo) để tránh vòng phụ
/// thuộc; chỉ cần provider trả access token hiện tại hoặc null.
class ApiClient {
  final Dio _dio;

  /// Đọc access token hiện tại (nullable). AuthRepository gán sau khi init.
  static String? Function()? authTokenProvider;

  ApiClient(this._dio);

  factory ApiClient.fromConfig({String? baseUrl}) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    return ApiClient(dio);
  }

  Options _authOptions(Map<String, String>? headers) {
    final Map<String, String> merged = {};
    final String? token = authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      merged['Authorization'] = 'Bearer $token';
    }
    if (headers != null) merged.addAll(headers);
    return Options(headers: merged.isEmpty ? null : merged);
  }

  /// GET `path` với query params; ném [ApiException] cho mọi lỗi mạng/HTTP.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: _authOptions(headers),
      );
      return _requireMap(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// GET `path` khi backend trả top-level JSON array (vd /events/{id}/lessons).
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: _authOptions(headers),
      );
      final Object? data = response.data;
      if (data is List) return data;
      if (data == null) return const [];
      throw const ApiException(
        ApiError(
          code: 'INVALID_RESPONSE',
          message: 'Server trả về dữ liệu sai định dạng.',
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// POST `path` với JSON body; `headers` cho phép truyền Idempotency-Key v.v.
  /// Response có thể rỗng (204) — trả `{}`.
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: _authOptions(headers),
      );
      final Object? data = response.data;
      if (data == null || (data is String && data.isEmpty)) {
        return const {};
      }
      return _requireMap(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// PUT `path` với JSON body; `headers` cho phép truyền Idempotency-Key v.v.
  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.put<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: _authOptions(headers),
      );
      final Object? data = response.data;
      if (data == null || (data is String && data.isEmpty)) {
        return const {};
      }
      return _requireMap(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// DELETE `path`; `headers` cho phép truyền Idempotency-Key v.v.
  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: _authOptions(headers),
      );
      final Object? data = response.data;
      if (data == null || (data is String && data.isEmpty)) {
        return const {};
      }
      return _requireMap(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// GET bytes thô — dùng cho learner asset endpoint (image bytes, có auth).
  Future<List<int>> getBytes(String path) async {
    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        path,
        options: _authOptions(null).copyWith(responseType: ResponseType.bytes),
      );
      return response.data ?? const <int>[];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Map<String, dynamic> _requireMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    throw const ApiException(
      ApiError(
        code: 'INVALID_RESPONSE',
        message: 'Server trả về dữ liệu sai định dạng.',
      ),
    );
  }

  ApiException _mapDioException(DioException e) {
    final Response<dynamic>? response = e.response;
    if (response != null) {
      return ApiException(
        _parseErrorBody(response.data),
        statusCode: response.statusCode,
      );
    }
    // Không có response: timeout hoặc lỗi kết nối.
    final bool isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
    return ApiException(
      ApiError(
        code: isTimeout ? 'TIMEOUT' : 'NETWORK_ERROR',
        message: isTimeout
            ? 'Kết nối máy chủ quá chậm, vui lòng thử lại.'
            : 'Không kết nối được máy chủ Dấu Việt.',
      ),
    );
  }

  ApiError _parseErrorBody(Object? data) {
    if (data is Map) {
      try {
        return ApiError.fromJson(data.cast<String, dynamic>());
      } on FormatException {
        // Rơi xuống envelope tổng quát phía dưới.
      }
    }
    return const ApiError(
      code: 'UNKNOWN_ERROR',
      message: 'Đã có lỗi xảy ra, vui lòng thử lại sau.',
    );
  }
}
