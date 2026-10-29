import 'package:flutter/material.dart';

import 'kabi_mascot_widget.dart';
import 'mascot_speech_bubble.dart';

/// Slot chuẩn cho linh vật — lắp `KabiMascotWidget` + `MascotSpeechBubble`
/// theo tư thế nhất quán trên mọi màn.
///
/// Dùng:
/// ```dart
/// MascotSlot(message: 'Chọn thời kỳ để bắt đầu!', mood: KabiMood.guiding)
/// MascotSlot.icon(mood: KabiMood.cheering) // chỉ avatar, không bubble
/// ```
class MascotSlot extends StatelessWidget {
  final String? message;
  final KabiMood mood;
  final double size;
  final bool compact;
  final VoidCallback? onTap;

  /// Đầy đủ: mascot + speech bubble.
  const MascotSlot({
    super.key,
    required this.message,
    this.mood = KabiMood.guiding,
    this.size = 64,
    this.compact = false,
    this.onTap,
  });

  /// Chỉ avatar mascot, không bubble — dùng cho header chật.
  const MascotSlot.icon({
    super.key,
    this.mood = KabiMood.guiding,
    this.size = 44,
    this.compact = true,
    this.onTap,
  }) : message = null;

  @override
  Widget build(BuildContext context) {
    if (compact || message == null) {
      return KabiMascotWidget(
        mood: mood,
        width: size,
        height: size,
        onTap: onTap,
      );
    }
    return MascotSpeechBubble(message: message!, mood: mood, avatarSize: size);
  }
}
