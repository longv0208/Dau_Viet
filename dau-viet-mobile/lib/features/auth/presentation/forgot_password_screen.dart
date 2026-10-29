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

/// Quên mật khẩu — bước 1 (Issue #34): nhập email → server gửi OTP
/// PASSWORD_RESET (luôn 200, không lộ email tồn tại) → chuyển sang màn OTP.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    try {
      await ref.read(authSessionProvider.notifier).forgotPassword(email: email);
      if (!mounted) return;
      context.go(
        '/auth/otp',
        extra: OtpFlowArgs.passwordReset(email: email),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.isNetworkError
          ? 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.'
          : 'Không gửi được yêu cầu, vui lòng thử lại.');
    } catch (_) {
      setState(() => _error = 'Có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
          onPressed: () => context.go('/auth'),
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
                    'KHÔI PHỤC MẬT KHẨU',
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 22,
                      color: DauVietColors.cinnabarRed,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập email đã đăng ký — chúng tôi sẽ gửi mã xác thực 6 số.',
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
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_loading,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: DauVietColors.inkMuted),
                              filled: true,
                              fillColor: DauVietColors.parchmentSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Nhập email hợp lệ'
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
                            label: _loading ? 'ĐANG GỬI...' : 'Gửi Mã Xác Thực',
                            icon: Icons.mark_email_read_outlined,
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
