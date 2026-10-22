import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';

/// ANIM-01 — Slider mực nước schematic (0..1, KHÔNG phải dữ liệu triều
/// thật) + 2 preset "Nước dâng"/"Nước rút". Chỉ dùng cho river scenes
/// (`definition.hasWaterControl`).
class WaterLevelControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const WaterLevelControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Mực nước sông minh họa',
          slider: true,
          value: '${(value * 100).round()} phần trăm',
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
            activeColor: DauVietColors.riverBlue,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChanged(0.92),
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: const Text('Nước dâng'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: DauVietColors.riverBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChanged(0.18),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: const Text('Nước rút'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: DauVietColors.woodBrown,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
