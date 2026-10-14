import 'api_error.dart';

/// Ngoại lệ chuẩn của tầng API: bọc [ApiError] + HTTP status để UI
/// ra quyết định copy sư phạm phù hợp từng loại lỗi.
class ApiException implements Exception {
  final ApiError error;
  final int? statusCode;

  const ApiException(this.error, {this.statusCode});

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isBadRequest => statusCode == 400;

  /// Lỗi không có HTTP response (timeout, mất mạng, DNS...).
  bool get isNetworkError => statusCode == null;

  @override
  String toString() =>
      'ApiException(status: $statusCode, error: ${error.code} - ${error.message})';
}
