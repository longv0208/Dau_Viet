import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/data/learning_providers.dart';
import 'otp_verification_screen.dart';

/// Màn hình đăng ký tài khoản learner (P0-03).
/// Gọi POST /api/v1/auth/register qua [AuthSessionController.register]
/// (đăng ký xong đăng nhập luôn) → vào /dashboard khi thành công.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    try {
      final challenge = await ref
          .read(authSessionProvider.notifier)
          .requestRegisterOtp(
            email: email,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text.trim().isEmpty
                ? null
                : _nameCtrl.text.trim(),
          );
      if (!mounted) return;
      // Issue #34: sang màn nhập OTP — user chưa tồn tại tới khi verify.
      context.go(
        '/auth/otp',
        extra: OtpFlowArgs.register(
          email: email,
          resendCooldownSeconds: challenge.resendCooldownSeconds,
        ),
      );
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
    switch (e.error.code) {
      case 'EMAIL_TAKEN':
        return 'Email này đã được đăng ký. Đăng nhập thay nhé.';
      case 'VALIDATION_ERROR':
        return e.error.message.isNotEmpty
            ? e.error.message
            : 'Thông tin chưa hợp lệ — kiểm tra lại email và mật khẩu.';
      default:
        return e.error.message.isNotEmpty
            ? e.error.message
            : 'Đăng ký thất bại, vui lòng thử lại.';
    }
  }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(14),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'GHI DANH SĨ TỬ',
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 22,
                        color: DauVietColors.cinnabarRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo tài khoản để lưu tiến độ học tập và bộ sưu tập của bạn.',
                      textAlign: TextAlign.center,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 24),

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
                            TextFormField(
                              controller: _nameCtrl,
                              enabled: !_loading,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecoration(
                                hint: 'Tên hiển thị (không bắt buộc)',
                                icon: Icons.badge_outlined,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                              decoration: _inputDecoration(
                                hint: 'Mật khẩu (tối thiểu 8 ký tự)',
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
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'Mật khẩu tối thiểu 8 ký tự'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscure,
                              enabled: !_loading,
                              onFieldSubmitted: (_) => _register(),
                              decoration: _inputDecoration(
                                hint: 'Nhập lại mật khẩu',
                                icon: Icons.lock_reset_rounded,
                              ),
                              validator: (v) => v != _passwordCtrl.text
                                  ? 'Mật khẩu nhập lại chưa khớp'
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
                              label: _loading ? 'ĐANG GHI DANH...' : 'Đăng Ký',
                              icon: Icons.how_to_reg_rounded,
                              variant: DongSonButtonVariant.primaryCinnabar,
                              height: 52,
                              onPressed: _loading ? () {} : _register,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _loading ? null : () => context.go('/auth'),
                      child: Text(
                        'Đã có tài khoản? Đăng nhập',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
