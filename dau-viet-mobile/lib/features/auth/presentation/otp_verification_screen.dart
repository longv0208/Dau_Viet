import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../learning/data/learning_providers.dart';

/// Mục đích của màn OTP — quyết định gọi endpoint nào và đi đâu sau verify.
enum OtpFlow { registerVerify, passwordReset }

/// Args truyền qua go_router `extra`.
class OtpFlowArgs {
  final String email;
  final OtpFlow flow;
  final int resendCooldownSeconds;

  const OtpFlowArgs._(this.email, this.flow, this.resendCooldownSeconds);

  factory OtpFlowArgs.register({required String email, int resendCooldownSeconds = 60}) =>
      OtpFlowArgs._(email, OtpFlow.registerVerify, resendCooldownSeconds);

  factory OtpFlowArgs.passwordReset({required String email, int resendCooldownSeconds = 60}) =>
      OtpFlowArgs._(email, OtpFlow.passwordReset, resendCooldownSeconds);

  String get purpose => switch (flow) {
        OtpFlow.registerVerify => 'REGISTER_VERIFY',
        OtpFlow.passwordReset => 'PASSWORD_RESET',
      };
}

/// Màn nhập mã OTP 6 số (Issue #34):
/// - REGISTER_VERIFY: sau đăng ký — verify → tự đăng nhập → /dashboard.
/// - PASSWORD_RESET: sau forgot — verify → sang bước đặt mật khẩu mới.
/// Resend bị khoá trong resendCooldownSeconds (đếm ngược hiển thị).
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final OtpFlowArgs args;

  const OtpVerificationScreen({super.key, required this.args});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  late int _cooldownLeft;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _cooldownLeft = widget.args.resendCooldownSeconds;
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_cooldownLeft > 0) _cooldownLeft--;
        if (_cooldownLeft <= 0) t.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Nhập đủ 6 chữ số của mã.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.args.flow == OtpFlow.registerVerify) {
        await ref.read(authSessionProvider.notifier).verifyRegisterOtp(
              email: widget.args.email,
              otpCode: code,
            );
        if (!mounted) return;
        final session = ref.read(authSessionProvider);
        if (session.isAuthenticated) {
          context.go('/dashboard');
        } else {
          setState(() => _error = 'Xác thực chưa thành công, thử lại nhé.');
        }
      } else {
        // PASSWORD_RESET: backend chưa có endpoint "verify-only" — mã OTP
        // được kiểm tra cùng lúc với mật khẩu mới ở /password/reset. Chuyển
        // sang bước đặt mật khẩu, kèm mã đã nhập.
        if (!mounted) return;
        context.go('/auth/reset-password', extra: (
          email: widget.args.email,
          otpCode: code,
        ));
      }
    } on ApiException catch (e) {
      setState(() => _error = _mapError(e));
    } catch (_) {
      setState(() => _error = 'Có lỗi xảy ra, vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldownLeft > 0 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(authSessionProvider.notifier).resendOtp(
            email: widget.args.email,
            purpose: widget.args.purpose,
          );
      if (!mounted) return;
      setState(() {
        _cooldownLeft = challenge.resendCooldownSeconds;
      });
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lại mã xác thực.')),
      );
    } on ApiException catch (e) {
      setState(() => _error = _mapError(e));
    } catch (_) {
      setState(() => _error = 'Không gửi lại được mã, thử lại sau.');
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
        return 'Mã xác thực chưa đúng. Kiểm tra lại trong email.';
      case 'OTP_EXPIRED':
        return 'Mã đã hết hạn. Bấm "Gửi lại mã" để nhận mã mới.';
      case 'OTP_MAX_ATTEMPTS_EXCEEDED':
        return 'Nhập sai quá nhiều lần. Bấm "Gửi lại mã" để nhận mã mới.';
      case 'OTP_RESEND_COOLDOWN':
        return 'Vừa gửi mã rồi — chờ một lát rồi gửi lại.';
      case 'OTP_NO_CHALLENGE':
        return 'Chưa có mã nào được gửi cho email này.';
      case 'EMAIL_TAKEN':
        return 'Email này đã được đăng ký.';
      default:
        return e.error.message.isNotEmpty
            ? e.error.message
            : 'Xác thực thất bại, vui lòng thử lại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.args.flow == OtpFlow.registerVerify;
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: DauVietColors.inkText),
          onPressed: () => context.go(isRegister ? '/register' : '/auth/forgot'),
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
                    'XÁC THỰC EMAIL',
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 22,
                      color: DauVietColors.cinnabarRed,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập mã 6 số đã gửi tới\n${widget.args.email}',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _codeCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                            fontSize: 28,
                            letterSpacing: 12,
                            fontWeight: FontWeight.w700,
                            color: DauVietColors.inkText,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: DauVietColors.inkMuted.withValues(alpha: 0.5),
                              letterSpacing: 12,
                            ),
                            filled: true,
                            fillColor: DauVietColors.parchmentSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: DauVietColors.imperialGold),
                            ),
                          ),
                          onSubmitted: (_) => _verify(),
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
                              ? 'ĐANG XÁC THỰC...'
                              : (isRegister ? 'Xác Thực & Vào Học' : 'Tiếp Tục'),
                          icon: isRegister
                              ? Icons.verified_user_rounded
                              : Icons.arrow_forward_rounded,
                          variant: DongSonButtonVariant.primaryCinnabar,
                          height: 52,
                          onPressed: _loading ? () {} : _verify,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed:
                        (_cooldownLeft > 0 || _loading) ? null : _resend,
                    child: Text(
                      _cooldownLeft > 0
                          ? 'Gửi lại mã sau ${_cooldownLeft}s'
                          : 'Gửi lại mã',
                      style: DauVietTypography.labelMedium.copyWith(
                        color: _cooldownLeft > 0
                            ? DauVietColors.inkMuted
                            : DauVietColors.cinnabarRed,
                        fontWeight: FontWeight.w700,
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
