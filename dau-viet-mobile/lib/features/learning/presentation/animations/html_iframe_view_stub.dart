import 'package:flutter/widgets.dart';

/// Fallback stub cho nền tảng không phải Web (Android/iOS dùng WebViewWidget).
Widget buildWebHtmlIframe({
  Key? key,
  required String html,
  required String channelTag,
  required ValueChanged<String> onJsMessage,
}) {
  return SizedBox.shrink(key: key);
}
