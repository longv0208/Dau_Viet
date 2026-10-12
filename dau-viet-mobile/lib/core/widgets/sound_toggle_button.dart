import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

/// Nút chuyển đổi trạng thái âm thanh (Bật / Tắt Tiếng) chuẩn di sản Dấu Việt
class SoundToggleButton extends StatelessWidget {
  final double size;
  final Color? color;

  const SoundToggleButton({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DauVietAudioService.instance,
      builder: (context, _) {
        final audioService = DauVietAudioService.instance;
        final isEnabled = audioService.isSoundEnabled;

        return IconButton(
          tooltip: isEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: size,
            color: color ?? (isEnabled ? DauVietColors.cinnabarRed : DauVietColors.inkMuted),
          ),
          onPressed: () {
            audioService.toggleSound();
          },
        );
      },
    );
  }
}
