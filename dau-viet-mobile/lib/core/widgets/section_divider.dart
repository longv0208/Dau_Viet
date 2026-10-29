import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import 'section_eyebrow.dart';

/// Divider kiểu Landing Page: `border-b-4 border-heading` + `SectionEyebrow`.
///
/// Dùng để ngăn section trên các màn dài (dashboard, journey, collection).
///
/// Ví dụ:
/// ```dart
/// SectionDivider(eyebrow: 'CHƯƠNG 02', title: 'Nhà Trần Hưng Đạo')
/// ```
class SectionDivider extends StatelessWidget {
  final String? eyebrow;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool showLine;

  const SectionDivider({
    super.key,
    this.eyebrow,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 24, bottom: 12),
    this.showLine = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (eyebrow != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: SectionEyebrow(eyebrow!),
                ),
              if (title != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    style: theme.headlineMedium?.copyWith(fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ] else
                const Spacer(),
              ?trailing,
            ],
          ),
          if (showLine) ...[
            const SizedBox(height: 10),
            Container(height: 3, color: DauVietColors.inkHeading),
          ],
        ],
      ),
    );
  }
}
