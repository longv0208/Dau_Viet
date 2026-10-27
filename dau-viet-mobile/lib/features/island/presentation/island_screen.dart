import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/tactile_3d_button.dart';
import '../data/island_dto.dart';
import '../data/island_providers.dart';
import 'widgets/island_inventory_sheet.dart';
import 'widgets/island_scene.dart';
import 'widgets/island_slot_detail_card.dart';
import 'widgets/island_upgrade_panel.dart';

/// Màn hình chính Đảo Di Sản Cá Nhân 2.5D (`/island`).
class IslandScreen extends ConsumerStatefulWidget {
  const IslandScreen({super.key});

  @override
  ConsumerState<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends ConsumerState<IslandScreen> {
  String? _selectedSlotId;
  bool _isMutating = false;
  bool _showUpgradeCelebration = false;
  bool _dismissedIntroBanner = false;
  bool _isSheetOpen = false;
  int _resetCameraVersion = 0;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final islandAsync = ref.watch(islandControllerProvider);
    final walletAsync = ref.watch(islandWalletProvider);

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: _showUpgradeCelebration,
        child: SafeArea(
          child: Column(
            children: [
              // Header gọn gàng phân biệt rõ Quy mô Đảo và Level Tài Khoản
              _buildHeader(
                context,
                islandAsync.asData?.value,
                walletAsync.asData?.value,
              ),

              // Thân màn hình: Canvas 2.5D hoặc Loading/Error
              Expanded(
                child: islandAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                  error: (error, stack) => _buildErrorView(error),
                  data: (island) => _buildIslandContent(island),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header tối ưu cho màn hình nhỏ (ISLAND-06 Part D1):
  /// - Nút quay về
  /// - Tên Đảo Di Sản + Quy mô hiện tại (Đảo nhỏ / Đảo vừa / Đảo lớn)
  /// - Phụ đề Level tài khoản & EXP (tách bạch rõ với Tier của đảo)
  /// - Chỉ số Điểm Sử Ký + Nút Cửa hàng + Nút Mở rộng đảo
  Widget _buildHeader(
    BuildContext context,
    IslandDto? island,
    WalletDto? wallet,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: const Border(
          bottom: BorderSide(color: DauVietColors.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: DauVietColors.woodBrown,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'ĐẢO DI SẢN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DauVietColors.cinnabarRed,
                          letterSpacing: 0.4,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (island != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DauVietColors.heritageGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          island.tierScaleLabel,
                          style: DauVietTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  island != null
                      ? 'Level tài khoản ${island.currentLevel} · ${island.currentExp} EXP'
                      : 'Không gian di sản cá nhân',
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

          // Chỉ số Điểm Sử Ký thật
          GestureDetector(
            onTap: () => context.push('/island/shop'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: DauVietColors.parchmentContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DauVietColors.imperialGold,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: DauVietColors.imperialGold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet != null ? '${wallet.historyPoints}' : '...',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.woodBrown,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Nút Cửa Hàng
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Cửa Hàng Di Sản',
            icon: const Icon(
              Icons.storefront_rounded,
              color: DauVietColors.cinnabarRed,
              size: 22,
            ),
            onPressed: () => context.push('/island/shop'),
          ),

          // Nút Mở Rộng Đảo (có chấm sáng báo hiệu khi đủ điều kiện nâng cấp)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Mở Rộng Đảo',
                icon: const Icon(
                  Icons.landscape_rounded,
                  color: DauVietColors.heritageGreen,
                  size: 22,
                ),
                onPressed: island != null
                    ? () => _openUpgradePanel(island)
                    : null,
              ),
              if (island != null && island.canUpgrade && !island.isMaxTier)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DauVietColors.parchmentSurface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Thân màn hình đảo: Canvas 2.5D + Hướng dẫn ngữ cảnh lần đầu + Card chi tiết slot.
  Widget _buildIslandContent(IslandDto island) {
    final selectedSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
      (s) => s?.slotId == _selectedSlotId,
      orElse: () => null,
    );
    final placedCount = island.slots.where((s) => s.isOccupied).length;
    final showContextualGuide =
        !_dismissedIntroBanner &&
        selectedSlot == null &&
        (placedCount == 0 || (island.canUpgrade && !island.isMaxTier));

    return Stack(
      children: [
        // 1. Canvas 2.5D Isometric Scene
        Positioned.fill(
          child: IslandScene(
            island: island,
            selectedSlotId: _selectedSlotId,
            transformationController: _transformationController,
            resetCameraVersion: _resetCameraVersion,
            onSelectSlot: (slot) {
              setState(() {
                _selectedSlotId = slot?.slotId;
              });
            },
          ),
        ),

        // 2. Chỉ dẫn ngữ cảnh gọn nhẹ cho người dùng mới hoặc khi đủ điều kiện mở rộng (Part D2)
        if (showContextualGuide)
          Positioned(
            left: 12,
            right: 58,
            top: 10,
            child: _buildContextualGuideBanner(island, placedCount),
          ),

        // 3. Card chi tiết slot nổi ở phía dưới màn hình khi có slot được chọn (Part D4)
        if (selectedSlot != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: IslandSlotDetailCard(
              slot: selectedSlot,
              isMutating: _isMutating,
              onClose: () => setState(() => _selectedSlotId = null),
              onChooseItem: () => _openInventorySheet(selectedSlot),
              onRemoveItem: () => _removePlacement(selectedSlot),
              onUpgradeInfo: () => _openUpgradePanel(island),
            ),
          ),

        // 4. Nút đặt lại góc nhìn chuẩn theo quy mô đảo (Reset Camera - Part B7)
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'btn_reset_zoom',
            backgroundColor: DauVietColors.parchmentSurface.withValues(
              alpha: 0.92,
            ),
            foregroundColor: DauVietColors.woodBrown,
            elevation: 2,
            tooltip: 'Căn giữa Đảo Di Sản',
            onPressed: () {
              setState(() {
                _resetCameraVersion++;
              });
            },
            child: const Icon(Icons.center_focus_strong_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildContextualGuideBanner(IslandDto island, int placedCount) {
    final canUpgradeNow = island.canUpgrade && !island.isMaxTier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canUpgradeNow
              ? DauVietColors.imperialGold
              : DauVietColors.outlineVariant,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            canUpgradeNow
                ? Icons.auto_awesome_rounded
                : Icons.touch_app_rounded,
            size: 18,
            color: canUpgradeNow
                ? DauVietColors.cinnabarRed
                : DauVietColors.heritageGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: canUpgradeNow ? () => _openUpgradePanel(island) : null,
              child: Text(
                canUpgradeNow
                    ? 'Đủ Level mở rộng đảo! Chạm vào đây để khai mở vùng đất mới.'
                    : 'Chạm ô trống (+) để đặt vật phẩm. Học bài nhận EXP nâng Level mở rộng đảo.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.inkText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _dismissedIntroBanner = true),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Màn hình thông báo lỗi kết nối và nút thử lại.
  Widget _buildErrorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: DauVietColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Không thể kết nối Đảo Di Sản',
              style: DauVietTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error is ApiException
                  ? error.error.message
                  : 'Vui lòng kiểm tra lại kết nối mạng.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            Tactile3DButton(
              label: 'THỬ LẠI',
              variant: Tactile3DVariant.secondaryParchment,
              onPressed: () =>
                  ref.read(islandControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở Bottom Sheet Túi Đồ để chọn vật phẩm đặt lên slot (chặn mở chồng nhiều sheet).
  Future<void> _openInventorySheet(IslandSlotDto slot) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandInventorySheet(
          targetSlot: slot,
          onSelectItem: (itemId) => _placeItem(slot, itemId),
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Thực hiện đặt vật phẩm lên ô.
  Future<void> _placeItem(IslandSlotDto slot, String itemId) async {
    setState(() => _isMutating = true);

    try {
      await ref
          .read(islandControllerProvider.notifier)
          .placeItem(slotId: slot.slotId, itemId: itemId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đặt vật phẩm lên Đảo Di Sản thành công!'),
          backgroundColor: DauVietColors.heritageGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đặt vật phẩm, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  /// Thực hiện gỡ vật phẩm khỏi ô và cất về kho.
  Future<void> _removePlacement(IslandSlotDto slot) async {
    setState(() => _isMutating = true);

    try {
      await ref
          .read(islandControllerProvider.notifier)
          .removePlacement(slotId: slot.slotId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cất vật phẩm về kho an toàn.'),
          backgroundColor: DauVietColors.heritageGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cất vật phẩm, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  /// Mở panel tiến trình mở rộng Đảo Di Sản (chặn mở chồng nhiều sheet).
  Future<void> _openUpgradePanel(IslandDto island) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => IslandUpgradePanel(
          island: island,
          isUpgrading: _isMutating,
          onUpgrade: () {
            Navigator.of(ctx).pop();
            _executeUpgrade();
          },
        ),
      );
    } finally {
      _isSheetOpen = false;
    }
  }

  /// Thực hiện nâng cấp đảo sang tier tiếp theo.
  Future<void> _executeUpgrade() async {
    setState(() => _isMutating = true);

    try {
      await ref.read(islandControllerProvider.notifier).upgrade();

      if (!mounted) return;
      setState(() {
        _showUpgradeCelebration = true;
        _resetCameraVersion++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chúc mừng! Đảo Di Sản của bạn đã được mở rộng thêm vùng đất mới!',
          ),
          backgroundColor: DauVietColors.heritageGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể mở rộng đảo lúc này, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }
}
