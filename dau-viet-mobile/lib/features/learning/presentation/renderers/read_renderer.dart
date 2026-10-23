import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../animations/historical_animation_player.dart';
import '../animations/historical_animation_registry.dart';
import '../animations/runtime/animation_manifest_dto.dart';
import '../animations/runtime/animation_runtime_registry.dart';
import '../animations/widgets/manifest_asset_layers.dart';
import 'renderer_base.dart';

/// READ — nội dung đọc + nút "Đã đọc xong, tiếp tục" (acknowledgment `{}`).
/// Không chấm điểm phía client; server trả COMPLETED.
/// Typography theo hướng "sử liệu": title nổi bật, đoạn văn thoáng, dễ đọc
/// dài trên màn nhỏ. Hỗ trợ `body`/`text`/`content`/`passage` + `paragraphs[]`.
class ReadRenderer extends StatelessWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const ReadRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final config = activity.config;
    final String? title = configText(config, [
      'title',
      'heading',
      'passageTitle',
    ]);
    final String? subtitle = configText(config, ['subtitle', 'lede']);
    final String? source = configText(config, ['source', 'attribution']);

    // Draft schema: body/text/content/paragraphs — render tuần tự.
    final List<Widget> blocks = [];
    final String? body = configText(config, [
      'body',
      'text',
      'content',
      'passage',
    ]);
    if (body != null) {
      for (final para in _splitParagraphs(body)) {
        blocks.add(_Paragraph(para));
      }
    }
    final Object? paragraphs = config['paragraphs'];
    if (paragraphs is List) {
      for (final p in paragraphs.whereType<String>()) {
        for (final para in _splitParagraphs(p)) {
          blocks.add(_Paragraph(para));
        }
      }
    }
    if (blocks.isEmpty) {
      blocks.add(const _Paragraph('(Không có nội dung đọc.)'));
    }

    // ANIM-03: ưu tiên manifest data-driven embed trong snapshot
    // (`config.animationManifest`) — published scene pin sẵn manifest +
    // renderer code. Legacy `config.animationKey` (snapshot cũ) vẫn
    // resolve qua registry hard-code. Cả hai đều null → render text
    // thường; rendererCode lạ (app cũ gặp renderer mới) → fallback
    // placeholder an toàn, KHÔNG crash.
    final manifestDto = AnimationRuntimeRegistry.parseManifest(
      config['animationManifest'],
    );
    final manifestRenderer = manifestDto == null
        ? null
        : AnimationRuntimeRegistry.resolve(manifestDto.rendererCode);
    final playbackMode = configText(config, ['playbackMode']) ?? 'AUTO';
    final animation = manifestRenderer != null &&
            manifestRenderer.canRender(manifestDto!)
        ? manifestRenderer.build(manifestDto, playbackMode: playbackMode)
        : HistoricalAnimationRegistry.resolve(
            configText(config, ['animationKey']),
          );
    final bool unsupportedManifest =
        manifestDto != null && manifestRenderer == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (animation != null) ...[
          // Keyed theo animationKey + activity id: đổi activity → dispose
          // controller cũ, không rò state giữa các bài.
          //
          // P0-4: manifest mang assets[]/objects[] → bọc player bằng lớp
          // ảnh (background dưới + object trên). Manifest KHÔNG khai báo
          // ảnh nào → widget trả về `child` nguyên trạng, không đổi layout.
          ManifestAssetLayers(
            manifest: manifestDto ?? AnimationManifestDto.empty,
            aspectRatio: animation.aspectRatio,
            child: HistoricalAnimationPlayer(
              key: ValueKey('anim_${animation.key}_${activity.id}'),
              definition: animation,
            ),
          ),
          const SizedBox(height: 14),
        ] else if (unsupportedManifest) ...[
          // ANIM-03: app cũ gặp manifest của renderer chưa hỗ trợ —
          // fallback rõ ràng thay vì crash hay im lặng trắng.
          _UnsupportedAnimationNotice(title: manifestDto.title),
          const SizedBox(height: 14),
        ],
        ActivityCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 19,
                    height: 1.3,
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: DauVietColors.cinnabarRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    subtitle,
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkMuted,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              ...blocks,
              if (source != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Nguồn: $source',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: DauVietColors.inkMuted,
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
          label: 'ĐÃ ĐỌC XONG, TIẾP TỤC',
          onPressed: () => onSubmit(const {}),
        ),
      ],
    );
  }

  /// Tách đoạn theo dòng trống / \n\n để spacing đều khi tác giả viết
  /// một block dài.
  static List<String> _splitParagraphs(String text) => text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

/// ANIM-03 — Fallback khi snapshot embed manifest của renderer mà app
/// hiện tại chưa hỗ trợ (versioning case 4). Hiển thị nội dung đọc
/// bình thường + thông báo nhẹ — không crash, không chặn học.
class _UnsupportedAnimationNotice extends StatelessWidget {
  final String title;
  const _UnsupportedAnimationNotice({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.movie_outlined,
            color: DauVietColors.inkMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hoạt họa${title.isEmpty ? '' : ' "$title"'} cần phiên bản '
              'ứng dụng mới hơn. Nội dung đọc vẫn đầy đủ bên dưới.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText(
        text,
        style: DauVietTypography.bodyMedium.copyWith(
          color: DauVietColors.inkText,
          height: 1.7,
          fontSize: 15,
        ),
      ),
    );
  }
}
