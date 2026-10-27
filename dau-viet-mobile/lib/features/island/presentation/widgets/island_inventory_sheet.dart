import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';
import '../../data/island_providers.dart';

enum _InventoryFilter { placeable, unplaced, placed, owned, all }

enum _TypeFilter { all, decor, replica }

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
  _TypeFilter _selectedTypeFilter = _TypeFilter.all;

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
        maxHeight: MediaQuery.of(context).size.height * 0.78,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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

          // 2. Filter Chips (Trạng thái)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                _buildFilterChip('Có thể đặt', _InventoryFilter.placeable),
                const SizedBox(width: 8),
                _buildFilterChip('Chưa đặt', _InventoryFilter.unplaced),
                const SizedBox(width: 8),
                _buildFilterChip('Đang đặt', _InventoryFilter.placed),
                const SizedBox(width: 8),
                _buildFilterChip('Đã sở hữu', _InventoryFilter.owned),
                const SizedBox(width: 8),
                _buildFilterChip('Tất cả', _InventoryFilter.all),
              ],
            ),
          ),

          // 2b. Filter Chips (Loại vật phẩm)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                _buildTypeChip('Tất cả loại', _TypeFilter.all),
                const SizedBox(width: 8),
                _buildTypeChip('Trang trí (DECOR)', _TypeFilter.decor),
                const SizedBox(width: 8),
                _buildTypeChip('Mô hình (REPLICA)', _TypeFilter.replica),
              ],
            ),
          ),
          const Divider(height: 12, color: DauVietColors.outlineVariant),

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
                        onPressed: () {
                          ref.invalidate(inventoryCatalogProvider);
                          ref.invalidate(inventoryItemsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              data: (catalog) {
                final filteredItems = _filterItems(catalog, placedItemIds);

                if (filteredItems.isEmpty) {
                  final hasAnyOwnedPlaceable = catalog.any(
                    (it) => it.owned && it.placeable,
                  );
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: DauVietColors.inkMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasAnyOwnedPlaceable
                                ? _emptyMessage()
                                : 'Kho của bạn hiện chưa có vật phẩm trang trí nào.',
                            textAlign: TextAlign.center,
                            style: DauVietTypography.bodyMedium.copyWith(
                              color: DauVietColors.inkText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasAnyOwnedPlaceable
                                ? 'Bạn có thể đổi bộ lọc hoặc ghé Cửa Hàng Di Sản để sưu tầm thêm.'
                                : 'Hãy dùng Điểm Sử Ký mua vật phẩm tại Cửa Hàng Di Sản hoặc hoàn thành bài học lịch sử để nhận phần thưởng.',
                            textAlign: TextAlign.center,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.inkMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              SizedBox(
                                width: 170,
                                child: Tactile3DButton(
                                  label: 'ĐẾN CỬA HÀNG',
                                  height: 38,
                                  icon: Icons.storefront_rounded,
                                  variant: Tactile3DVariant.primaryCinnabar,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    context.push('/island/shop');
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: Tactile3DButton(
                                  label: 'HÀNH TRÌNH HỌC',
                                  height: 38,
                                  icon: Icons.school_rounded,
                                  variant: Tactile3DVariant.secondaryParchment,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    context.go('/dashboard');
                                  },
                                ),
                              ),
                            ],
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
                    childAspectRatio: 0.76,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isPlaced =
                        placedItemIds.contains(item.itemId) ||
                        item.placedSlotId != null;
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

  Widget _buildTypeChip(String label, _TypeFilter typeFilter) {
    final isSelected = _selectedTypeFilter == typeFilter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedTypeFilter = typeFilter);
      },
      selectedColor: DauVietColors.woodBrown,
      backgroundColor: DauVietColors.parchmentContainer,
      labelStyle: DauVietTypography.bodySmall.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : DauVietColors.inkText,
      ),
      side: BorderSide(
        color: isSelected
            ? DauVietColors.woodBrown
            : DauVietColors.outlineVariant,
      ),
    );
  }

  bool _isAllowedInTargetSlot(CatalogItemDto item) {
    final allowed = widget.targetSlot.allowedCategories
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet();
    if (allowed.isEmpty) return true;
    final cat = item.category.trim().toUpperCase();
    final type = item.itemType.trim().toUpperCase();
    return allowed.contains(cat) || allowed.contains(type);
  }

  List<CatalogItemDto> _filterItems(
    List<CatalogItemDto> catalog,
    Set<String> placedItemIds,
  ) {
    final byType = catalog.where((item) {
      switch (_selectedTypeFilter) {
        case _TypeFilter.all:
          return item.placeable ||
              item.category.toUpperCase() == 'DECOR' ||
              item.itemType.toUpperCase() == 'DECOR' ||
              item.itemType.toUpperCase() == 'HISTORICAL_REPLICA';
        case _TypeFilter.decor:
          return item.category.toUpperCase() == 'DECOR' ||
              item.itemType.toUpperCase() == 'DECOR';
        case _TypeFilter.replica:
          return item.itemType.toUpperCase() == 'HISTORICAL_REPLICA';
      }
    }).toList();

    return byType.where((item) {
      final isPlaced =
          placedItemIds.contains(item.itemId) || item.placedSlotId != null;

      switch (_selectedFilter) {
        case _InventoryFilter.placeable:
          return item.owned && item.placeable && !isPlaced;
        case _InventoryFilter.unplaced:
          return item.owned && !isPlaced;
        case _InventoryFilter.placed:
          return item.owned && isPlaced;
        case _InventoryFilter.owned:
          return item.owned;
        case _InventoryFilter.all:
          return true;
      }
    }).toList();
  }

  String _emptyMessage() {
    switch (_selectedFilter) {
      case _InventoryFilter.placed:
        return 'Chưa có vật phẩm nào đang đặt trên đảo.';
      case _InventoryFilter.placeable:
      case _InventoryFilter.unplaced:
        return 'Không còn vật phẩm trang trí rảnh rỗi trong kho. Bạn có thể ghé Cửa Hàng Di Sản để mua thêm!';
      case _InventoryFilter.owned:
      case _InventoryFilter.all:
        return 'Bạn chưa sở hữu vật phẩm trang trí nào phù hợp. Hãy ghé Cửa Hàng Di Sản nhé!';
    }
  }

  Widget _buildNeutralArtwork(CatalogItemDto item) {
    final key = (item.renderKey ?? item.code).toLowerCase();
    IconData icon = Icons.temple_buddhist_rounded;
    if (key.contains('tre') || key.contains('cay')) {
      icon = Icons.park_rounded;
    } else if (key.contains('gieng') || key.contains('sen')) {
      icon = Icons.water_drop_rounded;
    } else if (key.contains('den_long')) {
      icon = Icons.light_rounded;
    } else if (key.contains('thuyen') || key.contains('cau')) {
      icon = Icons.sailing_rounded;
    } else if (key.contains('thap') || key.contains('khue_van')) {
      icon = Icons.account_balance_rounded;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Icon(icon, size: 36, color: DauVietColors.woodBrown),
    );
  }

  Widget _buildItemCard({
    required CatalogItemDto item,
    required bool isPlaced,
    required bool isCurrentSlotItem,
  }) {
    final assetPath = resolveIslandAsset(item.renderKey, item.code, item.assetId);
    final bool isAllowedCategory = _isAllowedInTargetSlot(item);
    final bool slotIsEmpty = widget.targetSlot.isEmpty;
    final bool canPlaceHere =
        slotIsEmpty &&
        item.owned &&
        item.placeable &&
        !isPlaced &&
        isAllowedCategory;

    String buttonLabel = 'ĐẶT';
    if (isCurrentSlotItem) {
      buttonLabel = 'ĐANG Ở Ô NÀY';
    } else if (!slotIsEmpty) {
      buttonLabel = 'Ô ĐANG CÓ ĐỒ';
    } else if (isPlaced) {
      buttonLabel = 'ĐÃ ĐẶT Ô KHÁC';
    } else if (!item.placeable) {
      buttonLabel = 'KHÔNG ĐẶT ĐƯỢC';
    } else if (!isAllowedCategory) {
      buttonLabel = 'KHÁC NHÓM Ô';
    }

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
          // Ảnh vật phẩm hoặc biểu tượng di sản trung tính
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (assetPath != null)
                  Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildNeutralArtwork(item),
                  )
                else
                  _buildNeutralArtwork(item),
                if (!item.owned)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        color: isCurrentSlotItem
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.woodBrown,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCurrentSlotItem ? 'Ô hiện tại' : 'Đang đặt',
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
            item.owned
                ? (item.placeable ? 'Có thể trang trí' : 'Vật phẩm sưu tầm')
                : 'Chưa sở hữu',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: item.owned
                  ? DauVietColors.natureGreen
                  : DauVietColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Nút đặt (chỉ kích hoạt khi owned && placeable && !isPlaced && isAllowedCategory)
          SizedBox(
            height: 34,
            child: item.owned
                ? Tactile3DButton(
                    label: buttonLabel,
                    height: 34,
                    depth: 2,
                    variant: canPlaceHere
                        ? Tactile3DVariant.heritageGreen
                        : Tactile3DVariant.secondaryParchment,
                    onPressed: canPlaceHere
                        ? () {
                            Navigator.of(context).pop();
                            widget.onSelectItem(item.itemId);
                          }
                        : null,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
