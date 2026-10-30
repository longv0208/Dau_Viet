import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/collection_dto.dart';
import '../data/collection_providers.dart';
import 'dossier_tab_view.dart';
import 'models_collection_tab_view.dart';

/// FR-40 — Màn "Bộ Sưu Tập Dấu Việt": danh sách bằng chứng lịch sử đã
/// thu thập qua học tập thật (EVIDENCE_SELECT hoàn thành). Nguồn duy nhất
/// là `GET /api/v1/me/collection` (mock chỉ khi USE_MOCK).
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  /// Filter loại đang chọn — '' = Tất cả. Key cho family provider.
  String _typeFilter = '';

  /// Nhãn Tiếng Việt cho các loại chuẩn; loại khác dùng raw type (P2-D).
  String _typeLabel(String? type) => switch (type) {
    'LOCATION' => 'Địa điểm',
    'CHARACTER' => 'Nhân vật',
    'ARTIFACT' => 'Hiện vật',
    'DOCUMENT' => 'Tư liệu',
    null => 'Bằng chứng',
    _ => type,
  };

  /// Primary categories luôn hiển thị; authored types mới sẽ xuất hiện
  /// thêm chip từ `totalElements` của list "Tất cả" — không cần CMS.
  static const List<(String, String)> _primaryChips = [
    ('', 'Tất cả'),
    ('LOCATION', 'Địa điểm'),
    ('CHARACTER', 'Nhân vật'),
    ('ARTIFACT', 'Hiện vật'),
    ('DOCUMENT', 'Tư liệu'),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collectionListProvider(_typeFilter));
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: DauVietColors.paperBackground,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF2E1),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 74,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF3E4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE3D2B4),
                    width: 1.1,
                  ),
                  boxShadow: DauVietColors.softCardShadow,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  color: DauVietColors.inkHeading,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBC3023),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFE6B665),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  'BẢO TÀNG DẤU VIỆT',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: const Color(0xFFFFF6E5),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Bộ Sưu Tập Dấu Việt',
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF163C2B),
                  height: 1.15,
                ),
              ),
            ],
          ),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5CE),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFE3D2B4),
                    width: 1.1,
                  ),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: DauVietColors.heritageGreen,
                    borderRadius: BorderRadius.circular(9.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24163A2B),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: DauVietColors.woodBrown,
                  labelPadding: EdgeInsets.zero,
                  labelStyle: DauVietTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: DauVietTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Dấu'),
                    Tab(text: 'Nhân vật'),
                    Tab(text: 'Địa điểm'),
                    Tab(text: 'Hiện vật'),
                    Tab(text: 'Mô hình'),
                  ],
                ),
              ),
            ),

          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF2E1), Color(0xFFF6ECDA)],
            ),
          ),
          child: TabBarView(
            children: [
              Column(
                children: [
                  _buildHeader(async),
                  _buildFilterRow(async),
                  Expanded(child: _buildBody(async)),
                ],
              ),
              const DossierTabView(dossierType: 'PERSON'),
              const DossierTabView(dossierType: 'LOCATION'),
              const DossierTabView(dossierType: 'ARTIFACT'),
              const ModelsCollectionTabView(),
            ],
          ),
        ),
        bottomNavigationBar: const MainBottomNav(),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<CollectionListState> async) {
    final total = async.value?.totalElements;
    // totalElements là số item của FILTER hiện tại — nói rõ để không bị
    // hiểu nhầm là tổng collection khi đang lọc (§3).
    final filtered = _typeFilter.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF3E4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3D2B4), width: 1.0),
          boxShadow: DauVietColors.softCardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3D6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 15,
                color: DauVietColors.imperialGoldDark,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                total == null
                    ? 'Bằng chứng thu thập qua các bài học'
                    : filtered
                    ? '$total bằng chứng thuộc loại này'
                    : '$total bằng chứng đã sưu tầm',
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DauVietColors.inkHeading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chips: 4 loại chuẩn + loại authored khác lấy từ TOÀN collection qua
  /// `collectionTypesProvider` (§3 — loại chỉ ở trang sau vẫn xuất hiện
  /// chip ngay). Endpoint lỗi → fallback suy ra từ items đã tải.
  Widget _buildFilterRow(AsyncValue<CollectionListState> async) {
    final chips = List<(String, String)>.from(_primaryChips);
    final known = _primaryChips.map((c) => c.$1).toSet();

    final serverTypes = ref.watch(collectionTypesProvider).value;
    final fallbackTypes = (async.value?.items ?? const [])
        .map((i) => i.evidenceType)
        .whereType<String>()
        .toSet();
    final extra = (serverTypes ?? fallbackTypes.toList())
        .where((t) => t.isNotEmpty && !known.contains(t))
        .toSet();
    // Giữ chip của filter đang chọn hiển thị kể cả lúc types chưa tải
    // xong/lỗi — chip mất giữa chừng làm UI giật và mất context (§3).
    if (_typeFilter.isNotEmpty && !known.contains(_typeFilter)) {
      extra.add(_typeFilter);
    }
    for (final t in extra) {
      chips.add((t, _typeLabel(t)));
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = chips[i];
          final selected = _typeFilter == value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _typeFilter = value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1A4B38)
                        : const Color(0xFFFAF3E4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFDEC69A).withValues(alpha: 0.55)
                          : const Color(0xFFE3D2B4),
                      width: 1.1,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x24163A2B),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : DauVietColors.softCardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        value.isEmpty
                            ? Icons.grid_view_rounded
                            : _typeIcon(value),
                        size: 13,
                        color: selected
                            ? const Color(0xFFFFDEA7)
                            : _typeStampColor(value),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 11.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : DauVietColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncValue<CollectionListState> async) {
    return async.when(
      loading: () => AsyncStateView.loading(),
      error: (e, _) => AsyncStateView.error(
        error: e,
        onRetry: () => ref.invalidate(collectionListProvider(_typeFilter)),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return _emptyState();
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: DauVietColors.cinnabarRed,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount:
                list.items.length +
                (list.hasMore || list.loadMoreError != null ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == list.items.length) {
                return list.loadMoreError != null
                    ? _buildLoadMoreError(list)
                    : _buildLoadMore(list);
              }
              return _buildCard(list.items[i]);
            },
          ),
        );
      },
    );
  }

  /// Empty state + CTA mở luồng khám phá bài học thật (P2-C). Không
  /// hard-code Bạch Đằng — dùng trang danh sách sự kiện (campaign list) vì
  /// backend chưa có endpoint /events/list riêng; /dashboard là điểm vào
  /// chính xác của discovery flow.
  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: DauVietColors.cinnabarRed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: EmptyStateCard(
              title: 'Chưa có dấu vết',
              description:
                  'Hoàn thành bài học để thu thập dấu vết đầu tiên.',
              actionLabel: 'Bắt đầu học',
              onAction: () => context.go('/dashboard'),
              icon: Icons.museum_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(collectionListProvider(_typeFilter));
    await ref.read(collectionListProvider(_typeFilter).future);
  }

  Widget _buildLoadMore(CollectionListState list) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: list.isLoadingMore
              ? null
              : () => ref
                    .read(collectionListProvider(_typeFilter).notifier)
                    .loadMore(),
          icon: list.isLoadingMore
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded, size: 18),
          label: Text(list.isLoadingMore ? 'Đang tải...' : 'Xem thêm'),
          style: TextButton.styleFrom(
            foregroundColor: DauVietColors.cinnabarRed,
            textStyle: DauVietTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  /// Banner lỗi load-more: giữ items + vị trí scroll, nút THỬ LẠI chỉ gọi
  /// loadMore một lần cho đúng trang kế (P2-B).
  Widget _buildLoadMoreError(CollectionListState list) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TactileCard(
        usePixelShadow: false,
        backgroundColor: const Color(0xFFFDE3DD),
        borderRadius: 14,
        borderWidth: 1.1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderColor: DauVietColors.errorRed.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: DauVietColors.errorRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chưa tải thêm được. Kiểm tra kết nối rồi thử lại.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.errorRed,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(collectionListProvider(_typeFilter).notifier)
                  .loadMore(),
              style: TextButton.styleFrom(
                foregroundColor: DauVietColors.cinnabarRed,
                textStyle: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ),
    );
  }

  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  Widget _buildCard(
    CollectionItemDto item, {
    bool unlocked = true,
    ItemRarity? rarity,
  }) {
    final evidence = item.evidence;
    final accent = _typeStampColor(item.evidenceType);
    final bgTint = _typeBgColor(item.evidenceType);

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Thumbnail: asset thật nếu có; fallback icon loại bằng chứng trong khung pastel mềm.
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: bgTint,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: accent.withValues(alpha: 0.30),
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: item.assetId != null
              ? LearningAssetImage(
                  assetId: item.assetId!,
                  altText: item.title,
                  height: 72,
                  fit: BoxFit.cover,
                  tappable: false,
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _typeIcon(item.evidenceType),
                      size: 24,
                      color: accent,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeBadge(item.evidenceType),
                  const SizedBox(width: 6),
                  if (item.eventTitle != null)
                    Expanded(
                      child: Text(
                        item.eventTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.labelMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.inkHeading,
                ),
              ),
              if (evidence?.description != null) ...[
                const SizedBox(height: 3),
                Text(
                  evidence!.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: DauVietColors.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: unlocked
                    ? DauVietColors.heritageGreenSurface
                    : const Color(0xFFF3E5CE),
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked
                      ? DauVietColors.heritageGreenLight.withValues(alpha: 0.38)
                      : const Color(0xFFE3D2B4),
                  width: 1.0,
                ),
              ),
              child: Icon(
                unlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 14,
                color: unlocked
                    ? DauVietColors.heritageGreen
                    : DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: DauVietColors.inkMuted,
              size: 20,
            ),
          ],
        ),
      ],
    );

    Widget cardBody = unlocked
        ? rowContent
        : ColorFiltered(
            colorFilter: _grayscaleFilter,
            child: rowContent,
          );

    Widget card = TactileCard(
      usePixelShadow: false,
      backgroundColor: const Color(0xFFFAF3E4),
      borderColor: const Color(0xFFE3D2B4),
      borderWidth: 1.1,
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      onTap: unlocked
          ? () => context.push('/collection/${item.evidenceId}')
          : null,
      child: cardBody,
    );

    if (rarity != null) {
      card = RareFrameBadge(
        rarity: rarity,
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: card,
    );
  }

  Color _typeStampColor(String? type) => switch (type) {
    'LOCATION' => DauVietColors.jadeDark,
    'CHARACTER' => DauVietColors.heritageGreenLight,
    'ARTIFACT' => DauVietColors.imperialGoldDark,
    'DOCUMENT' => DauVietColors.cinnabarRed,
    _ => DauVietColors.jadeDark,
  };

  Color _typeBgColor(String? type) => switch (type) {
    'LOCATION' => const Color(0xFFDCEFED),
    'CHARACTER' => DauVietColors.heritageGreenSurface,
    'ARTIFACT' => const Color(0xFFFFF3D6),
    'DOCUMENT' => const Color(0xFFFDE3DD),
    _ => const Color(0xFFDCEFED),
  };

  IconData _typeIcon(String? type) => switch (type) {
    'LOCATION' => Icons.place_rounded,
    'CHARACTER' => Icons.person_rounded,
    'ARTIFACT' => Icons.diamond_rounded,
    'DOCUMENT' => Icons.menu_book_rounded,
    _ => Icons.inventory_2_rounded,
  };

  Widget _typeBadge(String? type) {
    final accent = _typeStampColor(type);
    final bg = _typeBgColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
          width: 1.0,
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
