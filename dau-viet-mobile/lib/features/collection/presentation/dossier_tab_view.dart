import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/tactile_card.dart';
import '../data/dossier_providers.dart';
import 'dossier_card.dart';

/// Tab "Nhân vật / Địa điểm / Hiện vật" trong Bộ Sưu Tập — danh sách
/// dossier theo loại, phân trang load-more. `eventId` null = toàn bộ
/// collection; truyền khi gọi từ campaign detail để chỉ hiện dossier của
/// sự kiện đó.
class DossierTabView extends ConsumerWidget {
  /// PERSON | LOCATION | ARTIFACT — filter type của tab.
  final String dossierType;

  /// Optional: chỉ dossier gắn event này (empty event scope = copy riêng).
  final String? eventId;

  const DossierTabView({super.key, required this.dossierType, this.eventId});

  DossierFilter get _filter =>
      (type: dossierType, eventId: eventId, unlocked: null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dossierListProvider(_filter));
    return async.when(
      loading: () => AsyncStateView.loading(),
      error: (e, _) => AsyncStateView.error(
        error: e,
        onRetry: () => ref.invalidate(dossierListProvider(_filter)),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return _emptyState(context, ref);
        }
        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
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
                    ? _buildLoadMoreError(context, ref, list)
                    : _buildLoadMore(context, ref, list);
              }
              return DossierCard(dossier: list.items[i]);
            },
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    final isEventScope = eventId != null;
    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      color: DauVietColors.cinnabarRed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TactileCard(
              usePixelShadow: false,
              backgroundColor: const Color(0xFFFAF3E4),
              borderColor: const Color(0xFFE3D2B4),
              borderWidth: 1.1,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: DauVietColors.heritageGreenSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DauVietColors.heritageGreenLight.withValues(
                          alpha: 0.35,
                        ),
                        width: 1.1,
                      ),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 28,
                      color: DauVietColors.heritageGreen,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isEventScope
                        ? 'Sự kiện chưa có hồ sơ'
                        : 'Chưa có hồ sơ loại này',
                    textAlign: TextAlign.center,
                    style: DauVietTypography.headlineSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.inkHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEventScope
                        ? 'Hoàn thành sự kiện để mở hồ sơ lịch sử liên quan.'
                        : 'Hoàn thành các sự kiện lịch sử để mở hồ sơ.',
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      height: 1.4,
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

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dossierListProvider(_filter));
    await ref.read(dossierListProvider(_filter).future);
  }

  Widget _buildLoadMore(
    BuildContext context,
    WidgetRef ref,
    DossierListState list,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: list.isLoadingMore
              ? null
              : () =>
                    ref.read(dossierListProvider(_filter).notifier).loadMore(),
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

  Widget _buildLoadMoreError(
    BuildContext context,
    WidgetRef ref,
    DossierListState list,
  ) {
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
              onPressed: () =>
                  ref.read(dossierListProvider(_filter).notifier).loadMore(),
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
}
