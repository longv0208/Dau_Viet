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
      keyFigures: 'Các đời Hùng Vương; Lạc tướng các bộ Lạc Việt',
      historicalSignificance:
          'Cái nôi dựng nước đầu tiên của dân tộc — nơi hình thành ý thức '
          'cộng đồng "con Rồng cháu Tiên" và nền tảng văn hóa Đông Sơn.',
      storyNarrative:
          'Theo truyền thuyết và các tài liệu cổ, khoảng thế kỷ VII TCN các '
          'bộ lạc Lạc Việt dọc lưu vực sông Hồng đã quy tụ về Phong Châu '
          'lập nên nước Văn Lang — nhà nước đầu tiên trong lịch sử Việt '
          'Nam. Vua Hùng chọn núi Nghĩa Lĩnh làm trung tâm thiêng liêng, '
          'nơi triều đình tổ chức lễ tế non sông cầu mùa màng bội thu.\n\n'
          'Đời đời, nhân dân ghi nhớ công lao dựng nước qua lễ hội Giỗ '
          'Tổ Hùng Vương ngày 10 tháng 3 âm lịch — biểu tượng bất diệt '
          'của tinh thần "uống nước nhớ nguồn".\n\n'
          "Ngày nay, khu di tích Đền Hùng gồm Đền Hạ, Đền Trung, Đền "
          'Thượng, Đền Giếng và lăng Hùng Vương — điểm hành hương lớn '
          'nhất của cộng đồng người Việt trong và ngoài nước.',
      eventIds: ['evt_van_lang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_van_lang',
          title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
          yearLabel: 'Khoảng thế kỷ VII TCN',
          role: 'PRIMARY',
          sortOrder: 0,
          slug: 'thoi-dai-hung-vuong',
          summary: 'Nhà nước Văn Lang đầu tiên của các Vua Hùng.',
          description:
              'Mười tám đời Hùng Vương nối tiếp cai trị nước Văn Lang, '
              'đặt nền móng cho văn minh Việt Nam.',
          periodCode: 'VAN_LANG',
          periodTitle: 'Thời đại Văn Lang',
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
          sourceCitation: 'Ban quản lý Khu di tích lịch sử Đền Hùng',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_den_hung_village',
          mediaType: 'IMAGE_2D',
          title: 'Làng cổ thời Văn Lang — sinh hoạt Lạc Việt',
          caption: 'Tái hiện sinh hoạt làng xóm Lạc Việt dưới chân núi '
              'Nghĩa Lĩnh thời Hùng Vương.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          sourceCitation: 'Tranh minh họa theo Đại Việt sử ký toàn thư',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_den_hung_map',
          mediaType: 'IMAGE_2D',
          title: 'Bản đồ nước Văn Lang — mười lăm bộ Lạc Việt',
          caption: 'Phạm vi nước Văn Lang theo phục dựng sử học, trải '
              'rộng từ vùng Hồng — Lô — Mã tới đồng bằng Bắc Bộ.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          sourceCitation: 'Phục dựng theo Viện Sử học Việt Nam',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
        ),
        MapLocationMediaDto(
          id: 'media_den_hung_clip',
          mediaType: 'DOCUMENTARY_CLIP',
          title: 'Phim tư liệu: Văn minh sông Hồng và trống đồng Đông Sơn',
          caption: 'Tái hiện đời sống cư dân Lạc Việt buổi bình minh lịch sử.',
          externalUrl: 'https://example.com/van-lang-doc.mp4',
          sourceCitation: 'Bảo tàng Lịch sử Quốc gia',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 3,
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
      keyFigures: 'Cư dân Lạc Việt; các thợ luyện đồng Đông Sơn',
      historicalSignificance:
          'Ngã ba sông Hạc là vùng đất tâm linh hình thành nền văn minh '
          'lúa nước — nơi văn hóa Đông Sơn rực sáng bậc nhất Đông Nam Á.',
      storyNarrative:
          'Vùng đất giáp ranh Phong Châu nơi sông Hồng, sông Lô, sông Đà '
          'hợp lưu từ lâu đã là trung tâm buôn bán và sinh hoạt của các '
          'bộ Lạc Việt. Đất đai màu mỡ bồi đắp bởi ba con sông lớn tạo '
          'nên những cánh đồng lúa nước đầu tiên.\n\n'
          'Tại đây, các nghệ nhân Lạc Việt đã đúc những mặt trống đồng '
          'Ngọc Lũ trứ danh — minh chứng cho trình độ luyện kim đỉnh cao '
          'của nước Văn Lang.\n\n'
          'Di chỉ khảo cổ quanh vùng vẫn tiếp tục phơi bày những lớp '
          'văn hóa dày dặn của cư dân Văn Lang - Âu Lạc qua hàng nghìn năm.',
      eventIds: ['evt_van_lang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_van_lang',
          title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
          yearLabel: 'Khoảng thế kỷ VII TCN',
          role: 'PRIMARY',
          sortOrder: 0,
          slug: 'thoi-dai-hung-vuong',
          periodCode: 'VAN_LANG',
          periodTitle: 'Thời đại Văn Lang',
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_hac_panorama',
          mediaType: 'IMAGE_2D',
          title: 'Toàn cảnh Ngã Ba Hạc — nơi hợp lưu ba dòng sông',
          caption: 'Vùng nước mâu thiệt nơi sông Hồng, sông Lô và sông '
              'Đà gặp nhau dưới chân núi Nghĩa Lĩnh.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          sourceCitation: 'Ban quản lý Khu di tích lịch sử Đền Hùng',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_hac_life',
          mediaType: 'IMAGE_2D',
          title: 'Đời sống cư dân Lạc Việt bên Ngã Ba Hạc',
          caption: 'Cảnh cày cấy, đánh cá và xưởng đúc đồng của cư dân '
              'Văn Lang phục dựng qua tranh minh họa.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          sourceCitation: 'Tranh minh họa Bảo tàng Lịch sử Quốc gia',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_hac_drum',
          mediaType: 'IMAGE_2D',
          title: 'Hiện vật trống đồng Đông Sơn khai quật tại vùng',
          caption: 'Mặt trống đồng hoa văn sao và chim Lạc — biểu tượng '
              'văn minh lúa nước thời Hùng Vương.',
          externalUrl: '/heritage/den-hung-phong-chau.jpg',
          sourceCitation: 'Bảo tàng Lịch sử Quốc gia — sưu tập Đông Sơn',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
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
      keyFigures: 'Trưng Trắc; Trưng Nhị; Thi Sách; Tô Định (đối phương)',
      historicalSignificance:
          'Khởi nghĩa đầu tiên do phụ nữ lãnh đạo giành lại độc lập dân '
          'tộc sau hơn hai thế kỷ Bắc thuộc — minh chứng tinh thần bất '
          'khuất của phụ nữ Việt Nam.',
      storyNarrative:
          'Mùa xuân năm 40, trước cảnh quan quân Đông Hán bóc lột, Trưng '
          'Trắc cùng em Trưng Nhị dựng đại nghĩa tại Mê Linh rồi kéo về '
          'cửa sông Hát lập đàn tế cờ trước ba quân.\n\n'
          'Dưới cờ đại nghĩa, Hai Bà phát lệnh tổng tiến công; các quận '
          'huyện đồng loạt hưởng ứng, Tô Định phải tháo chạy về nước. '
          'Trưng Nữ Vương xưng vương đóng đô Mê Linh, khôi phục độc lập '
          'sau hơn 200 năm Bắc thuộc.\n\n'
          'Hát Môn từ đó trở thành nơi tưởng niệm thiêng liêng của nhân '
          'dân vùng Sơn Tây qua nhiều thế kỷ.',
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
          slug: 'khoi-nghia-hai-ba-trung',
          summary: 'Khởi nghĩa đầu tiên giành lại độc lập dân tộc.',
          description:
              'Hai Bà Trưng phất cờ Mê Linh, thu phục 65 thành trì và '
              'dựng nền tự chủ đầu tiên sau Bắc thuộc.',
          periodCode: 'BAC_THUOC_LAN_1',
          periodTitle: 'Thời Bắc thuộc lần 1',
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
          sourceCitation: 'Tranh minh họa theo Hậu Hán thư & Đại Việt '
              'sử ký toàn thư',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_hat_mon_map',
          mediaType: 'IMAGE_2D',
          title: 'Bản đồ chiến lược Mê Linh — thế trận năm 40',
          caption: 'Sơ đồ tuyến tiến công của nghĩa quân Hai Bà Trưng '
              'dọc lưu vực sông Hồng - sông Hát.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Phục dựng theo Tập bản đồ lịch sử Việt Nam',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_hat_mon_camp',
          mediaType: 'IMAGE_2D',
          title: 'Doanh trại nghĩa quân Hai Bà Trưng bên sông Hát',
          caption: 'Phục dựng doanh trại, đàn tế và đoàn voi chiến của '
              'nghĩa quân trong mùa xuân năm 40.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Tranh minh họa nhóm nghiên cứu Dấu Việt',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
        ),
        MapLocationMediaDto(
          id: 'media_hat_mon_secret',
          mediaType: 'PANORAMA_360',
          title: 'Không gian 360° Đền Hát Môn',
          caption: 'Chỉ hiển thị sau khi mở khoá địa điểm.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Tư liệu phóng sự Đền Hát Môn',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 3,
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
      keyFigures: 'Trưng Trắc (Trưng Nữ Vương); Trưng Nhị; các tướng Mê Linh',
      historicalSignificance:
          'Kinh đô đầu tiên của chính quyền tự chủ do phụ nữ lập nên — '
          'biểu tượng vĩnh viễn của lòng yêu nước và khí phách anh thư.',
      storyNarrative:
          'Sau đại thắng đánh đuổi Tô Định, Trưng Trắc xưng vương hiệu '
          'Trưng Nữ Vương và chọn Mê Linh làm kinh đô — nơi tập họp các '
          'tướng lĩnh, cai quản 65 thành trì Lĩnh Ngoại vừa giành lại.\n\n'
          'Trong ba năm tự chủ ngắn ngủi (40–43), Mê Linh là trung tâm '
          'chính trị - quân sự của quốc gia phục hưng, nơi ban hành '
          'những chính sách đầu tiên hậu Bắc thuộc.\n\n'
          'Ngày nay, dấu tích thành cổ, đền thờ Hai Bà và hạt gạo Mê '
          'Linh cổ vẫn còn, chứng minh cho sức sống bất diệt của tinh '
          'thần độc lập.',
      eventIds: ['evt_hai_ba_trung'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_hai_ba_trung',
          title: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
          yearLabel: 'Năm 40',
          role: 'PRIMARY',
          sortOrder: 0,
          slug: 'khoi-nghia-hai-ba-trung',
          periodCode: 'BAC_THUOC_LAN_1',
          periodTitle: 'Thời Bắc thuộc lần 1',
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_me_linh_gate',
          mediaType: 'IMAGE_2D',
          title: 'Thành cổ Mê Linh — kinh đô Trưng Nữ Vương',
          caption: 'Dấu tích thành cổ nơi Trưng Nữ Vương triệu tập các '
              'tướng lĩnh quản trị 65 thành trì.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Ban quản lý di tích Mê Linh',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_me_linh_army',
          mediaType: 'IMAGE_2D',
          title: 'Nghĩa quân Mê Linh duyệt binh trước thành',
          caption: 'Đoàn voi chiến và bộ binh Lạc Việt được phục dựng '
              'theo tư liệu cổ và di chỉ khảo cổ.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Tranh minh họa theo Hậu Hán thư',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_me_linh_artifact',
          mediaType: 'IMAGE_2D',
          title: 'Hiện vật gốm và binh khí thời Hai Bà Trưng',
          caption: 'Các hiện vật sành sứ, đồng khí khai quật quanh vùng '
              'Mê Linh chứng minh diện mạo kinh đô thời Trưng Vương.',
          externalUrl: '/heritage/me-linh-hai-ba-trung.jpg',
          sourceCitation: 'Bảo tàng Hà Nội — sưu tập Mê Linh',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
        ),
      ],
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
      keyFigures:
          'Ngô Quyền; Dương Tam Kha; Nguyễn Tất Tố; Lưu Hoằng Thao (đối phương)',
      historicalSignificance:
          'Chiến thắng chấm dứt hơn 1000 năm Bắc thuộc, mở ra kỷ nguyên '
          'độc lập trường tồn của dân tộc Việt Nam.',
      storyNarrative:
          'Mùa đông năm 938, quân Nam Hán kéo hạm đội lớn vào sông Bạch '
          'Đằng trừng phạt Khúc Thừa Dụ. Ngô Quyền nắm lấy cơ hội đánh '
          'đuổi nội phản, rồi bố trận quyết chiến trên dòng sông lịch '
          'sử.\n\n'
          'Lợi dụng quy luật bán nhật triều, ông cho cắm hàng nghìn '
          'cọc gỗ lim bọc sắt nhọn dưới lòng sông. Khi triều lên, nghĩa '
          'quân giả thua dụ thuyền giặc tiến sâu; triều rút, hạm đội '
          'Nam Hán mắc cọc nát như tương, Lưu Hoằng Thao bỏ mình tại '
          'trận.\n\n'
          'Chiến thắng vang dội đó chấm dứt hơn một thiên niên kỷ Bắc '
          'thuộc. Năm 939, Ngô Quyền xưng vương đóng đô Cổ Loa, mở ra '
          'kỷ nguyên độc lập trường tồn cho dân tộc.',
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
          slug: 'dai-chien-bach-dang-938',
          summary: 'Trận cọc ngầm đánh tan hạm đội Nam Hán năm 938.',
          description:
              'Ngô Quyền cắm cọc sông Bạch Đằng, lợi dụng thủy triều '
              'diệt hạm đội Nam Hán, chấm dứt Bắc thuộc.',
          periodCode: 'DOC_LAP_DAU',
          periodTitle: 'Buổi đầu độc lập',
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
          sourceCitation: 'Tranh minh họa theo Đại Việt sử ký toàn thư',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_bach_dang_tactics',
          mediaType: 'IMAGE_2D',
          title: 'Sơ đồ chiến thuật cọc ngầm và thủy triều',
          caption: 'Phân tích cách Ngô Quyền lợi dụng chế độ bán nhật '
              'triều để giăng bẫy hạm đội Nam Hán.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          sourceCitation: 'Phục dựng theo Tập bản đồ lịch sử quân sự '
              'Việt Nam',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_bach_dang_camp',
          mediaType: 'IMAGE_2D',
          title: 'Doanh trại nghĩa quân bên cửa sông Bạch Đằng',
          caption: 'Phục dựng trại quân, điểm hiếu và hạm đội nghĩa '
              'quân trong tháng chuẩn bị quyết chiến.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          sourceCitation: 'Tranh minh họa nhóm nghiên cứu Dấu Việt',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
        ),
        MapLocationMediaDto(
          id: 'media_bach_dang_audio',
          mediaType: 'AUDIO_GUIDE',
          title: 'Thuyết minh chiến thuật cọc ngầm trên sông Bạch Đằng',
          caption: 'Phân tích cách Ngô Quyền lợi dụng chế độ bán nhật triều.',
          externalUrl: '/heritage/bach-dang-audio.mp3',
          sourceCitation: 'Bảo tàng Hải Phòng — phòng thuyết minh số',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 3,
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
      keyFigures: 'Ngô Quyền; cư dân làng chài Yên Giang',
      historicalSignificance:
          'Bãi cọc khảo cổ duy nhất còn sót lại của trận địa Bạch Đằng — '
          'bằng chứng vật chất sống động của chiến thuật cọc ngầm năm 938.',
      storyNarrative:
          'Năm 1953, người dân Yên Giang đào đất phát hiện hàng trăm '
          'thân cọc gỗ lim vạt nhọn cắm sâu trong bùn — khớp đúng với '
          'mô tả trận địa Bạch Đằng của Ngô Quyền năm 938.\n\n'
          'Các cuộc khai quật 1976, 2019–2020 tiếp tục phơi bày một bãi '
          'cọc quy hoạch chặt chẽ gồm nhiều hàng cọc lớn nhỏ xen kẽ — '
          'chứng minh mạch truyền kỹ thuật cọc ngầm qua ba triều đại '
          'Ngô - Trần - Lê.\n\n'
          'Bãi cọc Yên Giang hôm nay vẫn là một trong những di chỉ '
          'quân sự khảo cổ quan trọng bậc nhất Việt Nam.',
      eventIds: ['evt_bach_dang'],
      events: [
        MapLocationLinkedEventDto(
          eventId: 'evt_bach_dang',
          title: 'Đại Chiến Bạch Đằng 938',
          yearLabel: 'Năm 938',
          role: 'PRIMARY',
          sortOrder: 0,
          slug: 'dai-chien-bach-dang-938',
          periodCode: 'DOC_LAP_DAU',
          periodTitle: 'Buổi đầu độc lập',
        ),
      ],
      media: [
        MapLocationMediaDto(
          id: 'media_yen_giang_stakes',
          mediaType: 'IMAGE_2D',
          title: 'Bãi cọc Yên Giang — chứng tích gỗ lim ngàn năm',
          caption: 'Hàng trăm thân cọc gỗ lim vạt nhọn cắm sâu lòng '
              'sông ngầm, chứng tích vật chất trận địa năm 938.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          sourceCitation: 'Ban quản lý di tích Bãi cọc Bạch Đằng',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 0,
        ),
        MapLocationMediaDto(
          id: 'media_yen_giang_excavation',
          mediaType: 'IMAGE_2D',
          title: 'Cuộc khai quật bãi cọc Yên Giang 2019–2020',
          caption: 'Các chuyên gia khảo cổ phơi bày từng hàng cọc lớn '
              'nhỏ xen kẽ còn nguyên vẹn dưới bùn cửa sông.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          sourceCitation: 'Viện Khảo cổ học Việt Nam',
          visibility: 'PUBLIC_PREVIEW',
          sortOrder: 1,
        ),
        MapLocationMediaDto(
          id: 'media_yen_giang_closeup',
          mediaType: 'IMAGE_2D',
          title: 'Thân cọc gỗ lim vạt nhọn — chi tiết hiện vật',
          caption: 'Đường vân gỗ lim ngàn năm vẫn rõ ràng, minh chứng '
              'cho kỹ thuật gia công cọc của thời Ngô - Trần - Lê.',
          externalUrl: '/heritage/bai-coc-bach-dang.jpg',
          sourceCitation: 'Bảo tàng Quảng Ninh',
          visibility: 'UNLOCKED_ONLY',
          sortOrder: 2,
        ),
      ],
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
      mapAssetId: found.mapAssetId,
      requiredLesson: found.requiredLesson,
      eventIds: found.eventIds,
      events: found.events,
      unlockLessons: found.unlockLessons,
      media: found.visibleMedia,
      keyFigures: found.keyFigures,
      storyNarrative: found.storyNarrative,
      historicalSignificance: found.historicalSignificance,
    );
  }
}
