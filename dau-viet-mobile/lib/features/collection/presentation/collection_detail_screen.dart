import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/parchment_card.dart';
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
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: DauVietColors.parchmentSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: DauVietColors.inkText,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/collection'),
        ),
        title: Text(
          'Chi Tiết Bằng Chứng',
          style: DauVietTypography.headlineSmall.copyWith(
            color: DauVietColors.cinnabarRed,
          ),
        ),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => AsyncStateView.loading(),
        error: (e, _) => AsyncStateView.error(
          error: e,
          onRetry: () => ref.invalidate(collectionDetailProvider(evidenceId)),
        ),
        data: (item) => _buildDetail(context, item),
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
            LearningAssetImage(
              assetId: item.assetId!,
              altText: item.title,
              height: 240,
              fit: BoxFit.cover,
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
        ],
      ),
    );
  }

  bool _hasSource(EvidenceSourceDto s) =>
      (s.title?.isNotEmpty ?? false) ||
      (s.author?.isNotEmpty ?? false) ||
      (s.citation?.isNotEmpty ?? false) ||
      (s.url?.isNotEmpty ?? false);

  Widget _typeBadge(String? type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: DauVietColors.cinnabarRed.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: DauVietColors.cinnabarRed,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _metaSection(CollectionItemDto item) {
    return ParchmentCard(
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
    return ParchmentCard(
      padding: const EdgeInsets.all(14),
      borderColor: DauVietColors.imperialGold,
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
