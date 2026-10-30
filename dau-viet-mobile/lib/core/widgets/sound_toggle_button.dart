import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

/// Nút chuyển đổi trạng thái âm thanh (Bật / Tắt Tiếng) chuẩn di sản Dấu Việt
class SoundToggleButton extends StatelessWidget {
  final double size;
  final Color? color;

  const SoundToggleButton({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DauVietAudioService.instance,
      builder: (context, _) {
        final audioService = DauVietAudioService.instance;
        final isEnabled = audioService.isSoundEnabled;

        return Semantics(
          button: true,
          label: isEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
          child: IconButton(
            tooltip: isEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF7E9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDFC28C), width: 1.1),
              ),
              alignment: Alignment.center,
              child: Icon(
                isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: size - 2,
                color:
                    color ??
                    (isEnabled
                        ? const Color(0xFFA8221B)
                        : DauVietColors.inkMuted),
              ),
            ),
            onPressed: () {
              audioService.toggleSound();
            },
          ),
        );
      },
    );
  }
}
