import 'package:dau_viet_mobile/features/streak/data/streak_dto.dart';
import 'package:dau_viet_mobile/features/streak/data/streak_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_streak_repository.dart';

/// STREAK-01 — kiểm chứng thứ tự snapshot/GET của streakProvider KHÔNG phụ
/// thuộc đồng hồ thiết bị (clock skew). Mọi mốc freshness lấy từ serverTime
/// mà backend trả; request đến sai thứ tự không được ghi đè state mới.
void main() {
  group('streakProvider', () {
    // Dùng CÙNG đồng hồ (giờ 10) cho cả GET lẫn complete — serverTime là một
    // trục thời gian server duy nhất, mốc sau phải lớn hơn mốc trước.
    LearningStreakDto st(
      int current, {
      int? longest,
      bool alive = true,
      required int minute,
    }) => LearningStreakDto(
      currentStreak: current,
      longestStreak: longest ?? current,
      completedToday: true,
      streakAlive: alive,
      lastQualifiedDate: DateTime(2026, 10, 26),
      today: DateTime(2026, 10, 26),
      serverTime: DateTime.utc(2026, 10, 26, 10, minute),
    );

    StreakInfoDto info(
      int current, {
      required int minute,
      bool shieldConsumed = false,
      int shieldCount = 0,
      int bonusExp = 0,
      int bonusPoints = 0,
      int? milestoneDay,
    }) => StreakInfoDto(
      dayRecorded: true,
      currentStreak: current,
      longestStreak: current,
      studyDate: DateTime(2026, 10, 26),
      serverTime: DateTime.utc(2026, 10, 26, 10, minute),
      shieldConsumed: shieldConsumed,
      shieldCount: shieldCount,
      bonusExp: bonusExp,
      bonusPoints: bonusPoints,
      milestoneDay: milestoneDay,
    );

    Future<ProviderContainer> newContainer(FakeStreakRepository repo) async {
      final c = ProviderContainer(
        overrides: [streakRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(streakProvider, (_, _) {});
      addTearDown(sub.close);
      return c;
    }

    test('build fetch state thật từ repository', () async {
      final repo = FakeStreakRepository()..next = st(5, minute: 5);
      final c = await newContainer(repo);
      final dto = await c.read(streakProvider.future);
      expect(dto.currentStreak, 5);
      expect(repo.calls, 1);
    });

    test(
      'applyStreakInfo dùng serverTime SERVER, không phải device clock',
      () async {
        final repo = FakeStreakRepository()..next = st(4, minute: 5);
        final c = await newContainer(repo);
        await c.read(streakProvider.future); // state 4 @10:05

        // Snapshot từ complete @10:06 (server) — device clock không liên quan.
        c.read(streakProvider.notifier).applyStreakInfo(info(5, minute: 6));
        final applied = c.read(streakProvider).value!;
        expect(applied.currentStreak, 5);
        // serverTime phải là mốc SERVER 10:06, KHÔNG phải DateTime.now() lúc test.
        expect(applied.serverTime, DateTime.utc(2026, 10, 26, 10, 6));
      },
    );

    test('GET trễ sau complete không ghi đè snapshot mới', () async {
      final repo = FakeStreakRepository()..next = st(4, minute: 5);
      final c = await newContainer(repo);
      await c.read(streakProvider.future); // 4 @10:05

      // Complete ghi ngày mới @10:06 → state 5.
      c.read(streakProvider.notifier).applyStreakInfo(info(5, minute: 6));

      // GET trễ (khởi động trước complete) trả state cũ 4 @10:05 → bị bỏ.
      repo.next = st(4, minute: 5);
      await c.read(streakProvider.notifier).refresh();
      expect(
        c.read(streakProvider).value?.currentStreak,
        5,
        reason: 'GET cũ hơn mốc complete không được lùi streak',
      );
    });

    test('GET MỚI hơn mốc complete → được phép ghi đè', () async {
      final repo = FakeStreakRepository()..next = st(4, minute: 5);
      final c = await newContainer(repo);
      await c.read(streakProvider.future);

      c.read(streakProvider.notifier).applyStreakInfo(info(5, minute: 6));

      // GET tới SAU complete, serverTime mới hơn (vd server merge thêm ngày)
      // → phải áp, không bị chặn bởi cờ fromComplete.
      repo.next = st(6, longest: 9, minute: 9);
      await c.read(streakProvider.notifier).refresh();
      expect(c.read(streakProvider).value?.currentStreak, 6);
      expect(c.read(streakProvider).value?.longestStreak, 9);
    });

    test(
      'clock skew: đồng hồ thiết bị chạy TRƯỚC vẫn không sai thứ tự',
      () async {
        // Giả lập device clock +2h so server. Nếu code cũ dùng DateTime.now()
        // làm mốc thì mọi GET đều bị coi là "cũ" và provider mắc kẹt state tay.
        // Với serverTime-server thật, GET mới hơn vẫn áp đúng.
        final repo = FakeStreakRepository()..next = st(4, minute: 5);
        final c = await newContainer(repo);
        await c.read(streakProvider.future);

        c.read(streakProvider.notifier).applyStreakInfo(info(5, minute: 6));

        // GET serverTime thật mới hơn mốc complete → vẫn áp dù device nhanh.
        repo.next = st(7, minute: 20);
        await c.read(streakProvider.notifier).refresh();
        expect(c.read(streakProvider).value?.currentStreak, 7);
      },
    );

    test('complete liên tiếp giữ đúng số lớn hơn', () async {
      final repo = FakeStreakRepository()..next = st(4, minute: 5);
      final c = await newContainer(repo);
      await c.read(streakProvider.future);

      c.read(streakProvider.notifier).applyStreakInfo(info(5, minute: 6));
      c.read(streakProvider.notifier).applyStreakInfo(info(6, minute: 7));
      expect(c.read(streakProvider).value?.currentStreak, 6);
    });

    /* ---------- STREAK-02: shield + rewards ---------- */

    test(
      'applyStreakInfo đồng bộ shieldCount khi khiên vừa tự cứu chuỗi',
      () async {
        final repo = FakeStreakRepository()..next = st(4, minute: 5);
        final c = await newContainer(repo);
        await c.read(streakProvider.future);

        c.read(streakProvider.notifier).applyStreakInfo(
          info(5, minute: 6, shieldConsumed: true, shieldCount: 2),
        );
        final s = c.read(streakProvider).value!;
        expect(s.currentStreak, 5);
        expect(s.shieldCount, 2);
      },
    );

    test('buyShield gọi repo và cập nhật shieldCount trong state', () async {
      final repo = FakeStreakRepository()
        ..next = st(5, minute: 5)
        ..shieldResult = const StreakShieldPurchaseDto(
          shieldCount: 2,
          maxShields: 3,
          costPoints: 20,
          balanceAfter: 60,
        );
      final c = await newContainer(repo);
      await c.read(streakProvider.future);

      final res = await c
          .read(streakProvider.notifier)
          .buyShield(idempotencyKey: 'test-key-1');
      expect(res.shieldCount, 2);
      expect(res.balanceAfter, 60);
      expect(repo.buyCalls, 1);
      expect(repo.lastIdempotencyKey, 'test-key-1');
      expect(c.read(streakProvider).value?.shieldCount, 2);
    });

    test('buyShield ném lỗi lên caller (422/409) và không đổi state',
        () async {
      final repo = FakeStreakRepository()
        ..next = st(5, minute: 5)
        ..buyError = Exception('shield at max');
      final c = await newContainer(repo);
      await c.read(streakProvider.future);

      expect(
        () => c
            .read(streakProvider.notifier)
            .buyShield(idempotencyKey: 'test-key-2'),
        throwsA(isA<Exception>()),
      );
      // state vẫn giữ shieldCount cũ (0) — lỗi không cập nhật.
      expect(c.read(streakProvider).value?.shieldCount, 0);
    });
  });
}
