import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';
import 'island_heritage_building.dart';

/// Bottom Sheet thông tin ô đất và hành động tương tác.
/// Gọn gàng, chuẩn phong cách Cozy Heritage, giới hạn max-width trên web/tablet.
class IslandTileSheet extends StatelessWidget {
  final IslandSlotDto? slot;
  final IslandTileDto? tile;
  final int islandTier;
  final VoidCallback onPlaceItem;
  final VoidCallback onRemoveItem;
  final VoidCallback onViewRequirements;
  final VoidCallback onClose;

  const IslandTileSheet({
    super.key,
    required this.slot,
    required this.tile,
    required this.islandTier,
    required this.onPlaceItem,
    required this.onRemoveItem,
    required this.onViewRequirements,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = (slot != null && slot!.unlockTier > islandTier) ||
        (tile != null && tile!.unlockTier > islandTier);
    final hasItem = slot != null && slot!.placement != null;

    final title = _buildTitle();
    final subtitle = _buildSubtitle(isLocked, hasItem);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC), // Cream UI surface
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE5D5BC),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo nhẹ ở đỉnh sheet
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C2A5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header tiêu đề và nút đóng
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusBadgeColor(isLocked, hasItem),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getStatusIcon(isLocked, hasItem),
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: DauVietTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF49382C),
                                ),
                              ),
                              Text(
                                subtitle,
                                style: DauVietTypography.bodySmall.copyWith(
                                  color: const Color(0xFF7A6858),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF7A6858),
                            size: 20,
                          ),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),

                    const Divider(color: Color(0xFFEADCC7), height: 20),

                    // Nội dung chi tiết vật phẩm nếu đã đặt
                    if (hasItem) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4E9D5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFDECFB8)),
                            ),
                            alignment: Alignment.center,
                            child: IslandHeritageBuilding(
                              placement: slot!.placement!,
                              tileWidth: 54,
                              tileHeight: 27,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot!.placement!.name,
                                  style: DauVietTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF49382C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getItemDescription(slot!.placement!),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DauVietTypography.bodySmall.copyWith(
                                    color: const Color(0xFF6B5848),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nút hành động chính
                    Row(
                      children: [
                        if (isLocked) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onViewRequirements,
                              icon: const Icon(Icons.lock_open_rounded, size: 18),
                              label: const Text('XEM ĐIỀU KIỆN MỞ KHÓA'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B6B48),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else if (hasItem) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onRemoveItem,
                              icon: const Icon(Icons.archive_outlined, size: 18),
                              label: const Text('CẤT VÀO KHO'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF8B4513),
                                side: const BorderBorderSide(color: Color(0xFFC4A482)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onPlaceItem,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('ĐỔI VẬT PHẨM'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB65E3F), // Terracotta
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else if (slot != null) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onPlaceItem,
                              icon: const Icon(Icons.add_home_rounded, size: 18),
                              label: const Text('ĐẶT VẬT PHẨM DI SẢN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A994E), // Nature green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              'Cảnh quan thiên nhiên tự nhiên của đảo di sản.',
                              textAlign: TextAlign.center,
                              style: DauVietTypography.bodySmall.copyWith(
                                color: const Color(0xFF7A6858),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
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

  String _buildTitle() {
    if (slot != null) {
      final region = slot!.regionCode ?? 'Khu Vực';
      return '$region • Ô #${slot!.slotIndex + 1}';
    }
    if (tile != null) {
      return 'Ô địa hình (${tile!.row}, ${tile!.col})';
    }
    return 'Vị trí trên Đảo';
  }

  String _buildSubtitle(bool isLocked, bool hasItem) {
    if (isLocked) {
      final tierReq = slot?.unlockTier ?? tile?.unlockTier ?? 2;
      return 'Yêu cầu mở rộng Đảo Cấp $tierReq';
    }
    if (hasItem) {
      return 'Đã xây dựng • Đang trưng bày di sản';
    }
    if (slot != null) {
      return 'Ô đất trống • Sẵn sàng xây dựng';
    }
    return 'Cảnh quan tự nhiên';
  }

  Color _getStatusBadgeColor(bool isLocked, bool hasItem) {
    if (isLocked) return const Color(0xFF78909C);
    if (hasItem) return const Color(0xFFB65E3F);
    if (slot != null) return const Color(0xFF6A994E);
    return const Color(0xFF9E8A73);
  }

  IconData _getStatusIcon(bool isLocked, bool hasItem) {
    if (isLocked) return Icons.lock_outline_rounded;
    if (hasItem) return Icons.account_balance_rounded;
    if (slot != null) return Icons.add_circle_outline_rounded;
    return Icons.park_outlined;
  }

  String _getItemDescription(IslandPlacementDto placement) {
    final code = placement.code.toLowerCase();
    if (code.contains('nha_tranh')) {
      return 'Kiến trúc mộc mạc lưu giữ hồn quê Việt Nam thuở khai hoang mở cõi.';
    }
    if (code.contains('cau_kieu')) {
      return 'Nhịp cầu ngói uốn lượn soi bóng bến nước ao làng quê hương.';
    }
    if (code.contains('ho_sen')) {
      return 'Hồ sen thanh tịnh tỏa hương ngát ngào khắp không gian làng cổ.';
    }
    if (code.contains('cay_da')) {
      return 'Cây đa cổ thụ hàng trăm năm tuổi, nơi gắn kết cội nguồn dân tộc.';
    }
    if (code.contains('dinh_lang')) {
      return 'Nơi tụ hội sinh hoạt văn hóa tín ngưỡng với mái đao cong vút cổ kính.';
    }
    return 'Hiện vật di sản quý giá tô điểm thêm vẻ đẹp của Đảo.';
  }
}
