import 'package:flutter/material.dart';

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
    StepProgressItem(icon: Icons.menu_book_outlined, label: 'Đọc tư liệu'),
    StepProgressItem(icon: Icons.search_rounded, label: 'Điều tra'),
    StepProgressItem(icon: Icons.lightbulb_outline_rounded, label: 'Tái dựng'),
    StepProgressItem(icon: Icons.fact_check_outlined, label: 'Lập luận'),
    StepProgressItem(icon: Icons.trending_up_rounded, label: 'Kết luận'),
    StepProgressItem(icon: Icons.workspace_premium_outlined, label: 'Đúc kết'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = steps ?? defaultSteps;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final int count = totalSteps < 1 ? 1 : totalSteps;
          final double maxCellWidth = count > 1 && w.isFinite
              ? ((w - (count - 1) * 4.0) / count).clamp(16.0, 56.0)
              : 44.0;
          // Nhãn 9px (~12px dòng) + gap 2px đặt dưới chấm: nếu `height` còn lại
          // không đủ cho nhãn → ép compact, tránh overflow 1-4px chiều dọc.
          final bool compact = !showLabels ||
              w < 190 ||
              maxCellWidth < 34 ||
              height < 42;
          final double baseDot = w < 220 ? 24.0 : 28.0;
          final double dotSize = (maxCellWidth - 2.0) < baseDot
              ? (maxCellWidth - 2.0).clamp(16.0, 28.0)
              : baseDot;
          final double iconSize = (dotSize * 0.50).clamp(10.0, 15.0);
          final double cellWidth = compact
              ? dotSize
              : maxCellWidth.clamp(dotSize, 48.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < totalSteps; i++) ...[
                SizedBox(
                  width: cellWidth,
                  child: _StepDot(
                    index: i,
                    item: items[i % items.length],
                    state: i < currentStep
                        ? _StepState.done
                        : i == currentStep
                        ? _StepState.current
                        : _StepState.upcoming,
                    showLabel: !compact,
                    size: dotSize,
                    maxLabelWidth: cellWidth,
                    iconSize: iconSize,
                  ),
                ),
                if (i < totalSteps - 1)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: dotSize / 2 - 1),
                      child: Container(
                        height: 2,
                        color: i < currentStep
                            ? const Color(0xFF4A7C4B)
                            : const Color(0xFFD5C3A3),
                      ),
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
  final double maxLabelWidth;
  final double iconSize;

  const _StepDot({
    required this.index,
    required this.item,
    required this.state,
    required this.showLabel,
    this.size = 28,
    this.maxLabelWidth = 44,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor) = switch (state) {
      _StepState.done => (
        const Color(0xFF4A7C4B),
        const Color(0xFF3A633B),
        const Color(0xFFFFFBF2),
      ),
      _StepState.current => (
        const Color(0xFFA8221B),
        const Color(0xFFE5B869),
        const Color(0xFFFFFBF2),
      ),
      _StepState.upcoming => (
        const Color(0xFFFAF3E4),
        const Color(0xFFCBB694),
        const Color(0xFF6B5B4B),
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
            border: Border.all(
              color: border,
              width: state == _StepState.current ? 2.0 : 1.5,
            ),
            boxShadow: state == _StepState.current
                ? const [
                    BoxShadow(
                      color: Color(0x38A8221B),
                      blurRadius: 6,
                      spreadRadius: 1.5,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            state == _StepState.done ? Icons.check_rounded : item.icon,
            size: iconSize,
            color: iconColor,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 9.0,
                  color: state == _StepState.current
                      ? const Color(0xFFA8221B)
                      : const Color(0xFF5C4E42),
                  fontWeight: state == _StepState.current
                      ? FontWeight.w800
                      : FontWeight.w600,
                  height: 1.05,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
