import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../../../core/theme/dau_viet_typography.dart';
import '../../data/learning_api_client.dart';
import '../../data/learning_providers.dart';
import 'runtime/animation_manifest_dto.dart';
import 'html_iframe_view.dart';

/// HTML_WEBVIEW runtime — renderer DUY NHẤT cho mọi cảnh HTML tải lên.
///
/// Luồng: fetch bytes qua endpoint learner qua `withAuth` (Bearer trong
/// header của Dio, WebView KHÔNG BAO GIỜ thấy token) → verify sha256 khớp
/// `manifest.html.sha256` pin trong snapshot → `loadHtmlString` trên
/// `about:blank` (không URL thật, không token-in-URL, không file://).
///
/// Cô lập nhiều lớp:
///   1. Backend validate khi IMPORT (external refs bị chặn trước khi lưu).
///   2. Stored bytes mang CSP <meta> do server chèn — áp dụng cả khi
///      response-header CSP không còn (loadHtmlString/blob URL).
///   3. `NavigationDelegate` prevent mọi điều hướng top-level.
///   4. JS channel `DauVietChannel` whitelist 5 message + envelope check +
///      size cap — message lạ/lớn bị drop; HTML không đọc được token,
///      không gửi được điểm/EXP/completion (server authoritative).
///   5. Generation counter: mọi pending fetch/dispose/scene-change vô hiệu
///      kết quả cũ — response của phiên trước không ghi đè phiên mới.
class HtmlAnimationPlayer extends ConsumerStatefulWidget {
  /// sceneVersionId từ envelope `config.animationManifest` — pin bản
  /// bất biến; attempt cũ vẫn fetch đúng version đã pin.
  final String sceneVersionId;
  final AnimationManifestDto manifest;
  final double aspectRatio;
  final VoidCallback? onFinished;
  final ValueChanged<String>? onRuntimeError;

  /// Test seams — production để hết null:
  ///   apiOverride       : thay LearningApiClient (bỏ qua withAuth/network).
  ///   controllerOverride : WebViewController giả — KHÔNG dùng được vì
  ///                       WebViewController không phải interface; giữ
  ///                       tham số cho tương thích nhưng test nên dùng
  ///                       jsMessageHandler.
  ///   webViewBuilder    : thay widget platform view.
  ///   controllerOverride : giữ signature cho tương lai; WebViewController
  ///                       không phải interface nên không fake được —
  ///                       test dispatch dùng handleJsMessageForTest.
  ///   webViewBuilder    : thay widget platform view.
  final LearningApiClient? apiOverride;
  final WebViewController? controllerOverride;
  final Widget Function(BuildContext context, WebViewController? controller)?
  webViewBuilder;

  const HtmlAnimationPlayer({
    super.key,
    required this.sceneVersionId,
    required this.manifest,
    this.aspectRatio = 16 / 10,
    this.onFinished,
    this.onRuntimeError,
    this.apiOverride,
    this.controllerOverride,
    this.webViewBuilder,
  });

  @override
  ConsumerState<HtmlAnimationPlayer> createState() =>
      _HtmlAnimationPlayerState();
}

enum _HtmlLoadState { loading, ready, error }

class _HtmlAnimationPlayerState extends ConsumerState<HtmlAnimationPlayer> {
  /// JS → Dart whitelist. Payload khác bị drop trước khi chạm switch.
  static const Set<String> _allowedMessages = {
    'READY',
    'PLAYBACK_STARTED',
    'PLAYBACK_PAUSED',
    'PLAYBACK_FINISHED',
    'RUNTIME_ERROR',
  };

  /// Max bytes một JS message được mang — drop trước khi jsonDecode để
  /// tránh parse payload khổng lồ / pathological.
  static const int _maxJsMessageBytes = 8 * 1024;

  /// Monotonic session tag — mọi pending work ghi tag lúc bắt đầu; kết quả
  /// chỉ được áp dụng nếu tag vẫn là tag hiện hành. Đổi versionId / retry /
  /// dispose đều ++, làm response cũ tự vô hiệu mà không cần cancel future
  /// (không cancel được future của Dio, nhưng kết quả bị bỏ).
  int _generation = 0;

  WebViewController? _controller;

  /// FIX-03: session-scoped controller. Mỗi `_load()` tạo controller mới →
  /// document + JS channel cũ cùng widget cũ bị huỷ khi `WebViewWidget`
  /// rebuild với controller mới (key đổi). JS message từ document phiên
  /// trước không thể lẫn vào phiên mới vì handler của channel đó thuộc
  /// controller đã bị detach; message còn sót lại bị `_msgGen` check loại.
  int _controllerGen = -1;

  _HtmlLoadState _state = _HtmlLoadState.loading;
  String _error = '';
  bool _finishedFired = false;
  String _loadedHtml = '';

  WebViewController? get _ctrlOrNull =>
      widget.controllerOverride ?? _controller;

