import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';

/// ANIM-01 — Thanh điều khiển chung của player: ◀ trước / ▶ tiếp /
/// phát-dừng / tua lại / bỏ qua. Touch target ≥44px, semantic labels
/// tiếng Việt, compact cho màn hẹp.
class HistoricalAnimationControls extends StatelessWidget {
  final bool playing;
  final bool canPrev;
  final bool canNext;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onSkip;

  const HistoricalAnimationControls({
    super.key,
    required this.playing,
    required this.canPrev,
    required this.canNext,
    required this.stepIndex,
    required this.stepCount,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onReplay,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress dots + nhãn bước.
        Row(
          children: [
            Expanded(
              child: Text(
                'Bước ${stepIndex + 1}/$stepCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DauVietColors.inkMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Bỏ qua', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _IconBtn(
              icon: Icons.replay_rounded,
              label: 'Tua lại hoạt họa',
              onPressed: onReplay,
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.skip_previous_rounded,
              label: 'Bước trước',
              onPressed: canPrev ? onPrev : null,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: playing ? 'Tạm dừng' : 'Phát hoạt họa',
                child: FilledButton.icon(
                  onPressed: onPlayPause,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(
                    playing ? 'TẠM DỪNG' : 'PHÁT',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: DauVietColors.cinnabarRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.skip_next_rounded,
              label: 'Bước tiếp',
              onPressed: canNext ? onNext : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 22,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        color: DauVietColors.inkText,
        disabledColor: DauVietColors.inkLight.withValues(alpha: 0.4),
      ),
    );
  }
}
