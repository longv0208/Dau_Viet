import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _nextWebIframeViewId = 0;

/// Render tài liệu HTML tự chứa trên Flutter Web bằng `<iframe sandbox="allow-scripts">`.
///
/// Bảo mật:
/// - `sandbox="allow-scripts"` KHÔNG có `allow-same-origin` → document chạy ở
///   opaque origin, không đọc được `localStorage`/`cookie`/token của ứng dụng.
/// - Cầu nối `window.DauVietChannel.postMessage(...)` được ánh xạ qua
///   `window.parent.postMessage` kèm `channelTag` định danh riêng cho từng phiên.
Widget buildWebHtmlIframe({
  Key? key,
  required String html,
  required String channelTag,
  required ValueChanged<String> onJsMessage,
}) {
  return _WebHtmlIframeView(
    key: key,
    html: html,
    channelTag: channelTag,
    onJsMessage: onJsMessage,
  );
}

class _WebHtmlIframeView extends StatefulWidget {
  final String html;
  final String channelTag;
  final ValueChanged<String> onJsMessage;

  const _WebHtmlIframeView({
    super.key,
    required this.html,
    required this.channelTag,
    required this.onJsMessage,
  });

  @override
  State<_WebHtmlIframeView> createState() => _WebHtmlIframeViewState();
}

class _WebHtmlIframeViewState extends State<_WebHtmlIframeView> {
  late final String _viewType;
  StreamSubscription<web.MessageEvent>? _msgSub;

  @override
  void initState() {
    super.initState();
    _viewType = 'dv-html-anim-iframe-${++_nextWebIframeViewId}';
    final String bridgedHtml = _injectDauVietChannelBridge(
      widget.html,
      widget.channelTag,
    );

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.style.display = 'block';
      iframe.style.backgroundColor = '#fdf8ee';
      iframe.setAttribute('sandbox', 'allow-scripts');
      iframe.srcdoc = bridgedHtml.toJS;
      return iframe;
    });

    _msgSub = web.EventStreamProviders.messageEvent
        .forTarget(web.window)
        .listen(_handleWindowMessage);
  }

  void _handleWindowMessage(web.MessageEvent event) {
    if (!mounted) return;
    final JSAny? data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final String raw = (data as JSString).toDart;
    final String prefix = 'dv_bridge:${widget.channelTag}:';
    if (raw.startsWith(prefix)) {
      final String payload = raw.substring(prefix.length);
      widget.onJsMessage(payload);
    }
  }

  static String _injectDauVietChannelBridge(String html, String channelTag) {
    final String safeTag = channelTag.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    final String bridgeScript =
        '<script>(function(){'
        'if(!window.DauVietChannel){'
        'window.DauVietChannel={'
        'postMessage:function(m){'
        'try{window.parent.postMessage("dv_bridge:$safeTag:"+String(m),"*");}catch(e){}'
        '}'
        '};'
        '}'
        '})();</script>';
    final int headClose = html.toLowerCase().indexOf('</head>');
    if (headClose != -1) {
      return html.substring(0, headClose) +
          bridgeScript +
          html.substring(headClose);
    }
    return bridgeScript + html;
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
