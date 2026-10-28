import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'map_location_dto.dart';
import 'map_repository.dart';

/// Demo data cho `USE_MOCK=true` — tuân thủ hợp đồng Bản đồ Di sản v2
/// (`GET /api/v1/map/locations` & `GET /api/v1/map/locations/{id}`).
/// Không hardcode UUID sản phẩm; đầy đủ trạng thái (`unlocked`, `available`,
/// `locked`), `visibility` (`PUBLIC`, `ALWAYS_VISIBLE`, `HIDDEN_UNTIL_UNLOCKED`),
/// và học liệu đa phương tiện (`IMAGE_2D`, `PANORAMA_360`, `DOCUMENTARY_CLIP`, `AUDIO_GUIDE`).
class MockMapRepository implements MapRepository {
  static const List<MapLocationDto> _demo = [
    // 1. Thời Đại Hùng Vương - Dựng Nước Văn Lang
    MapLocationDto(
      id: 'loc_den_hung',
      eventId: 'evt_van_lang',
      eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
      title: 'Khu di tích Đền Hùng',
      shortSummary:
          'Núi Nghĩa Lĩnh, Phong Châu — kinh đô nước Văn Lang thời 18 đời Hùng Vương.',
      description:
          'Núi Nghĩa Lĩnh, Phong Châu — nơi hội tụ linh khí non sông, nơi phụng thờ 18 đời Hùng Vương mở cõi dựng nước.',
      latitude: 21.3653,
      longitude: 105.3262,
      kind: 'ANCIENT_CAPITAL',
      coordinatePrecision: 'EXACT',
      visibility: 'PUBLIC',
      unlockMode: 'NONE',
      unlocked: true,
      unlockState: MapUnlockState.unlocked,
      eventIds: ['evt_van_lang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_van_lang',
          title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
          yearLabel: 'Khoảng thế kỷ VII TCN',
          role: 'PRIMARY',
          sortOrder: 0,
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_den_hung_img',
          mediaType: 'IMAGE_2D',
          title: 'Toàn cảnh Khu di tích Đền Hùng — Núi Nghĩa Lĩnh',
          caption:
              'Đền Hùng trên núi Nghĩa Lĩnh, Phong Châu — trung tâm nước Văn Lang.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_den_hung_clip',
          mediaType: 'DOCUMENTARY_CLIP',
          title: 'Phim tư liệu: Văn minh sông Hồng và trống đồng Đông Sơn',
          caption: 'Tái hiện đời sống cư dân Lạc Việt buổi bình minh lịch sử.',
          externalUrl: 'https://example.com/van-lang-doc.mp4',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
      ],
    ),
    MapLocationDto(
      id: 'loc_nga_ba_hac',
      eventId: 'evt_van_lang',
      eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
      title: 'Làng Cổ Văn Lang & Ngã Ba Hạc',
      shortSummary:
          'Nơi hợp lưu sông Hồng, sông Lô và sông Đà — cái nôi văn minh lúa nước.',
      description:
          'Nơi hợp lưu của sông Hồng, sông Lô và sông Đà — cái nôi của nền văn minh lúa nước và văn hóa Đông Sơn rực rỡ.',
      latitude: 21.3121,
      longitude: 105.4215,
      kind: 'ARCHAEOLOGICAL_SITE',
      coordinatePrecision: 'APPROXIMATE',
      visibility: 'ALWAYS_VISIBLE',
      unlockMode: 'NONE',
      unlocked: true,
      unlockState: MapUnlockState.available,
      eventIds: ['evt_van_lang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_van_lang',
          title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
          yearLabel: 'Khoảng thế kỷ VII TCN',
          role: 'PRIMARY',
          sortOrder: 0,
        ),
      ],
    ),

