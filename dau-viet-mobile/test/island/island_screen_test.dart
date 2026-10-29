import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dau_viet_mobile/features/island/data/island_dto.dart';
import 'package:dau_viet_mobile/features/island/data/island_providers.dart';
import 'package:dau_viet_mobile/features/island/data/mock_island_repository.dart';
import 'package:dau_viet_mobile/features/island/presentation/island_screen.dart';
import 'package:dau_viet_mobile/features/island/presentation/island_shop_screen.dart';
import 'package:dau_viet_mobile/features/island/presentation/widgets/island_upgrade_panel.dart';

void main() {
  Future<void> pumpAsync(
    WidgetTester tester, [
    Duration duration = const Duration(milliseconds: 300),
  ]) async {
    await tester.pump();
    await tester.pump(duration);
  }

  Widget buildTestableWidget(Widget child, [MockIslandRepository? repo]) {
    final mockRepo = repo ?? MockIslandRepository();
    return ProviderScope(
      overrides: [islandRepositoryProvider.overrideWithValue(mockRepo)],
      child: MaterialApp(home: child),
    );
  }

  group('IslandScreen Widget Tests', () {
    testWidgets(
      'Header displays ĐẢO DI SẢN, Tier 1 badge, and History Points',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
        await pumpAsync(tester);

        expect(find.text('ĐẢO DI SẢN'), findsOneWidget);
        expect(find.textContaining('Đảo nhỏ'), findsWidgets);
        expect(
          find.text('500'),
          findsOneWidget,
        ); // 500 History Points from Mock
        expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
        expect(find.byIcon(Icons.landscape_rounded), findsWidgets);
      },
    );

    testWidgets('Slots display locked, empty, and occupied states correctly', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
      await pumpAsync(tester);

      // SLOT_NHA_TRANH has Nhà Tranh Vách Đất
      expect(
        find.bySemanticsLabel(RegExp(r'Nhà Tranh Vách Đất')),
        findsOneWidget,
      );

      // SLOT_EMPTY_01 is empty
      expect(
        find.bySemanticsLabel(RegExp(r'Ô trống SLOT_EMPTY_01')),
        findsOneWidget,
      );

      // SLOT_CAY_DA is locked at Tier 2
      expect(find.text('Cấp 2'), findsWidgets);
    });

    testWidgets('Tapping locked slot shows detail card explaining lock tier', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
      await pumpAsync(tester);

      final handle = tester.ensureSemantics();
      try {
        tester.semantics.tap(
          find.semantics.byLabel(RegExp(r'Ô khóa SLOT_CAY_DA Cấp 2')),
        );
        await pumpAsync(tester);

        expect(find.textContaining('Yêu cầu mở rộng Đảo Cấp 2'), findsOneWidget);
        expect(find.text('XEM ĐIỀU KIỆN MỞ KHÓA'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Tapping empty slot shows ĐẶT VẬT PHẨM DI SẢN', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
      await pumpAsync(tester);

      final handle = tester.ensureSemantics();
      try {
        tester.semantics.tap(
          find.semantics.byLabel(RegExp(r'Ô trống SLOT_EMPTY_01')),
        );
        await pumpAsync(tester);

        expect(find.text('ĐẶT VẬT PHẨM DI SẢN'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Tapping occupied slot shows ĐỔI VẬT PHẨM and CẤT VÀO KHO', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
      await pumpAsync(tester);

      final handle = tester.ensureSemantics();
      try {
        tester.semantics.tap(
          find.semantics.byLabel(RegExp(r'Nhà Tranh Vách Đất')),
        );
        await pumpAsync(tester);

        expect(find.text('ĐỔI VẬT PHẨM'), findsOneWidget);
        expect(find.text('CẤT VÀO KHO'), findsOneWidget);

        // Tap CẤT VÀO KHO
        await tester.tap(find.text('CẤT VÀO KHO'));
        await pumpAsync(tester);

        // Slot should now become empty
        expect(
          find.textContaining('Đã cất vật phẩm về kho'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('IslandUpgradePanel Widget Tests', () {
    testWidgets(
      'Upgrade panel shows EXP progression and correct button when canUpgrade=false',
      (tester) async {
        const island = IslandDto(
          tier: 1,
          maxTier: 3,
          rowVersion: 1,
          currentExp: 200,
          currentLevel: 1,
          nextTierRequiredLevel: 2,
          nextTierRequiredExp: 500,
          canUpgrade: false,
          progress: IslandProgressDto(
            completedEvents: 1,
            nextTierRequiredEvents: 2,
            canUpgrade: false,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IslandUpgradePanel(island: island, onUpgrade: () {}),
            ),
          ),
        );
        await pumpAsync(tester);

        expect(find.text('MỞ RỘNG ĐẢO DI SẢN'), findsOneWidget);
        expect(find.text('TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP'), findsOneWidget);
      },
    );

    testWidgets('Upgrade panel shows MỞ RỘNG ĐẢO NGAY when canUpgrade=true', (
      tester,
    ) async {
      const island = IslandDto(
        tier: 1,
        maxTier: 3,
        rowVersion: 1,
        currentExp: 600,
        currentLevel: 2,
        nextTierRequiredLevel: 2,
        nextTierRequiredExp: 500,
        canUpgrade: true,
        progress: IslandProgressDto(
          completedEvents: 2,
          nextTierRequiredEvents: 2,
          canUpgrade: true,
        ),
      );

      bool upgraded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IslandUpgradePanel(
              island: island,
              onUpgrade: () => upgraded = true,
            ),
          ),
        ),
      );
      await pumpAsync(tester);

      expect(find.text('MỞ RỘNG LÊN ĐẢO VỪA'), findsOneWidget);
      await tester.tap(find.text('MỞ RỘNG LÊN ĐẢO VỪA'));
      expect(upgraded, true);
    });
  });

  group('IslandShopScreen Widget Tests', () {
    testWidgets('Shop displays items with prices and user wallet balance', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestableWidget(const IslandShopScreen()));
      await pumpAsync(tester);

      expect(find.text('CỬA HÀNG DI SẢN'), findsOneWidget);
      expect(find.text('500'), findsOneWidget); // Wallet points

      expect(find.text('Cây Đa Di Sản'), findsOneWidget);
      expect(find.text('100 Điểm'), findsOneWidget);

      expect(find.text('Thủy Tạ Hồ Sen'), findsOneWidget);
      expect(find.text('300 Điểm'), findsOneWidget);

      // Owned item shows ĐÃ SỞ HỮU
      expect(find.text('ĐÃ SỞ HỮU'), findsOneWidget);
    });
  });
}
