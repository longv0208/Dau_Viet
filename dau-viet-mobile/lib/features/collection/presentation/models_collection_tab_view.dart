import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/clue_tag.dart';
import '../../../core/widgets/heritage_artifact_model_view.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../rewards/data/reward_providers.dart';

/// Tab "Mô hình & Bảo vật" trong Bộ Sưu Tập Dấu Việt (`/collection`).
/// Hiển thị toàn bộ các Mô hình di sản (`MO_HINH`), Phiên bản số (`PHIEN_BAN_SO`)
/// và Huy hiệu kỷ niệm (`HUY_HIEU`) kèm mô hình 2.5D tương tác.
class ModelsCollectionTabView extends ConsumerStatefulWidget {
  const ModelsCollectionTabView({super.key});

  @override
  ConsumerState<ModelsCollectionTabView> createState() =>
      _ModelsCollectionTabViewState();
}

class _ModelsCollectionTabViewState
    extends ConsumerState<ModelsCollectionTabView> {
  String _categoryFilter = 'ALL';

  static const List<(String, String)> _filters = [
    ('ALL', 'Tất cả'),
    ('MO_HINH', 'Mô hình 2.5D'),
    ('PHIEN_BAN_SO', 'Phiên bản số'),
    ('HUY_HIEU', 'Huy hiệu'),
  ];

  static const Map<String, String> _categoryLabels = {
    'MO_HINH': 'Mô hình di sản',
    'PHIEN_BAN_SO': 'Phiên bản số',
    'HUY_HIEU': 'Huy hiệu kỷ niệm',
    'DECOR': 'Tiểu cảnh đảo',
  };

  static const Map<String, Color> _rarityColors = {
    'COMMON': DauVietColors.natureGreen,
    'UNCOMMON': DauVietColors.jade,
    'RARE': DauVietColors.imperialGold,
    'EPIC': DauVietColors.cinnabarRed,
  };

  ItemRarity _parseRarity(String raw) => switch (raw.toUpperCase()) {
    'EPIC' => ItemRarity.epic,
    'RARE' => ItemRarity.rare,
    'UNCOMMON' => ItemRarity.uncommon,
    _ => ItemRarity.common,
  };

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inventoryCatalogProvider);

    return catalogAsync.when(
      loading: () => AsyncStateView.loading(
        message: 'Đang tải bộ sưu tập mô hình di sản...',
      ),
      error: (err, _) => AsyncStateView.error(
        error: err,
        onRetry: () => ref.invalidate(inventoryCatalogProvider),
      ),
      data: (allItems) {
        // Ưu tiên hiển thị các mô hình lịch sử, phiên bản số và huy hiệu trong Bộ Sưu Tập
        final collectionItems = allItems
            .where((i) => i.category != 'DECOR')
            .toList();
        final filtered = _categoryFilter == 'ALL'
            ? collectionItems
            : collectionItems
                  .where((i) => i.category == _categoryFilter)
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} mô hình & kỷ vật lịch sử (chạm để khám phá cấu tạo 2.5D)',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.view_in_ar_rounded,
                    size: 18,
                    color: DauVietColors.imperialGoldDark,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final (code, label) = _filters[idx];
                  final selected = _categoryFilter == code;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryFilter = code),
                    child: Center(
                      child: ClueTag(
                        label,
                        color: selected
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.jade,
                        filled: selected,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final rarityColor =
                      _rarityColors[item.rarity] ?? DauVietColors.imperialGold;
                  final kind = resolveHeritageModelKind(
                    code: item.code,
                    renderKey: item.renderKey,
                    title: item.name,
                    category: item.category,
                  );

                  return RareFrameBadge(
                    rarity: _parseRarity(item.rarity),
                    borderRadius: 16,
                    showGlow: item.owned,
                    child: ParchmentCard(
                      padding: const EdgeInsets.all(10),
                      backgroundColor: DauVietColors.paperCard,
                      borderColor: rarityColor.withValues(alpha: 0.65),
                      onTap: () => showHeritageModelInspectorDialog(
                        context,
                        kind: kind,
                        title: item.name,
                        description: item.description,
                        sourceNote: item.sourceNote,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: ClueTag(
                                  _categoryLabels[item.category] ??
                                      item.category,
                                  color: rarityColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                ),
                              ),
                              Icon(
                                item.owned
                                    ? Icons.verified_rounded
                                    : Icons.view_in_ar_rounded,
                                size: 15,
                                color: item.owned
                                    ? DauVietColors.heritageGreen
                                    : DauVietColors.imperialGoldDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFFFFFBF2),
                                    DauVietColors.paperCardHi,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: DauVietColors.outlineVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: HeritageArtifactModelView(
                                code: item.code,
                                renderKey: item.renderKey,
                                title: item.name,
                                category: item.category,
                                size: 92,
                                showPedestal: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DauVietColors.inkHeading,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chạm để xem mô hình 2.5D ›',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: DauVietColors.cinnabarRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