    // 2. Khởi Nghĩa Hai Bà Trưng (Năm 40)
    MapLocationDto(
      id: 'loc_hat_mon',
      eventId: 'evt_hai_ba_trung',
      eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
      title: 'Cửa Sông Hát (Hát Môn)',
      shortSummary:
          'Đền Hát Môn bên cửa sông Hát — nơi Hai Bà Trưng lập đàn tế cờ mùa xuân năm 40.',
      description:
          'Nơi Hai Bà Trưng tế cờ khởi nghĩa mùa xuân năm 40, truyền vang lời thề cứu nước cứu dân đuổi quân đô hộ Đông Hán.',
      latitude: 21.1452,
      longitude: 105.5801,
      kind: 'MEMORIAL',
      coordinatePrecision: 'EXACT',
      visibility: 'PUBLIC',
      unlockMode: 'ANY',
      unlocked: false,
      unlockState: MapUnlockState.locked,
      requiredLesson: RequiredLessonRef(
        lessonId: 'lesson_me_linh_01',
        title: 'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
      ),
      eventIds: ['evt_hai_ba_trung'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_hai_ba_trung',
          title: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
          yearLabel: 'Năm 40',
          role: 'PRIMARY',
          sortOrder: 0,
        ),
      ],
      unlockLessons: [
        MapLocationUnlockLessonDto(
          lessonId: 'lesson_me_linh_01',
          title: 'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
          completed: false,
          accessible: true,
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_hat_mon_preview',
          mediaType: 'IMAGE_2D',
          title: 'Hội thề Hát Môn — Khởi nghĩa Hai Bà Trưng năm 40',
          caption: 'Đoàn voi chiến và cờ đại nghĩa bên dòng sông Hát.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_hat_mon_secret',
          mediaType: 'PANORAMA_360',
          title: 'Không gian 360° Đền Hát Môn',
          caption: 'Chỉ hiển thị sau khi mở khoá địa điểm.',
          externalUrl: '/heritage/hat-mon-360.jpg',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 1,
        ),
      ],
    ),
    MapLocationDto(
      id: 'loc_me_linh',
      eventId: 'evt_hai_ba_trung',
      eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
      title: 'Thành Cổ Mê Linh',
      shortSummary:
          'Kinh đô Mê Linh của Trưng Nữ Vương sau khi thu phục 65 thành trì Lĩnh Ngoại.',
      description:
          'Trung tâm chỉ huy nghĩa quân và kinh đô sau khi Trưng Nữ Vương xưng vương, giành lại 65 thành trì Lĩnh Ngoại.',
      latitude: 21.1804,
      longitude: 105.7103,
      kind: 'ANCIENT_CAPITAL',
      coordinatePrecision: 'EXACT',
      visibility: 'ALWAYS_VISIBLE',
      unlockMode: 'NONE',
      unlocked: true,
      unlockState: MapUnlockState.available,
      eventIds: ['evt_hai_ba_trung'],
    ),

    // 3. Đại Chiến Bạch Đằng 938
    MapLocationDto(
      id: 'loc_ben_bach_dang',
      eventId: 'evt_bach_dang',
      eventTitle: 'Đại Chiến Bạch Đằng 938',
      title: 'Bến Bạch Đằng - Trận Địa Cọc',
      shortSummary:
          'Cửa sông Bạch Đằng lịch sử — trận địa cọc gỗ bịt sắt của Ngô Quyền năm 938.',
      description:
          'Cửa sông Bạch Đằng lịch sử — nơi Ngô Quyền cắm cọc vạt nhọn bọc sắt tiêu diệt hạm đội thuyền giặc Nam Hán năm 938.',
      latitude: 20.8492,
      longitude: 106.6891,
      kind: 'BATTLEFIELD',
      coordinatePrecision: 'EXACT',
      visibility: 'PUBLIC',
      unlockMode: 'ANY',
      unlocked: true,
      unlockState: MapUnlockState.unlocked,
      requiredLesson: RequiredLessonRef(
        lessonId: 'lesson_bach_dang_01',
        title: 'Trận Bạch Đằng 938',
      ),
      eventIds: ['evt_bach_dang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_bach_dang',
          title: 'Đại Chiến Bạch Đằng 938',
          yearLabel: 'Năm 938',
          role: 'PRIMARY',
          sortOrder: 0,
        ),
      ],
      unlockLessons: [
        MapLocationUnlockLessonDto(
          lessonId: 'lesson_bach_dang_01',
          title: 'Trận Bạch Đằng 938',
          completed: true,
          accessible: true,
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_bach_dang_img',
          mediaType: 'IMAGE_2D',
          title: 'Trận địa cọc Bạch Đằng Giang năm 938',
          caption:
              'Hàng cọc gỗ lim bịt sắt nhô lên giữa sóng nước cửa sông Bạch Đằng khi thủy triều rút.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_bach_dang_audio',
          mediaType: 'AUDIO_GUIDE',
          title: 'Thuyết minh chiến thuật cọc ngầm trên sông Bạch Đằng',
          caption: 'Phân tích cách Ngô Quyền lợi dụng chế độ bán nhật triều.',
          externalUrl: '/heritage/bach-dang-audio.mp3',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 1,
        ),
      ],
    ),
    MapLocationDto(
      id: 'loc_bai_coc_yen_giang',
      eventId: 'evt_bach_dang',
      eventTitle: 'Đại Chiến Bạch Đằng 938',
      title: 'Bãi Cọc Yên Giang (Quảng Yên)',
      shortSummary:
          'Chứng tích hàng trăm cọc gỗ lim cắm ngầm dưới lòng sông Bạch Đằng.',
      description:
          'Chứng tích những thân gỗ lim cắm sâu lòng sông ngầm, biểu tượng mưu trí và sức mạnh quật cường của quân dân Việt.',
      latitude: 20.9324,
      longitude: 106.8123,
      kind: 'ARCHAEOLOGICAL_SITE',
      coordinatePrecision: 'EXACT',
      visibility: 'ALWAYS_VISIBLE',
      unlockMode: 'NONE',
      unlocked: true,
      unlockState: MapUnlockState.available,
      eventIds: ['evt_bach_dang'],
    ),
  ];

  @override
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _demo.where((loc) {
      if (!loc.shouldDisplayOnMap) return false;
      if (eventId != null &&
          eventId.trim().isNotEmpty &&
          loc.eventId != eventId.trim() &&
          !loc.eventIds.contains(eventId.trim())) {
        return false;
      }
      if (kind != null &&
          kind.trim().isNotEmpty &&
          loc.kind.toUpperCase() != kind.trim().toUpperCase()) {
        return false;
      }
      if (unlocked != null && loc.unlocked != unlocked) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<MapLocationDto> getLocationDetail(String locationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final found = _demo.where((l) => l.id == locationId).firstOrNull;
    if (found == null) {
      throw const ApiException(
        ApiError(
          code: 'NOT_FOUND',
          message: 'Không tìm thấy hồ sơ địa điểm di sản.',
        ),
      );
    }
    return MapLocationDto(
      id: found.id,
      eventId: found.eventId,
      eventTitle: found.eventTitle,
      slug: found.slug,
      title: found.title,
      shortSummary: found.shortSummary,
      description: found.description,
      latitude: found.latitude,
      longitude: found.longitude,
      kind: found.kind,
      coordinatePrecision: found.coordinatePrecision,
      visibility: found.visibility,
      unlockMode: found.unlockMode,
      unlocked: found.unlocked,
      unlockState: found.unlockState,
      coverAssetId: found.coverAssetId,
      requiredLesson: found.requiredLesson,
      eventIds: found.eventIds,
      events: found.events,
      unlockLessons: found.unlockLessons,
      media: found.visibleMedia,
    );
  }
}
