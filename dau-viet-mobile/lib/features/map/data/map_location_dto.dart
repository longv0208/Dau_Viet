/// DTO khớp contract `GET /api/v1/map/locations[/{id}]` (TASK-0021).
/// `unlockState` do server tính theo learner trong JWT — client KHÔNG gửi
/// userId hay cờ completed (server-authoritative).
enum MapUnlockState {
  available,
  locked,
  unlocked;

  static MapUnlockState parse(String raw) {
    switch (raw) {
      case 'AVAILABLE':
        return MapUnlockState.available;
      case 'UNLOCKED':
        return MapUnlockState.unlocked;
      case 'LOCKED':
      default:
        return MapUnlockState.locked;
    }
  }
}

/// Tham chiếu bài học cần hoàn thành để mở khoá địa điểm.
/// `accessible=false` = bài học liên kết không còn mở được cho learner
/// (draft/archived sau khi địa điểm publish) → UI ẩn CTA bài học; trạng
/// thái UNLOCKED đã đạt được KHÔNG bị thu hồi.
class RequiredLessonRef {
  final String lessonId;
  final String title;
  final bool accessible;

  const RequiredLessonRef({
    required this.lessonId,
    required this.title,
    this.accessible = true,
  });

  factory RequiredLessonRef.fromJson(Map<String, dynamic> json) {
    return RequiredLessonRef(
      lessonId: json['lessonId'] as String,
      title: json['title'] as String? ?? '',
      accessible: json['accessible'] as bool? ?? true,
    );
  }
}

/// Một địa điểm trên bản đồ lịch sử.
class MapLocationDto {
  final String id;
  final String eventId;
  final String? eventTitle;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final MapUnlockState unlockState;
  final RequiredLessonRef? requiredLesson;

  const MapLocationDto({
    required this.id,
    required this.eventId,
    this.eventTitle,
    required this.title,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.unlockState,
    this.requiredLesson,
  });

  factory MapLocationDto.fromJson(Map<String, dynamic> json) {
    final Object? req = json['requiredLesson'];
    return MapLocationDto(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      unlockState: MapUnlockState.parse(json['unlockState'] as String? ?? ''),
      requiredLesson: req is Map<String, dynamic>
          ? RequiredLessonRef.fromJson(req)
          : null,
    );
  }
}