  WebViewController get _ctrl =>
      widget.controllerOverride ?? (_controller ??= _buildController());

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(HtmlAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // sceneVersionId đổi → pending fetch của version cũ vô hiệu + load lại.
    // manifest đổi (sha256 mới) cũng phải reload vì checksum pin khác.
    if (oldWidget.sceneVersionId != widget.sceneVersionId ||
        oldWidget.manifest.html?.sha256 != widget.manifest.html?.sha256) {
      _invalidatePending();
      _finishedFired = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    // Invalidate trước — pending future sẽ thấy tag lệch và không setState
    // sau dispose. Controller không cần dispose thủ công (platform tự dọn
    // khi widget unmount); bridge/JS channel cũng chết theo.
    _invalidatePending();
    super.dispose();
  }

  void _invalidatePending() {
    _generation++;
  }

  /// Controller mới cho MỖI load session — document cũ không thể phát
  /// event vào phiên mới; pending loadHtmlString của document cũ chết
  /// theo widget cũ. JS handler gắn `_controllerGen` tại build để message
  /// đến trễ từ document đã bị detach bị drop.
  WebViewController _buildController() {
    final int builtFor = _controllerGen;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DauVietColors.parchmentContainer)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Document self-contained — MỌI navigation đều chặn (link,
          // window.open, meta-refresh đã bị validator cấm nhưng phòng thủ
          // thêm ở đây). loadHtmlString không qua delegate này; subresource
          // fetch bị CSP meta chặn ở tầng document.
          onNavigationRequest: (_) => NavigationDecision.prevent,
          // FIX (stale callback): gắn cùng builtFor guard như JS channel —
          // error của document phiên cũ không được cập nhật state của
          // phiên mới (A fail không được làm error B).
          onWebResourceError: (err) => _onWebResourceError(err, builtFor),
        ),
      )
      ..addJavaScriptChannel(
        'DauVietChannel',
        // Chỉ nhận message khi controller này vẫn là của session hiện
        // hành — message đến trễ từ document đã detach bị drop.
        onMessageReceived: (msg) {
          if (builtFor == _controllerGen && mounted) _onJsMessage(msg);
        },
      );
    return controller;
  }

  /// NavigationDelegate error callback — guard `builtFor` giống JS
  /// channel: callback của document phiên cũ không cập nhật state phiên
  /// mới (A fail không được làm error B); đến sau dispose thì bỏ.
  void _onWebResourceError(WebResourceError err, int builtFor) {
    if (builtFor != _controllerGen || !mounted) return;
    if (err.isForMainFrame ?? false) {
      _setErrorIfCurrent('Nội dung hoạt họa không tải được.');
    }
  }

  /// Whitelist + envelope + size check trước khi đụng switch. Message quá
  /// lớn hoặc không parse được type hợp lệ bị drop — HTML không thể flood
  /// hay gửi command lạ. Public-for-test để widget test emit message trực
  /// tiếp mà không cần WebViewPlatform (controller là platform impl).
  @visibleForTesting
  void handleJsMessageForTest(JavaScriptMessage msg) => _onJsMessage(msg);

  /// Mô phỏng error callback của MỘT session cụ thể — widget test gọi
  /// với `builtFor` cũ để chứng minh stale callback bị drop (không chỉ
  /// gửi vào state hiện tại).
  @visibleForTesting
  void handleWebResourceErrorForTest(WebResourceError err, int builtFor) =>
      _onWebResourceError(err, builtFor);

  /// Session generation hiện hành của controller — test đọc để đóng vai
  /// callback của session cũ (builtFor < _controllerGen).
  @visibleForTesting
  int get controllerGenerationForTest => _controllerGen;

  void _onJsMessage(JavaScriptMessage msg) {
    final text = msg.message;
    if (text.isEmpty || text.length > _maxJsMessageBytes) return;
    // Chỉ nhận "NAME" hoặc {"type":"NAME"} — mọi shape khác bỏ.
    String? type;
    if (text.startsWith('{')) {
      try {
        final parsed = jsonDecode(text);
        if (parsed is Map && parsed['type'] is String) {
          type = parsed['type'] as String;
        } else {
          return;
        }
      } catch (_) {
        return; // JSON hỏng → drop
      }
    } else {
      type = text;
    }
    if (!_allowedMessages.contains(type)) return;
    switch (type) {
      case 'PLAYBACK_FINISHED':
        // Idempotent — HTML có thể emit FINISHED nhiều lần (loop/replay);
        // chỉ fire callback đúng 1 lần mỗi load generation.
        if (!_finishedFired) {
          _finishedFired = true;
          widget.onFinished?.call();
        }
      case 'RUNTIME_ERROR':
        widget.onRuntimeError?.call('Hoạt họa báo lỗi khi chạy.');
      default:
        break; // READY / PLAYBACK_STARTED / PLAYBACK_PAUSED — chưa cần xử lý.
    }
  }

  /// Fetch → verify → load, có generation guard. `withAuth` cho retry-
  /// sau-refresh 1 lần (architecture auth chung); KHÔNG retry vô hạn —
  /// lỗi thứ hai surface thẳng ra UI.
  Future<void> _load() async {
    final int gen = ++_generation;
    if (!mounted) return;
    // Session tag cho callbacks của document — `_controllerGen` đặt
    // trước, callback nào mang `builtFor` khác bị drop.
    _controllerGen = gen;
    // Session-scoped controller — document cũ (và JS channel + pending
    // loadHtmlString của nó) detach cùng widget; message sót lại bị
    // `builtFor == _controllerGen` check drop. Chỉ tạo khi sẽ render
    // platform view thật (không webViewBuilder/controllerOverride) —
    // test seam không đụng WebViewPlatform.
    final bool useNativeWebView =
        !kIsWeb &&
        widget.controllerOverride == null &&
        widget.webViewBuilder == null;
    setState(() {
      _state = _HtmlLoadState.loading;
      _error = '';
    });
    try {
      if (useNativeWebView) {
        _controller = _buildController();
      }
      final List<int> bytes;
      if (widget.apiOverride != null) {
        bytes = await widget.apiOverride!.getAnimationHtmlBytes(
          widget.sceneVersionId,
        );
      } else {
        final LearningApiClient api = ref.read(learningApiClientProvider);
        // FIX-04: giống fetchLearningAssetBytes — 401 → refresh 1 lần →
        // retry; không retry vô hạn, 403 lỗi ra UI ngay.
        bytes = await ref
            .read(authRepositoryProvider)
            .withAuth(() => api.getAnimationHtmlBytes(widget.sceneVersionId));
      }
      if (gen != _generation || !mounted) return; // stale session
      if (bytes.isEmpty) {
        _setErrorIfCurrent('Tệp hoạt họa rỗng.', gen);
        return;
      }
      // Verify bytes khớp đúng file đã publish — manifest pin sha256.
      final expected = widget.manifest.html?.sha256 ?? '';
      if (expected.isNotEmpty) {
        final actual = sha256.convert(bytes).toString();
        if (actual != expected) {
          _setErrorIfCurrent('Hoạt họa không khớp bản đã phát hành.', gen);
          return;
        }
      }
      final String html;
      try {
        html = utf8.decode(bytes, allowMalformed: false);
      } on FormatException {
        _setErrorIfCurrent('Tệp hoạt họa lỗi mã hoá.', gen);
        return;
      }
      if (gen != _generation || !mounted) return;
      // loadHtmlString: không URL thật, không token, không file://.
      // baseUrl about:blank giữ document ở opaque origin. CSP meta server
      // chèn chạy ngay cả khi không có response header.
      _loadedHtml = html;
      if (!kIsWeb &&
          (widget.controllerOverride != null ||
              widget.webViewBuilder == null)) {
        await _ctrl.loadHtmlString(html, baseUrl: 'about:blank');
      } else if (kIsWeb && widget.controllerOverride != null) {
        await _ctrl.loadHtmlString(html, baseUrl: 'about:blank');
      }
      if (gen != _generation || !mounted) return;
      setState(() => _state = _HtmlLoadState.ready);
    } catch (e) {
      if (gen != _generation || !mounted) return;
      _setErrorIfCurrent(
        'Không tải được hoạt họa — kiểm tra kết nối rồi thử lại.',
        gen,
      );
    }
  }

  void _setErrorIfCurrent(String message, [int? gen]) {
    if (!mounted) return;
    if (gen != null && gen != _generation) return;
    setState(() {
      _state = _HtmlLoadState.error;
      _error = message;
    });
  }

  /// Gọi API JS của document nếu tác giả cài `window.DauVietAnimation`
  /// (play/pause/resume/replay/destroy — tùy chọn). Để public: control
  /// ngoài (nút play/pause của player shell) gọi khi playback được nối.
  void callBridge(String method) {
    _ctrlOrNull?.runJavaScript(
      'window.DauVietAnimation && window.DauVietAnimation.$method && '
      'window.DauVietAnimation.$method()',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      color: DauVietColors.parchmentContainer,
      child: switch (_state) {
        _HtmlLoadState.loading => const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        _HtmlLoadState.error => _ErrorPane(
            message: _error,
            onRetry: () {
              _finishedFired = false;
              unawaited(_load());
            },
          ),
        _HtmlLoadState.ready =>
          widget.webViewBuilder != null
              ? widget.webViewBuilder!(context, _ctrlOrNull)
              : kIsWeb && widget.controllerOverride == null
              ? buildWebHtmlIframe(
                  key: ValueKey<String>(
                    'web-iframe-$_controllerGen-${widget.sceneVersionId}',
                  ),
                  html: _loadedHtml,
                  channelTag: 'dv-$_controllerGen',
                  onJsMessage: (msg) =>
                      _onJsMessage(JavaScriptMessage(message: msg)),
                )
              : WebViewWidget(
                  key: ValueKey<Object>(_ctrlOrNull ?? _ctrl),
                  controller: _ctrl,
                ),
      },
    );

    if (widget.aspectRatio > 0) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPane({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: DauVietColors.inkMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
