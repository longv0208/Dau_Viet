import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/dossier_dto.dart';
import '../data/dossier_providers.dart';

/// GAME-04 — Chi tiết một hồ sơ lịch sử. Unlocked = đầy đủ (mô tả +
/// nguồn trích dẫn); locked preview = metadata + yêu cầu mở khoá.
class DossierDetailScreen extends ConsumerWidget {
  final String dossierId;

  const DossierDetailScreen({super.key, required this.dossierId});

  String _typeLabel(String type) => switch (type) {
    'PERSON' => 'Nhân vật',
    'LOCATION' => 'Địa điểm',
    'ARTIFACT' => 'Hiện vật',
    'CONTEXT' => 'Bối cảnh',
    _ => type,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dossierDetailProvider(dossierId));
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
          'Hồ Sơ Lịch Sử',
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
              onRetry: () => ref.invalidate(dossierDetailProvider(dossierId)),
            ),
            data: (d) => _buildDetail(context, d),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, DossierDetailDto d) {
    final locked = d.preview;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.assetId != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDEC69A), width: 1.2),
                boxShadow: DauVietColors.softCardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: LearningAssetImage(
                assetId: d.assetId!,
                altText: d.title,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          _typeBadge(d.dossierType),
          const SizedBox(height: 10),
          Text(
            d.title,
            style: DauVietTypography.headlineMedium.copyWith(
              color: DauVietColors.inkText,
            ),
          ),
          if (d.summary != null) ...[
            const SizedBox(height: 8),
            Text(
              d.summary!,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.5,
              ),
            ),
          ],
          if (locked) ...[
            const SizedBox(height: 18),
            _lockedBanner(),
          ] else ...[
            if (d.description != null) ...[
              const SizedBox(height: 14),
              Text(
                d.description!,
                style: DauVietTypography.bodyMedium.copyWith(height: 1.55),
              ),
            ],
            if (d.source != null) ...[
              const SizedBox(height: 18),
              _sourceCard(d.source!),
            ],
            if (d.grantedAt != null) ...[
              const SizedBox(height: 14),
              _metaSection(d),
            ],
          ],
        ],
      ),
    );
  }

  Widget _lockedBanner() {
    return TactileCard(
      usePixelShadow: false,
      backgroundColor: const Color(0xFFFAF3E4),
      borderColor: const Color(0xFFE3D2B4),
      borderWidth: 1.1,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: DauVietColors.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hoàn thành sự kiện lịch sử liên quan để mở toàn bộ hồ sơ — '
              'mô tả chi tiết và nguồn trích dẫn chỉ hiện sau khi mở khoá.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeAccentColor(String type) => switch (type) {
    'PERSON' => DauVietColors.heritageGreenLight,
    'LOCATION' => DauVietColors.jadeDark,
    'ARTIFACT' => DauVietColors.imperialGoldDark,
    'CONTEXT' => DauVietColors.cinnabarRed,
    _ => DauVietColors.jadeDark,
  };

  Color _typeBgColor(String type) => switch (type) {
    'PERSON' => DauVietColors.heritageGreenSurface,
    'LOCATION' => const Color(0xFFDCEFED),
    'ARTIFACT' => const Color(0xFFFFF3D6),
    'CONTEXT' => const Color(0xFFFDE3DD),
    _ => const Color(0xFFDCEFED),
  };

  Widget _typeBadge(String type) {
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

  Widget _metaSection(DossierDetailDto d) {
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
          _metaRow(
            Icons.bookmark_added_rounded,
            'Mở khoá lúc',
            _formatDate(d.grantedAt!),
          ),
          if (d.unlockEventId != null)
            _metaRow(Icons.event_rounded, 'Từ sự kiện', d.unlockEventId!),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
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

  Widget _sourceCard(DossierSourceDto s) {
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
          if (s.citation != null && s.citation!.isNotEmpty)
            _sourceLine(s.citation!, italic: true),
          if (s.url != null && s.url!.isNotEmpty) _sourceLine(s.url!),
          if (s.reliability != null && s.reliability!.isNotEmpty)
            _sourceLine('Độ tin cậy: ${s.reliability}'),
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
