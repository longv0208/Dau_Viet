import '../../../core/api/api_client.dart';
import 'streak_dto.dart';

/// Client mỏng cho `GET /api/v1/me/streak`, `GET /me/streak/calendar` và
/// `POST /me/streak/shields` (STREAK-01 + STREAK-02). Ghi streak chỉ xảy
/// ra server-side khi learner hoàn thành bài — endpoint duy nhất client
/// ghi trực tiếp là đổi Khiên Bảo Vệ (Idempotency-Key bắt buộc).
class StreakApiClient {
  final ApiClient _client;

  const StreakApiClient(this._client);

  Future<LearningStreakDto> getMyStreak() async {
    final json = await _client.get('/api/v1/me/streak');
    return LearningStreakDto.fromJson(json);
  }

  /// Lịch sử ngày đã học trong [from, to] (ISO yyyy-MM-dd) — backend giới
  /// hạn tối đa 92 ngày span.
  Future<LearningStreakCalendarDto> getCalendar(
    DateTime from,
    DateTime to,
  ) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final json = await _client.get(
      '/api/v1/me/streak/calendar?from=${fmt(from)}&to=${fmt(to)}',
    );
    return LearningStreakCalendarDto.fromJson(json);
  }

  /// Đổi 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ — tối đa 3/3 (V51).
  /// [idempotencyKey] bắt buộc: một key = một giao dịch duy nhất dù retry.
  /// ApiException 422 SHIELD_AT_MAX_CAPACITY / 409 INSUFFICIENT_FUNDS
  /// ném thẳng lên UI.
  Future<StreakShieldPurchaseDto> buyShield({
    required String idempotencyKey,
  }) async {
    final json = await _client.post(
      '/api/v1/me/streak/shields',
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return StreakShieldPurchaseDto.fromJson(json);
  }
}
