import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../../../core/theme/dau_viet_typography.dart';
import '../../data/learning_api_client.dart';
import '../../data/learning_providers.dart';
import 'runtime/animation_manifest_dto.dart';

/// HTML_WEBVIEW runtime — renderer DUY NHẤT cho mọi cảnh HTML tải lên.
/// Luồng: fetch bytes qua endpoint learner (Bearer trong header —
/// WebView không bao giờ thấy token) → verify sha256 khớp manifest
/// pin trong snapshot → `loadHtmlString` (không navigation tới URL,
/// không token-in-URL, không file://).
///
/// Cô lập:
///   - NavigationDecision.prevent mọi điều hướng — document tự chứa,
///     không có link nào hợp lệ.
///   - JS chạy được (hoạt họa cần) nhưng document không có network:
///     backend đã chặn fetch/XHR/script-src lúc import, và không có
///     gốc nào để gọi tới.
///   - JS bridge `DauVietChannel` chỉ nhận message whitelist
///     {READY, PLAYBACK_STARTED, PLAYBACK_PAUSED, PLAYBACK_FINISHED,
///     RUNTIME_ERROR} — mọi payload khác bị bỏ. HTML KHÔNG đọc được
///     token, KHÔNG gửi được điểm/EXP/completion (server authoritative).
class HtmlAnimationPlayer extends ConsumerStatefulWidget {
  /// sceneVersionId từ envelope `config.animationManifest` — pin bản
  /// bất biến; attempt cũ vẫn fetch đúng version đã pin.
  final String sceneVersionId;
  final AnimationManifestDto manifest;
  final double aspectRatio;
  final VoidCallback? onFinished;
  final ValueChanged<String>? onRuntimeError;

  /// Test seams: `apiOverride` thay HTTP fetch; `controllerOverride` thay
  /// platform controller (widget-test không có WebViewPlatform); `webViewBuilder`
  /// thay widget platform view. Production để hết null.
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
  static const Set<String> _allowedMessages = {
    'READY',
    'PLAYBACK_STARTED',
    'PLAYBACK_PAUSED',
    'PLAYBACK_FINISHED',
    'RUNTIME_ERROR',
  };

  /// Lazy: controllerOverride (test) hoặc build khi sắp load bytes thật.
  /// Khi cả hai null mà `_load` gọi `loadHtmlString` — nghĩa là prod path,
  /// `_ctrl` sẽ khởi tạo platform impl lúc đó.
  WebViewController? _controller;
  _HtmlLoadState _state = _HtmlLoadState.loading;
  String _error = '';

  /// Controller hiện dùng — null khi đang test seam chưa build (widget
  /// test không có WebViewPlatform → không được ép tạo).
  WebViewController? get _ctrlOrNull => widget.controllerOverride ?? _controller;

  WebViewController get _ctrl =>
      widget.controllerOverride ?? (_controller ??= _buildController());

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  WebViewController _buildController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DauVietColors.parchmentContainer)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Document self-contained — MỌI navigation đều chặn (link,
          // window.open, meta-refresh đã bị validator cấm nhưng phòng
          // thủ thêm ở đây). loadHtmlString không qua delegate này.
          onNavigationRequest: (_) => NavigationDecision.prevent,
          onWebResourceError: (err) {
            // Sub-resource lỗi (ví dụ data-URI hỏng) — không crash,
            // chỉ báo UI lỗi khi frame chính hỏng.
            if (err.isForMainFrame ?? false) {
              _setError('Nội dung hoạt họa không tải được.');
            }
          },
        ),
      )
      // JS → Dart: chỉ message whitelist; payload tùy ý bị drop.
      ..addJavaScriptChannel(
        'DauVietChannel',
        onMessageReceived: _onJsMessage,
      );
    return controller;
  }

  void _onJsMessage(JavaScriptMessage msg) {
    final text = msg.message;
    // Hỗ trợ cả dạng "NAME" và {"type":"NAME"} — chỉ `type` quyết định.
    String type = text;
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map && parsed['type'] is String) {
        type = parsed['type'] as String;
      }
    } catch (_) {
      // Plain string — giữ nguyên.
    }
    if (!_allowedMessages.contains(type)) return;
    switch (type) {
      case 'PLAYBACK_FINISHED':
        widget.onFinished?.call();
      case 'RUNTIME_ERROR':
        widget.onRuntimeError?.call('Hoạt họa báo lỗi khi chạy.');
      default:
        break; // READY / PLAYBACK_STARTED / PLAYBACK_PAUSED — chỉ telemetry sau.
    }
  }

  /// Fetch + verify + load. Gọi lại khi retry.
  Future<void> _load() async {
    setState(() {
      _state = _HtmlLoadState.loading;
      _error = '';
    });
    try {
      final LearningApiClient api =
          widget.apiOverride ?? ref.read(learningApiClientProvider);
      final List<int> bytes =
          await api.getAnimationHtmlBytes(widget.sceneVersionId);
      if (bytes.isEmpty) {
        throw StateError('empty html');
      }
      // Verify bytes khớp đúng file đã publish — manifest.pin sha256.
      final expected = widget.manifest.html?.sha256 ?? '';
      if (expected.isNotEmpty) {
        final actual = sha256.convert(bytes).toString();
        if (actual != expected) {
          _setError('Hoạt họa không khớp bản đã phát hành.');
          return;
        }
      }
      final html = utf8.decode(bytes, allowMalformed: false);
      // loadHtmlString: không URL thật, không token, không file://.
      // baseUrl about:blank giữ document ở opaque origin.
      // Test seam: controllerOverride null + webViewBuilder được inject →
      // bỏ qua load (không có platform impl) nhưng vẫn đánh dấu ready.
      if (widget.controllerOverride != null || widget.webViewBuilder == null) {
        await _ctrl.loadHtmlString(html, baseUrl: 'about:blank');
      }
      if (!mounted) return;
      setState(() => _state = _HtmlLoadState.ready);
    } catch (e) {
      _setError(
        e is FormatException
            ? 'Tệp hoạt họa lỗi mã hoá.'
            : 'Không tải được hoạt họa — kiểm tra kết nối rồi thử lại.',
      );
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _state = _HtmlLoadState.error;
      _error = message;
    });
  }

  /// Gọi API JS của document nếu tác giả cài `window.DauVietAnimation`
  /// (play/pause/resume/replay/destroy — tùy chọn; file không cài vẫn
  /// hiển thị bình thường). Để public: control ngoài (nút play/pause của
  /// player shell) sẽ gọi khi playback control được nối.
  void callBridge(String method) {
    _ctrlOrNull?.runJavaScript(
      'window.DauVietAnimation && window.DauVietAnimation.$method && '
      'window.DauVietAnimation.$method()',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
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
                onRetry: () => unawaited(_load()),
              ),
            _HtmlLoadState.ready => widget.webViewBuilder != null
                ? widget.webViewBuilder!(context, _ctrlOrNull)
                : WebViewWidget(controller: _ctrl),
          },
        ),
      ),
    );
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
