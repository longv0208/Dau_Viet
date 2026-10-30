import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';

/// Thanh Segmented Pill Tab 3 cấp đảo theo thiết kế 9 màn hình (Issue #50 AC-1):
/// - `Đảo Nhỏ` (Cấp 1 — 6×6)
/// - `Đảo Vừa` (Cấp 2 — 8×8)
/// - `Đảo Lớn` (Cấp 3 — 10×10)
/// Tab đang chọn có nền xanh cổ đậm (`#1A5642`), chữ trắng và icon ngôi nhà/đình;
/// các tab chưa mở khóa hiển thị icon ổ khóa `🔒`.
class IslandTierTabs extends StatelessWidget {
  final IslandDto island;
  final int previewTier;
  final ValueChanged<int> onSelectTier;

  const IslandTierTabs({
    super.key,
    required this.island,
    required this.previewTier,
    required this.onSelectTier,
  });

  @override
  Widget build(BuildContext context) {
    final tiers = island.tiers.isNotEmpty
        ? island.tiers
        : <IslandTierInfoDto>[
            const IslandTierInfoDto(
              tier: 1,
              nameKey: 'tier.small',
              stageLabel: 'Đảo Nhỏ',
              slotCount: 36,
              unlocked: true,
            ),
            IslandTierInfoDto(
              tier: 2,
              nameKey: 'tier.medium',
              stageLabel: 'Đảo Vừa',
              slotCount: 64,
              unlocked: island.tier >= 2,
            ),
            IslandTierInfoDto(
              tier: 3,
              nameKey: 'tier.grand',
              stageLabel: 'Đảo Lớn',
              slotCount: 100,
              unlocked: island.tier >= 3,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E6CE).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < tiers.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _buildTierTab(tiers[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildTierTab(IslandTierInfoDto info) {
    final isActive = previewTier == info.tier;
    final isUnlocked = info.unlocked || island.tier >= info.tier;
    final label = IslandDto.tierHeritageName(info.tier);

    return GestureDetector(
      onTap: () => onSelectTier(info.tier),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1A5642)
              : const Color(0xFFF8EFE0).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF123F30)
                : const Color(0xFFE5D4B7),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnlocked
                  ? Icons.holiday_village_rounded
                  : Icons.lock_outline_rounded,
              size: 14,
              color: isActive
                  ? Colors.white
                  : isUnlocked
                      ? const Color(0xFF3E2D20)
                      : const Color(0xFF8C7A68),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? Colors.white
                      : isUnlocked
                          ? const Color(0xFF3A2A1E)
                          : const Color(0xFF7D6B59),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ hình thu nhỏ (thumbnail isometric) cho từng cấp đảo trên thanh tab và thẻ thông tin.
class IslandTierThumbnail extends StatelessWidget {
  final int tier;
  final bool isUnlocked;
  final double width;
  final double height;

  const IslandTierThumbnail({
    super.key,
    required this.tier,
    this.isUnlocked = true,
    this.width = 48,
    this.height = 42,
  });

  static String _tierAssetPath(int tier) {
    switch (tier) {
      case 1:
        return 'assets/island/effects/island_tier_1.png';
      case 2:
        return 'assets/island/effects/island_tier_2.png';
      case 3:
      default:
        return 'assets/island/effects/island_tier_3.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        _tierAssetPath(tier),
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => CustomPaint(
          painter: _TierIslandThumbnailPainter(
            tier: tier,
            isUnlocked: isUnlocked,
            isActive: false,
          ),
        ),
      ),
    );
  }
}

class _TierIslandThumbnailPainter extends CustomPainter {
  final int tier;
  final bool isUnlocked;
  final bool isActive;

  const _TierIslandThumbnailPainter({
    required this.tier,
    required this.isUnlocked,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final cliffColor = isUnlocked
        ? const Color(0xFF7E5738)
        : const Color(0xFF8D8274);
    final grassColor = isUnlocked
        ? const Color(0xFF6EA846)
        : const Color(0xFFA69B8D);
    final roofColor = isUnlocked
        ? const Color(0xFFC6362F)
        : const Color(0xFF756A5E);

    // Đế nước ngọc bích dưới chân đảo
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.84),
        width: w * 0.84,
        height: h * 0.26,
      ),
      Paint()
        ..color = isUnlocked
            ? const Color(0xFF4DB6AC).withValues(alpha: 0.55)
            : const Color(0xFFB0A494).withValues(alpha: 0.35),
    );

    // Khối vách đá 2.5D
    final cliffPath = Path()
      ..moveTo(w * 0.14, h * 0.56)
      ..lineTo(w * 0.50, h * 0.76)
      ..lineTo(w * 0.86, h * 0.56)
      ..lineTo(w * 0.78, h * 0.84)
      ..lineTo(w * 0.50, h * 0.94)
      ..lineTo(w * 0.22, h * 0.84)
      ..close();
    canvas.drawPath(cliffPath, Paint()..color = cliffColor);

    // Mặt đảo hình thoi
    final topDiamond = Path()
      ..moveTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.86, h * 0.56)
      ..lineTo(w * 0.50, h * 0.76)
      ..lineTo(w * 0.14, h * 0.56)
      ..close();
    canvas.drawPath(topDiamond, Paint()..color = grassColor);

    // Công trình biểu tượng trên mặt đảo (Cấp 1: Nhà đình, Cấp 2: Đình + Tháp, Cấp 3: Quần thể điện)
    final roofPath = Path()
      ..moveTo(w * 0.30, h * 0.48)
      ..lineTo(w * 0.50, h * 0.20)
      ..lineTo(w * 0.70, h * 0.48)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roofColor);

    if (tier >= 2) {
      final towerPath = Path()
        ..moveTo(w * 0.60, h * 0.44)
        ..lineTo(w * 0.70, h * 0.14)
        ..lineTo(w * 0.80, h * 0.44)
        ..close();
      canvas.drawPath(towerPath, Paint()..color = roofColor);
    }

    if (!isUnlocked) {
      // Hình ổ khóa nhỏ ở tâm đảo khi chưa mở
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.50),
        h * 0.18,
        Paint()..color = const Color(0xFF5D4E40).withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TierIslandThumbnailPainter oldDelegate) =>
      oldDelegate.tier != tier ||
      oldDelegate.isUnlocked != isUnlocked ||
      oldDelegate.isActive != isActive;
}
