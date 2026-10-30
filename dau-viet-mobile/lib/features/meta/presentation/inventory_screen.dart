import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/clue_tag.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../../core/widgets/heritage_artifact_model_view.dart';
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

  static const _typeLabels = {
    'HISTORICAL_REPLICA': 'Mô hình lịch sử',
    'DIGITAL_EDITION': 'Ấn bản số',
    'COMMEMORATIVE_BADGE': 'Huy hiệu kỷ niệm',
  };

  ItemRarity _parseRarity(String raw) {
    return switch (raw.toUpperCase()) {
      'EPIC' => ItemRarity.epic,
      'RARE' => ItemRarity.rare,
      'UNCOMMON' => ItemRarity.uncommon,
      _ => ItemRarity.common,
    };
  }

  List<CatalogItemDto> _filter(List<CatalogItemDto> items) {
    if (_selectedCategory == 'all') return items;
    return items.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(inventoryCatalogProvider);

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DauVietColors.paperCard,
              DauVietColors.paperBackground,
              DauVietColors.paperCardHi,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: EmptyStateCard(
                title: 'Chưa có vật phẩm',
                description: 'Chưa có vật phẩm nào trong nhóm này.',
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
        color: DauVietColors.paperBackground,
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
                    const SectionEyebrow(
                      'KHO VẬT PHẨM',
                      showShadow: false,
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
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
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: ClueTag(
                    cat['label']!,
                    color: isSelected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.jade,
                    filled: isSelected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected =
            _selectedItemId == item.itemId ||
            (_selectedItemId == null && index == 0);
        final rarityColor =
            _rarityColors[item.rarity] ?? DauVietColors.outlineVariant;
        final parsedRarity = _parseRarity(item.rarity);

        return RareFrameBadge(
          rarity: parsedRarity,
          borderRadius: 16,
          borderWidth: isSelected ? 2.4 : 1.6,
          showGlow: isSelected || item.owned,
          child: TactileCard(
            onTap: () {
              setState(() {
                _selectedItemId = item.itemId;
              });
            },
            padding: const EdgeInsets.all(10),
            backgroundColor: isSelected
                ? DauVietColors.paperCardHi
                : DauVietColors.paperCard,
            borderColor: isSelected
                ? DauVietColors.cinnabarRed
                : rarityColor.withValues(alpha: 0.5),
            borderWidth: isSelected ? 2.0 : 1.2,
            child: Opacity(
              opacity: item.owned ? 1.0 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: ClueTag(
                          _categoryLabels[item.category] ?? item.category,
                          color: rarityColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
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
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFFFFFBF2),
                            DauVietColors.paperCardHi,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: HeritageArtifactModelView(
                        code: item.code,
                        renderKey: item.renderKey,
                        title: item.name,
                        category: item.category,
                        size: 58,
                        showPedestal: true,
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
    final parsedRarity = _parseRarity(item.rarity);
    final req = item.requirement;
    final categoryLabel = _categoryLabels[item.category] ?? item.category;
    final typeLabel = _typeLabels[item.itemType] ?? item.itemType;

    return TactileCard(
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.8,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroPaperBanner(
            height: 140,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => showHeritageModelInspectorDialog(
                    context,
                    kind: resolveHeritageModelKind(
                      code: item.code,
                      renderKey: item.renderKey,
                      title: item.name,
                      category: item.category,
                    ),
                    title: item.name,
                    description: item.description,
                    sourceNote: item.sourceNote,
                  ),
                  child: RareFrameBadge(
                    rarity: parsedRarity,
                    borderRadius: 12,
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: DauVietColors.paperCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: HeritageArtifactModelView(
                        code: item.code,
                        renderKey: item.renderKey,
                        title: item.name,
                        category: item.category,
                        size: 64,
                        showPedestal: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionEyebrow(
                        _rarityLabels[item.rarity] ?? item.rarity,
                        color: rarityColor,
                        showShadow: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 15,
                          color: DauVietColors.inkHeading,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ClueTag(
                            categoryLabel,
                            color: DauVietColors.jade,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                          ),
                          if (typeLabel.isNotEmpty)
                            ClueTag(
                              typeLabel,
                              color: DauVietColors.imperialGoldDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
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
          const SizedBox(height: 12),
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
                const StampSealBadge.success('✓', size: 28),
                const SizedBox(width: 8),
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
                    backgroundColor: DauVietColors.paperCardHi,
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
