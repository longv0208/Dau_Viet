import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../rewards/data/reward_dtos.dart';
import '../../rewards/data/reward_providers.dart';

/// Màn hình M-27: Túi Đồ & Kho Vật Phẩm Học Tập (Inventory Screen)
/// TASK-0023: dữ liệu thật từ GET /api/v1/me/inventory/catalog — catalog
/// đầy đủ kèm owned + requirement + progress. Vật phẩm luôn là mô hình /
/// phiên bản số / huy hiệu kỷ niệm — KHÔNG phải cổ vật thật.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  /// 'all' | category code (MO_HINH / PHIEN_BAN_SO / HUY_HIEU / ...).
  String _selectedCategory = 'all';
  String? _selectedItemId;

  static const _categoryLabels = {
    'MO_HINH': 'Mô hình',
    'PHIEN_BAN_SO': 'Phiên bản số',
    'HUY_HIEU': 'Huy hiệu',
  };

  static const _rarityLabels = {
    'COMMON': 'Thường',
    'UNCOMMON': 'Không phổ biến',
    'RARE': 'Hiếm',
    'EPIC': 'Sử thi',
  };

  static const _rarityColors = {
    'COMMON': DauVietColors.natureGreen,
    'UNCOMMON': DauVietColors.riverBlue,
    'RARE': DauVietColors.imperialGold,
    'EPIC': DauVietColors.cinnabarRed,
  };

  static const _typeIcons = {
    'HISTORICAL_REPLICA': Icons.account_balance_rounded,
    'DIGITAL_EDITION': Icons.photo_library_rounded,
    'COMMEMORATIVE_BADGE': Icons.workspace_premium_rounded,
  };

  List<CatalogItemDto> _filter(List<CatalogItemDto> items) {
    if (_selectedCategory == 'all') return items;
    return items.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(inventoryCatalogProvider);

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7EB),
              DauVietColors.parchmentSurface,
              Color(0xFFF7ECDA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, catalog.value),
              Expanded(
                child: catalog.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(inventoryCatalogProvider),
                  ),
                  data: (items) => _buildBody(items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<CatalogItemDto> items) {
    final filtered = _filter(items);
    final ownedCount = items.where((i) => i.owned).length;

    // Giữ selection hợp lệ khi filter đổi / dữ liệu reload.
    final CatalogItemDto? selected =
        filtered.where((i) => i.itemId == _selectedItemId).firstOrNull ??
        (filtered.isNotEmpty ? filtered.first : null);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$ownedCount/${items.length} vật phẩm đã sở hữu',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          _buildCategoryFilters(items),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Chưa có vật phẩm nào trong nhóm này.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
            )
          else
            _buildInventoryGrid(filtered),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _buildItemInspectorCard(selected),
          ],
          const SizedBox(height: 20),
          DongSonButton(
            label: 'VỀ BÀN HỌC TẬP (DASHBOARD)',
            icon: Icons.home_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            height: 52,
            onPressed: () {
              context.go('/dashboard');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Header đỉnh trang
  Widget _buildTopBar(BuildContext context, List<CatalogItemDto>? items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: DauVietColors.inkText,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'KHO VẬT PHẨM',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TÚI ĐỒ SĨ TỬ',
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 16,
                          color: DauVietColors.inkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Mô hình & huy hiệu học tập — không phải cổ vật thật',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          EnergyPill(
            energy: 100,
            maxEnergy: 100,
            showHistoryPoints: false,
            onEnergyTap: () => context.go('/energy'),
          ),
        ],
      ),
    );
  }

  // Bộ lọc danh mục — dựng động từ category thực tế trong catalog.
  Widget _buildCategoryFilters(List<CatalogItemDto> items) {
    final cats = items.map((i) => i.category).toSet().toList()..sort();
    final categories = [
      {'key': 'all', 'label': 'Tất Cả (${items.length})'},
      for (final c in cats)
        {
          'key': c,
          'label':
              '${_categoryLabels[c] ?? c} (${items.where((i) => i.category == c).length})',
        },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DauVietColors.cinnabarRed
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  cat['label']!,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : DauVietColors.inkText,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Lưới vật phẩm — owned hiện đầy màu, chưa mở khóa mờ + icon khoá.
  Widget _buildInventoryGrid(List<CatalogItemDto> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected =
            _selectedItemId == item.itemId ||
            (_selectedItemId == null && index == 0);
        final rarityColor =
            _rarityColors[item.rarity] ?? DauVietColors.outlineVariant;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedItemId = item.itemId;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFBF4E4)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? DauVietColors.cinnabarRed
                    : rarityColor.withValues(alpha: 0.5),
                width: isSelected ? 2.0 : 1.2,
              ),
              boxShadow: isSelected ? DauVietColors.heritageShadow : null,
            ),
            child: Opacity(
              opacity: item.owned ? 1.0 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _categoryLabels[item.category] ?? item.category,
                          style: TextStyle(
                            color: rarityColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                      if (item.owned && isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: DauVietColors.cinnabarRed,
                          size: 16,
                        )
                      else if (!item.owned)
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: DauVietColors.inkMuted,
                          size: 14,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        _typeIcons[item.itemType] ??
                            Icons.workspace_premium_rounded,
                        color: item.owned
                            ? rarityColor
                            : DauVietColors.inkLight,
                        size: 26,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.name,
                    style: DauVietTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.inkText,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Thẻ soi chi tiết vật phẩm đang chọn — kèm điều kiện + tiến độ khi
  // chưa mở khóa (GAME-05: `requirement` là cây ALL/ANY + leaf server đã
  // tính sẵn per-branch; render TỪNG dòng, không gộp một bar tổng).
  Widget _buildItemInspectorCard(CatalogItemDto item) {
    final rarityColor =
        _rarityColors[item.rarity] ?? DauVietColors.outlineVariant;
    final req = item.requirement;

    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.8,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rarityColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  _typeIcons[item.itemType] ?? Icons.workspace_premium_rounded,
                  color: item.owned ? rarityColor : DauVietColors.inkLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: rarityColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _rarityLabels[item.rarity] ?? item.rarity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.name,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 14.5,
                        color: DauVietColors.inkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.description ?? '',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
          if (item.sourceNote != null && item.sourceNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.sourceNote!,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (item.owned)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: DauVietColors.natureGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Đã sở hữu',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.natureGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            )
          else if (req != null) ...[
            _RequirementTree(node: req, rarityColor: rarityColor),
          ],
        ],
      ),
    );
  }
}

