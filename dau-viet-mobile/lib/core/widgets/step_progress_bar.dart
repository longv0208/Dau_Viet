import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Thanh tiến trình 6 chặng — theo dõi hành trình thám tử lịch sử:
/// Bối cảnh → Dấu vết → Giả thuyết → Kiểm chứng → Dựng lại → Kết luận.
///
/// Mỗi step là một chấm tròn + icon + nhãn, nối bằng line.
/// Khi không đủ chỗ (<360px) hoặc `showLabels=false`, tự động rút gọn chỉ còn
/// dot + line để tránh RenderFlex overflow.
class StepProgressBar extends StatelessWidget {
  final int currentStep; // 0-based
  final int totalSteps;
  final List<StepProgressItem>? steps;
  final double height;
  final bool showLabels;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 6,
    this.steps,
    this.height = 56,
    this.showLabels = true,
  }) : assert(
         steps == null || steps.length == totalSteps,
         'steps.length must equal totalSteps',
       );

  static const List<StepProgressItem> defaultSteps = [
    StepProgressItem(icon: Icons.menu_book_outlined, label: 'Bối cảnh'),
    StepProgressItem(icon: Icons.search_outlined, label: 'Dấu vết'),
    StepProgressItem(icon: Icons.lightbulb_outline, label: 'Giả thuyết'),
    StepProgressItem(icon: Icons.fact_check_outlined, label: 'Kiểm chứng'),
    StepProgressItem(icon: Icons.timeline_outlined, label: 'Dựng lại'),
    StepProgressItem(icon: Icons.workspace_premium_outlined, label: 'Kết luận'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = steps ?? defaultSteps;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Tính toán scale theo không gian:
          // - w < 200: dot=24, không label (compact tối đa)
          // - w < 360: dot=32, không label
          // - w >= 360: dot=32 + label
          final w = constraints.maxWidth;
          final bool compact = w < 360 || !showLabels;
          final int count = totalSteps < 1 ? 1 : totalSteps;
          final double maxDotForWidth = count > 1 && w.isFinite
              ? ((w - (count - 1) * 6.0) / count).clamp(16.0, 32.0)
              : 32.0;
          final double baseDot = w < 200 ? 24.0 : 32.0;
          final double dotSize = maxDotForWidth < baseDot
              ? maxDotForWidth
              : baseDot;
          final double iconSize = w < 200
              ? 12.0
              : (dotSize * 0.5).clamp(10.0, 16.0);
          final double lineMargin = dotSize < 26.0 ? 2.0 : 4.0;
          return Row(
            children: [
              for (var i = 0; i < totalSteps; i++) ...[
                _StepDot(
                  index: i,
                  item: items[i % items.length],
                  state: i < currentStep
                      ? _StepState.done
                      : i == currentStep
                      ? _StepState.current
                      : _StepState.upcoming,
                  showLabel: !compact,
                  size: dotSize,
                  iconSize: iconSize,
                ),
                if (i < totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.symmetric(horizontal: lineMargin),
                      color: i < currentStep
                          ? DauVietColors.natureGreen
                          : DauVietColors.outlineVariant,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class StepProgressItem {
  final IconData icon;
  final String label;
  const StepProgressItem({required this.icon, required this.label});
}

enum _StepState { done, current, upcoming }

class _StepDot extends StatelessWidget {
  final int index;
  final StepProgressItem item;
  final _StepState state;
  final bool showLabel;
  final double size;
  final double iconSize;

  const _StepDot({
    required this.index,
    required this.item,
    required this.state,
    required this.showLabel,
    this.size = 32,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor) = switch (state) {
      _StepState.done => (
        DauVietColors.natureGreen,
        DauVietColors.natureGreen,
        DauVietColors.paperBackground,
      ),
      _StepState.current => (
        DauVietColors.cinnabarRed,
        DauVietColors.cinnabarRedDark,
        DauVietColors.paperBackground,
      ),
      _StepState.upcoming => (
        DauVietColors.paperCard,
        DauVietColors.outlineVariant,
        DauVietColors.inkMuted,
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: 2),
            boxShadow: state == _StepState.current
                ? DauVietColors.pixelShadowSm
                : null,
          ),
          child: Icon(
            state == _StepState.done ? Icons.check : item.icon,
            size: iconSize,
            color: iconColor,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            item.label,
            style: DauVietTypography.labelSmall.copyWith(
              fontSize: 9,
              color: state == _StepState.current
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.inkMuted,
              fontWeight: state == _StepState.current
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}
