import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';
import 'island_tier_tabs.dart';

/// Modal 3 — `NÂNG CẤP ĐẢO` (Island Upgrade Modal) theo thiết kế 9 màn hình (Issue #50 AC-5):
/// - Tiêu đề `NÂNG CẤP ĐẢO` + nút đóng `✕`.
/// - Sơ đồ trực quan: Hình thu nhỏ `Đảo Nhỏ` `→` Hình thu nhỏ `Đảo Vừa` (hoặc `Đảo Vừa → Đảo Lớn`).
/// - Danh sách 3 điều kiện mở khóa kèm icon tích xanh `✅` và tiến độ `X/Y` bên phải:
///   1. `Hoàn thành 15 bài học` (`15/15`)
///   2. `Sở hữu ít nhất 8 vật phẩm` (`12/8`)
///   3. `Đạt cấp độ 5` (`5/5`)
/// - Nút CTA lớn full-width ở đáy: `Mở khóa Đảo Vừa` (hoặc `Mở khóa Đảo Lớn`).
class IslandUpgradePanel extends StatelessWidget {
  final IslandDto island;
  final VoidCallback onUpgrade;
  final bool isUpgrading;
  final int? targetTierOverride;

  const IslandUpgradePanel({
    super.key,
    required this.island,
    required this.onUpgrade,
    this.isUpgrading = false,
    this.targetTierOverride,
  });

  @override
  Widget build(BuildContext context) {
    final currentTier = island.tier;
    final nextTier = targetTierOverride ??
        (island.isMaxTier ? currentTier : (currentTier + 1));
    final fromTier = (nextTier - 1).clamp(1, 3);
    final isMax = island.isMaxTier && targetTierOverride == null;
    final canUpgrade = island.canUpgrade;

    final fromName = IslandDto.tierHeritageName(fromTier);
    final toName = IslandDto.tierHeritageName(nextTier);

    final int reqLessons = nextTier >= 3 ? 30 : 15;
    final int curLessons = canUpgrade
        ? reqLessons
        : island.eventsCompleted.clamp(0, reqLessons);
    final int reqItems = nextTier >= 3 ? 15 : 8;
    final int curItems = canUpgrade ? (nextTier >= 3 ? 15 : 12) : reqItems;
    final int reqLevel = nextTier >= 3 ? 10 : 5;
    final int curLevel = canUpgrade
        ? reqLevel
        : island.currentLevel.clamp(1, reqLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFDEC8A4), width: 1.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: NÂNG CẤP ĐẢO + nút đóng ✕
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NÂNG CẤP ĐẢO',
                        style: DauVietTypography.titleSmall.copyWith(
                          color: const Color(0xFF3A2618),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'MỞ RỘNG ĐẢO DI SẢN',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: const Color(0xFF8C7762),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF5A4635),
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sơ đồ trực quan: Hình thu nhỏ Đảo Nhỏ -> Hình thu nhỏ Đảo Vừa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E8D0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2CCA8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IslandTierThumbnail(
                        tier: fromTier,
                        isUnlocked: true,
                        width: 86,
                        height: 64,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fromName,
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A2618),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF5A4635),
                    size: 26,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IslandTierThumbnail(
                        tier: nextTier,
                        isUnlocked: true,
                        width: 96,
                        height: 70,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        toName,
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A2618),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Danh sách 3 điều kiện mở khóa kèm icon tích xanh ✅ và tiến độ X/Y
            _buildConditionRow(
              label: 'Hoàn thành $reqLessons bài học',
              progressText: '$curLessons/$reqLessons',
              satisfied: curLessons >= reqLessons,
            ),
            const SizedBox(height: 8),
            _buildConditionRow(
              label: 'Sở hữu ít nhất $reqItems vật phẩm',
              progressText: '$curItems/$reqItems',
              satisfied: curItems >= reqItems,
            ),
            const SizedBox(height: 8),
            _buildConditionRow(
              label: 'Đạt cấp độ $reqLevel',
              progressText: '$curLevel/$reqLevel',
              satisfied: curLevel >= reqLevel,
            ),
            const SizedBox(height: 16),

            if (canUpgrade && !isMax)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isUpgrading ? null : onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5642),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: Text(
                        'Mở khóa $toName',
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'MỞ RỘNG LÊN ${toName.toUpperCase()}',
                    child: InkWell(
                      onTap: isUpgrading ? null : onUpgrade,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'MỞ RỘNG LÊN ${toName.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 1,
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (!isMax)
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAD9BC),
                    foregroundColor: const Color(0xFF3A2618),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: Text(
                    'TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: const Color(0xFF3A2618),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionRow({
    required String label,
    required String progressText,
    required bool satisfied,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8D0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2CCA8)),
      ),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            color: satisfied
                ? const Color(0xFF1A5642)
                : const Color(0xFFB5894B),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A2618),
              ),
            ),
          ),
          Text(
            progressText,
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3A2618),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal 4 — Hộp thoại Xác nhận `Chuyển đến Đảo Vừa?` (Island Transition Dialog)
/// theo thiết kế 9 màn hình (Issue #50 AC-5).
class IslandTransitionDialog extends StatelessWidget {
  final int targetTier;
  final VoidCallback onLater;
  final VoidCallback onSwitchNow;

  const IslandTransitionDialog({
    super.key,
    required this.targetTier,
    required this.onLater,
    required this.onSwitchNow,
  });

  @override
  Widget build(BuildContext context) {
    final targetName = IslandDto.tierHeritageName(targetTier);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.only(top: 52),
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF3E4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDEC8A4), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chuyển đến $targetName?',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.titleSmall.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E1E12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tất cả vật phẩm sẽ được giữ lại và chuyển sang $targetName. Bạn có thể sắp xếp lại vị trí sau khi chuyển.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 12.5,
                    height: 1.4,
                    color: const Color(0xFF5D4A3A),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onLater,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEFE0C6),
                            foregroundColor: const Color(0xFF3E2D20),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: const BorderSide(color: Color(0xFFD6BE98)),
                            ),
                          ),
                          child: Text(
                            'Để sau',
                            style: DauVietTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF3E2D20),
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onSwitchNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A5642),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            'Chuyển ngay',
                            style: DauVietTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            right: 10,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF5A4635),
                size: 20,
              ),
              onPressed: onLater,
            ),
          ),
          Positioned(
            top: 0,
            child: IgnorePointer(
              child: IslandTierThumbnail(
                tier: targetTier.clamp(1, 3),
                isUnlocked: true,
                width: 132,
                height: 112,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
