import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../data/attempt_dtos.dart';
import '../animations/historical_animation_definition.dart';
import '../animations/historical_animation_player.dart';
import '../animations/historical_animation_registry.dart';
import '../animations/html_animation_player.dart';
import '../animations/runtime/animation_manifest_dto.dart';
import '../animations/runtime/animation_runtime_registry.dart';
import '../animations/runtime/cinematic_state.dart';
import 'renderer_base.dart';
import '../lesson_cover_resolver.dart';

/// READ — nội dung đọc + nút "Đã đọc xong, tiếp tục" (acknowledgment `{}`).
/// Không chấm điểm phía client; server trả COMPLETED.
/// Typography theo hướng "sử liệu": title nổi bật, đoạn văn thoáng, dễ đọc
/// dài trên màn nhỏ. Hỗ trợ `body`/`text`/`content`/`passage` + `paragraphs[]`.
class ReadRenderer extends StatelessWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  /// Test seam: thay player HTML để widget-test không cần WebViewPlatform.
  /// Production để null → `_HtmlSceneSlot` tự dựng `HtmlAnimationPlayer`.
  final Widget Function(String sceneVersionId, AnimationManifestDto manifest)?
  htmlPlayerFactory;

  const ReadRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.htmlPlayerFactory,
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
    final String? source = configText(config, [
      'source',
      'citation',
      'attribution',
    ]);
    final String? callout = configText(config, [
      'callout',
      'quote',
      'historicalQuote',
    ]);

    // Draft schema: body/text/content/paragraphs/sections — render tuần tự.
    final List<Widget> blocks = [];
    final String? body = configText(config, [
      'body',
      'text',
      'content',
      'passage',
    ]);
    final bool hasPrimaryBody =
        configText(config, ['body', 'content', 'text']) != null;
    bool dropCapApplied = false;
    if (body != null) {
      for (final para in _splitParagraphs(body)) {
        final useDropCap = hasPrimaryBody && !dropCapApplied;
        blocks.add(_Paragraph(para, dropCap: useDropCap));
        dropCapApplied = true;
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
    final sections = configList(config, 'sections');
    for (final s in sections) {
      final String? secTitle = configText(s, ['title', 'heading', 'label']);
      final String? secBody = configText(s, ['body', 'text', 'content']);
      if (secTitle != null && secTitle.trim().isNotEmpty) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              secTitle.trim(),
              style: DauVietTypography.headlineSmall.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
              ),
            ),
          ),
        );
      }
      if (secBody != null) {
        for (final para in _splitParagraphs(secBody)) {
          blocks.add(_Paragraph(para));
        }
      }
    }
    if (callout != null && callout.trim().isNotEmpty) {
      blocks.add(
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: DauVietColors.imperialGold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: DauVietColors.imperialGold, width: 3.5),
            ),
          ),
          child: Text(
            callout.trim(),
            style: DauVietTypography.ancientCitation.copyWith(
              fontSize: 14.5,
              height: 1.55,
              color: DauVietColors.inkText,
            ),
          ),
        ),
      );
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
    //
    // FIX-P1 — phân biệt 3 nhánh, KHÔNG để manifest hỏng rơi về
    // animationKey (đó là scene khác, sai ngữ cảnh):
    //   1. Không có animationManifest, không animationKey → text thường.
    //   2. Chỉ legacy animationKey → registry hard-code (snapshot cũ).
    //   3. Có animationManifest nhưng invalid/unsupported → notice rõ,
    //      giữ nội dung đọc, không crash, không tự hoàn thành bài.
    final parseRes = AnimationRuntimeRegistry.parseManifestDetailed(
      config['animationManifest'],
    );
    final manifestDto = parseRes.dto;

    // HTML_WEBVIEW — nhánh riêng trước runtime registry: scene HTML không
    // build thành HistoricalAnimationDefinition (không steps/painter);
    // player là WebView fetch bytes theo sceneVersionId pin trong
    // envelope. Manifest phải có html.sha256 + envelope có sceneVersionId.
    final bool isHtmlScene =
        manifestDto?.rendererCode == 'HTML_WEBVIEW' &&
        manifestDto?.html != null;
    final manifestRenderer = manifestDto == null
        ? null
        : AnimationRuntimeRegistry.resolve(manifestDto.rendererCode);
    final playbackMode = configText(config, ['playbackMode']) ?? 'AUTO';
    // Có manifest (parseRes.present): render theo manifest NẾU hợp lệ;
    // nếu không → null + notice. Chỉ khi manifest ABSENT (không có key
    // animationManifest) mới resolve legacy animationKey (snapshot cũ).
    final bool manifestPresent = parseRes.present;
    final animation = manifestPresent
        ? (manifestDto != null &&
                  manifestRenderer != null &&
                  manifestRenderer.canRender(manifestDto)
              ? manifestRenderer.build(manifestDto, playbackMode: playbackMode)
              : null)
        : HistoricalAnimationRegistry.resolve(
            configText(config, ['animationKey']),
          );
    // "unsupported" gồm: (a) manifest present nhưng invalid shape /
    // parse fail (dto=null), (b) rendererCode lạ (resolve=null), hoặc
    // (c) renderer khớp nhưng manifest không đủ cấu trúc/version
    // (canRender=false — vd map thiếu locations, rendererVersion/
    // schemaVersion mới hơn app). Tất cả hiện notice thay vì im lặng
    // rơi về animationKey fallback (có thể mount animation CŨ sai ngữ
    // cảnh). Notice KHÔNG chứa JSON/nội bộ — chỉ title + thông báo.
    final bool unsupportedManifest =
        manifestPresent &&
        (manifestDto == null ||
            manifestRenderer == null ||
            !manifestRenderer.canRender(manifestDto));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isHtmlScene) ...[
          _HtmlSceneSlot(
            key: ValueKey('html_anim_${activity.id}'),
            config: config,
            manifest: manifestDto!,
            playerFactory: htmlPlayerFactory,
          ),
          const SizedBox(height: 14),
        ] else if (animation != null) ...[
          // Keyed theo animationKey + activity id: đổi activity → dispose
          // controller cũ, không rò state giữa các bài.
          //
          // P0-4: manifest mang assets[]/objects[] → bọc player bằng lớp
          // ảnh (background dưới + object trên). Manifest KHÔNG khai báo
          // ảnh nào → widget trả về `child` nguyên trạng, không đổi layout.
          _CinematicBoundPlayer(
            key: ValueKey('anim_${animation.key}_${activity.id}'),
            manifest: manifestDto ?? AnimationManifestDto.empty,
            definition: animation,
          ),
          const SizedBox(height: 14),
        ] else if (unsupportedManifest) ...[
          // ANIM-03: app cũ gặp manifest của renderer chưa hỗ trợ —
          // fallback rõ ràng thay vì crash hay im lặng trắng.
          _UnsupportedAnimationNotice(title: manifestDto?.title ?? ''),
          const SizedBox(height: 14),
        ],
        ImperialScrollFrame(
          plaqueTitle: 'CỔ THƯ • ĐỌC KỸ',
          hiddenPlaqueTestText: 'CỔ THƯ · ĐỌC KỸ',
          topRightBadge: const ImperialBookSealBadge(label: 'ĐỌC'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isHtmlScene &&
                  animation == null &&
                  !unsupportedManifest) ...[
                Container(
                  height: 168,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD8C29D),
                      width: 1.3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x184A3219),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    resolveLessonFallbackAsset(
                      title ?? '',
                      '${subtitle ?? ''} ${activity.instruction ?? ''} ${body ?? ''}',
                    ),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (title != null) ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 18.5,
                    height: 1.3,
                    color: const Color(0xFF6E1A14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                // Đường kẻ hoa văn vàng giữa tiêu đề và nội dung (khớp ảnh mẫu #6)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 1.2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x00D8B467), Color(0xFFD8B467)],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.cloud_queue_rounded,
                        size: 13,
                        color: Color(0xFFD4A048),
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 1.2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFD8B467), Color(0x00D8B467)],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
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
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ClueTag('Nguồn'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          style: DauVietTypography.labelSmall.copyWith(
                            fontStyle: FontStyle.italic,
                            color: DauVietColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
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

/// v2 — Player bọc trong binding cinematic: giữ [ValueNotifier] frame
/// dùng chung giữa scene canvas (camera transform trong
/// `ManifestAssetLayers` BÊN TRONG player — xem `_buildSceneCanvas`)
/// và player (phát frame mỗi tick). Scene v1 (manifest rỗng/không
/// cinematic) → render đúng như trước.
///
/// P0 layout §2: ManifestAssetLayers KHÔNG còn bọc toàn bộ player —
/// camera chỉ transform vùng scene canvas bounded bởi AspectRatio,
/// UI controls/narration/prediction nằm ngoài camera transform.
class _CinematicBoundPlayer extends StatefulWidget {
  final AnimationManifestDto manifest;
  final HistoricalAnimationDefinition definition;

  const _CinematicBoundPlayer({
    super.key,
    required this.manifest,
    required this.definition,
  });

  @override
  State<_CinematicBoundPlayer> createState() => _CinematicBoundPlayerState();
}

class _CinematicBoundPlayerState extends State<_CinematicBoundPlayer> {
  late final ValueNotifier<CinematicFrame> _frame;

  @override
  void initState() {
    super.initState();
    _frame = ValueNotifier(
      CinematicFrame(camera: widget.manifest.cinematic.cameraInitial),
    );
  }

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HistoricalAnimationPlayer(
      definition: widget.definition,
      manifest: widget.manifest,
      cinematicFrame: _frame,
    );
  }
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
        color: DauVietColors.paperCardHi.withValues(alpha: 0.6),
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

/// Đọc sceneVersionId từ envelope `config.animationManifest` (do
/// SnapshotBuilder embed: {manifest, sceneVersionId, versionNo, ...})
/// rồi mount HtmlAnimationPlayer. Thiếu versionId → notice an toàn
/// thay vì fetch mù.
class _HtmlSceneSlot extends StatelessWidget {
  final Map<String, dynamic> config;
  final AnimationManifestDto manifest;
  final Widget Function(String sceneVersionId, AnimationManifestDto manifest)?
  playerFactory;

  const _HtmlSceneSlot({
    super.key,
    required this.config,
    required this.manifest,
    this.playerFactory,
  });

  @override
  Widget build(BuildContext context) {
    final Object? envelope = config['animationManifest'];
    final String? versionId = envelope is Map
        ? envelope['sceneVersionId'] as String?
        : null;
    if (versionId == null || versionId.isEmpty) {
      return _UnsupportedAnimationNotice(title: manifest.title);
    }
    if (playerFactory != null) {
      return playerFactory!(versionId, manifest);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double resolvedAspectRatio = manifest.canvasAspectRatio > 0
            ? manifest.canvasAspectRatio
            : (constraints.maxWidth > 0 && constraints.maxWidth < 600
                  ? 0.66
                  : 16 / 10);
        return HtmlAnimationPlayer(
          sceneVersionId: versionId,
          manifest: manifest,
          aspectRatio: resolvedAspectRatio,
        );
      },
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  final bool dropCap;
  const _Paragraph(this.text, {this.dropCap = false});

  @override
  Widget build(BuildContext context) {
    final bodyStyle = DauVietTypography.bodyMedium.copyWith(
      color: const Color(0xFF2B1F17),
      fontWeight: FontWeight.w500,
      height: 1.58,
      fontSize: 14.5,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText(
        text,
        style: bodyStyle,
      ),
    );
  }
}
