import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-02: Đăng Nhập & Chế Độ Khách (Auth / Guest Mode)
/// Khớp 100% với thiết kế Stitch ba52d1ce499942d9b23180b59b3f9ff2
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DauVietColors.parchmentSurface,
              Color(0xFFFAF2E4),
              Color(0xFFF5E7CE),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Header Seal & Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DauVietColors.imperialGold, width: 2),
                        boxShadow: DauVietColors.heritageShadow,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'DẤU\nVIỆT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Noto Serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'SĨ TỬ NHẬP MÔN',
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 24,
                        color: DauVietColors.cinnabarRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Chào mừng bạn bước vào không gian học tập và điều tra lịch sử Việt Nam tương tác.',
                      textAlign: TextAlign.center,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card Tùy chọn Nhập cảnh
                    ParchmentCard(
                      backgroundColor: DauVietColors.parchmentContainer,
                      borderColor: DauVietColors.imperialGold,
                      borderWidth: 1.5,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, color: DauVietColors.imperialGold, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'VÀO HỌC NGAY KHÔNG CẦN ĐĂNG KÝ',
                                  style: DauVietTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: DauVietColors.inkText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Trải nghiệm trọn vẹn chiến dịch Bạch Đằng 938, tự do khám phá 4 Dấu Vết và sa bàn lịch sử ở Chế độ Khách.',
                            style: DauVietTypography.bodySmall,
                          ),
                          const SizedBox(height: 18),

                          // Nút chính: Chế độ Khách (Guest Mode)
                          DongSonButton(
                            label: 'Vào Học Ngay (Chế độ Khách)',
                            icon: Icons.explore_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: () {
                              context.go('/dashboard');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hoặc đăng nhập tài khoản
                    Row(
                      children: [
                        const Expanded(child: Divider(color: DauVietColors.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'HOẶC LIÊN KẾT TÀI KHOẢN',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.inkMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: DauVietColors.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nút Đăng nhập Google
                    DongSonButton(
                      label: 'Tiếp tục với Google',
                      icon: Icons.account_circle_outlined,
                      variant: DongSonButtonVariant.secondaryParchment,
                      height: 48,
                      onPressed: () {
                        context.go('/dashboard');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Nút Cổng Giáo Dục EduID
                    DongSonButton(
                      label: 'Cổng Giáo dục EduID (Học sinh & GV)',
                      icon: Icons.school_outlined,
                      variant: DongSonButtonVariant.secondaryParchment,
                      height: 48,
                      onPressed: () {
                        context.go('/dashboard');
                      },
                    ),
                    const SizedBox(height: 32),

                    // Cam kết & Điều khoản
                    Text(
                      'Bằng cách tiếp tục, bạn đồng ý với Quy chế Học thuật và Cam kết Bảo tồn Sử liệu của Dấu Việt.\nPhiên bản Giáo dục Chuẩn GDPT 2018.',
                      textAlign: TextAlign.center,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: DauVietColors.inkMuted.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
