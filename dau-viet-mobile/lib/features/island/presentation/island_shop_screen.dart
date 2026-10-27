import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/tactile_3d_button.dart';
import '../data/island_dto.dart';
import '../data/island_providers.dart';

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
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: DauVietColors.parchmentSurface,
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
            error: (err, stack) => _buildWalletPill(0),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Hiện chưa có vật phẩm nào được bày bán trong cửa hàng.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
            );
          }

          final currentPoints = walletAsync.asData?.value.historyPoints ?? 0;

          return RefreshIndicator(
            color: DauVietColors.cinnabarRed,
            onRefresh: () async {
              ref.invalidate(islandShopItemsProvider);
              ref.invalidate(islandWalletProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final isPurchasing = _inFlightPurchaseItemIds.contains(
                  item.itemId,
                );

                return _buildShopItemCard(
                  item: item,
                  currentPoints: currentPoints,
                  isPurchasing: isPurchasing,
                );
              },
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
        color: DauVietColors.parchmentContainer,
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

  Widget _buildShopItemCard({
    required ShopItemDto item,
    required int currentPoints,
    required bool isPurchasing,
  }) {
    final assetPath = item.assetPath;
    final canAfford = currentPoints >= item.price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.owned
              ? DauVietColors.outlineVariant
              : DauVietColors.imperialGoldLight,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14613B28),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh lớn artwork vật phẩm
          Container(
            width: 90,
            height: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DauVietColors.outlineVariant),
            ),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance_rounded,
                size: 40,
                color: DauVietColors.woodBrown,
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
                    // Giá Điểm Sử Ký
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: DauVietColors.imperialGold,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.price} Điểm',
                          style: DauVietTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: item.owned
                                ? DauVietColors.inkMuted
                                : (canAfford
                                      ? DauVietColors.heritageGreen
                                      : DauVietColors.errorRed),
                          ),
                        ),
                      ],
                    ),

                    // Nút Mua hoặc Đã sở hữu
                    if (item.owned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DauVietColors.parchmentDim,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: DauVietColors.outlineVariant,
                          ),
                        ),
                        child: Text(
                          'ĐÃ SỞ HỮU',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DauVietColors.inkMuted,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 86,
                        height: 36,
                        child: Tactile3DButton(
                          label: 'MUA',
                          height: 36,
                          depth: 2,
                          variant: canAfford
                              ? Tactile3DVariant.primaryCinnabar
                              : Tactile3DVariant.secondaryParchment,
                          isLoading: isPurchasing,
                          onPressed: () =>
                              _confirmPurchase(item, currentPoints),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mở hộp thoại xác nhận mua vật phẩm.
  Future<void> _confirmPurchase(ShopItemDto item, int currentPoints) async {
    if (currentPoints < item.price) {
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
        backgroundColor: DauVietColors.parchmentSurface,
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
                color: DauVietColors.parchmentContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Điểm hiện có:'),
                      Text(
                        '$currentPoints',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Giá vật phẩm:'),
                      Text(
                        '-${item.price}',
                        style: const TextStyle(
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
                      const Text('Số dư còn lại:'),
                      Text(
                        '${currentPoints - item.price}',
                        style: const TextStyle(
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
        backgroundColor: DauVietColors.parchmentSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
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