/// Cây điều kiện mở khóa (GAME-05): operator ALL/ANY in heading cố định
/// ("Hoàn thành tất cả điều kiện sau" / "Hoàn thành một trong các điều
/// kiện sau") rồi render từng leaf một dòng với trạng thái riêng — leaf
/// boolean chỉ icon, leaf đếm thêm progress bar + current/required; leaf
/// UNSUPPORTED hiển thị "chưa hỗ trợ" thay vì giả vờ "sắp xong".
class _RequirementTree extends StatelessWidget {
  final ItemRequirementDto node;
  final Color rarityColor;
  const _RequirementTree({required this.node, required this.rarityColor});

  @override
  Widget build(BuildContext context) {
    // FIX-1: rule đang chờ admin cập nhật (backend audit needs-mapping
    // chặn grant + báo UNCONFIGURED) — hiển thị thông điệp trung lập,
    // không progress bar, không "đã đủ" giả, không nhánh con nào.
    if (node.isUnconfigured) {
      return Row(
        children: [
          const Icon(
            Icons.tune_rounded,
            color: DauVietColors.inkMuted,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              node.description != null && node.description!.isNotEmpty
                  ? node.description!
                  : 'Điều kiện mở khóa đang được cập nhật',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }
    if (node.isOperator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: DauVietColors.inkMuted,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.operatorHeading(),
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final child in node.conditions)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 4),
              child: _RequirementTree(node: child, rarityColor: rarityColor),
            ),
        ],
      );
    }
    // Leaf — một dòng trạng thái riêng.
    final progress = node.progressFraction;
    final done = node.satisfied;
    final muted = node.isUnsupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : muted
                  ? Icons.block_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done ? DauVietColors.natureGreen : DauVietColors.inkMuted,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.describe(),
                style: DauVietTypography.bodySmall.copyWith(
                  color: muted
                      ? DauVietColors.inkLight
                      : DauVietColors.inkMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (progress != null && !done) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: DauVietColors.parchmentHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      DauVietColors.imperialGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: DauVietColors.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tải được kho vật phẩm.',
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            DongSonButton(
              label: 'THỬ LẠI',
              icon: Icons.refresh_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 44,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
