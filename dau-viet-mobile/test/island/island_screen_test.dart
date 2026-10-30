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
    // Flush các Future.delayed trong MockIslandRepository (150-250ms)
    await tester.pump(const Duration(milliseconds: 400));
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

    testWidgets(
      'Issue #50: Renders all 9 screens — Screen 1 (Đảo Nhỏ, Turtle top bubble, Bản đồ button, Kho vật phẩm tray), Screen 2 (Placement Preview 2x2 + ✕/↻/✓ + Đặt), Screen 3 (Lưu / Thu hồi / Xoay), Screen 4 (Panoramic 3-Island Map), and Modals 1-4 (KHO VẬT PHẨM, CHI TIẾT VẬT PHẨM, NÂNG CẤP ĐẢO, Chuyển đến Đảo Vừa?)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
        await pumpAsync(tester);

        // Screen 1: 3-tier pill tabs (Đảo Nhỏ / Đảo Vừa / Đảo Lớn), Top Turtle Guide, Bản đồ button, Compact Kho vật phẩm tray
        expect(find.text('Đảo Nhỏ'), findsWidgets);
        expect(find.text('Đảo Vừa'), findsWidgets);
        expect(find.text('Đảo Lớn'), findsWidgets);
        expect(
          find.bySemanticsLabel(RegExp(r'Đây là Đảo Nhỏ của bạn!')),
          findsOneWidget,
        );
        expect(find.text('Bản đồ'), findsOneWidget);
        expect(find.text('Kho vật phẩm'), findsOneWidget);
        expect(find.text('Cây đa'), findsOneWidget);
        expect(find.text('Nhà rông'), findsOneWidget);

        // Modal 1 (KHO VẬT PHẨM) -> Modal 2 (CHI TIẾT VẬT PHẨM: Cây đa cổ thụ, Kích thước: 2x2, ⭐ 50, Đặt lên đảo)
        await tester.tap(find.text('Kho vật phẩm'));
        await pumpAsync(tester);
        expect(find.text('KHO VẬT PHẨM'), findsOneWidget);
        expect(find.text('Tất cả'), findsOneWidget);
        expect(find.text('Công trình'), findsOneWidget);
        expect(find.text('Cây cối'), findsOneWidget);
        expect(find.text('Trang trí'), findsOneWidget);

        // Tap Cây đa in KHO VẬT PHẨM -> opens Modal 2 CHI TIẾT VẬT PHẨM
        await tester.tap(find.text('Cây đa').last);
        await pumpAsync(tester);
        expect(find.text('CHI TIẾT VẬT PHẨM'), findsOneWidget);
        expect(find.text('Cây đa cổ thụ'), findsOneWidget);
        expect(find.text('Kích thước: 2x2'), findsOneWidget);
        expect(find.text('Đặt lên đảo'), findsOneWidget);

        // Tap Đặt lên đảo -> enters Screen 2 (Placement Preview with inline ✕ / ↻ / ✓ and bottom Đặt card)
        await tester.tap(find.text('Đặt lên đảo'));
        await pumpAsync(tester);
        expect(find.text('2x2'), findsOneWidget);
        expect(find.text('Đặt'), findsOneWidget);
        expect(find.bySemanticsLabel('Hủy đặt'), findsOneWidget);
        expect(find.bySemanticsLabel('Xoay hướng'), findsOneWidget);
        expect(find.bySemanticsLabel('Xác nhận đặt'), findsOneWidget);

        // Tap Đặt -> places item and enters Screen 3 (floating Lưu / Thu hồi / Xoay toolbar)
        await tester.tap(find.text('Đặt'));
        await pumpAsync(tester);
        expect(find.text('Lưu'), findsOneWidget);
        expect(find.text('Thu hồi'), findsOneWidget);
        expect(find.text('Xoay'), findsOneWidget);

        // Tap Lưu -> returns to Screen 1 view
        await tester.tap(find.text('Lưu'));
        await pumpAsync(tester);
        expect(find.text('Bản đồ'), findsOneWidget);

        // Tap Bản đồ -> opens Screen 4 (Panoramic 3-Island Map)
        await tester.tap(find.text('Bản đồ'));
        await pumpAsync(tester);
        expect(find.text('Đang sử dụng'), findsOneWidget);
        expect(find.textContaining('Hoàn thành 15 bài học'), findsOneWidget);
        expect(find.textContaining('Hoàn thành 30 bài học'), findsOneWidget);

        // Tap locked Đảo Vừa on Panoramic Map -> opens Modal 3 (NÂNG CẤP ĐẢO)
        await tester.tap(find.textContaining('Hoàn thành 15 bài học'));
        await pumpAsync(tester);
        expect(find.text('NÂNG CẤP ĐẢO'), findsOneWidget);
        expect(find.text('Hoàn thành 15 bài học'), findsOneWidget);
        expect(find.text('Sở hữu ít nhất 8 vật phẩm'), findsOneWidget);
        expect(find.text('Đạt cấp độ 5'), findsOneWidget);
        expect(find.text('Mở khóa Đảo Vừa'), findsOneWidget);

        // Tap Mở khóa Đảo Vừa -> opens Modal 4 (Chuyển đến Đảo Vừa?)
        await tester.tap(find.text('Mở khóa Đảo Vừa'));
        await pumpAsync(tester);
        expect(find.text('Chuyển đến Đảo Vừa?'), findsOneWidget);
        expect(find.text('Để sau'), findsOneWidget);
        expect(find.text('Chuyển ngay'), findsOneWidget);

        // Tap Chuyển ngay -> upgrades and switches to Screen 5 (Đảo Vừa)
        await tester.tap(find.text('Chuyển ngay'));
        await pumpAsync(tester);
        expect(find.text('Lưu'), findsOneWidget);
        expect(find.text('Thu hồi'), findsOneWidget);
        expect(find.text('Xoay'), findsOneWidget);
      },
    );

    testWidgets(
      'Issue #50 AC-6: Responsive layout has zero overflow on compact 360x800 mobile screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildTestableWidget(const IslandScreen()));
        await pumpAsync(tester);

        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Nhà rông'));
        await pumpAsync(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Đặt'));
        await pumpAsync(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'V51: IslandDto parses tiers metadata from backend response',
      (tester) async {
        final island = IslandDto.fromJson({
          'tier': 1,
          'maxTier': 3,
          'rowVersion': 1,
          'slots': const [],
          'tiers': [
            {
              'tier': 1,
              'nameKey': 'tier.small',
              'stageLabel': 'Giai đoạn Sơ Khai',
              'slotCount': 12,
              'requiredLevel': 1,
              'requiredExp': 0,
              'unlocked': true,
              'highlights': ['Lều trại'],
            },
            {
              'tier': 2,
              'nameKey': 'tier.medium',
              'stageLabel': 'Giai đoạn Định Cư',
              'slotCount': 28,
              'requiredLevel': 2,
              'requiredExp': 500,
              'unlocked': false,
            },
            {
              'tier': 3,
              'nameKey': 'tier.grand',
              'stageLabel': 'Giai đoạn Toàn Bích',
              'slotCount': 56,
              'requiredLevel': 3,
              'requiredExp': 1200,
              'unlocked': false,
            },
          ],
        });

        expect(island.tiers, hasLength(3));
        expect(island.tiers[0].slotCount, 12);
        expect(island.tiers[1].slotCount, 28);
        expect(island.tiers[2].slotCount, 56);
        expect(island.tiers[0].unlocked, isTrue);
        expect(island.tiers[2].unlocked, isFalse);
        expect(island.tiers[1].requiredExp, 500);
      },
    );

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

        expect(find.text('NÂNG CẤP ĐẢO'), findsOneWidget);
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

      expect(find.text('Mở khóa Đảo Vừa'), findsOneWidget);
      await tester.tap(find.text('Mở khóa Đảo Vừa'));
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
