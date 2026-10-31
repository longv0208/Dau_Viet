import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import 'kabi_mascot_widget.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

enum MascotState {
  guiding, // Hướng dẫn / Chú ý chi tiết lịch sử
  cheering, // Đắc thắng / Chúc mừng trả lời đúng
  thinking, // Đăm chiêu / Gợi ý khi chọn sai hoặc gặp câu khó
}

/// Nhân vật đại diện đồng hành (Interactive Historical Guide / Mascot)
/// Lấy hình tượng Tê Giác Dấu Việt, phản hồi tức thì theo trạng thái học tập.
/// Issue #53: bỏ animation nhún nhảy, chỉ dùng ảnh tĩnh sắc nét.
class InteractiveHistoricalMascotWidget extends StatelessWidget {
  final MascotState state;
  final String? message;
  final double avatarSize;
  final bool compact;
  final VoidCallback? onTap;

  const InteractiveHistoricalMascotWidget({
    super.key,
    this.state = MascotState.guiding,
    this.message,
    this.avatarSize = 64.0,
    this.compact = false,
    this.onTap,
  });

  String _getDefaultMessage() {
    switch (state) {
      case MascotState.cheering:
        return 'Tuyệt đỉnh! Ngươi quả có nhãn quan của một nhà sử học chân chính!';
      case MascotState.thinking:
        return 'Đừng vội nản lòng! Hãy nhớ kỹ mẹo: cọc gỗ lim phải ẩn ngầm dưới mặt nước!';
      case MascotState.guiding:
        return 'Hãy chú ý kỹ trích đoạn sử liệu và quy luật nhật triều để chọn đáp án chuẩn xác!';
    }
  }

  Color _getStatusColor() {
    switch (state) {
      case MascotState.cheering:
        return DauVietColors.natureGreen;
      case MascotState.thinking:
        return DauVietColors.cinnabarRed;
      case MascotState.guiding:
        return DauVietColors.imperialGold;
    }
  }

  String _getStatusLabel() {
    switch (state) {
      case MascotState.cheering:
        return 'TÊ GIÁC KHEN NGỢI';
      case MascotState.thinking:
        return 'TÊ GIÁC GỢI Ý';
      case MascotState.guiding:
        return 'BẠN ĐỒNG HÀNH';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final messageText = message ?? _getDefaultMessage();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          DauVietAudioService.instance.playTap();
          onTap?.call();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar Tê Giác Dấu Việt — ảnh tĩnh sắc nét
            KabiMascotWidget(
              mood: state == MascotState.cheering
                  ? KabiMood.cheering
                  : (state == MascotState.thinking
                      ? KabiMood.thinking
                      : KabiMood.guiding),
              width: avatarSize,
              height: avatarSize,
              headOnly: true,
            ),
            const SizedBox(width: 12),

            // 2. Hộp thoại lời nói (Speech Bubble) phong vị Giấy Dó & Viền Gỗ
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4E4),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.8),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      messageText,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkText,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
