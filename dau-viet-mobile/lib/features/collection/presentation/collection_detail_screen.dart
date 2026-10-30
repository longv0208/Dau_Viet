import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../../core/widgets/heritage_artifact_model_view.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/collection_dto.dart';
import '../data/collection_providers.dart';

/// FR-41 — Chi tiết một bằng chứng đã sưu tập: ảnh (zoom qua tap),
/// mô tả, loại, nguồn trích dẫn, sự kiện, bài học và ngày thu thập.
/// Dữ liệu lấy từ snapshot immutable — bền khi admin sửa/archive gốc.
class CollectionDetailScreen extends ConsumerWidget {
  final String evidenceId;

  const CollectionDetailScreen({super.key, required this.evidenceId});

  String _typeLabel(String? type) => switch (type) {
    'LOCATION' => 'Địa điểm',
    'CHARACTER' => 'Nhân vật',
    'ARTIFACT' => 'Hiện vật',
    'DOCUMENT' => 'Tư liệu',
    null => 'Bằng chứng',
    _ => type,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionDetailProvider(evidenceId));
    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF2E1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF3E4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE3D2B4), width: 1.1),
                boxShadow: DauVietColors.softCardShadow,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                color: DauVietColors.inkHeading,
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/collection'),
              ),
            ),
          ),
        ),
        title: Text(
          'Chi Tiết Bằng Chứng',
          style: DauVietTypography.headlineSmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF163C2B),
          ),
        ),
        centerTitle: false,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF2E1), Color(0xFFF6ECDA)],
          ),
        ),
        child: SizedBox.expand(
          child: async.when(
            loading: () => AsyncStateView.loading(),
            error: (e, _) => AsyncStateView.error(
              error: e,
              onRetry: () =>
                  ref.invalidate(collectionDetailProvider(evidenceId)),
            ),
            data: (item) => _buildDetail(context, item),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, CollectionItemDto item) {
    final evidence = item.evidence;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh lớn — tap mở fullscreen zoom (tappable mặc định của
          // LearningAssetImage).
          if (item.assetId != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDEC69A), width: 1.2),
                boxShadow: DauVietColors.softCardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: LearningAssetImage(
                assetId: item.assetId!,
                altText: item.title,
                height: 240,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFF8E8), DauVietColors.paperCardHi],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DauVietColors.imperialGold),
              ),
              alignment: Alignment.center,
              child: HeritageArtifactModelView(
                title: item.title,
                category: item.evidenceType,
                size: 148,
                showPedestal: true,
                interactiveInspector: true,
                description: evidence?.description,
              ),
            ),
          const SizedBox(height: 16),
          _typeBadge(item.evidenceType),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: DauVietTypography.headlineMedium.copyWith(
              color: DauVietColors.inkText,
            ),
          ),
          if (evidence?.description != null) ...[
            const SizedBox(height: 10),
            Text(
              evidence!.description!,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          _metaSection(item),
          if (evidence?.source != null && _hasSource(evidence!.source!)) ...[
            const SizedBox(height: 14),
            _sourceCard(evidence.source!),
          ],
          // P2-C — CTA mở sự kiện liên quan khi backend trả eventId.
          // CampaignDetailScreen tự xử lý event archived/404 (AsyncStateView
          // lỗi/empty) nên ta chỉ truyền id, không suy diễn trạng thái.
          if (item.eventId != null) ...[
            const SizedBox(height: 14),
            TactileCard(
              usePixelShadow: false,
              backgroundColor: const Color(0xFFFAF3E4),
              borderColor: const Color(0xFFDEC69A),
              borderWidth: 1.1,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3D6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_rounded,
                      size: 16,
                      color: DauVietColors.imperialGoldDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.eventTitle != null
                          ? 'Sự kiện: ${item.eventTitle}'
                          : 'Mở sự kiện liên quan',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkHeading,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/campaign/${item.eventId}'),
                    style: TextButton.styleFrom(
                      foregroundColor: DauVietColors.cinnabarRed,
                      textStyle: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('XEM SỰ KIỆN'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasSource(EvidenceSourceDto s) =>
      (s.title?.isNotEmpty ?? false) ||
      (s.author?.isNotEmpty ?? false) ||
      (s.citation?.isNotEmpty ?? false) ||
      (s.url?.isNotEmpty ?? false);

  Color _typeAccentColor(String? type) => switch (type) {
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

  Widget _typeBadge(String? type) {
    final accent = _typeAccentColor(type);
    final bg = _typeBgColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
          width: 1.0,
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _metaSection(CollectionItemDto item) {
    return TactileCard(
      usePixelShadow: false,
      backgroundColor: const Color(0xFFFAF3E4),
      borderColor: const Color(0xFFE3D2B4),
      borderWidth: 1.1,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.eventTitle != null)
            _metaRow(Icons.event_rounded, 'Sự kiện', item.eventTitle!),
          if (item.lessonTitle != null)
            _metaRow(Icons.school_rounded, 'Thu từ bài', item.lessonTitle!),
          if (item.collectedAt != null)
            _metaRow(
              Icons.bookmark_added_rounded,
              'Thu thập lúc',
              _formatDate(item.collectedAt!),
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: DauVietColors.imperialGold),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceCard(EvidenceSourceDto s) {
    return TactileCard(
      usePixelShadow: false,
      backgroundColor: const Color(0xFFFAF3E4),
      borderColor: const Color(0xFFDEC69A),
      borderWidth: 1.1,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.source_rounded,
                size: 15,
                color: DauVietColors.cinnabarRed,
              ),
              const SizedBox(width: 6),
              Text(
                'NGUỒN TRÍCH DẪN',
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.cinnabarRed,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if (s.title != null && s.title!.isNotEmpty)
            _sourceLine(s.title!, bold: true),
          if (s.author != null && s.author!.isNotEmpty)
            _sourceLine('Tác giả: ${s.author}'),
          if (s.publishedAt != null && s.publishedAt!.isNotEmpty)
            _sourceLine('Xuất bản: ${s.publishedAt}'),
          if (s.citation != null && s.citation!.isNotEmpty)
            _sourceLine(s.citation!, italic: true),
          if (s.url != null && s.url!.isNotEmpty) _sourceLine(s.url!),
        ],
      ),
    );
  }

  Widget _sourceLine(String text, {bool bold = false, bool italic = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: DauVietTypography.bodySmall.copyWith(
          color: DauVietColors.inkText,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.4,
        ),
      ),
    );
  }
}
