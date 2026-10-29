import 'streak_dto.dart';

/// Hợp đồng nguồn dữ liệu Chuỗi Ngày Học — presentation chỉ phụ thuộc
/// interface; provider chọn Api (real) hay Mock (demo) theo USE_MOCK.
/// Read-only: không có phương thức cộng/trừ chuỗi.
abstract class StreakRepository {
  /// GET /api/v1/me/streak — trạng thái Chuỗi authoritative của learner.
  Future<LearningStreakDto> getMyStreak();

  /// GET /api/v1/me/streak/calendar — các ngày đã học trong [from, to].
  Future<LearningStreakCalendarDto> getCalendar(DateTime from, DateTime to);

  /// POST /api/v1/me/streak/shields — đổi 20 Điểm Sử Ký lấy 1 Khiên
  /// (STREAK-02). [idempotencyKey] bắt buộc, một key = một giao dịch.
  Future<StreakShieldPurchaseDto> buyShield({
    required String idempotencyKey,
  });
}
