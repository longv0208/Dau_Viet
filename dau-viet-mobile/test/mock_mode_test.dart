import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/mock_events_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mock mode (USE_MOCK seam)', () {
    test('override eventsRepositoryProvider bằng MockEventsRepository '
        'trả đúng hành trình demo Bạch Đằng', () async {
      final container = ProviderContainer(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(MockEventsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(eventsListProvider.future);
      expect(result.milestones, isNotEmpty);
      final active = result.milestones.firstWhere((m) => m.isActive);
      expect(active.eventId, 'evt_bach_dang_938');
      expect(active.title, contains('Bạch Đằng'));

      final detail = await container.read(
        eventDetailProvider('evt_bach_dang_938').future,
      );
      expect(detail.title, 'Đại Chiến Bạch Đằng 938');
      expect(detail.year, 938);
    });

    test('MockEventsRepository trả lỗi EVENT_NOT_FOUND cho id lạ — '
        'không tự động suy diễn event khác', () async {
      final container = ProviderContainer(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(MockEventsRepository()),
        ],
      );
      addTearDown(container.dispose);
      // listen giữ subscription để provider không auto-dispose trước khi
      // future resolve — .future trên family cần subscription sống.
      final sub = container.listen(
        eventDetailProvider('uuid-la'),
        (prev, next) {},
      );
      addTearDown(sub.close);
      await expectLater(
        container.read(eventDetailProvider('uuid-la').future),
        throwsA(anything),
      );
    });
  });
}
