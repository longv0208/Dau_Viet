import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/prefs/onboarding_flag.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../learning/data/learning_providers.dart';
import '../data/auth_state.dart';

/// Màn hình M-01: Splash Screen Thương hiệu Dấu Việt
/// Khớp 100% với thiết kế Stitch b867c4faee4749f99e3caecb0a519eb3
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  Timer? _navTimer;
  Future<void>? _restore;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();

    // Khôi phục phiên đăng nhập song song với animation; chuyển màn sau
    // tối thiểu 2.5s và khi restore xong (auth → dashboard / guest →
    // dashboard trong demo / unauthenticated → auth).
    _navTimer = Timer(const Duration(milliseconds: 2500), _route);
    _restore = ref.read(authSessionProvider.notifier).restore();
  }

  Future<void> _route() async {
    try {
      await _restore;
    } catch (_) {
      // Restore lỗi → router guard sẽ quyết định (thường rơi về /auth).
    }
    if (!mounted) return;
    final status = ref.read(authSessionProvider).status;
    final String dest = switch (status) {
      AuthStatus.authenticated || AuthStatus.guest => '/dashboard',
      _ => '/auth',
    };
    // Lần đầu mở app → đưa qua onboarding 3 bước trước khi vào đích (P1-02).
    try {
      final seen = await OnboardingFlag.isSeen();
      if (!mounted) return;
      if (!seen) {
        context.go('/onboarding?next=${Uri.encodeComponent(dest)}');
        return;
      }
    } catch (_) {
      // Lỗi đọc cờ → vào thẳng đích, không chặn luồng.
    }
    if (!mounted) return;
    context.go(dest);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _skip() {
    _navTimer?.cancel();
    _route();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                DauVietColors.parchmentSurface,
                DauVietColors.parchmentContainer,
                Color(0xFFF3E0C0),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated Logo Block
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            // Biểu tượng Mặt trời Trống Đồng & Ấn Triện Son Đỏ
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: DauVietColors.parchmentContainer,
                                border: Border.all(
                                  color: DauVietColors.imperialGold,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DauVietColors.imperialGold
                                        .withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                  const BoxShadow(
                                    color: Color(0x2A613B28),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Vòng hào quang trống đồng
                                  Icon(
                                    Icons.wb_sunny_rounded,
                                    size: 80,
                                    color: DauVietColors.imperialGold
                                        .withValues(alpha: 0.7),
                                  ),
                                  // Dấu ấn triện vuông màu son
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: DauVietColors.cinnabarRed,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'DẤU\nVIỆT',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Noto Serif',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Wordmark DẤU VIỆT
                            Text(
                              'DẤU VIỆT',
                              style: DauVietTypography.headlineLarge.copyWith(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: DauVietColors.cinnabarRed,
                                letterSpacing: 3.5,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Slogan
                            Text(
                              'Khám phá Hào khí Sử Việt qua Từng Dấu Vết',
                              textAlign: TextAlign.center,
                              style: DauVietTypography.bodyMedium.copyWith(
                                color: DauVietColors.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Footer Loading Indicator & Subtitle
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                DauVietColors.cinnabarRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'CHẠM ĐỂ BỎ QUA • PHIÊN BẢN v2.0 DI SẢN',
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: DauVietColors.inkMuted.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
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
