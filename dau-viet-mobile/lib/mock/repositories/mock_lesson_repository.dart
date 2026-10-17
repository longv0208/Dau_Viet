import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_bach_dang_data.dart';
import '../models/lesson_models.dart';

/// Hợp đồng Interface LessonRepository
/// Tuân thủ Dependency Inversion: Presentation chỉ phụ thuộc Interface này
abstract class LessonRepository {
  Future<HistoricalEventModel> getEventById(String eventId);
  Future<LessonModel> getLessonById(String lessonId);
  Future<HeritageArtifactModel> getArtifactById(String artifactId);
  Future<Map<String, dynamic>> submitActivity({
    required String lessonId,
    required String activityId,
    required dynamic answerPayload,
  });
}

/// Triển khai MockLessonRepository phục vụ chế độ Demo
class MockLessonRepository implements LessonRepository {
  @override
  Future<HistoricalEventModel> getEventById(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockBachDangData.event;
  }

  @override
  Future<LessonModel> getLessonById(String lessonId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockBachDangData.lessonEpisode2;
  }

  @override
  Future<HeritageArtifactModel> getArtifactById(String artifactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockBachDangData.artifactThuyenChien;
  }

  @override
  Future<Map<String, dynamic>> submitActivity({
    required String lessonId,
    required String activityId,
    required dynamic answerPayload,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Mô phỏng phản hồi từ Backend server
    return {
      'isCorrect': true,
      'earnedXp': 50,
      'earnedHistoryPoints': 100,
      'feedback':
          'Xuất sắc! Bạn đã tái hiện chuẩn xác mưu lược của Tiền Ngô Vương.',
    };
  }
}

/// Riverpod Provider cho LessonRepository
/// Sau này khi có Backend Spring Boot, chỉ cần đổi sang Provider trả về ApiLessonRepository
final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return MockLessonRepository();
});
