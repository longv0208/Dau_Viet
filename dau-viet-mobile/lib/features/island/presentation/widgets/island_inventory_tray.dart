import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';
import '../../data/island_providers.dart';
import 'island_heritage_building.dart';

/// Khay Kho Vật Phẩm Phân loại 5 Tab & Lưới Thẻ Vuông 4 Cột (Issue #46 AC-4).
/// - Thanh Filter Chips: `Tất cả`, `Công trình`, `Cây cối`, `Trang trí`, `Khác`.
/// - Lưới 4 cột thẻ vật phẩm trên nền giấy kem: hình minh họa isometric,
///   tên vật phẩm bên dưới và huy hiệu tròn số lượng góc trên phải.
class IslandInventoryTray extends ConsumerStatefulWidget {
  final IslandDto island;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;

  const IslandInventoryTray({
    super.key,
    required this.island,
    required this.selectedItemId,
    required this.onSelectItem,
  });

  @override
  ConsumerState<IslandInventoryTray> createState() =>
      _IslandInventoryTrayState();
}

class _IslandInventoryTrayState extends ConsumerState<IslandInventoryTray> {
  IslandInventoryCategory _selectedCategory = IslandInventoryCategory.all;
  List<CatalogItemDto> _mergePlaceableItems(
    List<CatalogItemDto> catalogItems,
    List<ShopItemDto> shopItems,
    IslandDto island,
  ) {
    final byCode = <String, CatalogItemDto>{};
    for (final it in catalogItems) {
      if (it.owned && it.placeable) {
        final key = it.code.trim().toLowerCase();
        byCode[key.isNotEmpty ? key : it.itemId] = it;
      }
    }
    for (final s in shopItems) {
      if (s.owned && s.placeable) {
        final key = s.code.trim().toLowerCase();
        final mapKey = key.isNotEmpty ? key : s.itemId;
        byCode.putIfAbsent(
          mapKey,
          () => CatalogItemDto(
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
            owned: true,
          ),
        );
      }
    }
    for (final slot in island.slots) {
      final p = slot.placement;
      if (p != null && p.itemId.isNotEmpty) {
        final key = p.code.trim().toLowerCase();
        final mapKey = key.isNotEmpty ? key : p.itemId;
        byCode.putIfAbsent(
          mapKey,
          () => CatalogItemDto(
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
    return byCode.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);
    final shopAsync = ref.watch(islandShopItemsProvider);

    final unlockedSlots =
        widget.island.slots.where((s) => s.unlocked).length;
    final placedCount =
        widget.island.slots.where((s) => s.placement != null).length;

    final catalogList = catalogAsync.asData?.value ?? const <CatalogItemDto>[];
    final shopList = shopAsync.asData?.value ?? const <ShopItemDto>[];
    final allPlaceable =
        _mergePlaceableItems(catalogList, shopList, widget.island);

    final filteredItems = _selectedCategory == IslandInventoryCategory.all
        ? allPlaceable
        : allPlaceable.where((it) {
            final cat = resolveIslandItemCategory(
              code: it.code,
              renderKey: it.renderKey,
              category: it.category,
              itemType: it.itemType,
            );
            return cat == _selectedCategory;
          }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF1E0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC9A8), width: 1.5),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thanh 5 Filter Chips theo danh mục: Tất cả, Công trình, Cây cối, Trang trí, Khác
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(
                children: [
                  for (int i = 0; i < IslandInventoryCategory.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _buildCategoryFilterChip(
                        IslandInventoryCategory.values[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Dòng thông tin phụ nhỏ gọn (giữ khả năng truy vết số lượng đã đặt)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kho vật phẩm của bạn (chạm chọn vật phẩm rồi chạm ô đất để đặt nhiều bản sao)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF7D6B59),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$placedCount/$unlockedSlots đã đặt',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E4D3B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 2. Lưới thẻ vật phẩm 4 cột (Issue #46 AC-4)
            Flexible(
              child: (catalogAsync.isLoading && allPlaceable.isEmpty)
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DauVietColors.cinnabarRed,
                          ),
                        ),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? SizedBox(
                          height: 110,
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Chưa có vật phẩm trong danh mục "${_selectedCategory.labelVi}".',
                                textAlign: TextAlign.center,
                                style: DauVietTypography.bodySmall.copyWith(
                                  color: DauVietColors.inkMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.94,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) => _buildGridItemCard(
                            filteredItems[index],
                            widget.island,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(IslandInventoryCategory category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E4D3B)
              : const Color(0xFFF3E6CE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF14382A)
                : const Color(0xFFE0CDA9),
            width: 1.0,
          ),
        ),
        child: Text(
          category.labelVi,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF4E3B2B),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItemCard(CatalogItemDto item, IslandDto island) {
    final isSelected = widget.selectedItemId == item.itemId;
    final placedCountOnIsland = island.slots
        .where(
          (s) =>
              s.placement?.itemId == item.itemId ||
              (s.placement?.code.isNotEmpty == true &&
                  s.placement?.code.toLowerCase() == item.code.toLowerCase()),
        )
        .length;
    final badgeCount = placedCountOnIsland > 0 ? placedCountOnIsland : 1;
    final shortLabel = shortIslandItemDisplayName(
      item.name,
      item.code,
      item.renderKey,
    );

    return GestureDetector(
      onTap: () => widget.onSelectItem(isSelected ? null : item.itemId),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE6F3EC)
              : const Color(0xFFF4E7CE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E4D3B)
                : const Color(0xFFDFC9A6),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
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
                          tileWidth: 42,
                          tileHeight: 22,
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

            // Huy hiệu tròn góc trên phải hiển thị số lượng
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1E4D3B)
                      : const Color(0xFF5A4635),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
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
