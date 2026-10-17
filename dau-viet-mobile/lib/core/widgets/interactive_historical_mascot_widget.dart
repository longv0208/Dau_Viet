import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

enum MascotState {
  guiding, // Hướng dẫn / Chú ý chi tiết lịch sử
  cheering, // Đắc thắng / Chúc mừng trả lời đúng
  thinking, // Đăm chiêu / Gợi ý khi chọn sai hoặc gặp câu khó
}

/// Nhân vật đại diện đồng hành (Interactive Historical Guide / Mascot)
/// Lấy hình tượng Bé Sĩ Tử Dấu Việt thông thái, phản hồi tức thì theo trạng thái học tập chuẩn Duolingo.
class InteractiveHistoricalMascotWidget extends StatefulWidget {
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

  @override
  State<InteractiveHistoricalMascotWidget> createState() =>
      _InteractiveHistoricalMascotWidgetState();
}

class _InteractiveHistoricalMascotWidgetState
    extends State<InteractiveHistoricalMascotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant InteractiveHistoricalMascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state &&
        !DauVietAudioService.isTestEnvironment) {
      _bounceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  String _getImageAsset() {
    switch (widget.state) {
      case MascotState.cheering:
        return 'assets/images/mascot_cheering.jpg';
      case MascotState.thinking:
        return 'assets/images/mascot_thinking.jpg';
      case MascotState.guiding:
        return 'assets/images/mascot_guiding.jpg';
    }
  }

  String _getDefaultMessage() {
    switch (widget.state) {
      case MascotState.cheering:
        return 'Tuyệt đỉnh! Ngươi quả có nhãn quan của một nhà sử học chân chính!';
      case MascotState.thinking:
        return 'Đừng vội nản lòng! Hãy nhớ kỹ mẹo: cọc gỗ lim phải ẩn ngầm dưới mặt nước!';
      case MascotState.guiding:
        return 'Hãy chú ý kỹ trích đoạn sử liệu và quy luật nhật triều để chọn đáp án chuẩn xác!';
    }
  }

  Color _getStatusColor() {
    switch (widget.state) {
      case MascotState.cheering:
        return DauVietColors.natureGreen;
      case MascotState.thinking:
        return DauVietColors.cinnabarRed;
      case MascotState.guiding:
        return DauVietColors.imperialGold;
    }
  }

  String _getStatusLabel() {
    switch (widget.state) {
      case MascotState.cheering:
        return 'SĨ TỬ KHEN NGỢI';
      case MascotState.thinking:
        return 'SĨ TỬ GỢI Ý';
      case MascotState.guiding:
        return 'BẠN ĐỒNG HÀNH';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final messageText = widget.message ?? _getDefaultMessage();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          DauVietAudioService.instance.playTap();
          if (!DauVietAudioService.isTestEnvironment) {
            _bounceController.forward(from: 0.0);
          }
          widget.onTap?.call();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar Chibi Bé Sĩ Tử Dấu Việt có hiệu ứng nhảy lò xo khi chuyển trạng thái
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: widget.avatarSize,
                height: widget.avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    _getImageAsset(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: DauVietColors.parchmentContainer,
                      child: Icon(
                        widget.state == MascotState.cheering
                            ? Icons.sentiment_very_satisfied_rounded
                            : (widget.state == MascotState.thinking
                                  ? Icons.psychology_rounded
                                  : Icons.school_rounded),
                        color: statusColor,
                        size: widget.avatarSize * 0.55,
                      ),
                    ),
                  ),
                ),
              ),
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
