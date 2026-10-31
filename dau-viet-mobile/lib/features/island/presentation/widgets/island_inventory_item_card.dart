import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../rewards/data/reward_dtos.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';

/// Lớp phủ khóa / giảm bão hòa cho vật phẩm chưa mở.
class LockedItemOverlay extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const LockedItemOverlay({
    super.key,
    required this.child,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.22, 0.42, 0.12, 0, 18,
            0.22, 0.42, 0.12, 0, 18,
            0.22, 0.42, 0.12, 0, 22,
            0, 0, 0, 0.95, 0,
          ]),
          child: child,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x66191010),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        const Center(
          child: Icon(
            Icons.lock_rounded,
            color: Color(0xFFF4E6CE),
            size: 18,
          ),
        ),
      ],
    );
  }
}

/// Thẻ vật phẩm trong khay kho / lưới kho.
class InventoryItemCard extends StatelessWidget {
  final CatalogItemDto item;
  final int quantity;
  final bool isLocked;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final double? height;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.quantity = 1,
    this.isLocked = false,
    this.isSelected = false,
    this.width = 78,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final shortLabel = shortIslandItemDisplayName(
      item.name,
      item.code,
      item.renderKey,
    );
    final art = IgnorePointer(
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
        isSelected: isSelected && !isLocked,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected && !isLocked ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5CC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected && !isLocked
                  ? DauVietColors.imperialGold
                  : const Color(0xFFDEC6A2),
              width: isSelected && !isLocked ? 2.1 : 1.2,
            ),
            boxShadow: [
              if (isSelected && !isLocked)
                BoxShadow(
                  color: DauVietColors.imperialGold.withValues(alpha: 0.38),
                  blurRadius: 10,
                  spreadRadius: 0.4,
                ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
                child: Column(
                  children: [
                    Expanded(
                      child: isLocked
                          ? LockedItemOverlay(child: art)
                          : Center(child: art),
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
                        color: isLocked
                            ? const Color(0xFF8A7764)
                            : const Color(0xFF3A2A1E),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLocked)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7D1AC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFCBA978),
                        width: 0.9,
                      ),
                    ),
                    child: Text(
                      'x$quantity',
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
      ),
    );
  }
}
