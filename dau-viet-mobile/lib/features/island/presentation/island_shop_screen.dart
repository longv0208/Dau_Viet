import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/clue_tag.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_3d_button.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../rewards/data/reward_providers.dart';
import '../data/island_dto.dart';
import '../data/island_providers.dart';
import 'widgets/island_heritage_building.dart';

/// Màn hình Cửa Hàng Vật Phẩm Trang Trí Đảo Di Sản (`/island/shop`).
class IslandShopScreen extends ConsumerStatefulWidget {
  const IslandShopScreen({super.key});

  @override
  ConsumerState<IslandShopScreen> createState() => _IslandShopScreenState();
}

class _IslandShopScreenState extends ConsumerState<IslandShopScreen> {
  // Chặn double-tap khi đang xử lý mua
  final Set<String> _inFlightPurchaseItemIds = {};

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(islandWalletProvider);
    final shopItemsAsync = ref.watch(islandShopItemsProvider);

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      appBar: AppBar(
        backgroundColor: DauVietColors.paperBackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: DauVietColors.woodBrown,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/island');
            }
          },
        ),
        title: Text(
          'CỬA HÀNG DI SẢN',
          style: DauVietTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: DauVietColors.cinnabarRed,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Badge Điểm Sử Ký thật từ Wallet
          walletAsync.when(
            data: (wallet) => _buildWalletPill(wallet.historyPoints),
            loading: () => _buildWalletPill(null),
            error: (err, stack) => _buildWalletPill(null),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: shopItemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DauVietColors.cinnabarRed),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: DauVietColors.errorRed,
                ),
                const SizedBox(height: 12),
                Text(
                  'Không thể kết nối Cửa Hàng Di Sản',
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err is ApiException
                      ? err.error.message
                      : 'Vui lòng kiểm tra lại kết nối mạng.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Tactile3DButton(
                  label: 'THỬ LẠI',
                  variant: Tactile3DVariant.secondaryParchment,
                  onPressed: () {
                    ref.invalidate(inventoryItemsProvider);
                    ref.invalidate(islandShopItemsProvider);
                    ref.invalidate(islandWalletProvider);
                  },
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  title: 'Cửa hàng đang cập nhật',
                  description:
                      'Hiện chưa có vật phẩm nào được bày bán trong cửa hàng.',
                ),
              ),
            );
          }

          final bool walletLoaded =
              walletAsync.hasValue && !walletAsync.hasError;
          final currentPoints = walletAsync.asData?.value.historyPoints ?? 0;
          final bool ownershipVerified =
              items.every((it) => it.ownershipVerified);

          return RefreshIndicator(
            color: DauVietColors.cinnabarRed,
            onRefresh: () async {
              ref.invalidate(inventoryItemsProvider);
              ref.invalidate(islandShopItemsProvider);
              ref.invalidate(islandWalletProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                const SectionDivider(
                  eyebrow: 'CỬA HÀNG',
                  title: 'Móc khóa & trang trí đảo',
                  padding: EdgeInsets.only(top: 4, bottom: 16),
                ),
                if (!ownershipVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DauVietColors.paperCardHi,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: DauVietColors.woodBrown,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chưa xác minh được Túi đồ. Tạm khóa thao tác mua để tránh mua trùng.',
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.inkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(inventoryItemsProvider);
                            ref.invalidate(islandShopItemsProvider);
                          },
                          child: Text(
                            'TẢI LẠI',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DauVietColors.cinnabarRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _buildShopItemCard(
                    item: items[i],
                    walletLoaded: walletLoaded,
                    currentPoints: currentPoints,
                    isPurchasing: _inFlightPurchaseItemIds.contains(
                      items[i].itemId,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWalletPill(int? points) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: DauVietColors.paperCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            color: DauVietColors.imperialGold,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            points != null ? '$points' : '...',
            style: DauVietTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: DauVietColors.woodBrown,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralItemArtwork(ShopItemDto item) {
    final key = (item.renderKey ?? item.code).toLowerCase();
    IconData icon = Icons.temple_buddhist_rounded;
    if (key.contains('tre') || key.contains('cay')) {
      icon = Icons.park_rounded;
    } else if (key.contains('gieng') || key.contains('sen')) {
      icon = Icons.water_drop_rounded;
    } else if (key.contains('den_long')) {
      icon = Icons.light_rounded;
    } else if (key.contains('thuyen') || key.contains('cau')) {
      icon = Icons.sailing_rounded;
    } else if (key.contains('thap') || key.contains('khue_van')) {
      icon = Icons.account_balance_rounded;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 38, color: DauVietColors.woodBrown),
        const SizedBox(height: 4),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: DauVietColors.woodBrown,
          ),
        ),
      ],
    );
  }

  ItemRarity _resolveItemRarity(ShopItemDto item) {
    final cat = item.category.toUpperCase();
    if (cat == 'EPIC') return ItemRarity.epic;
    if (cat == 'RARE') return ItemRarity.rare;
    if (cat == 'UNCOMMON') return ItemRarity.uncommon;
    if (cat == 'COMMON') return ItemRarity.common;
    final pts = item.pricePoints ?? 0;
    if (pts >= 300) return ItemRarity.epic;
    if (pts >= 200) return ItemRarity.rare;
    if (pts >= 100) return ItemRarity.uncommon;
    return ItemRarity.common;
  }

  Widget _buildShopItemCard({
    required ShopItemDto item,
    required bool walletLoaded,
    required int currentPoints,
    required bool isPurchasing,
  }) {
    final assetPath = item.assetPath;
    final bool hasValidPrice =
        item.pricePoints != null && item.pricePoints! > 0;
    final bool isForSale = item.purchasable && hasValidPrice;
    final bool canAfford =
        walletLoaded &&
        item.ownershipVerified &&
        isForSale &&
        currentPoints >= item.pricePoints!;
    final rarity = _resolveItemRarity(item);

    return RareFrameBadge(
      rarity: rarity,
      borderRadius: 20,
      showGlow: !item.owned && isForSale,
      child: TactileCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: DauVietColors.paperCard,
        borderColor: (item.owned || !isForSale || !item.ownershipVerified)
            ? DauVietColors.outlineVariant
            : DauVietColors.imperialGoldLight,
        borderWidth: 1.5,
        borderRadius: 18,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh lớn artwork vật phẩm hoặc biểu tượng di sản trung tính
            Container(
              width: 90,
              height: 90,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DauVietColors.paperBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DauVietColors.outlineVariant),
              ),
              child: assetPath != null
                  ? Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildNeutralItemArtwork(item),
                    )
                  : Center(
                      child: IgnorePointer(
                        child: IslandHeritageBuilding(
                          placement: IslandPlacementDto(
                            itemId: item.itemId,
                            code: item.code,
                            name: item.name,
                            renderKey: item.renderKey,
                            assetId: item.assetId,
                          ),
                          tileWidth: 56,
                          tileHeight: 28,
                          useProportionalScale: false,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Thông tin vật phẩm & CTA Mua
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: DauVietTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DauVietColors.inkText,
                      fontSize: 15,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Giá và Nút mua
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Giá Điểm Sử Ký hoặc Chưa mở bán
                      ClueTag(
                        hasValidPrice
                            ? '${item.pricePoints} Điểm'
                            : 'Chưa mở bán',
                        icon: hasValidPrice
                            ? Icons.monetization_on
                            : Icons.lock_clock_rounded,
                        color: hasValidPrice
                            ? DauVietColors.imperialGoldDark
                            : DauVietColors.inkMuted,
                      ),

                      // Nút Mua / Đã sở hữu / Chưa mở bán / Chờ xác minh kho
                      if (!item.ownershipVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: DauVietColors.paperDim,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DauVietColors.outlineVariant,
                            ),
                          ),
                          child: Text(
                            'CHỜ TẢI KHO',
                            style: DauVietTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DauVietColors.inkMuted,
                            ),
                          ),
                        )
                      else if (item.owned)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const StampSealBadge.success('✓', size: 28),
                            const SizedBox(width: 6),
                            Text(
                              'ĐÃ SỞ HỮU',
                              style: DauVietTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: DauVietColors.natureGreen,
                              ),
                            ),
                          ],
                        )
                      else if (!isForSale)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: DauVietColors.paperDim,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DauVietColors.outlineVariant,
                            ),
                          ),
                          child: Text(
                            'CHƯA MỞ BÁN',
                            style: DauVietTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DauVietColors.inkMuted,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: 86,
                          height: 44,
                          child: Tactile3DButton(
                            label: 'MUA',
                            height: 40,
                            depth: 2,
                            variant: canAfford
                                ? Tactile3DVariant.primaryCinnabar
                                : Tactile3DVariant.secondaryParchment,
                            isLoading: isPurchasing,
                            onPressed: (walletLoaded &&
                                    item.ownershipVerified &&
                                    canAfford &&
                                    !isPurchasing)
                                ? () => _confirmPurchase(item, currentPoints)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở hộp thoại xác nhận mua vật phẩm.
  Future<void> _confirmPurchase(ShopItemDto item, int currentPoints) async {
    if (!item.ownershipVerified ||
        item.owned ||
        !item.isForSale ||
        item.pricePoints == null) {
      return;
    }
    if (currentPoints < item.pricePoints!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bạn không đủ Điểm Sử Ký để mua "${item.name}". Hiện có $currentPoints / Cần ${item.price}.',
          ),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.paperBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'XÁC NHẬN MUA VẬT PHẨM',
          style: DauVietTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: DauVietColors.cinnabarRed,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn mua "${item.name}" bằng Điểm Sử Ký?',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DauVietColors.paperCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Điểm hiện có:',
                        style: DauVietTypography.bodySmall,
                      ),
                      Text(
                        '$currentPoints',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giá vật phẩm:',
                        style: DauVietTypography.bodySmall,
                      ),
                      Text(
                        '-${item.price}',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DauVietColors.cinnabarRed,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Số dư còn lại:',
                        style: DauVietTypography.bodySmall,
                      ),
                      Text(
                        '${currentPoints - item.price}',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DauVietColors.heritageGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'HỦY',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DauVietColors.cinnabarRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÁC NHẬN MUA'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _executePurchase(item);
    }
  }

  /// Thực thi mua với Idempotency Key và chặn double-tap.
  Future<void> _executePurchase(ShopItemDto item) async {
    if (_inFlightPurchaseItemIds.contains(item.itemId)) return;

    setState(() {
      _inFlightPurchaseItemIds.add(item.itemId);
    });

    final String idempotencyKey = const Uuid().v4();

    try {
      await purchaseIslandShopItem(
        ref,
        item.itemId,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      _showPurchaseSuccessDialog(item);
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
          content: Text('Giao dịch chưa hoàn thành, vui lòng thử lại.'),
          backgroundColor: DauVietColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _inFlightPurchaseItemIds.remove(item.itemId);
        });
      }
    }
  }

  /// Thông báo mua thành công và đề xuất đặt ngay lên Đảo Di Sản.
  void _showPurchaseSuccessDialog(ShopItemDto item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DauVietColors.paperBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: DauVietColors.heritageGreenSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: DauVietColors.natureGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MUA THÀNH CÔNG!',
              style: DauVietTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: DauVietColors.heritageGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vật phẩm "${item.name}" đã được chuyển vào Túi đồ của bạn.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Ở LẠI CỬA HÀNG',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DauVietColors.heritageGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/island');
            },
            child: const Text('ĐẶT LÊN ĐẢO NGAY'),
          ),
        ],
      ),
    );
  }
}
