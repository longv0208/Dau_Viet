import 'package:shared_preferences/shared_preferences.dart';

/// Cờ "đã xem onboarding" (P1-02) — lưu bền trên thiết bị, một lần duy
/// nhất sau lần mở app đầu tiên (hoặc khi người dùng bấm Bỏ qua).
/// Splash đọc trước khi điều hướng; sau khi xem → không hiển thị lại.
abstract final class OnboardingFlag {
  static const String _key = 'onboarding_seen_v1';

  static Future<bool> isSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Lỗi storage không chặn luồng — lần sau sẽ hiện lại onboarding.
    }
  }
}
