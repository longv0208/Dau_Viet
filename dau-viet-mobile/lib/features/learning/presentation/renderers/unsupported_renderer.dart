import 'package:flutter/material.dart';

import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/empty_state_card.dart';

/// Fallback cho activity type chưa được hỗ trợ trên mobile.
/// KHÔNG có nút submit — học viên không thể tự gửi đáp án kiểu này;
/// hiển thị thông báo rõ ràng thay vì fail ngầm.
class UnsupportedRenderer extends StatelessWidget {
  final String type;

  const UnsupportedRenderer({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EmptyStateCard(
          title: 'Chưa hỗ trợ',
          description: 'Hoạt động này sẽ sớm được bổ sung.',
          icon: Icons.construction_outlined,
        ),
        if (type.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClueTag(type),
        ],
      ],
    );
  }
}
