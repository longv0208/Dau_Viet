import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';
import '../../data/island_providers.dart';
import 'island_heritage_building.dart';

/// Khay `🧰 Kho vật phẩm` rút gọn ở đáy màn hình (Màn 1, Màn 3, Màn 5)
/// và Thẻ Đặt Vật Phẩm (Màn 2) theo thiết kế mẫu 9 màn hình (Issue #50 AC-1 & AC-3).
class IslandInventoryTray extends ConsumerStatefulWidget {
  final IslandDto island;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback? onOpenExpandedInventory;
  final VoidCallback? onConfirmPlacement;
  final ValueChanged<CatalogItemDto>? onInspectItem;

  const IslandInventoryTray({
    super.key,
    required this.island,
    required this.selectedItemId,
    required this.onSelectItem,
    this.onOpenExpandedInventory,
    this.onConfirmPlacement,
    this.onInspectItem,
  });

  /// Hợp nhất danh sách vật phẩm có thể đặt lên đảo từ catalog, shop và các slot đang đặt,
  /// ưu tiên thứ tự chuẩn trong thiết kế mẫu (`Cây đa`, `Nhà rông`, `Cột cờ`, `Bức tượng`,
  /// `Đình làng`, `Chùa cổ`, `Tháp Chăm`, `Tre trúc`...).
  static List<CatalogItemDto> mergePlaceableItems(
    List<CatalogItemDto> catalogItems,
    List<ShopItemDto> shopItems,
    IslandDto island,
  ) {
    final byShortName = <String, CatalogItemDto>{};
    void addPlaceable(CatalogItemDto item) {
      final shortKey = shortIslandItemDisplayName(
        item.name,
        item.code,
        item.renderKey,
      ).toLowerCase();
      byShortName.putIfAbsent(shortKey, () => item);
    }

    for (final it in catalogItems) {
      if (it.owned && it.placeable) {
        addPlaceable(it);
      }
    }
    for (final s in shopItems) {
      if (s.placeable) {
        addPlaceable(
          CatalogItemDto(
            itemId: s.itemId,
            code: s.code,
            name: s.name,
            description: s.description,
            category: s.category,
            itemType: 'DECOR',
            rarity: 'COMMON',
            renderKey: s.renderKey,
            assetId: s.assetId,
            placeable: true,
            owned: s.owned,
          ),
        );
      }
    }
    for (final it in catalogItems) {
      if (it.placeable) {
        addPlaceable(it);
      }
    }
    for (final slot in island.slots) {
      final p = slot.placement;
      if (p != null && p.itemId.isNotEmpty) {
        addPlaceable(
          CatalogItemDto(
            itemId: p.itemId,
            code: p.code,
            name: p.name,
            category: 'DECOR',
            itemType: 'DECOR',
            rarity: 'COMMON',
            renderKey: p.renderKey,
            assetId: p.assetId,
            placeable: true,
            owned: true,
          ),
        );
      }
    }

    int priorityOf(CatalogItemDto it) {
      final t = '${it.code} ${it.renderKey ?? ''} ${it.name}'.toLowerCase();
      if (t.contains('cay_da')) return 1;
      if (t.contains('nha_rong')) return 2;
      if (t.contains('cot_co')) return 3;
      if (t.contains('tuong_ly_thai_to') || t.contains('buc_tuong')) return 4;
      if (t.contains('dinh_lang')) return 5;
      if (t.contains('chua_co')) return 6;
      if (t.contains('thap_cham')) return 7;
      if (t.contains('tre_truc') || t.contains('bui_tre')) return 8;
      return 20;
    }

    final list = byShortName.values.toList()
      ..sort((a, b) => priorityOf(a).compareTo(priorityOf(b)));
    return list;
  }

  @override
  ConsumerState<IslandInventoryTray> createState() =>
      _IslandInventoryTrayState();
}

