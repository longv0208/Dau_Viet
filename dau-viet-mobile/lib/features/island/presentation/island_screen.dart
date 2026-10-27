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
              // Header thanh tiêu đề & chỉ số thật
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

  /// Header chứa nút quay lại, tiêu đề, Badge cấp đảo thật, Điểm Sử Ký thật và các nút chức năng.
  Widget _buildHeader(
    BuildContext context,
    IslandDto? island,
    WalletDto? wallet,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // Nút quay về
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: DauVietColors.woodBrown,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),

          // Tiêu đề & Cấp đảo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'ĐẢO DI SẢN',
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: DauVietColors.cinnabarRed,
                        letterSpacing: 0.5,
                        fontSize: 14,
                      ),
                    ),
                    if (island != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DauVietColors.heritageGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CẤP ${island.tier}',
                          style: DauVietTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Không gian di sản cá nhân',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),

          // Chỉ số Điểm Sử Ký thật
          GestureDetector(
            onTap: () => context.push('/island/shop'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DauVietColors.parchmentContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: DauVietColors.imperialGold,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: DauVietColors.imperialGold,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet != null ? '${wallet.historyPoints}' : '...',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.woodBrown,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút Cửa Hàng
          IconButton(
            tooltip: 'Cửa Hàng',
            icon: const Icon(
              Icons.storefront_rounded,
              color: DauVietColors.cinnabarRed,
            ),
            onPressed: () => context.push('/island/shop'),
          ),

          // Nút Mở Rộng Đảo
          IconButton(
            tooltip: 'Mở Rộng Đảo',
            icon: const Icon(
              Icons.landscape_rounded,
              color: DauVietColors.heritageGreen,
            ),
            onPressed: island != null ? () => _openUpgradePanel(island) : null,
          ),
        ],
      ),
    );
  }

  /// Thân màn hình đảo: Canvas isometric 2.5D + Card chi tiết slot docked ở đáy.
  Widget _buildIslandContent(IslandDto island) {
    // Tìm slot đang được chọn (nếu có)
    final selectedSlot = island.slots.cast<IslandSlotDto?>().firstWhere(
      (s) => s?.slotId == _selectedSlotId,
      orElse: () => null,
    );

    return Stack(
      children: [
        // 1. Canvas 2.5D Isometric Scene
        Positioned.fill(
          child: IslandScene(
            island: island,
            selectedSlotId: _selectedSlotId,
            transformationController: _transformationController,
            onSelectSlot: (slot) {
              setState(() {
                _selectedSlotId = slot?.slotId;
              });
            },
          ),
        ),

        // 2. Card chi tiết slot nổi ở phía dưới màn hình khi có slot được chọn
        if (selectedSlot != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IslandSlotDetailCard(
              slot: selectedSlot,
              isMutating: _isMutating,
              onClose: () => setState(() => _selectedSlotId = null),
              onChooseItem: () => _openInventorySheet(selectedSlot),
              onRemoveItem: () => _removePlacement(selectedSlot),
              onUpgradeInfo: () => _openUpgradePanel(island),
            ),
          ),

        // 3. Nút đặt lại góc nhìn zoom (Reset Camera) ở góc trên bên phải
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'btn_reset_zoom',
            backgroundColor: DauVietColors.parchmentSurface.withValues(
              alpha: 0.9,
            ),
            foregroundColor: DauVietColors.woodBrown,
            elevation: 2,
            tooltip: 'Đặt lại góc nhìn',
            onPressed: () {
              _transformationController.value = Matrix4.identity();
            },
            child: const Icon(Icons.center_focus_strong_rounded, size: 20),
          ),
        ),
      ],
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

  /// Mở Bottom Sheet Túi Đồ để chọn vật phẩm đặt lên slot.
  void _openInventorySheet(IslandSlotDto slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IslandInventorySheet(
        targetSlot: slot,
        onSelectItem: (itemId) => _placeItem(slot, itemId),
      ),
    );
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
        SnackBar(
          content: Text(
            'Đã đặt vật phẩm vào vị trí ${slot.slotId} thành công!',
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
        SnackBar(
          content: Text(
            'Đã cất vật phẩm ở vị trí ${slot.slotId} về kho an toàn.',
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
          content: Text('Không thể cất vật phẩm, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  /// Mở panel tiến trình mở rộng Đảo Di Sản.
  void _openUpgradePanel(IslandDto island) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IslandUpgradePanel(
        island: island,
        isUpgrading: _isMutating,
        onUpgrade: () async {
          Navigator.of(ctx).pop();
          _executeUpgrade();
        },
      ),
    );
  }

  /// Thực hiện nâng cấp đảo sang tier tiếp theo.
  Future<void> _executeUpgrade() async {
    setState(() => _isMutating = true);

    try {
      await ref.read(islandControllerProvider.notifier).upgrade();

      if (!mounted) return;
      setState(() => _showUpgradeCelebration = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chúc mừng! Đảo Di Sản của bạn đã được mở rộng thành công!',
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
