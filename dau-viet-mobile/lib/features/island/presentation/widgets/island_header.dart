import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';

/// Header gọn của màn Đảo Di Sản: back, tên màn, cấp đảo, điểm, trợ giúp.
class IslandHeader extends StatelessWidget {
  final IslandDto? island;
  final WalletDto? wallet;
  final int previewTier;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onShop;
  final VoidCallback? onUpgrade;

  const IslandHeader({
    super.key,
    required this.island,
    required this.wallet,
    required this.previewTier,
    required this.onBack,
    required this.onHelp,
    required this.onShop,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 480;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xF2F6ECD9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFDEC9A8), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Quay lại',
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ĐẢO DI SẢN',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 0.6,
                  ),
                ),
                if (island != null)
                  Text(
                    '${IslandDto.tierHeritageName(previewTier)} · ${island!.legacyTierScaleLabel} (LV${island!.currentLevel})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF7D6B59),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onShop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF3E4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDEC9A8), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFE6A117),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet != null ? '${wallet!.historyPoints}' : '...',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3E2D20),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _CircleIconButton(
            icon: Icons.help_outline_rounded,
            size: 30,
            iconSize: 16,
            tooltip: 'Trợ giúp',
            onTap: onHelp,
          ),
          if (!isCompact) ...[
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Cửa Hàng Di Sản',
              icon: const Icon(
                Icons.storefront_rounded,
                color: DauVietColors.cinnabarRed,
                size: 20,
              ),
              onPressed: onShop,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Mở Rộng Đảo',
              icon: const Icon(
                Icons.landscape_rounded,
                color: DauVietColors.heritageGreen,
                size: 20,
              ),
              onPressed: onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 34,
    this.iconSize = 22,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF3E4),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDEC9A8), width: 1.2),
        ),
        child: Icon(icon, color: const Color(0xFF4A3728), size: iconSize),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
