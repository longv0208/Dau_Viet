/// Phân giải tranh minh họa lịch sử cục bộ (bundled asset) theo tiêu đề / ngữ cảnh
/// của bài học hoặc hoạt động đọc khi chưa có `coverAssetId` từ máy chủ hoặc đang tải.
String resolveLessonFallbackAsset(String title, [String? secondaryText]) {
  final combined =
      '${title.toLowerCase()} ${(secondaryText ?? '').toLowerCase()}';

  if (combined.contains('mê linh') ||
      combined.contains('hai bà trưng') ||
      combined.contains('trưng nữ') ||
      combined.contains('trưng trắc') ||
      combined.contains('hát môn') ||
      combined.contains('tô định') ||
      combined.contains('bà triệu') ||
      combined.contains('năm 248')) {
    return 'assets/images/heritage/me-linh-hai-ba-trung.jpg';
  }

  if (combined.contains('đông sơn') ||
      combined.contains('trống đồng') ||
      combined.contains('ngọc lũ') ||
      combined.contains('công cụ bằng đồng') ||
      combined.contains('khảo cổ')) {
    return 'assets/images/lesson_scene_hung_kings_life.jpg';
  }

  if (combined.contains('hùng vương') ||
      combined.contains('văn lang') ||
      combined.contains('phong châu') ||
      combined.contains('nghĩa lĩnh') ||
      combined.contains('lạc long quân') ||
      combined.contains('âu cơ')) {
    return 'assets/images/heritage/den-hung-phong-chau.jpg';
  }

  if (combined.contains('cọc gỗ') ||
      combined.contains('bãi cọc') ||
      combined.contains('cắm cọc')) {
    return 'assets/images/bg_story_tran_dia.jpg';
  }

  if (combined.contains('bạch đằng') ||
      combined.contains('ngô quyền') ||
      combined.contains('nam hán') ||
      combined.contains('938') ||
      combined.contains('1288') ||
      combined.contains('trần hưng đạo')) {
    return 'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg';
  }

  if (combined.contains('sông cầu') ||
      combined.contains('như nguyệt') ||
      combined.contains('1077') ||
      combined.contains('nhà tống') ||
      combined.contains('lý thường kiệt') ||
      combined.contains('nam quốc sơn hà')) {
    return 'assets/images/heritage/phong-tuyen-nhu-nguyet.jpg';
  }

  if (combined.contains('điện biên phủ') ||
      combined.contains('1954') ||
      combined.contains('đồi a1') ||
      combined.contains('mường thanh') ||
      combined.contains('phương châm') ||
      combined.contains('võ nguyên giáp')) {
    return 'assets/images/heritage/doi-a1-dien-bien-phu.jpg';
  }

  if (combined.contains('dời đô') ||
      combined.contains('thăng long') ||
      combined.contains('đại la') ||
      combined.contains('1010') ||
      combined.contains('lý thái tổ') ||
      combined.contains('đô thành') ||
      combined.contains('kinh đô') ||
      combined.contains('thành nhà hồ') ||
      combined.contains('huế')) {
    return 'assets/images/heritage/hoang-thanh-thang-long.jpg';
  }

  if (combined.contains('vạn xuân') ||
      combined.contains('lý bí') ||
      combined.contains('thế kỷ vi') ||
      combined.contains('quân cơ') ||
      combined.contains('so sánh hai cuộc khởi nghĩa')) {
    return 'assets/images/bg_story_doanh_trai.jpg';
  }

  if (combined.contains('mỹ sơn') ||
      combined.contains('champa') ||
      combined.contains('hội an') ||
      combined.contains('thương cảng') ||
      combined.contains('thương mại') ||
      combined.contains('nghi lễ')) {
    return 'assets/images/bg_story_thu_phong.jpg';
  }

  return 'assets/images/heritage/den-hung-phong-chau.jpg';
}
