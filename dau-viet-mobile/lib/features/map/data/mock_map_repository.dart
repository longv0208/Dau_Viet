import 'map_location_dto.dart';
import 'map_repository.dart';

/// Demo data cho USE_MOCK=true — cố định 3 địa điểm Bạch Đằng với đủ 3
/// trạng thái để showcase UI. Tọa độ thật (không bịa vị trí).
class MockMapRepository implements MapRepository {
  static const List<MapLocationDto> _demo = [
    MapLocationDto(
      id: 'demo-loc-bach-dang',
      eventId: 'evt_bach_dang_938',
      title: 'Bến Bạch Đằng',
      description:
          'Cửa sông Bạch Đằng — nơi Ngô Quyền bố trí bãi cọc ngầm đánh tan '
          'thủy quân Nam Hán năm 938.',
      latitude: 20.9101,
      longitude: 106.8231,
      unlockState: MapUnlockState.unlocked,
      requiredLesson: RequiredLessonRef(
        lessonId: 'demo-lesson-bach-dang',
        title: 'Trận Bạch Đằng 938',
      ),
    ),
    MapLocationDto(
      id: 'demo-loc-hoa-lu',
      eventId: 'evt_bach_dang_938',
      title: 'Cửa Lạch Trường',
      description: 'Cửa sông phụ nơi thuyền giặc mắc cọc khi triều rút.',
      latitude: 20.9521,
      longitude: 106.7912,
      unlockState: MapUnlockState.locked,
      requiredLesson: RequiredLessonRef(
        lessonId: 'demo-lesson-hoa-lu',
        title: 'Hoa Lư — Kinh đô đầu tiên',
      ),
    ),
    MapLocationDto(
      id: 'demo-loc-co-loa',
      eventId: 'evt_bach_dang_938',
      title: 'Đồng bằng Bắc Bộ',
      description: 'Vùng đồng bằng mở ra sau chiến thắng — đất nước độc lập.',
      latitude: 21.0285,
      longitude: 105.8542,
      unlockState: MapUnlockState.available,
    ),
  ];

  @override
  Future<List<MapLocationDto>> listLocations() async {
    // Giả lập độ trễ mạng nhẹ cho demo.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.of(_demo);
  }
}
