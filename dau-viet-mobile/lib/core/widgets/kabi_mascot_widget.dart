import 'package:flutter/material.dart';


import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

/// Các trạng thái cảm xúc của Mascot Kabi theo chuẩn gamification Duolingo
enum KabiMood {
  idle, // Nghỉ ngơi / Chờ đợi
  guiding, // Đang dẫn nhập / Chỉ tay hướng dẫn sử liệu
  cheering, // Trả lời ĐÚNG! Nhảy cẫng ăn mừng, cười rạng rỡ
  thinking, // Trả lời SAI! Đăm chiêu gãi đầu, động viên thử lại
  streak, // Chuỗi đúng liên tiếp! Đeo kính râm ngầu, bốc lửa
  victory, // Hoàn thành bài học! Ôm cúp vàng vinh quang
}

/// Widget hiển thị Linh vật Kabi (Capybara Mascot) từ repository bryllim/kabi-mascot
/// Rive 0.14.x: dùng FileLoader + RiveWidgetController + RiveWidget (API mới,
/// input lấy qua stateMachine.number/boolean/trigger thay SMI* cũ).
class KabiMascotWidget extends StatefulWidget {
  final KabiMood mood;
  final double width;
  final double height;
  final bool headOnly;
  final bool enableSound;
  final VoidCallback? onTap;

  const KabiMascotWidget({
    super.key,
    this.mood = KabiMood.guiding,
    this.width = 110,
    this.height = 110,
    this.headOnly = false,
    this.enableSound = true,
    this.onTap,
  });

  @override
  State<KabiMascotWidget> createState() => _KabiMascotWidgetState();
}

class _KabiMascotWidgetState extends State<KabiMascotWidget> {
  void _handleTap() {
    if (widget.enableSound) {
      DauVietAudioService.instance.playTap();
    }
    widget.onTap?.call();
  }
  @override
  Widget build(BuildContext context) {
    // Ưu tiên hiển thị linh vật Rùa Kabi đội nón lá truyền thống Việt Nam
    // đồng bộ 100% với bộ thiết kế chuẩn Di sản Dấu Việt.
    return _buildFallbackMascot();
  }

  Widget _buildFallbackMascot() {
    return Semantics(
      label: 'Linh vật Kabi',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _buildFallbackAvatar(),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    final String assetPath =
        (widget.mood == KabiMood.victory || widget.mood == KabiMood.cheering)
        ? 'assets/images/kabi_celebration_victory.png'
        : 'assets/images/kabi_reading_book.png';
    return Image.asset(
      assetPath,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DauVietColors.imperialGold.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Icon(
            Icons.auto_stories_rounded,
            size: (widget.width * 0.48).clamp(18.0, 48.0),
            color: DauVietColors.cinnabarRed,
          ),
        ),
      ),
    );
  }
}
