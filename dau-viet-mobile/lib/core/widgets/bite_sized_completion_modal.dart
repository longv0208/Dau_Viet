import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'dong_son_button.dart';
import 'gold_confetti_overlay.dart';

/// Modal tổng kết nhanh sau mỗi hoạt động học tập (Bite-sized Completion Modal) chuẩn Duolingo
/// Cung cấp vòng lặp tưởng thưởng phấn khích:
/// - Huy hiệu chiến công nảy lên (Spring scale animation)
/// - Âm thanh mở rương / chiến thắng cổ điển
/// - Nhãn tỉ lệ chính xác & ngọn lửa hào khí chuỗi đúng
/// - Hiệu ứng số đếm nạp thưởng tăng dần (+Điểm Sử Ký, +XP)
/// - Nút hành động 3D tiếp tục hành trình
class BiteSizedCompletionModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final int scorePoints;
  final int xpPoints;
  final double accuracy;
  final int streakCount;
  final double multiplier;
  final String badgeAsset;
  final VoidCallback onContinue;

  const BiteSizedCompletionModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scorePoints,
    required this.xpPoints,
    this.accuracy = 1.0,
    this.streakCount = 3,
    this.multiplier = 1.5,
    this.badgeAsset = 'assets/badges/badge_trace_1_context.png',
    required this.onContinue,
  });

  /// Hàm tĩnh mở Modal một cách thuận tiện
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int scorePoints,
    required int xpPoints,
    double accuracy = 1.0,
    int streakCount = 3,
    double multiplier = 1.5,
    String badgeAsset = 'assets/badges/badge_trace_1_context.png',
    required VoidCallback onContinue,
  }) {
    // Phát âm thanh rương báu mở ngay khi modal hiển thị
    DauVietAudioService.instance.playChestOpen();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => BiteSizedCompletionModal(
        title: title,
        subtitle: subtitle,
        scorePoints: scorePoints,
        xpPoints: xpPoints,
        accuracy: accuracy,
        streakCount: streakCount,
        multiplier: multiplier,
        badgeAsset: badgeAsset,
        onContinue: onContinue,
      ),
    );
  }

  @override
  State<BiteSizedCompletionModal> createState() => _BiteSizedCompletionModalState();
}

class _BiteSizedCompletionModalState extends State<BiteSizedCompletionModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _badgeFloatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: DauVietAudioService.isTestEnvironment
          ? const Duration(milliseconds: 10)
          : const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _badgeFloatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _accuracyLabel {
    final percent = (widget.accuracy * 100).toInt();
    if (percent >= 100) return '100% Tuyệt Đỉnh';
    if (percent >= 80) return '$percent% Xuất Sắc';
    if (percent >= 60) return '$percent% Thành Thạo';
    return '$percent% Hoàn Thành';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GoldConfettiOverlay(
        trigger: true,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: DauVietColors.imperialGold,
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40613B28),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x33E7B451),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Huy hiệu chiến công với hiệu ứng lơ lửng hoàng gia
                AnimatedBuilder(
                  animation: _badgeFloatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _badgeFloatAnimation.value),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vòng hào quang sáng
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: DauVietColors.imperialGold.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // Ảnh huy hiệu
                      Image.asset(
                        widget.badgeAsset,
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DauVietColors.imperialGold,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            size: 50,
                            color: DauVietColors.cinnabarRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Tiêu đề chiến công
                Text(
                  widget.title,
                  style: DauVietTypography.headlineMedium.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // 3. Phụ đề tóm tắt thành quả
                Text(
                  widget.subtitle,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkMuted,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 4. Nhãn tỉ lệ chính xác & Chuỗi hào khí
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Tỉ lệ chính xác
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: DauVietColors.natureGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: DauVietColors.natureGreen,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: DauVietColors.natureGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _accuracyLabel,
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.natureGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Chuỗi hào khí
                    if (widget.streakCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF9800),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: Color(0xFFE65100),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Chuỗi ${widget.streakCount} 🔥',
                              style: DauVietTypography.labelSmall.copyWith(
                                color: const Color(0xFFBF360C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Thẻ thống kê phần thưởng với hiệu ứng số chạy tăng dần
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: DauVietColors.parchmentContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: DauVietColors.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Điểm Sử Ký
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: DauVietColors.imperialGold,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: widget.scorePoints),
                                  duration: const Duration(milliseconds: 900),
                                  builder: (context, val, child) {
                                    return Text(
                                      '+$val',
                                      style: DauVietTypography.headlineSmall.copyWith(
                                        color: DauVietColors.cinnabarRed,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.multiplier > 1.0
                                  ? 'Điểm Sử Ký (x${widget.multiplier.toStringAsFixed(1)})'
                                  : 'Điểm Sử Ký',
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vạch phân cách
                      Container(
                        height: 36,
                        width: 1,
                        color: DauVietColors.outlineVariant,
                      ),

                      // Kinh Nghiệm XP
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFF1E88E5),
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: widget.xpPoints),
                                  duration: const Duration(milliseconds: 900),
                                  builder: (context, val, child) {
                                    return Text(
                                      '+$val',
                                      style: DauVietTypography.headlineSmall.copyWith(
                                        color: const Color(0xFF0D47A1),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kinh Nghiệm XP',
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Nút 3D Tiếp tục hành trình
                DongSonButton(
                  label: 'TIẾP TỤC HÀNH TRÌNH ›',
                  icon: Icons.arrow_forward_rounded,
                  variant: DongSonButtonVariant.primaryCinnabar,
                  height: 52,
                  onPressed: () {
                    DauVietAudioService.instance.playTap();
                    Navigator.of(context).pop();
                    widget.onContinue();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
