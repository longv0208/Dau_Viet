import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_error.dart';
import 'api_exception.dart';

/// HTTP client chung cho toàn app — bọc Dio với timeout rõ ràng,
/// map envelope lỗi `{code,message,details,traceId}` sang [ApiException].
/// Không retry ngầm: mỗi request là một lần gọi duy nhất, UI tự quyết
/// định có cho người dùng bấm "Thử lại" hay không (AC-1).
class ApiClient {
  final Dio _dio;

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

  /// GET `path` với query params; ném [ApiException] cho mọi lỗi mạng/HTTP.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>(path, queryParameters: query);
      return _requireMap(response.data);
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
    final bool isTimeout = e.type == DioExceptionType.connectionTimeout ||
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
