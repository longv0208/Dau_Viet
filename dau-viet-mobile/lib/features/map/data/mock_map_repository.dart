import 'map_location_dto.dart';
import 'map_repository.dart';

/// Demo data cho USE_MOCK=true — 11 địa điểm lịch sử trải dài qua 5 giai đoạn
/// hào hùng của dân tộc Việt Nam với đầy đủ trạng thái (available, locked, unlocked)
/// để showcase bản đồ hành trình chuẩn UI/UX Pro Max. Tọa độ thực tế chính xác.
class MockMapRepository implements MapRepository {
  static const List<MapLocationDto> _demo = [
    // 1. Thời Đại Hùng Vương - Dựng Nước Văn Lang
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000001',
      eventId: '00000000-0000-0000-0000-000000000005',
      eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
      title: 'Khu di tích Đền Hùng',
      description:
          'Núi Nghĩa Lĩnh, Phong Châu — nơi hội tụ linh khí non sông, nơi phụng thờ 18 đời Hùng Vương mở cõi dựng nước.',
      latitude: 21.3653,
      longitude: 105.3262,
      unlockState: MapUnlockState.unlocked,
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000002',
      eventId: '00000000-0000-0000-0000-000000000005',
      eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
      title: 'Làng Cổ Văn Lang & Ngã Ba Hạc',
      description:
          'Nơi hợp lưu của sông Hồng, sông Lô và sông Đà — cái nôi của nền văn minh lúa nước và văn hóa Đông Sơn rực rỡ.',
      latitude: 21.3121,
      longitude: 105.4215,
      unlockState: MapUnlockState.available,
    ),

    // 2. Đại Chiến Bạch Đằng 938
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000003',
      eventId: '00000000-0000-0000-0000-000000000001',
      eventTitle: 'Đại Chiến Bạch Đằng 938',
      title: 'Bến Bạch Đằng - Trận Địa Cọc',
      description:
          'Cửa sông Bạch Đằng lịch sử — nơi Ngô Quyền cắm cọc vạt nhọn bọc sắt tiêu diệt hạm đội thuyền giặc Nam Hán năm 938.',
      latitude: 20.8492,
      longitude: 106.6891,
      unlockState: MapUnlockState.unlocked,
      requiredLesson: RequiredLessonRef(
        lessonId: 'lesson-bach-dang-01',
        title: 'Trận Bạch Đằng 938',
      ),
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000004',
      eventId: '00000000-0000-0000-0000-000000000001',
      eventTitle: 'Đại Chiến Bạch Đằng 938',
      title: 'Bãi Cọc Yên Giang (Quảng Yên)',
      description:
          'Chứng tích những thân gỗ lim cắm sâu lòng sông ngầm, biểu tượng mưu trí và sức mạnh quật cường của quân dân Việt.',
      latitude: 20.9324,
      longitude: 106.8123,
      unlockState: MapUnlockState.available,
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000005',
      eventId: '00000000-0000-0000-0000-000000000001',
      eventTitle: 'Đại Chiến Bạch Đằng 938',
      title: 'Cửa Sông Nam Triệu',
      description:
          'Cửa ngõ huyết mạch dẫn từ biển vào Bạch Đằng giang, nơi giặc lọt vào thế trận mai phục khi thủy triều rút kiệt.',
      latitude: 20.7801,
      longitude: 106.7902,
      unlockState: MapUnlockState.available,
    ),

    // 3. Khởi Nghĩa Hai Bà Trưng (Năm 40)
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000006',
      eventId: '00000000-0000-0000-0000-000000000002',
      eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
      title: 'Cửa Sông Hát (Hát Môn)',
      description:
          'Nơi Hai Bà Trưng tế cờ khởi nghĩa mùa xuân năm 40, truyền vang lời thề cứu nước cứu dân đuổi quân đô hộ Đông Hán.',
      latitude: 21.1452,
      longitude: 105.5801,
      unlockState: MapUnlockState.locked,
      requiredLesson: RequiredLessonRef(
        lessonId: '10000000-0000-0000-0000-000000000002',
        title: 'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
      ),
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000007',
      eventId: '00000000-0000-0000-0000-000000000002',
      eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
      title: 'Thành Cổ Mê Linh',
      description:
          'Trung tâm chỉ huy nghĩa quân và kinh đô sau khi Trưng Nữ Vương xưng vương, giành lại 65 thành trì Lĩnh Ngoại.',
      latitude: 21.1804,
      longitude: 105.7103,
      unlockState: MapUnlockState.available,
    ),

    // 4. Chiến Thắng Như Nguyệt 1077
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000008',
      eventId: '00000000-0000-0000-0000-000000000003',
      eventTitle: 'Chiến Thắng Như Nguyệt 1077',
      title: 'Phòng Tuyến Sông Cầu',
      description:
          'Phòng tuyến hiểm trở dài hàng trăm dặm do Lý Thường Kiệt đắp luỹ cắm chông chặn đứng 30 vạn quân Tống xâm lược.',
      latitude: 21.2175,
      longitude: 106.0024,
      unlockState: MapUnlockState.locked,
      requiredLesson: RequiredLessonRef(
        lessonId: '10000000-0000-0000-0000-000000000003',
        title: 'Chiến Tuyến Sông Cầu: Bẻ Gãy Mưu Đồ Xâm Lược Nhà Tống',
      ),
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000009',
      eventId: '00000000-0000-0000-0000-000000000003',
      eventTitle: 'Chiến Thắng Như Nguyệt 1077',
      title: 'Đền Xà - Bài Thơ Thần',
      description:
          'Bản tuyên ngôn độc lập đầu tiên Nam Quốc Sơn Hà ngân vang giữa đêm trăng làm rung chuyển ý chí quân xâm lược.',
      latitude: 21.2051,
      longitude: 106.0182,
      unlockState: MapUnlockState.available,
    ),

    // 5. Chiến Dịch Điện Biên Phủ 1954
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000010',
      eventId: '00000000-0000-0000-0000-000000000004',
      eventTitle: 'Chiến Dịch Điện Biên Phủ 1954',
      title: 'Cứ Điểm Đồi A1 (Eliane 2)',
      description:
          'Trận địa đẫm máu then chốt bảo vệ trung tâm Mường Thanh, ngọn đồi quyết định cục diện chiến trường Điện Biên Phủ.',
      latitude: 21.3854,
      longitude: 103.0185,
      unlockState: MapUnlockState.locked,
      requiredLesson: RequiredLessonRef(
        lessonId: '10000000-0000-0000-0000-000000000004',
        title: 'Quyết Định Lịch Sử: Chuyển Phương Châm Tại Điện Biên Phủ',
      ),
    ),
    MapLocationDto(
      id: 'a0000000-0000-0000-0000-000000000011',
      eventId: '00000000-0000-0000-0000-000000000004',
      eventTitle: 'Chiến Dịch Điện Biên Phủ 1954',
      title: 'Hầm Tướng De Castries',
      description:
          'Nơi cờ quyết chiến quyết thắng tung bay vào chiều ngày 7/5/1954, kết thúc 56 ngày đêm chấn động địa cầu.',
      latitude: 21.3882,
      longitude: 103.0151,
      unlockState: MapUnlockState.available,
    ),
  ];

  @override
  Future<List<MapLocationDto>> listLocations() async {
    // Giả lập độ trễ mạng nhẹ cho demo.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.of(_demo);
  }
}
