import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../../rewards/data/reward_providers.dart';
import '../../data/island_dto.dart';

/// Khay "Kho vật phẩm của bạn" docked đáy màn hình Đảo Di Sản (V51).
/// Chọn item → chạm ô đất để đặt. Cho phép đặt nhiều bản sao của 1 item.
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
  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);

    // Đếm ô đã đặt / tổng ô đã mở khoá ở tier hiện tại
    final unlockedSlots =
        widget.island.slots.where((s) => s.unlocked).length;
    final placedCount =
        widget.island.slots.where((s) => s.placement != null).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFE5D5BC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    color: DauVietColors.woodBrown,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kho vật phẩm của bạn',
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DauVietColors.inkText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.heritageGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$placedCount/$unlockedSlots đã đặt',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Ghi chú nhiều bản sao
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Vật phẩm đã nhận có thể đặt nhiều bản sao — chạm ô đất trên đảo để đặt.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.inkMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
            // Danh sách item ngang
            SizedBox(
              height: 92,
              child: catalogAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Không tải được kho đồ',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
                data: (catalog) {
                  final placeable = catalog
                      .where((it) => it.owned && it.placeable)
                      .toList();
                  if (placeable.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Chưa có vật phẩm đặt được. Hoàn thành bài học hoặc ghé Cửa hàng Di sản.',
                          textAlign: TextAlign.center,
                          style: DauVietTypography.bodySmall.copyWith(
                            color: DauVietColors.inkMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: placeable.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) =>
                        _trayItem(placeable[i], widget.island),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _trayItem(CatalogItemDto item, IslandDto island) {
    final isSelected = widget.selectedItemId == item.itemId;
    final assetPath = resolveIslandAsset(item.renderKey, item.code, item.assetId);
    final placedCountOnIsland = island.slots
        .where((s) => s.placement?.itemId == item.itemId)
        .length;

    return GestureDetector(
      onTap: () => widget.onSelectItem(isSelected ? null : item.itemId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 76,
        decoration: BoxDecoration(
          color: isSelected
              ? DauVietColors.imperialGold.withValues(alpha: 0.25)
              : DauVietColors.parchmentContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? DauVietColors.cinnabarRed
                : DauVietColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 44,
                  child: assetPath != null
                      ? Image.asset(assetPath, fit: BoxFit.contain)
                      : const Icon(
                          Icons.temple_buddhist_rounded,
                          color: DauVietColors.woodBrown,
                          size: 32,
                        ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
            // Badge số bản sao đã đặt
            if (placedCountOnIsland > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: DauVietColors.cinnabarRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '×$placedCountOnIsland',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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
