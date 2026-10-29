import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/dong_son_button.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/stamp_seal_badge.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'learning_asset_image.dart';
import 'renderer_base.dart';

/// VIEW_IMAGE — ảnh lịch sử + caption + attribution + gợi ý quan sát.
/// Ảnh qua learner asset endpoint có auth; thiếu/lỗi asset → fallback alt.
/// Tap ảnh → fullscreen pinch-zoom (LearningAssetImage lo phần này).
class ViewImageRenderer extends StatelessWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const ViewImageRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final config = activity.config;
    final String? assetId = configText(config, [
      'imageAssetId',
      'assetId',
      'imageId',
      'image',
    ]);
    final String? caption = configText(config, [
      'caption',
      'description',
      'alt',
      'source',
    ]);
    // Gợi ý quan sát: câu hỏi dẫn learner nhìn kỹ chi tiết ảnh.
    final String? observePrompt = configText(config, [
      'observePrompt',
      'guidingQuestion',
      'prompt',
      'question',
    ]);
    final Map<String, dynamic>? assetMeta = assetId == null
        ? null
        : content.assetById(assetId);
    final String alt =
        (assetMeta?['altText'] as String?) ?? caption ?? 'Hình ảnh tư liệu';
    // Attribution từ asset metadata (credit/attribution) hoặc config.source —
    // chỉ hiển thị khi tác giả cung cấp, không tự bịa nguồn.
    final String? attribution =
        configText(config, ['attribution', 'credit']) ??
        (assetMeta?['credit'] as String?) ??
        (assetMeta?['attribution'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TactileCard(
          padding: const EdgeInsets.all(10),
          borderWidth: 2.4,
          borderColor: DauVietColors.inkHeading,
          usePixelShadow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  if (assetId != null)
                    LearningAssetImage(
                      assetId: assetId,
                      altText: alt,
                      height: 240,
                      fit: BoxFit.cover,
                      tappable: !submitting,
                    )
                  else
                    _NoImage(altText: alt),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: StampSealBadge('XEM', size: 32),
                    ),
                  ),
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SectionEyebrow('HIỆN VẬT'),
                ),
                const SizedBox(height: 6),
                Text(
                  caption,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ],
              if (attribution != null && attribution.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Ảnh: $attribution',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 10.5,
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              DongSonButton(
                label: 'Soi chi tiết',
                icon: Icons.zoom_in,
                variant: DongSonButtonVariant.secondaryParchment,
                height: 44,
                onPressed: submitting
                    ? null
                    : () => _openZoomDialog(context, assetId, alt),
              ),
            ],
          ),
        ),
        if (observePrompt != null) ...[
          const SizedBox(height: 10),
          TactileCard(
            usePixelShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.travel_explore_rounded,
                  size: 18,
                  color: DauVietColors.imperialGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    observePrompt,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkText,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SubmitBar(
          enabled: true,
          submitting: submitting,
          label: 'ĐÃ QUAN SÁT, TIẾP TỤC',
          onPressed: () => onSubmit(const {}),
        ),
      ],
    );
  }

  void _openZoomDialog(BuildContext context, String? assetId, String alt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: DauVietColors.inkText.withValues(alpha: 0.92),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: assetId != null
                      ? LearningAssetImage(
                          assetId: assetId,
                          altText: alt,
                          fit: BoxFit.contain,
                          tappable: false,
                        )
                      : _NoImage(altText: alt),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  final String altText;
  const _NoImage({required this.altText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DauVietColors.paperCardHi.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_outlined,
            size: 30,
            color: DauVietColors.inkMuted,
          ),
          const SizedBox(height: 6),
          Text(
            altText,
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
