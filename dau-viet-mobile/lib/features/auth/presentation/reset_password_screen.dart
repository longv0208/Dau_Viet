import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/data/learning_providers.dart';

/// Quên mật khẩu — bước 2 (Issue #34): OTP đã nhập ở màn trước + mật khẩu
/// mới + xác nhận → POST /password/reset → về /auth.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String otpCode;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otpCode,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).resetPassword(
            email: widget.email,
            otpCode: widget.otpCode,
            newPassword: _passwordCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đặt lại mật khẩu thành công. Đăng nhập lại nhé.')),
      );
      context.go('/auth');
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
      case 'OTP_INVALID':
        return 'Mã xác thực chưa đúng. Quay lại nhập lại mã nhé.';
      case 'OTP_EXPIRED':
        return 'Mã đã hết hạn — yêu cầu mã mới.';
      case 'OTP_MAX_ATTEMPTS_EXCEEDED':
        return 'Mã bị khoá do nhập sai nhiều lần — yêu cầu mã mới.';
      case 'OTP_NO_CHALLENGE':
        return 'Chưa có mã nào được gửi cho email này.';
      case 'VALIDATION_ERROR':
        return e.error.message.isNotEmpty
            ? e.error.message
            : 'Mật khẩu chưa hợp lệ.';
      default:
        return e.error.message.isNotEmpty
            ? e.error.message
            : 'Đặt lại mật khẩu thất bại, thử lại nhé.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: DauVietColors.inkText),
          onPressed: () => context.go('/auth/forgot'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'MẬT KHẨU MỚI',
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 22,
                      color: DauVietColors.cinnabarRed,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đặt mật khẩu mới cho\n${widget.email}',
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
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            enabled: !_loading,
                            decoration: InputDecoration(
                              hintText: 'Mật khẩu mới (tối thiểu 8 ký tự)',
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: DauVietColors.inkMuted),
                              suffixIcon: IconButton(
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
                              filled: true,
                              fillColor: DauVietColors.parchmentSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
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
                            decoration: InputDecoration(
                              hintText: 'Nhập lại mật khẩu mới',
                              prefixIcon: const Icon(Icons.lock_reset_rounded,
                                  color: DauVietColors.inkMuted),
                              filled: true,
                              fillColor: DauVietColors.parchmentSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v != _passwordCtrl.text
                                ? 'Mật khẩu nhập lại chưa khớp'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
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
                                ? 'ĐANG CẬP NHẬT...'
                                : 'Đặt Lại Mật Khẩu',
                            icon: Icons.key_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: _loading ? () {} : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
