import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_energy_repository.dart';

void main() {
  group('energyProvider', () {
    test('build fetch state từ repository — repo trả 50/100 thì provider '
        'giữ đúng 50/100 (KHÔNG phải số giả)', () async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 50,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          canSubmitGraded: true,
        );
      final container = ProviderContainer(
        overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(energyProvider, (_, _) {});
      addTearDown(sub.close);

      final dto = await container.read(energyProvider.future);
      expect(dto.current, 50);
      expect(dto.max, 100);
      expect(repo.calls, 1);
    });

    test('applySnapshot ghi đè state — đồng bộ sau submit không cần '
        'refetch API', () async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(current: 80, max: 100);
      final container = ProviderContainer(
        overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(energyProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(energyProvider.future);
      final callsBefore = repo.calls;

      container
          .read(energyProvider.notifier)
          .applySnapshot(EnergyStateDto(current: 42, max: 100));
      final state = container.read(energyProvider);
      expect(state.value?.current, 42);
      expect(repo.calls, callsBefore); // không gọi API thêm
    });

    test('refresh() gọi lại repository — data mới thay thế', () async {
      final repo = FakeEnergyRepository()
        ..queue.addAll([
          EnergyStateDto(current: 50, max: 100),
          EnergyStateDto(current: 55, max: 100),
        ]);
      final container = ProviderContainer(
        overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(energyProvider, (_, _) {});
      addTearDown(sub.close);

      final first = await container.read(energyProvider.future);
      expect(first.current, 50);

      await container.read(energyProvider.notifier).refresh();
      expect(container.read(energyProvider).value?.current, 55);
      expect(repo.calls, 2);
    });

    test('network failure → AsyncError, KHÔNG phải 100/100', () async {
      final repo = FakeEnergyRepository()..error = Exception('network down');
      final container = ProviderContainer(
        overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(energyProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(energyProvider.future),
        throwsA(anything),
      );
      expect(container.read(energyProvider).value, isNull);
    });

    group('FIX-3 — thứ tự serverTime, chống snapshot/GET cũ ghi đè', () {
      // serverTime tăng dần theo "độ mới" phía server — chọn mốc quá khứ
      // (năm 2020) để stamp của DTO thiếu serverTime (= deviceNow thật)
      // luôn MỚI HƠN → case backward-compat "no-serverTime vẫn áp" giữ đúng.
      EnergyStateDto st(int current, int minute) => EnergyStateDto(
        current: current,
        max: 100,
        serverTime: DateTime.utc(2020, 1, 1, 10, minute),
      );

      Future<ProviderContainer> newContainer(FakeEnergyRepository repo) async {
        final c = ProviderContainer(
          overrides: [energyRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(c.dispose);
        final sub = c.listen(energyProvider, (_, _) {});
        addTearDown(sub.close);
        return c;
      }

      test(
        'snapshot CŨ hơn state hiện tại (serverTime nhỏ) → bỏ qua',
        () async {
          final repo = FakeEnergyRepository()..next = st(80, 5);
          final c = await newContainer(repo);
          await c.read(energyProvider.future); // state = 80 @10:05

          c.read(energyProvider.notifier).applySnapshot(st(30, 4)); // @10:04 cũ
          expect(
            c.read(energyProvider).value?.current,
            80,
            reason: 'snapshot serverTime cũ không được lùi balance',
          );
        },
      );

      test('snapshot MỚI hơn state (serverTime lớn) → áp', () async {
        final repo = FakeEnergyRepository()..next = st(80, 5);
        final c = await newContainer(repo);
        await c.read(energyProvider.future);

        c.read(energyProvider.notifier).applySnapshot(st(60, 6));
        expect(c.read(energyProvider).value?.current, 60);
      });

      test('snapshot cùng serverTime → áp (thứ tự đến quyết định)', () async {
        final repo = FakeEnergyRepository()..next = st(80, 5);
        final c = await newContainer(repo);
        await c.read(energyProvider.future);

        c.read(energyProvider.notifier).applySnapshot(st(70, 5));
        expect(c.read(energyProvider).value?.current, 70);
      });

      test(
        'thiếu serverTime (mock/server cũ) → vẫn áp, backward-compat',
        () async {
          final repo = FakeEnergyRepository()..next = st(80, 5);
          final c = await newContainer(repo);
          await c.read(energyProvider.future);

          c
              .read(energyProvider.notifier)
              .applySnapshot(EnergyStateDto(current: 42, max: 100));
          expect(c.read(energyProvider).value?.current, 42);
        },
      );

      test(
        'GET refresh trả dữ liệu CŨ hơn snapshot đã áp → không lùi',
        () async {
          // Build fetch trả @10:05; submit snapshot @10:07 về trước khi refresh
          // xong → refresh GET trả @10:06 (cũ hơn snapshot) phải bị bỏ.
          final repo = FakeEnergyRepository()..next = st(80, 5);
          final c = await newContainer(repo);
          await c.read(energyProvider.future); // 80 @10:05

          c.read(energyProvider.notifier).applySnapshot(st(60, 7)); // @10:07
          expect(c.read(energyProvider).value?.current, 60);

          // Refresh → repo trả dữ liệu cũ hơn snapshot (@10:06 < @10:07).
          repo.next = st(75, 6);
          await c.read(energyProvider.notifier).refresh();
          expect(
            c.read(energyProvider).value?.current,
            60,
            reason: 'GET cũ hơn snapshot không được ghi đè',
          );
        },
      );

      test(
        'hai snapshot đảo thứ tự → cái mới hơn thắng bất kể thứ tự đến',
        () async {
          final repo = FakeEnergyRepository()..next = st(80, 5);
          final c = await newContainer(repo);
          await c.read(energyProvider.future);

          // Submit B (mới, @10:09) về TRƯỚC submit A (cũ, @10:08).
          c.read(energyProvider.notifier).applySnapshot(st(55, 9));
          c.read(energyProvider.notifier).applySnapshot(st(60, 8));
          expect(c.read(energyProvider).value?.current, 55);
        },
      );
    });
  });
}
