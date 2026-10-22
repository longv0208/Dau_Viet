import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../../../core/theme/dau_viet_typography.dart';
import '../historical_animation_definition.dart';

/// ANIM-01 — Khối "DỰ ĐOÁN KHÁM PHÁ": chọn phương án → reveal giải thích.
/// KHÔNG chấm điểm, KHÔNG gửi server, KHÔNG ảnh hưởng EXP/progress.
class PredictionBlock extends StatelessWidget {
  final AnimationPrediction prediction;
  final int? chosen;
  final bool revealed;
  final ValueChanged<int> onChoose;
  final VoidCallback onReveal;

  const PredictionBlock({
    super.key,
    required this.prediction,
    required this.chosen,
    required this.revealed,
    required this.onChoose,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final correct = chosen != null && chosen == prediction.explainedOptionIndex;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DỰ ĐOÁN KHÁM PHÁ',
            style: DauVietTypography.labelSmall.copyWith(
              color: DauVietColors.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            prediction.question,
            style: DauVietTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: DauVietColors.inkText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < prediction.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PredictionOption(
                index: i,
                text: prediction.options[i],
                selected: chosen == i,
                // Dim phương án sai SAU reveal — chọn đúng vẫn nổi bật.
                dimmed: revealed && i != prediction.explainedOptionIndex,
                onTap: revealed ? null : () => onChoose(i),
              ),
            ),
          if (!revealed)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: chosen == null ? null : onReveal,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  backgroundColor: DauVietColors.riverBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'XEM KẾT QUẢ VÀ GIẢI THÍCH',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  correct
                      ? Icons.lightbulb_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: correct
                      ? DauVietColors.natureGreen
                      : DauVietColors.imperialGold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    correct
                        ? prediction.explanation
                        : '${prediction.retryHint}\n\n'
                              '${prediction.explanation}',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkText,
                      height: 1.5,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionOption extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const _PredictionOption({
    required this.index,
    required this.text,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(0x41 + index); // A, B, C…
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.riverBlue.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? DauVietColors.riverBlue
                  : DauVietColors.outlineVariant,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$letter.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: dimmed
                      ? DauVietColors.inkLight
                      : DauVietColors.inkText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: dimmed
                        ? DauVietColors.inkLight
                        : DauVietColors.inkText,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: DauVietColors.riverBlue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
