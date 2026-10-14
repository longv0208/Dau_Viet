/// Mô hình lỗi chuẩn từ Backend Dấu Việt.
/// Khớp envelope `{code, message, details, traceId}` trong docs/API_SPEC.md.
class ApiError {
  final String code;
  final String message;
  final String? details;
  final String? traceId;

  const ApiError({
    required this.code,
    required this.message,
    this.details,
    this.traceId,
  });

  /// Parse envelope lỗi chuẩn. Ném [FormatException] khi payload sai hình dạng
  /// thay vì nuốt lỗi âm thầm.
  factory ApiError.fromJson(Map<String, dynamic> json) {
    final Object? code = json['code'];
    final Object? message = json['message'];
    if (code is! String || message is! String) {
      throw const FormatException('Invalid ApiError envelope: missing code/message');
    }
    final Object? details = json['details'];
    final Object? traceId = json['traceId'];
    return ApiError(
      code: code,
      message: message,
      details: details is String ? details : null,
      traceId: traceId is String ? traceId : null,
    );
  }

  @override
  String toString() =>
      'ApiError(code: $code, message: $message, traceId: $traceId)';
}
