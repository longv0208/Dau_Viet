import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_button.dart';
import '../../data/island_dto.dart';

/// Card thông tin chi tiết gọn gàng nổi ở đáy màn hình khi người học chạm vào một slot.
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

  static String _scaleNameForTier(int tier) {
    switch (tier) {
      case 1:
        return 'Đảo nhỏ';
      case 2:
        return 'Đảo vừa';
      case 3:
        return 'Đảo lớn';
      default:
        return 'Đảo cấp $tier';
    }
  }

  String _shortSlotLabel() {
    if (slot.stableSlotKey != null && slot.stableSlotKey!.isNotEmpty) {
      final numPart = slot.stableSlotKey!.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.isNotEmpty) return 'Ô số $numPart';
    }
    if (slot.zIndex > 0) {
      final idx = slot.zIndex >= 10 ? (slot.zIndex ~/ 10) : slot.zIndex;
      return 'Ô số $idx';
    }
    return 'Ô di sản';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(), color: _statusColor(), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.headlineSmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _subTitleText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: DauVietColors.inkMuted,
                  size: 20,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _descriptionText(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: DauVietColors.inkText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (slot.isLocked) {
      return Tactile3DButton(
        label: 'XEM ĐIỀU KIỆN MỞ RỘNG ĐẢO',
        height: 40,
        icon: Icons.landscape_rounded,
        variant: Tactile3DVariant.secondaryParchment,
        onPressed: onUpgradeInfo,
      );
    }

    if (slot.isEmpty) {
      return Tactile3DButton(
        label: 'CHỌN VẬT PHẨM ĐẶT LÊN ĐẢO',
        height: 40,
        icon: Icons.add_business_rounded,
        variant: Tactile3DVariant.heritageGreen,
        isLoading: isMutating,
        onPressed: onChooseItem,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Tactile3DButton(
            label: 'ĐỔI VẬT PHẨM',
            height: 40,
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
            height: 40,
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
    if (slot.isLocked) return Icons.lock_outline_rounded;
    if (slot.isEmpty) return Icons.add_circle_outline_rounded;
    return Icons.temple_buddhist_rounded;
  }

  Color _statusColor() {
    if (slot.isLocked) return DauVietColors.inkMuted;
    if (slot.isEmpty) return DauVietColors.natureGreen;
    return DauVietColors.cinnabarRed;
  }

  String _titleText() {
    if (slot.isLocked) return 'Vị trí thuộc ${_scaleNameForTier(slot.unlockTier)}';
    if (slot.isEmpty) return '${_shortSlotLabel()} — Đang trống';
    return slot.placement!.name;
  }

  String _subTitleText() {
    if (slot.isLocked) {
      return '${_shortSlotLabel()} • Mở khóa khi nâng cấp lên ${_scaleNameForTier(slot.unlockTier)}';
    }
    if (slot.isEmpty) {
      return '${_shortSlotLabel()} • Sẵn sàng đặt vật phẩm trang trí';
    }
    return '${_shortSlotLabel()} • Đang trưng bày trên Đảo Di Sản';
  }

  String _descriptionText() {
    if (slot.isLocked) {
      return 'Hoàn thành bài học để tích lũy EXP, nâng Cấp tài khoản và mở rộng sang ${_scaleNameForTier(slot.unlockTier)}.';
    }
    if (slot.isEmpty) {
      return 'Chọn một vật phẩm trang trí từ Kho vật phẩm của bạn để tô điểm cho không gian di sản.';
    }
    return 'Bạn có thể đổi sang vật phẩm khác hoặc cất về kho bất kỳ lúc nào mà không làm mất vật phẩm.';
  }
}
