import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../learning/data/learning_providers.dart';

/// Màn hình M-02: Đăng Nhập & Chế Độ Khách (Auth / Guest Mode)
/// Đã được thiết kế lại theo tiêu chuẩn UI/UX Pro Max và chuẩn nhận diện Di Sản Dấu Việt:
/// - Tone màu Xanh Rêu Di Sản (Heritage Forest Green #1E4D3B)
/// - Linh vật Chú Rùa đội nón lá cầm bảng thư (transparent asset)
/// - Bố cục thẻ trắng nổi (floating sheet) bo góc lớn 24dp trên nền giấy dó
/// - Họa tiết hoa sen & non nước chân trang (lotus footer pattern)
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
      backgroundColor: const Color(0xFFFBF8F1),
      body: Stack(
        children: [
          // Nền giấy dó ấm áp với họa tiết mộc
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFBF8F1),
                  Color(0xFFF8F4EA),
                  Color(0xFFF3ECE0),
                ],
              ),
            ),
          ),

          // Họa tiết hoa sen & non nước chân trang (Tách nền trong suốt không đè UI)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  'assets/images/lotus_footer.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Nội dung cuộn chính
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    // Thanh Top Bar trang nhã
                    _buildTopBar(),

                    // Phần nội dung cuộn (Mascot + Card Đăng nhập)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 6),

                            // Mascot Chú Rùa đội nón lá cầm bảng "Chào mừng trở lại!"
                            _buildMascotSection(),

                            const SizedBox(height: 12),

                            // Card Form Đăng Nhập Trắng Tinh Khiết Chuẩn Mẫu UI Pro Max
                            _buildLoginCard(allowGuest),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: DauVietColors.inkText,
            tooltip: 'Quay lại',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/onboarding');
              }
            },
          ),
          Text(
            'Đăng nhập',
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DauVietColors.inkText,
            ),
          ),
          const SizedBox(width: 48), // Cân bằng với icon back
        ],
      ),
    );
  }

  Widget _buildMascotSection() {
    return Center(
      child: SizedBox(
        height: 175,
        child: Image.asset(
          'assets/images/turtle_welcome.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback an toàn nếu chưa load được ảnh
            return Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DauVietColors.heritageGreenSurface,
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 64,
                color: DauVietColors.heritageGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard(bool allowGuest) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBE6DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4D3B).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trường 1: Email hoặc tên đăng nhập
            _buildFieldLabel('Email hoặc tên đăng nhập'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_loading,
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Nhập email hoặc tên đăng nhập',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập email hoặc tên đăng nhập'
                  : null,
            ),
            const SizedBox(height: 16),

            // Trường 2: Mật khẩu
            _buildFieldLabel('Mật khẩu'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_loading,
              onFieldSubmitted: (_) => _login(),
              style: DauVietTypography.bodyMedium.copyWith(
                color: DauVietColors.inkText,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Nhập mật khẩu',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF8A948E),
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
            ),

            // (Quên mật khẩu — chưa triển khai backend, ẩn tạm)

            // Thông báo lỗi nếu có
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEEC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: DauVietColors.cinnabarRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: DauVietColors.cinnabarRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.cinnabarRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Nút Đăng nhập 3D Xúc giác nổi màu Xanh Rêu Di Sản chuẩn mẫu
            DongSonButton(
              label: _loading ? 'ĐANG ĐĂNG NHẬP...' : 'Đăng nhập',
              variant: DongSonButtonVariant.heritageGreen,
              height: 52,
              isLoading: _loading,
              onPressed: _loading ? null : _login,
            ),
            const SizedBox(height: 18),

            // (Đăng nhập mạng xã hội — chưa tích hợp)

            // Chế độ Khách (demo) nếu được phép
            if (allowGuest) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : _enterGuest,
                  icon: const Icon(
                    Icons.explore_rounded,
                    size: 16,
                    color: DauVietColors.heritageGreen,
                  ),
                  label: Text(
                    'Trải nghiệm ngay (Chế độ Khách)',
                    style: DauVietTypography.labelMedium.copyWith(
                      color: DauVietColors.heritageGreen,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Chuyển sang màn Đăng ký (Dùng Wrap chống tràn giao diện)
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Chưa có tài khoản? ',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => context.go('/register'),
                    child: Text(
                      'Đăng ký ngay',
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.heritageGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: DauVietTypography.labelMedium.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2D3436),
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
      hintStyle: DauVietTypography.bodyMedium.copyWith(
        color: const Color(0xFFA0A7A2),
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8A948E)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F6F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E2D9), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E2D9), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DauVietColors.heritageGreen,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 1.6,
        ),
      ),
    );
  }
}
