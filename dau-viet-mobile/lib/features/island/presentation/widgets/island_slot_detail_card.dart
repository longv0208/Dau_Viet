import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../data/island_dto.dart';

/// Card thông tin chi tiết nổi ở đáy màn hình khi người học chạm vào một slot.
class IslandSlotDetailCard extends StatelessWidget {
  final IslandSlotDto slot;
  final VoidCallback onClose;
  final VoidCallback onChooseItem;
  final VoidCallback onRemoveItem;
  final VoidCallback onUpgradeInfo;
  final bool isMutating;

  const IslandSlotDetailCard({
    super.key,
    required this.slot,
    required this.onClose,
    required this.onChooseItem,
    required this.onRemoveItem,
    required this.onUpgradeInfo,
    this.isMutating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Tên slot / Trạng thái + Nút đóng
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(), color: _statusColor(), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleText(),
                      style: DauVietTypography.headlineSmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _subTitleText(),
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
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mô tả ngữ cảnh
          Text(
            _descriptionText(),
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: 13,
              color: DauVietColors.inkText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Các nút hành động tương ứng với trạng thái
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (slot.isLocked) {
      return Tactile3DButton(
        label: 'XEM ĐIỀU KIỆN MỞ RỘNG',
        icon: Icons.flag_rounded,
        variant: Tactile3DVariant.secondaryParchment,
        onPressed: onUpgradeInfo,
      );
    }

    if (slot.isEmpty) {
      return Tactile3DButton(
        label: 'CHỌN VẬT PHẨM ĐẶT LÊN ĐẢO',
        icon: Icons.add_business_rounded,
        variant: Tactile3DVariant.heritageGreen,
        isLoading: isMutating,
        onPressed: onChooseItem,
      );
    }

    // Đã đặt vật phẩm: hiển thị nút Cất vào kho
    return Row(
      children: [
        Expanded(
          child: Tactile3DButton(
            label: 'ĐỔI VẬT PHẨM',
            icon: Icons.swap_horiz_rounded,
            variant: Tactile3DVariant.secondaryParchment,
            isLoading: isMutating,
            onPressed: onChooseItem,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Tactile3DButton(
            label: 'CẤT VÀO KHO',
            icon: Icons.archive_outlined,
            variant: Tactile3DVariant.dangerRed,
            isLoading: isMutating,
            onPressed: onRemoveItem,
          ),
        ),
      ],
    );
  }

  IconData _statusIcon() {
    if (slot.isLocked) {
      return Icons.lock_outline_rounded;
    }
    if (slot.isEmpty) {
      return Icons.add_circle_outline_rounded;
    }
    return Icons.deck_rounded;
  }

  Color _statusColor() {
    if (slot.isLocked) {
      return DauVietColors.inkMuted;
    }
    if (slot.isEmpty) {
      return DauVietColors.natureGreen;
    }
    return DauVietColors.cinnabarRed;
  }

  String _titleText() {
    if (slot.isLocked) {
      return 'Vị Trí Chưa Khai Mở';
    }
    if (slot.isEmpty) {
      return 'Ô Đất Cảnh Quan Sẵn Sàng';
    }
    return slot.placement!.name;
  }

  String _subTitleText() {
    if (slot.isLocked) {
      return 'Mã ô: ${slot.slotId} • Cần Đảo Cấp ${slot.unlockTier}';
    }
    if (slot.isEmpty) {
      return 'Mã ô: ${slot.slotId} • Đang để trống';
    }
    return 'Mã ô: ${slot.slotId} • Đã bố trí di sản';
  }

  String _descriptionText() {
    if (slot.isLocked) {
      return 'Vị trí này thuộc khu vực mở rộng của Đảo Cấp ${slot.unlockTier}. Hãy hoàn thành thêm các mốc sự kiện lịch sử để mở khóa vùng đất mới này!';
    }
    if (slot.isEmpty) {
      return 'Ô đất này đã khai khẩn hoàn tất và sẵn sàng đón nhận các công trình di sản (nhà tranh, hồ sen, cây đa, cầu kiều...). Mời bạn chọn từ Túi đồ!';
    }
    return 'Công trình kiến trúc di sản hiện diện tôn nghiêm trên đảo. Bạn có thể thay đổi vị trí hoặc cất về kho bất kỳ lúc nào mà không làm tiêu hao vật phẩm.';
  }
}
