import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';

/// Widget biểu diễn một ô (slot) trên bản đồ đảo di sản isometric 2.5D.
class IslandSlotWidget extends StatefulWidget {
  final IslandSlotDto slot;
  final bool isSelected;
  final VoidCallback onTap;

  const IslandSlotWidget({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<IslandSlotWidget> createState() => _IslandSlotWidgetState();
}

class _IslandSlotWidgetState extends State<IslandSlotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = isSelected ? _pulseAnimation.value * 1.08 : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: SizedBox(
          width: 100,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Đế Isometric (Isometric Platform Base)
              Positioned(
                bottom: 8,
                child: _buildIsometricBase(slot, isSelected),
              ),

              // 2. Nội dung bên trong slot: Vật phẩm đã đặt / Ô trống (+) / Ổ khóa
              Positioned(bottom: 22, child: _buildSlotContent(slot)),

              // 3. Vòng hào quang hoàng gia khi đang chọn
              if (isSelected)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 92,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(92, 48)),
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: DauVietColors.imperialGold.withValues(
                            alpha: 0.6,
                          ),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Badge nhỏ chỉ tên hoặc trạng thái
              Positioned(bottom: 0, child: _buildStatusLabel(slot)),
            ],
          ),
        ),
      ),
    );
  }

  /// Đế hình thoi isometric giả lập mặt đất / thềm đá cổ.
  Widget _buildIsometricBase(IslandSlotDto slot, bool isSelected) {
    Color fillColor;
    Color strokeColor;

    if (slot.isLocked) {
      fillColor = const Color(0x664A3B32);
      strokeColor = const Color(0x888C6747);
    } else if (slot.isEmpty) {
      fillColor = const Color(0x442D6A4F);
      strokeColor = isSelected
          ? DauVietColors.imperialGold
          : DauVietColors.natureGreen;
    } else {
      fillColor = const Color(0x55E7B451);
      strokeColor = isSelected
          ? DauVietColors.cinnabarRed
          : DauVietColors.imperialGold;
    }

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1.0, 0.52, 1.0),
      child: Container(
        width: 82,
        height: 64,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: strokeColor, width: isSelected ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 6),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }

  /// Nội dung vật phẩm hiển thị trên ô.
  Widget _buildSlotContent(IslandSlotDto slot) {
    if (slot.isLocked) {
      // Ổ khóa cổ điển
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xCC30251F),
          shape: BoxShape.circle,
          border: Border.all(color: DauVietColors.outlineVariant, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.lock_rounded,
          color: DauVietColors.imperialGoldLight,
          size: 22,
        ),
      );
    }

    if (slot.isEmpty) {
      // Dấu "+" mời đặt vật phẩm
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: DauVietColors.heritageGreen.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: DauVietColors.imperialGoldLight,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: DauVietColors.heritageGreen.withValues(alpha: 0.4),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      );
    }

    // Đã đặt vật phẩm: hiển thị tranh minh họa 2.5D
    final placement = slot.placement!;
    final asset = placement.assetPath;

    return Image.asset(
      asset,
      width: 76,
      height: 76,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: DauVietColors.parchmentContainer,
            shape: BoxShape.circle,
            border: Border.all(color: DauVietColors.imperialGold),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: DauVietColors.woodBrown,
            size: 28,
          ),
        );
      },
    );
  }

  /// Nhãn tên hoặc cấp độ bên dưới ô.
  Widget _buildStatusLabel(IslandSlotDto slot) {
    String label;
    Color bg;
    Color textCol;

    if (slot.isLocked) {
      label = 'Cấp ${slot.unlockTier}';
      bg = const Color(0xCC30251F);
      textCol = DauVietColors.parchmentDim;
    } else if (slot.isEmpty) {
      label = 'Ô Trống';
      bg = DauVietColors.heritageGreenDark.withValues(alpha: 0.85);
      textCol = Colors.white;
    } else {
      label = slot.placement!.name;
      bg = DauVietColors.parchmentContainer.withValues(alpha: 0.95);
      textCol = DauVietColors.woodBrown;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 96),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isSelected
              ? DauVietColors.imperialGold
              : DauVietColors.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textCol,
        ),
      ),
    );
  }
}
