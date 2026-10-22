import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/data/learning_providers.dart';

/// Màn hình M-02: Đăng Nhập & Chế Độ Khách (Auth / Guest Mode)
/// Real mode: email + password qua backend `/auth/login`.
/// Guest chỉ xuất hiện khi USE_MOCK=true (demo) — real mode bắt buộc login.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      final session = ref.read(authSessionProvider);
      if (session.isAuthenticated) {
        context.go('/dashboard');
      } else {
        setState(() => _error = 'Đăng nhập chưa thành công, vui lòng thử lại.');
      }
    } on ApiException catch (e) {
      setState(() => _error = _mapError(e));
    } catch (_) {
      setState(() => _error = 'Có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(ApiException e) {
    if (e.isNetworkError) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
    }
    if (e.isUnauthorized) {
      return 'Email hoặc mật khẩu chưa đúng.';
    }
    if (e.isForbidden) {
      return 'Tài khoản không có quyền truy cập.';
    }
    return e.error.message.isNotEmpty
        ? e.error.message
        : 'Đăng nhập thất bại, vui lòng thử lại.';
  }

  void _enterGuest() {
    ref.read(authSessionProvider.notifier).enterGuest();
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final bool allowGuest = ApiConfig.useMock;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
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
                        border: Border.all(
                          color: DauVietColors.imperialGold,
                          width: 2,
                        ),
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
                    const SizedBox(height: 28),

                    // Form đăng nhập thật
                    ParchmentCard(
                      backgroundColor: DauVietColors.parchmentContainer,
                      borderColor: DauVietColors.imperialGold,
                      borderWidth: 1.5,
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ĐĂNG NHẬP TÀI KHOẢN',
                              style: DauVietTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: DauVietColors.inkText,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_loading,
                              decoration: _inputDecoration(
                                hint: 'Email',
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Nhập email hợp lệ'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              enabled: !_loading,
                              onFieldSubmitted: (_) => _login(),
                              decoration: _inputDecoration(
                                hint: 'Mật khẩu',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: DauVietColors.inkMuted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Nhập mật khẩu'
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: DauVietTypography.bodySmall.copyWith(
                                  color: DauVietColors.cinnabarRed,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            DongSonButton(
                              label: _loading
                                  ? 'ĐANG ĐĂNG NHẬP...'
                                  : 'Đăng Nhập',
                              icon: Icons.login_rounded,
                              variant: DongSonButtonVariant.primaryCinnabar,
                              height: 52,
                              onPressed: _loading ? () {} : _login,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.go('/register'),
                      child: Text(
                        'Chưa có tài khoản? Đăng ký ngay',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Guest chỉ khi demo USE_MOCK
                    if (allowGuest) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: DauVietColors.outlineVariant),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'HOẶC TRẢI NGHIỆM DEMO',
                              style: DauVietTypography.labelSmall.copyWith(
                                color: DauVietColors.inkMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: DauVietColors.outlineVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DongSonButton(
                        label: 'Vào Học Ngay (Chế độ Khách)',
                        icon: Icons.explore_rounded,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: _enterGuest,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // SSO — sắp ra mắt
                    DongSonButton(
                      label: 'Tiếp tục với Google (Sắp ra mắt)',
                      icon: Icons.account_circle_outlined,
                      variant: DongSonButtonVariant.secondaryParchment,
                      height: 48,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    DongSonButton(
                      label: 'Cổng Giáo dục EduID — Học sinh & GV (Sắp ra mắt)',
                      icon: Icons.school_outlined,
                      variant: DongSonButtonVariant.secondaryParchment,
                      height: 48,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 28),

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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: DauVietTypography.bodySmall.copyWith(
        color: DauVietColors.inkMuted,
      ),
      prefixIcon: Icon(icon, size: 20, color: DauVietColors.inkMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DauVietColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DauVietColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 1.4,
        ),
      ),
    );
  }
}
