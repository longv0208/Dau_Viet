import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import 'renderer_base.dart';

/// Fallback cho activity type chưa được hỗ trợ trên mobile.
/// KHÔNG có nút submit — học viên không thể tự gửi đáp án kiểu này;
/// hiển thị thông báo rõ ràng thay vì fail ngầm.
class UnsupportedRenderer extends StatelessWidget {
  final String type;

  const UnsupportedRenderer({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return ActivityCard(
      child: Column(
        children: [
          const Icon(
            Icons.extension_off_outlined,
            size: 32,
            color: DauVietColors.inkMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'Hoạt động "$type" chưa được hỗ trợ trên phiên bản mobile này.',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vui lòng cập nhật ứng dụng hoặc học trên nền tảng khác.',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
