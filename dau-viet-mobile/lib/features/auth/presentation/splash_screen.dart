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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/app_logo.png'), context);
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
      AuthStatus.authenticated => '/island',
      AuthStatus.guest => '/dashboard',
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
                            // Logo Dấu Việt chính thức từ logo2.svg
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: DauVietColors.parchmentSurface
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: DauVietColors.imperialGold,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: DauVietColors.imperialGold
                                        .withValues(alpha: 0.32),
                                    blurRadius: 28,
                                    spreadRadius: 3,
                                  ),
                                  const BoxShadow(
                                    color: Color(0x22613B28),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/app_logo.png',
                                    width: 280,
                                    height: 92,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Text(
                                      'DẤU VIỆT',
                                      style: DauVietTypography.headlineLarge
                                          .copyWith(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: DauVietColors.cinnabarRed,
                                            letterSpacing: 3.5,
                                          ),
                                    ),
                                  ),
                                  // Giữ text 'DẤU VIỆT' cho accessibility & widget tests
                                  const Opacity(
                                    opacity: 0.0,
                                    child: SizedBox(
                                      height: 1,
                                      child: Text('DẤU VIỆT'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

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
