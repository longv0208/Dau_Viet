import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';
import '../../data/island_providers.dart';

enum _InventoryFilter { all, placeable, placed, unplaced }

/// Bottom sheet chọn vật phẩm từ Túi Đồ để đặt lên một ô trên Đảo Di Sản.
class IslandInventorySheet extends ConsumerStatefulWidget {
  final IslandSlotDto targetSlot;
  final ValueChanged<String> onSelectItem;

  const IslandInventorySheet({
    super.key,
    required this.targetSlot,
    required this.onSelectItem,
  });

  @override
  ConsumerState<IslandInventorySheet> createState() =>
      _IslandInventorySheetState();
}

class _IslandInventorySheetState extends ConsumerState<IslandInventorySheet> {
  _InventoryFilter _selectedFilter = _InventoryFilter.placeable;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);
    final islandState = ref.watch(islandControllerProvider).asData?.value;

    // Tập hợp các item_id đang được đặt trên đảo
    final placedItemIds =
        islandState?.slots
            .map((s) => s.placement?.itemId)
            .whereType<String>()
            .toSet() ??
        {};

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Drag Handle & Title
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: DauVietColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KHO VẬT PHẨM TRANG TRÍ',
                        style: DauVietTypography.headlineSmall.copyWith(
                          color: DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn vật phẩm đặt vào Ô #${widget.targetSlot.zIndex > 0 ? widget.targetSlot.zIndex : widget.targetSlot.slotId.substring(0, widget.targetSlot.slotId.length.clamp(0, 8))}',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: DauVietColors.inkMuted,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 2. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Có thể đặt', _InventoryFilter.placeable),
                const SizedBox(width: 8),
                _buildFilterChip('Chưa đặt', _InventoryFilter.unplaced),
                const SizedBox(width: 8),
                _buildFilterChip('Đang đặt', _InventoryFilter.placed),
                const SizedBox(width: 8),
                _buildFilterChip('Tất cả', _InventoryFilter.all),
              ],
            ),
          ),
          const Divider(height: 16, color: DauVietColors.outlineVariant),

          // 3. Grid danh sách vật phẩm
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: DauVietColors.cinnabarRed,
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: DauVietColors.inkMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải dữ liệu Túi đồ',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Tactile3DButton(
                        label: 'THỬ LẠI',
                        variant: Tactile3DVariant.secondaryParchment,
                        onPressed: () =>
                            ref.invalidate(inventoryCatalogProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (catalog) {
                // Lọc vật phẩm trang trí
                final decorItems = _filterItems(catalog, placedItemIds);

                if (decorItems.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 54,
                            color: DauVietColors.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _emptyMessage(),
                            textAlign: TextAlign.center,
                            style: DauVietTypography.bodyMedium.copyWith(
                              color: DauVietColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: decorItems.length,
                  itemBuilder: (context, index) {
                    final item = decorItems[index];
                    final isPlaced = placedItemIds.contains(item.itemId);
                    final isCurrentSlotItem =
                        widget.targetSlot.placement?.itemId == item.itemId;

                    return _buildItemCard(
                      item: item,
                      isPlaced: isPlaced,
                      isCurrentSlotItem: isCurrentSlotItem,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _InventoryFilter filter) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filter);
      },
      selectedColor: DauVietColors.heritageGreen,
      backgroundColor: DauVietColors.parchmentContainer,
      labelStyle: DauVietTypography.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : DauVietColors.inkText,
      ),
      side: BorderSide(
        color: isSelected
            ? DauVietColors.heritageGreen
            : DauVietColors.outlineVariant,
      ),
    );
  }

  List<CatalogItemDto> _filterItems(
    List<CatalogItemDto> catalog,
    Set<String> placedItemIds,
  ) {
    // Chỉ hiển thị item category DECOR hoặc có code decor_* mà user đang sở hữu.
    // Không fallback sang toàn bộ catalog — trong chế độ thực, catalog chứa
    // mọi item (kể cả chưa mua); chỉ lấy những gì đã owned + là decor.
    final decorPool = catalog.where((item) {
      final isDecorCategory = item.category.toUpperCase() == 'DECOR';
      final isDecorCode = item.code.toLowerCase().startsWith('decor_');
      return isDecorCategory || isDecorCode;
    }).toList();

    return decorPool.where((item) {
      final isPlaced = placedItemIds.contains(item.itemId);

      switch (_selectedFilter) {
        case _InventoryFilter.all:
          return true;
        case _InventoryFilter.placeable:
          return item.owned;
        case _InventoryFilter.placed:
          return item.owned && isPlaced;
        case _InventoryFilter.unplaced:
          return item.owned && !isPlaced;
      }
    }).toList();
  }

  String _emptyMessage() {
    switch (_selectedFilter) {
      case _InventoryFilter.placed:
        return 'Chưa có vật phẩm nào đang đặt trên đảo.';
      case _InventoryFilter.unplaced:
        return 'Không còn vật phẩm trang trí rảnh rỗi trong kho. Bạn có thể ghé Cửa Hàng để mua thêm!';
      case _InventoryFilter.placeable:
      case _InventoryFilter.all:
        return 'Bạn chưa sở hữu vật phẩm trang trí nào. Hãy ghé Cửa Hàng Điểm Sử Ký để mua đồ trang trí nhé!';
    }
  }

  Widget _buildItemCard({
    required CatalogItemDto item,
    required bool isPlaced,
    required bool isCurrentSlotItem,
  }) {
    final assetPath = resolveIslandAsset(null, item.code, item.assetId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentSlotItem
              ? DauVietColors.cinnabarRed
              : DauVietColors.outlineVariant,
          width: isCurrentSlotItem ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ảnh vật phẩm
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance_rounded,
                    size: 48,
                    color: DauVietColors.woodBrown,
                  ),
                ),
                if (!item.owned)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                if (isPlaced)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.woodBrown,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Đang đặt',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Tên vật phẩm
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: DauVietColors.inkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.owned ? 'Đã sở hữu' : 'Chưa mở khóa',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: item.owned
                  ? DauVietColors.natureGreen
                  : DauVietColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Nút đặt
          SizedBox(
            height: 34,
            child: item.owned
                ? Tactile3DButton(
                    label: isCurrentSlotItem ? 'ĐANG Ở Ô NÀY' : 'ĐẶT',
                    height: 34,
                    depth: 2,
                    variant: isCurrentSlotItem
                        ? Tactile3DVariant.secondaryParchment
                        : Tactile3DVariant.heritageGreen,
                    onPressed: isCurrentSlotItem
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onSelectItem(item.itemId);
                          },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
