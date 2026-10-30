import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/features/island/data/island_dto.dart';

void main() {
  group('IslandDto & Related DTOs Tests', () {
    test('Parse IslandDto from Section 9 JSON contract successfully', () {
      final json = {
        'tier': 1,
        'maxTier': 3,
        'revision': 5,
        'progress': {
          'completedEvents': 1,
          'nextTierRequiredEvents': 2,
          'canUpgrade': false,
        },
        'slots': [
          {
            'slotId': 'CENTER_01',
            'x': 0.5,
            'y': 0.45,
            'zIndex': 10,
            'unlockTier': 1,
            'unlocked': true,
            'allowedCategories': ['DECOR'],
            'placement': {
              'itemId': 'item-uuid-123',
              'code': 'decor_nha_tranh',
              'name': 'Nhà Tranh Mái Lá',
              'renderKey': 'decor_nha_tranh',
              'assetId': null,
            },
          },
          {
            'slotId': 'LOCKED_01',
            'x': 0.7,
            'y': 0.3,
            'zIndex': 5,
            'unlockTier': 2,
            'unlocked': false,
            'allowedCategories': ['DECOR'],
            'placement': null,
          },
        ],
      };

      final island = IslandDto.fromJson(json);

      expect(island.tier, 1);
      expect(island.maxTier, 3);
      expect(island.revision, 5);
      expect(island.isMaxTier, false);

      expect(island.progress.completedEvents, 0);
      expect(island.progress.nextTierRequiredEvents, 0);
      expect(island.progress.canUpgrade, false);
      expect(island.progress.progressFraction, 1.0);

      expect(island.slots.length, 2);

      final centerSlot = island.slots[0];
      expect(centerSlot.slotId, 'CENTER_01');
      expect(centerSlot.x, 0.5);
      expect(centerSlot.y, 0.45);
      expect(centerSlot.zIndex, 10);
      expect(centerSlot.unlockTier, 1);
      expect(centerSlot.unlocked, true);
      expect(centerSlot.isOccupied, true);
      expect(centerSlot.isEmpty, false);
      expect(centerSlot.isLocked, false);
      expect(centerSlot.placement?.itemId, 'item-uuid-123');
      expect(centerSlot.placement?.name, 'Nhà Tranh Mái Lá');
      expect(
        centerSlot.placement?.assetPath,
        'assets/items/decor_nha_tranh.png',
      );

      final lockedSlot = island.slots[1];
      expect(lockedSlot.slotId, 'LOCKED_01');
      expect(lockedSlot.unlockTier, 2);
      expect(lockedSlot.unlocked, false);
      expect(lockedSlot.isLocked, true);
      expect(lockedSlot.isEmpty, false);
      expect(lockedSlot.isOccupied, false);
      expect(lockedSlot.placement, isNull);
    });

    test('Empty IslandDto defaults correctly for new user', () {
      final island = IslandDto.fromJson({});

      expect(island.tier, 1);
      expect(island.maxTier, 3);
      expect(island.revision, 0);
      expect(island.progress.completedEvents, 0);
      expect(island.progress.nextTierRequiredEvents, 0);
      expect(island.progress.canUpgrade, false);
      expect(island.slots, isEmpty);
    });

    test('IslandProgressDto progressFraction edge cases', () {
      const zeroReq = IslandProgressDto(
        completedEvents: 0,
        nextTierRequiredEvents: 0,
      );
      expect(zeroReq.progressFraction, 1.0);

      const half = IslandProgressDto(
        completedEvents: 1,
        nextTierRequiredEvents: 2,
      );
      expect(half.progressFraction, 0.5);

      const clamped = IslandProgressDto(
        completedEvents: 5,
        nextTierRequiredEvents: 2,
      );
      expect(clamped.progressFraction, 1.0);
    });

    test('ShopItemDto parsing and asset resolution', () {
      // Backend now uses pricePoints (not price) and purchasable (not currency/owned).
      // Legacy 'price' field is still accepted as fallback for mocks.
      final json = {
        'itemId': 'item-cay-da-001',
        'code': 'decor_cay_da',
        'name': 'Cây Đa Di Sản',
        'description': 'Cây đa cổ thụ.',
        'category': 'DECOR',
        'pricePoints': 100,
        'purchasable': true,
        'owned': true,
        'renderKey': 'decor_cay_da',
        'placeable': true,
      };

      final item = ShopItemDto.fromJson(json);

      expect(item.itemId, 'item-cay-da-001');
      expect(item.code, 'decor_cay_da');
      expect(item.name, 'Cây Đa Di Sản');
      expect(item.price, 100); // getter delegates to pricePoints
      expect(item.pricePoints, 100);
      expect(item.purchasable, true);
      expect(item.owned, true);
      expect(item.placeable, true);
      expect(item.assetPath, 'assets/items/decor_cay_da.png');
    });

    test('WalletDto parsing handles different server field conventions', () {
      final w1 = WalletDto.fromJson({'historyPoints': 350, 'exp': 1000});
      expect(w1.historyPoints, 350);
      expect(w1.exp, 1000);

      final w2 = WalletDto.fromJson({'points': 420});
      expect(w2.historyPoints, 420);

      final w3 = WalletDto.fromJson({'balance': 500});
      expect(w3.historyPoints, 500);

      final wNull = WalletDto.fromJson(null);
      expect(wNull.historyPoints, 0);
    });

    test(
      'resolveIslandAsset resolves correct asset for all 4 decor items and fallback',
      () {
        expect(
          resolveIslandAsset('decor_nha_tranh', null),
          'assets/items/decor_nha_tranh.png',
        );
        expect(
          resolveIslandAsset(null, 'decor_cau_kieu'),
          'assets/items/decor_cau_kieu.png',
        );
        expect(
          resolveIslandAsset('decor_ho_sen', null),
          'assets/items/decor_ho_sen.png',
        );
        expect(
          resolveIslandAsset('decor_cay_da', null),
          'assets/items/decor_cay_da.png',
        );
        expect(
          resolveIslandAsset('unknown_code', 'unknown'),
          isNull,
        );
      },
    );

    test(
      'Issue #50: tierHeritageName (Đảo Nhỏ / Đảo Vừa / Đảo Lớn), 2x2/1x1 footprint, and 4-category classification',
      () {
        expect(IslandDto.tierHeritageName(1, 'tier.small'), 'Đảo Nhỏ');
        expect(IslandDto.tierHeritageName(2, 'tier.medium'), 'Đảo Vừa');
        expect(IslandDto.tierHeritageName(3, 'tier.grand'), 'Đảo Lớn');

        expect(
          IslandDto.kabiGuideTextForTier(1),
          contains('Đây là Đảo Nhỏ của bạn!'),
        );
        expect(
          IslandDto.kabiGuideTextForTier(2),
          contains('Đây là Đảo Vừa của bạn!'),
        );

        // Category classification
        expect(
          resolveIslandItemCategory(code: 'DECOR_NHA_RONG'),
          IslandInventoryCategory.building,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_CHUA_CO'),
          IslandInventoryCategory.building,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_THAP_CHAM'),
          IslandInventoryCategory.building,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_CAY_DA'),
          IslandInventoryCategory.tree,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_TRE_TRUC'),
          IslandInventoryCategory.tree,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_COT_CO'),
          IslandInventoryCategory.decoration,
        );
        expect(
          resolveIslandItemCategory(code: 'DECOR_TUONG_LY_THAI_TO'),
          IslandInventoryCategory.decoration,
        );

        // Footprint 2x2 vs 1x1
        expect(resolveIslandItemFootprint('DECOR_NHA_RONG', null), (2, 2));
        expect(resolveIslandItemFootprintLabel('DECOR_NHA_RONG', null), '2x2');
        expect(resolveIslandItemFootprint('DECOR_CAY_DA', null), (2, 2));
        expect(resolveIslandItemFootprintLabel('DECOR_COT_CO', null), '1x1');
        expect(resolveIslandItemPricePoints('DECOR_CAY_DA', null), 50);

        // Visual footprint scale: 2x2 building/banyan > medium > 1x1 decor
        final buildingScale =
            resolveIslandItemVisualScale('DECOR_NHA_RONG', 'decor.nha_rong');
        final bambooScale =
            resolveIslandItemVisualScale('DECOR_TRE_TRUC', 'decor.tre_truc');
        final decorScale =
            resolveIslandItemVisualScale('DECOR_COT_CO', 'decor.cot_co');
        expect(buildingScale, greaterThan(bambooScale));
        expect(bambooScale, greaterThan(decorScale));

        // Short card labels for 4-column inventory grid
        expect(
          shortIslandItemDisplayName('Nhà rông', 'DECOR_NHA_RONG', null),
          'Nhà rông',
        );
        expect(
          shortIslandItemDisplayName('Đình Làng Mái Đao', 'DECOR_DINH_LANG', null),
          'Đình làng',
        );
        expect(
          shortIslandItemDisplayName('Cây Đa Cổ Thụ', 'DECOR_CAY_DA', null),
          'Cây đa',
        );
        expect(
          shortIslandItemDisplayName('Tượng Lý Thái Tổ', 'DECOR_TUONG_LY_THAI_TO', null),
          'Bức tượng',
        );
      },
    );
  });
}
