import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'learning_asset_image.dart';
import 'renderer_base.dart';

/// VIEW_IMAGE — ảnh lịch sử + caption + hướng dẫn quan sát + nút tiếp tục.
/// Ảnh qua learner asset endpoint có auth; thiếu asset → fallback alt.
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
      'source',
    ]);
    final Map<String, dynamic>? assetMeta = assetId == null
        ? null
        : content.assetById(assetId);
    final String alt =
        (assetMeta?['altText'] as String?) ?? caption ?? 'Hình ảnh tư liệu';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (assetId != null)
                LearningAssetImage(
                  assetId: assetId,
                  altText: alt,
                  height: 240,
                  fit: BoxFit.cover,
                )
              else
                _NoImage(altText: alt),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    caption,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
}

class _NoImage extends StatelessWidget {
  final String altText;
  const _NoImage({required this.altText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(altText, style: DauVietTypography.bodySmall),
    );
  }
}
