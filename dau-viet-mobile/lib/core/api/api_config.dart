import 'dart:io' show Platform;

/// Cấu hình kết nối Backend Dấu Việt đọc từ `--dart-define`.
///
/// Ví dụ:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// flutter run --dart-define=USE_MOCK=true
/// ```
class ApiConfig {
  ApiConfig._();

  /// Base URL của backend. Mặc định:
  /// - Android emulator: `http://10.0.2.2:8080` (alias của localhost máy host)
  /// - iOS sim / desktop / web: `http://localhost:8080`
  static String get baseUrl {
    const String defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) {
      return defined;
    }
    return _defaultBaseUrl();
  }

  /// Chế độ mock chạy offline/demo. Phải bật tường minh — KHÔNG BAO GIỜ
  /// tự động bật khi API lỗi (AC-5).
  static bool get useMock =>
      const bool.fromEnvironment('USE_MOCK', defaultValue: false);

  static String _defaultBaseUrl() {
    // `Platform` không tồn tại trên web — bọc try/catch giữ mặc định an toàn.
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
    } catch (_) {
      // Web / môi trường không có dart:io — rơi về localhost.
    }
    return 'http://localhost:8080';
  }
}
