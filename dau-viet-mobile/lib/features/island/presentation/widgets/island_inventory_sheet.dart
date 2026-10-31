import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';
import '../../data/island_providers.dart';
import 'island_heritage_building.dart';
import 'island_inventory_item_card.dart';
import 'island_inventory_tray.dart';

/// Modal 1 — `KHO VẬT PHẨM` (Expanded Inventory Sheet) theo thiết kế 9 màn hình (Issue #50 AC-5):
/// - Tiêu đề `KHO VẬT PHẨM` + nút đóng `✕`.
/// - 4 tab lọc dạng pill: `Tất cả` (active nền xanh `#1A5642`), `Công trình`, `Cây cối`, `Trang trí`.
/// - Lưới 4 cột hiển thị các thẻ vật phẩm: `Nhà rông`, `Đình làng`, `Chùa cổ`, `Tháp Chăm`,
///   `Cây đa`, `Tre trúc`, `Cột cờ`, `Bức tượng`...
/// - Chạm vào thẻ vật phẩm mở Modal 2 — `CHI TIẾT VẬT PHẨM` (`IslandItemDetailSheet`).
class IslandInventorySheet extends ConsumerStatefulWidget {
  final IslandSlotDto? targetSlot;
  final ValueChanged<String> onSelectItem;

  const IslandInventorySheet({
    super.key,
    this.targetSlot,
    required this.onSelectItem,
  });

  @override
  ConsumerState<IslandInventorySheet> createState() =>
      _IslandInventorySheetState();
}

class _IslandInventorySheetState extends ConsumerState<IslandInventorySheet> {
  IslandInventoryCategory _selectedCategory = IslandInventoryCategory.all;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);
    final shopAsync = ref.watch(islandShopItemsProvider);
    final inventoryAsync = ref.watch(inventoryItemsProvider);
    final islandState = ref.watch(islandControllerProvider).asData?.value;

    final catalogList = catalogAsync.asData?.value ?? const <CatalogItemDto>[];
    final shopList = shopAsync.asData?.value ?? const <ShopItemDto>[];
    final inventoryList =
        inventoryAsync.asData?.value ?? const <InventoryItemDto>[];
    final allPlaceable = islandState != null
        ? IslandInventoryTray.mergePlaceableItems(
            catalogList,
            shopList,
            islandState,
            inventoryItems: inventoryList,
          )
        : catalogList.where((it) => it.placeable).toList();

    final filteredItems = _selectedCategory == IslandInventoryCategory.all
        ? allPlaceable
        : allPlaceable.where((it) {
            final cat = resolveIslandItemCategory(
              code: it.code,
              renderKey: it.renderKey,
              category: it.category,
              itemType: it.itemType,
            );
            if (_selectedCategory == IslandInventoryCategory.decoration &&
                cat == IslandInventoryCategory.other) {
              return true;
            }
            return cat == _selectedCategory;
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header: KHO VẬT PHẨM + nút đóng ✕
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'KHO VẬT PHẨM',
                      style: DauVietTypography.titleSmall.copyWith(
                        color: const Color(0xFF3A2618),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF5A4635),
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. 4 Tab lọc dạng Pill: Tất cả, Công trình, Cây cối, Trang trí
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: Row(
                children: [
                  for (int i = 0;
                      i < IslandInventoryCategory.modalTabs.length;
                      i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _buildCategoryPill(
                        IslandInventoryCategory.modalTabs[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Lưới 4 cột hiển thị các thẻ vật phẩm
            Flexible(
              child: (catalogAsync.isLoading && allPlaceable.isEmpty)
                  ? const SizedBox(
                      height: 160,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: DauVietColors.cinnabarRed,
                        ),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? SizedBox(
                          height: 140,
                          child: Center(
                            child: Text(
                              'Chưa có vật phẩm trong nhóm "${_selectedCategory.labelVi}".',
                              style: DauVietTypography.bodySmall.copyWith(
                                color: const Color(0xFF6E5A49),
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.84,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) => _buildGridCard(
                            context,
                            filteredItems[index],
                            shopList,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(IslandInventoryCategory category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A5642)
              : const Color(0xFFF3E6CE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF123F30)
                : const Color(0xFFE0CDA9),
          ),
        ),
        child: Text(
          category.labelVi,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF4E3B2B),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    CatalogItemDto item,
    List<ShopItemDto> shopItems,
  ) {
    final matchedShop = shopItems.cast<ShopItemDto?>().firstWhere(
      (s) =>
          s?.itemId == item.itemId ||
          s?.code.toLowerCase() == item.code.toLowerCase(),
      orElse: () => null,
    );

    return InventoryItemCard(
      item: item,
      width: double.infinity,
      isLocked: !item.owned,
      onTap: () async {
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => IslandItemDetailSheet(
            item: item,
            pricePoints: matchedShop?.pricePoints,
            onPlaceOnIsland: () => Navigator.of(ctx).pop(true),
          ),
        );
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop();
          widget.onSelectItem(item.itemId);
        }
      },
    );
  }
}

/// Modal 2 — `CHI TIẾT VẬT PHẨM` (Item Detail Sheet) theo thiết kế 9 màn hình (Issue #50 AC-5):
/// - Tiêu đề `CHI TIẾT VẬT PHẨM` + nút đóng `✕`.
/// - Bên trái: Hình minh họa lớn sắc nét (ví dụ `Cây đa cổ thụ`).
/// - Bên phải: Tên vật phẩm, mô tả văn hóa lịch sử, `Kích thước: 2x2`, giá/điểm `⭐ 50`.
/// - Nút CTA lớn full-width ở đáy: `Đặt lên đảo`.
class IslandItemDetailSheet extends StatelessWidget {
  final CatalogItemDto item;
  final int? pricePoints;
  final VoidCallback onPlaceOnIsland;

  const IslandItemDetailSheet({
    super.key,
    required this.item,
    this.pricePoints,
    required this.onPlaceOnIsland,
  });

  @override
  Widget build(BuildContext context) {
    final token = '${item.code} ${item.renderKey ?? ''} ${item.name}'
        .toLowerCase();
    final displayTitle = token.contains('cay_da')
        ? 'Cây đa cổ thụ'
        : shortIslandItemDisplayName(item.name, item.code, item.renderKey);
    final description = resolveIslandItemDescription(
      item.code,
      item.renderKey,
      item.description,
    );
    final footprintLabel = resolveIslandItemFootprintLabel(
      item.code,
      item.renderKey,
    );
    final points = resolveIslandItemPricePoints(
      item.code,
      item.renderKey,
      pricePoints,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CHI TIẾT VẬT PHẨM',
                    style: DauVietTypography.titleSmall.copyWith(
                      color: const Color(0xFF3A2618),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF5A4635),
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE5D3B3), height: 14),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E6CE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFDFC8A2),
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
                        tileWidth: 74,
                        tileHeight: 38,
                        useProportionalScale: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: DauVietTypography.titleSmall.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2E1E12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 12,
                          height: 1.35,
                          color: const Color(0xFF5D4A3A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kích thước: $footprintLabel',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3E2D20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFE6A117),
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$points',
                            style: DauVietTypography.bodyMedium.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF3E2D20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: item.owned
                    ? onPlaceOnIsland
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vật phẩm này chưa mở khóa. Hãy hoàn thành bài học hoặc mua tại Cửa hàng.',
                            ),
                            backgroundColor: Color(0xFF5A4635),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5642),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: Text(
                  'Đặt lên đảo',
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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
