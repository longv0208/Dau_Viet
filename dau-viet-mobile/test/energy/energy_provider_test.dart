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
        ..next = const EnergyStateDto(
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
        ..next = const EnergyStateDto(current: 80, max: 100);
      final container = ProviderContainer(
        overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(energyProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(energyProvider.future);
      final callsBefore = repo.calls;

      container.read(energyProvider.notifier).applySnapshot(
        const EnergyStateDto(current: 42, max: 100),
      );
      final state = container.read(energyProvider);
      expect(state.value?.current, 42);
      expect(repo.calls, callsBefore); // không gọi API thêm
    });

    test('refresh() gọi lại repository — data mới thay thế', () async {
      final repo = FakeEnergyRepository()
        ..queue.addAll([
          const EnergyStateDto(current: 50, max: 100),
          const EnergyStateDto(current: 55, max: 100),
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
      final repo = FakeEnergyRepository()
        ..error = Exception('network down');
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
  });
}
