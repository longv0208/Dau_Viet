import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../../../../../core/theme/dau_viet_typography.dart';

/// ANIM-01 — Placeholder tĩnh sau khi learner chọn "Bỏ qua": không
/// motion, không điều khiển, chỉ thông báo và để phần đọc tiếp tục.
class SkippedScene extends StatelessWidget {
  const SkippedScene({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Đã bỏ qua phần minh họa tương tác.\n'
          'Bạn có thể đọc tiếp nội dung bên dưới.',
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 13,
            color: DauVietColors.inkMuted,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
