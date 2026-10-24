import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main-bottom-nav.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/collection_dto.dart';
import '../data/collection_providers.dart';
import 'dossier_tab_view.dart';

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
      length: 4,
      child: Scaffold(
        backgroundColor: DauVietColors.parchmentSurface,
        appBar: AppBar(
          backgroundColor: DauVietColors.parchmentSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: DauVietColors.inkText,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
          ),
          title: Text(
            'Bộ Sưu Tập Dấu Việt',
            style: DauVietTypography.headlineSmall.copyWith(
              color: DauVietColors.cinnabarRed,
            ),
          ),
          centerTitle: false,
          bottom: TabBar(
            labelColor: DauVietColors.cinnabarRed,
            unselectedLabelColor: DauVietColors.inkMuted,
            indicatorColor: DauVietColors.cinnabarRed,
            labelStyle: DauVietTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
            tabs: const [
              Tab(text: 'Dấu'),
              Tab(text: 'Nhân vật'),
              Tab(text: 'Địa điểm'),
              Tab(text: 'Hiện vật'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: bằng chứng đã thu thập (UI cũ, giữ nguyên).
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
          ],
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              total == null
                  ? 'Bằng chứng thu thập qua các bài học'
                  : filtered
                  ? '$total bằng chứng thuộc loại này'
                  : '$total bằng chứng đã sưu tầm',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          const Icon(
            Icons.auto_stories_rounded,
            size: 18,
            color: DauVietColors.imperialGold,
          ),
        ],
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
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _typeFilter = value),
            labelStyle: DauVietTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : DauVietColors.inkText,
            ),
            selectedColor: DauVietColors.cinnabarRed,
            backgroundColor: DauVietColors.parchmentContainer,
            side: BorderSide(
              color: selected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
            ),
            showCheckmark: false,
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
            child: ParchmentCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    size: 40,
                    color: DauVietColors.cinnabarRed,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Bộ sưu tập còn trống',
                    textAlign: TextAlign.center,
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hoàn thành các hoạt động chọn bằng chứng trong bài học '
                    'để lưu bằng chứng vào đây.',
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: const Text('KHÁM PHÁ BÀI HỌC'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: DauVietColors.cinnabarRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      textStyle: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
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
      child: ParchmentCard(
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

  Widget _buildCard(CollectionItemDto item) {
    final evidence = item.evidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ParchmentCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/collection/${item.evidenceId}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail: asset thật nếu có; fallback icon loại bằng chứng.
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: item.assetId != null
                    ? LearningAssetImage(
                        assetId: item.assetId!,
                        altText: item.title,
                        height: 72,
                        fit: BoxFit.cover,
                        tappable: false,
                      )
                    : Container(
                        color: DauVietColors.parchmentHigh,
                        child: Icon(
                          _typeIcon(item.evidenceType),
                          size: 30,
                          color: DauVietColors.cinnabarRed,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (evidence?.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      evidence!.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DauVietColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String? type) => switch (type) {
    'LOCATION' => Icons.place_rounded,
    'CHARACTER' => Icons.person_rounded,
    'ARTIFACT' => Icons.diamond_rounded,
    'DOCUMENT' => Icons.menu_book_rounded,
    _ => Icons.inventory_2_rounded,
  };

  Widget _typeBadge(String? type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: DauVietColors.cinnabarRed.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: DauVietColors.cinnabarRed,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