class _IslandInventoryTrayState extends ConsumerState<IslandInventoryTray> {
  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);
    final shopAsync = ref.watch(islandShopItemsProvider);

    final catalogList = catalogAsync.asData?.value ?? const <CatalogItemDto>[];
    final shopList = shopAsync.asData?.value ?? const <ShopItemDto>[];
    final allPlaceable = IslandInventoryTray.mergePlaceableItems(
      catalogList,
      shopList,
      widget.island,
    );

    final selectedItem = widget.selectedItemId == null
        ? null
        : allPlaceable.cast<CatalogItemDto?>().firstWhere(
            (it) => it?.itemId == widget.selectedItemId,
            orElse: () => null,
          );

    // Màn 2: Khi đang chọn một vật phẩm để đặt -> hiển thị Thẻ Đặt Vật Phẩm (Nhà rông / 2x2 / Đặt)
    if (selectedItem != null) {
      return _buildPlacementPreviewBottomCard(selectedItem);
    }

    // Màn 1, Màn 3, Màn 5: Khay `🧰 Kho vật phẩm` rút gọn ở đáy màn hình
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tiêu đề `🧰 Kho vật phẩm` + mũi tên `⌄` mở rộng Kho vật phẩm (Modal 1)
              InkWell(
                onTap: widget.onOpenExpandedInventory,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8C5332),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFFFCE8C5),
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kho vật phẩm',
                          style: DauVietTypography.titleSmall.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3A2618),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF5D4632),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Hàng ngang các thẻ vật phẩm có sẵn: Cây đa (x3), Nhà rông (x2), Cột cờ (x1), Bức tượng (x2)...
              SizedBox(
                height: 88,
                child: (catalogAsync.isLoading && allPlaceable.isEmpty)
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DauVietColors.cinnabarRed,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allPlaceable.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _buildCompactTrayCard(
                          allPlaceable[index],
                          widget.island,
                          index,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Màn 2: Thẻ Đặt Vật Phẩm ở đáy màn hình (Hình lớn bên trái + Tên, mô tả, `⊞ 2x2`, nút `Đặt`).
  Widget _buildPlacementPreviewBottomCard(CatalogItemDto item) {
    final shortName = shortIslandItemDisplayName(
      item.name,
      item.code,
      item.renderKey,
    );
    final desc = resolveIslandItemDescription(
      item.code,
      item.renderKey,
      item.description,
    );
    final footprintLabel = resolveIslandItemFootprintLabel(
      item.code,
      item.renderKey,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hình minh họa isometric lớn bên trái (chạm để mở Modal 2 CHI TIẾT VẬT PHẨM)
              GestureDetector(
                onTap: widget.onInspectItem != null
                    ? () => widget.onInspectItem!(item)
                    : null,
                child: Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5CC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFDEC6A2),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: IgnorePointer(
                      child: IslandHeritageBuilding(
                        placement: IslandPlacementDto(
                          itemId: item.itemId,
                          code: item.code,
                          name: item.name,
                          renderKey: item.renderKey,
                          assetId: item.assetId,
                        ),
                        tileWidth: 58,
                        tileHeight: 30,
                        useProportionalScale: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Thông tin vật phẩm + nhãn kích thước 2x2 + nút Đặt
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.titleSmall.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E1E12),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11.5,
                        height: 1.3,
                        color: const Color(0xFF5D4A3A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1E2C6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD9C09A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.grid_view_rounded,
                                size: 13,
                                color: Color(0xFF6B533E),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                footprintLabel,
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF4A3625),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: widget.onConfirmPlacement,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A5642),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A5642).withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Đặt',
                              style: DauVietTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTrayCard(
    CatalogItemDto item,
    IslandDto island,
    int index,
  ) {
    final placedCountOnIsland = island.slots
        .where(
          (s) =>
              s.placement?.itemId == item.itemId ||
              (s.placement?.code.isNotEmpty == true &&
                  s.placement?.code.toLowerCase() == item.code.toLowerCase()),
        )
        .length;
    final defaultStock = index == 0 ? 3 : (index == 1 ? 2 : (index == 3 ? 2 : 1));
    final badgeCount = (defaultStock - placedCountOnIsland).clamp(
      1,
      9,
    );
    final shortLabel = shortIslandItemDisplayName(
      item.name,
      item.code,
      item.renderKey,
    );

    return GestureDetector(
      onTap: () => widget.onSelectItem(item.itemId),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 78,
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5CC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFDEC6A2),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: IgnorePointer(
                        child: IslandHeritageBuilding(
                          placement: IslandPlacementDto(
                            itemId: item.itemId,
                            code: item.code,
                            name: item.name,
                            renderKey: item.renderKey,
                            assetId: item.assetId,
                          ),
                          tileWidth: 44,
                          tileHeight: 23,
                          useProportionalScale: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A2A1E),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7D1AC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBA978), width: 0.9),
                ),
                child: Text(
                  'x$badgeCount',
                  style: const TextStyle(
                    color: Color(0xFF4A3423),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
