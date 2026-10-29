import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:dau_viet_mobile/features/map/presentation/journey_map_node.dart';
import 'package:dau_viet_mobile/features/map/presentation/location_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMapRepo implements MapRepository {
  final List<MapLocationDto> locations;

  _FakeMapRepo(this.locations);

  @override
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) async => locations;

  @override
  Future<MapLocationDto> getLocationDetail(String locationId) async {
    return locations.firstWhere((l) => l.id == locationId);
  }
}

void main() {
  const locVanLangUnlocked = MapLocationDto(
    id: 'loc_den_hung',
    eventId: 'evt_van_lang',
    eventTitle: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
    slug: 'khu-di-tich-den-hung',
    title: 'Khu di tích Đền Hùng',
    shortSummary: 'Kinh đô Phong Châu thời các Vua Hùng.',
    description: 'Núi Nghĩa Lĩnh, Phong Châu.',
    latitude: 21.3,
    longitude: 105.3,
    kind: 'ANCIENT_CAPITAL',
    coordinatePrecision: 'EXACT',
    visibility: 'PUBLIC',
    unlockMode: 'NONE',
    unlocked: true,
    unlockState: MapUnlockState.unlocked,
    events: [
      MapLocationLinkedEventDto(
        eventId: 'evt_van_lang',
        title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
        yearLabel: 'Khoảng thế kỷ VII TCN',
      ),
    ],
    media: [
      MapLocationMediaDto(
        id: 'm_img_1',
        mediaType: 'IMAGE_2D',
        title: 'Toàn cảnh Đền Hùng',
        caption: 'Ảnh tư liệu núi Nghĩa Lĩnh',
        visibility: 'PUBLIC_PREVIEW',
      ),
      MapLocationMediaDto(
        id: 'm_vid_1',
        mediaType: 'DOCUMENTARY_CLIP',
        title: 'Phim tư liệu Văn Lang',
        caption: 'Tái hiện văn minh Đông Sơn',
        visibility: 'PUBLIC_PREVIEW',
      ),
    ],
  );

  const locHaiBaTrungLockedPublic = MapLocationDto(
    id: 'loc_hat_mon',
    eventId: 'evt_hai_ba_trung',
    eventTitle: 'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
    slug: 'cua-song-hat-hat-mon',
    title: 'Cửa Sông Hát (Hát Môn)',
    shortSummary: 'Đền Hát Môn bên cửa sông Hát.',
    description: 'Nơi tế cờ khởi nghĩa mùa xuân năm 40.',
    latitude: 21.1,
    longitude: 105.5,
    kind: 'MEMORIAL',
    coordinatePrecision: 'EXACT',
    visibility: 'PUBLIC',
    unlockMode: 'ANY',
    unlocked: false,
    unlockState: MapUnlockState.locked,
    requiredLesson: RequiredLessonRef(
      lessonId: 'les_me_linh',
      title: 'Tiếng Trống Mê Linh',
    ),
    media: [
      MapLocationMediaDto(
        id: 'm_pub_img',
        mediaType: 'IMAGE_2D',
        title: 'Tranh Hội thề Hát Môn (Xem trước)',
        visibility: 'PUBLIC_PREVIEW',
      ),
      MapLocationMediaDto(
        id: 'm_secret_vid',
        mediaType: 'DOCUMENTARY_CLIP',
        title: 'Phim giải mã chỉ mở sau khi học',
        visibility: 'UNLOCKED_ONLY',
      ),
    ],
  );

  const locDocsOnly = MapLocationDto(
    id: 'loc_bach_dang_docs_only',
    eventId: 'evt_bach_dang',
    eventTitle: 'Đại Chiến Bạch Đằng 938',
    title: 'Bến Bạch Đằng - Trận Địa Cọc',
    description: 'Cửa sông Bạch Đằng lịch sử.',
    latitude: 20.8,
    longitude: 106.6,
    visibility: 'ALWAYS_VISIBLE',
    unlocked: true,
    unlockState: MapUnlockState.available,
  );

  group('Heritage Map v2 & Location Profile Tests (Issue #24)', () {
    testWidgets(
      'AC-1: Bản đồ Di sản hiển thị từ dữ liệu API v2, không còn chế độ timeline dựa trên map hay hardcode slug/UUID',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mapRepositoryProvider.overrideWithValue(
                _FakeMapRepo([locVanLangUnlocked, locDocsOnly]),
              ),
            ],
            child: const MaterialApp(home: HistoricalMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Không còn nút chuyển chế độ "Dòng thời gian" trên màn Bản đồ.
        expect(find.text('Dòng thời gian'), findsNothing);
        expect(find.text('Về Dòng Thời Gian'), findsNothing);

        // Hiển thị tiêu đề Bản đồ Di sản và thông tin chặng từ DTO v2.
        expect(find.text('Bản đồ Di sản Lịch sử Việt Nam'), findsOneWidget);
        expect(
          find.text('Bản Đồ Di Sản: Thời Đại Hùng Vương - Dựng Nước Văn Lang'),
          findsOneWidget,
        );
        expect(find.text('1 mốc toạ độ'), findsOneWidget);
        expect(find.byType(JourneyMapNode), findsOneWidget);
        expect(find.text('Khu di tích Đền Hùng'), findsWidgets);

        // Chuyển sang chặng 2.
        await tester.tap(find.byTooltip('Chặng sau'));
        await tester.pumpAndSettle();
        expect(
          find.text('Bản Đồ Di Sản: Đại Chiến Bạch Đằng 938'),
          findsOneWidget,
        );
        expect(find.text('Bến Bạch Đằng - Trận Địa Cọc'), findsWidgets);
      },
    );

    testWidgets(
      'AC-2: Địa điểm khoá có visibility = PUBLIC vẫn hiện tên và ghim trên bản đồ',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mapRepositoryProvider.overrideWithValue(
                _FakeMapRepo([locHaiBaTrungLockedPublic]),
              ),
            ],
            child: const MaterialApp(home: HistoricalMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Ghim địa điểm (JourneyMapNode) và tên vẫn hiển thị dù đang LOCKED.
        expect(find.byType(JourneyMapNode), findsOneWidget);
        expect(find.text('Cửa Sông Hát (Hát Môn)'), findsWidgets);
        expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      },
    );

    testWidgets(
      'Hồ sơ địa điểm: ẩn các tab rỗng (chỉ hiện Tư liệu khi không có Ảnh và Video)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mapRepositoryProvider.overrideWithValue(
                _FakeMapRepo([locDocsOnly]),
              ),
            ],
            child: const MaterialApp(home: HistoricalMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bến Bạch Đằng - Trận Địa Cọc').first);
        await tester.pumpAndSettle();

        // Chỉ có tab Tư liệu; tab Ảnh và Video rỗng nên bị ẩn hoàn toàn.
        expect(
          find.byKey(const ValueKey<String>('location_tab_documents')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_images')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_videos')),
          findsNothing,
        );
        expect(find.text('Cửa sông Bạch Đằng lịch sử.'), findsOneWidget);
      },
    );

    testWidgets(
      'Hồ sơ địa điểm đang khoá: lọc bỏ media UNLOCKED_ONLY, ẩn tab Video rỗng, chỉ hiện tab Ảnh (PUBLIC_PREVIEW) và Tư liệu',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mapRepositoryProvider.overrideWithValue(
                _FakeMapRepo([locHaiBaTrungLockedPublic]),
              ),
            ],
            child: const MaterialApp(home: HistoricalMapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cửa Sông Hát (Hát Môn)').first);
        await tester.pumpAndSettle();

        // Có tab Ảnh (do có 1 ảnh PUBLIC_PREVIEW) và tab Tư liệu, nhưng tab Video
        // bị ẩn vì video duy nhất là UNLOCKED_ONLY trong khi địa điểm đang khoá.
        expect(
          find.byKey(const ValueKey<String>('location_tab_images')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_documents')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_videos')),
          findsNothing,
        );
        expect(find.text('Tranh Hội thề Hát Môn (Xem trước)'), findsOneWidget);
        expect(find.text('Phim giải mã chỉ mở sau khi học'), findsNothing);
      },
    );

    testWidgets(
      'Hồ sơ địa điểm đã mở khoá: hiển thị đủ 3 tab Ảnh / Video / Tư liệu và chuyển tab mượt mà',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mapRepositoryProvider.overrideWithValue(
                _FakeMapRepo([locVanLangUnlocked]),
              ),
            ],
            child: const MaterialApp(
              home: LocationProfileScreen(locationId: 'loc_den_hung'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Cả 3 tab đều hiển thị.
        expect(
          find.byKey(const ValueKey<String>('location_tab_images')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_videos')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('location_tab_documents')),
          findsOneWidget,
        );

        // Mặc định ở tab Ảnh.
        expect(find.text('Toàn cảnh Đền Hùng'), findsOneWidget);

        // Chuyển sang tab Video.
        await tester.tap(
          find.byKey(const ValueKey<String>('location_tab_videos')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Phim tư liệu Văn Lang'), findsOneWidget);

        // Chuyển sang tab Tư liệu.
        await tester.tap(
          find.byKey(const ValueKey<String>('location_tab_documents')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Núi Nghĩa Lĩnh, Phong Châu.'), findsOneWidget);
        expect(
          find.textContaining(
            'Thời Đại Hùng Vương - Dựng Nước Văn Lang (Khoảng thế kỷ VII TCN)',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
