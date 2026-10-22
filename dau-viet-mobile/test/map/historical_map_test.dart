import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMapRepository implements MapRepository {
  List<MapLocationDto> locations = const [];
  Object? error;
  int calls = 0;

  @override
  Future<List<MapLocationDto>> listLocations() async {
    calls++;
    if (error != null) throw error!;
    return locations;
  }
}

void main() {
  const locked = MapLocationDto(
    id: 'loc-1',
    eventId: 'evt-1',
    title: 'Bến Bạch Đằng',
    description: 'Bãi cọc ngầm.',
    latitude: 20.91,
    longitude: 106.82,
    unlockState: MapUnlockState.locked,
    requiredLesson: RequiredLessonRef(
      lessonId: 'les-1',
      title: 'Trận Bạch Đằng 938',
    ),
  );
  const unlocked = MapLocationDto(
    id: 'loc-2',
    eventId: 'evt-1',
    title: 'Cửa Lạch Trường',
    latitude: 20.95,
    longitude: 106.79,
    unlockState: MapUnlockState.unlocked,
  );
  const available = MapLocationDto(
    id: 'loc-3',
    eventId: 'evt-1',
    title: 'Đồng bằng Bắc Bộ',
    latitude: 21.02,
    longitude: 105.85,
    unlockState: MapUnlockState.available,
  );

  Widget buildApp(_FakeMapRepository repo) {
    return ProviderScope(
      overrides: [mapRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: HistoricalMapScreen()),
    );
  }

  group('HistoricalMapScreen', () {
    testWidgets('hiển thị cả 3 trạng thái địa điểm trong danh sách', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..locations = const [locked, unlocked, available];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bến Bạch Đằng'), findsWidgets);
      expect(find.text('Cửa Lạch Trường'), findsWidgets);
      expect(find.text('Đồng bằng Bắc Bộ'), findsWidgets);
      // Phụ đề trạng thái
      expect(find.text('Mở khoá bằng: Trận Bạch Đằng 938'), findsOneWidget);
      expect(find.text('Đã mở khoá — nhấn để xem chi tiết'), findsOneWidget);
      expect(find.text('Sẵn sàng khám phá'), findsOneWidget);
    });

    testWidgets('chạm địa điểm LOCKED → sheet hiện CTA "HỌC ĐỂ MỞ"', (
      tester,
    ) async {
      final repo = _FakeMapRepository()..locations = const [locked];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bến Bạch Đằng').first);
      await tester.pumpAndSettle();

      expect(find.text('HỌC ĐỂ MỞ'), findsOneWidget);
      expect(find.textContaining('Trận Bạch Đằng 938'), findsWidgets);
    });

    testWidgets('lỗi API → trạng thái lỗi + nút Thử lại, không fallback', (
      tester,
    ) async {
      final repo = _FakeMapRepository()
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);

      repo.error = null;
      repo.locations = const [available];
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();

      expect(find.text('Đồng bằng Bắc Bộ'), findsWidgets);
    });

    testWidgets('danh sách rỗng → empty state thân thiện', (tester) async {
      final repo = _FakeMapRepository()..locations = const [];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có sự kiện nào'), findsOneWidget);
    });
  });
}
