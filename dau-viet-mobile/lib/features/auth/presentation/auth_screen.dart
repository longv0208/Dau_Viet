import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../learning/data/learning_providers.dart';
import '../data/google_sign_in_provider.dart';

/// Màn hình M-02: Đăng Nhập & Chế Độ Khách (Auth / Guest Mode)
/// Thiết kế mới với Linh vật Chú Tê Giác khăn rằn đỏ:
/// - Giữ nguyên logo chính thức Dấu Việt (`assets/images/app_logo.png`) + nút ngôn ngữ VI
/// - Ảnh nền di sản & chú Tê Giác (`assets/images/auth_rhino_full_bg.png`) bao phủ toàn màn hình
/// - Tiêu đề "Chào mừng trở lại!" điểm xuyết tia nắng vàng
/// - Thẻ form bo góc lớn điểm họa tiết mây cổ, nút Đăng nhập đỏ chu sa vân mây
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
  StreamSubscription<GoogleSignInCredentials>? _googleCredentialsSub;

  static const Color _crimsonPrimary = Color(0xFFCE2026);
  static const Color _crimsonDark = Color(0xFFB0161B);
  static const Color _inkDark = Color(0xFF2B1B12);
  static const Color _cardSurface = Color(0xFFFBF9F5);
  static const Color _inputFill = Color(0xFFF3EFEA);
  static const Color _inputBorder = Color(0xFFE6E0D6);

  @override
  void initState() {
    super.initState();
    // Web: GIS renderButton pushes credentials through the gateway stream.
    _googleCredentialsSub = ref
        .read(googleSignInGatewayProvider)
        .credentialsStream
        .listen(_onGoogleCredentials, onError: (_) {});
  }

  @override
  void dispose() {
    _googleCredentialsSub?.cancel();
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

  Future<void> _onGoogleCredentials(GoogleSignInCredentials credentials) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .loginWithGoogle(
            idToken: credentials.idToken,
            accessToken: credentials.accessToken,
          );
      if (!mounted) return;
      final session = ref.read(authSessionProvider);
      if (session.isAuthenticated) {
        context.go('/dashboard');
      } else {
        setState(() => _error = 'Đăng nhập Google chưa thành công, thử lại.');
      }
    } on ApiException catch (e) {
      await ref.read(googleSignInGatewayProvider).signOut();
      if (!mounted) return;
      setState(() => _error = _mapGoogleError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không kết nối được Google, thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credentials =
          await ref.read(googleSignInGatewayProvider).signIn();
      if (credentials == null) {
        return;
      }
      await ref
          .read(authSessionProvider.notifier)
          .loginWithGoogle(
            idToken: credentials.idToken,
            accessToken: credentials.accessToken,
          );
      if (!mounted) return;
      final session = ref.read(authSessionProvider);
      if (session.isAuthenticated) {
        context.go('/dashboard');
      } else {
        setState(() => _error = 'Đăng nhập Google chưa thành công, thử lại.');
      }
    } on UnsupportedError {
      if (!mounted) return;
      setState(() => _error = 'Dùng nút Google bên dưới để đăng nhập.');
    } on GoogleSignInNotConfiguredException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      await ref.read(googleSignInGatewayProvider).signOut();
      if (!mounted) return;
      setState(() => _error = _mapGoogleError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không kết nối được Google, thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapGoogleError(ApiException e) {
    if (e.isNetworkError) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
    }
    switch (e.error.code) {
      case 'GOOGLE_TOKEN_INVALID':
        return 'Xác thực Google thất bại, thử lại nhé.';
      case 'GOOGLE_EMAIL_UNVERIFIED':
        return 'Email này chưa xác thực — đăng nhập bằng mật khẩu hoặc hoàn tất OTP đăng ký trước.';
      case 'FEATURE_DISABLED':
        return 'Đăng nhập Google chưa được bật trên máy chủ.';
      default:
        return e.isUnauthorized
            ? 'Tài khoản không khả dụng.'
            : 'Đăng nhập Google thất bại, thử lại nhé.';
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
    final mediaSize = MediaQuery.sizeOf(context);
    final screenW = mediaSize.width.isFinite && mediaSize.width > 0
        ? mediaSize.width
        : 390.0;
    final screenH = mediaSize.height.isFinite && mediaSize.height > 0
        ? mediaSize.height
        : 844.0;
    final topInset = MediaQuery.paddingOf(context).top;

    // Tính vị trí chân áo Đông Sơn của chú Tê Giác trên ảnh nền full-screen (768x1376)
    final effectiveW = math.min(screenW, 480.0);
    final bgScale = math.max(effectiveW / 768.0, screenH / 1376.0);
    final rhinoWaistY = (850.0 * bgScale).clamp(
      screenH * 0.50,
      screenH * 0.62,
    );
    final headerBlockHeight = topInset + 138.0;
    final heroWindowHeight = math.max(
      200.0,
      rhinoWaistY - headerBlockHeight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EC),
      body: Stack(
        children: [
          // 1. Ảnh nền phong cảnh di sản & chú Tê Giác bao phủ toàn màn hình (không khuyết đáy)
          Positioned.fill(
            key: const ValueKey('rhino_mascot_hero'),
            child: kIsWeb
                ? Image.network(
                    'assets/assets/images/auth_rhino_full_bg.png?v=4',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : Image.asset(
                    'assets/images/auth_rhino_full_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),

          // 2. Nội dung giao diện đè lên trên ảnh nền toàn màn hình
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Thanh Header: Giữ nguyên Logo Dấu Việt gốc
                      _buildTopBar(),

                      // Tiêu đề "Chào mừng trở lại!" + phụ đề
                      _buildWelcomeHeader(),

                      // Khoảng không hiển thị trọn vẹn chú Tê Giác & áo họa tiết Đông Sơn
                      _buildMascotHeroWindow(heroWindowHeight),

                      // Thẻ Form Đăng nhập bo tròn góc trên
                      _buildLoginCard(allowGuest),

                      const SizedBox(height: 16),
                    ],
                  ),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Center(
        // Giữ nguyên Logo Dấu Việt chính thức (`assets/images/app_logo.png`)
        child: Image.asset(
          'assets/images/app_logo.png',
          key: const ValueKey('auth_app_logo'),
          height: 48,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox(height: 48),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: DauVietTypography.headlineLarge.copyWith(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Chào mừng ',
                      style: TextStyle(color: _inkDark),
                    ),
                    TextSpan(
                      text: 'trở lại!',
                      style: TextStyle(color: _crimsonPrimary),
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: -18,
                top: -10,
                child: SizedBox(
                  width: 24,
                  height: 22,
                  child: CustomPaint(
                    painter: _SparkleRaysPainter(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Đăng nhập để tiếp tục hành trình\nkhám phá lịch sử Việt Nam.',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.36,
              color: const Color(0xFF4A4238),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotHeroWindow(double height) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Viền mây gợn sóng mềm mại ngay phía trên mép thẻ đăng nhập
          Positioned(
            left: 18,
            bottom: -2,
            child: IgnorePointer(
              child: SizedBox(
                width: 110,
                height: 30,
                child: CustomPaint(
                  painter: _TopCardCloudCapPainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool allowGuest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFEDE6DA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF30251F).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: const Color(0xFF30251F).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trường 1: Email hoặc số điện thoại
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_loading,
              style: DauVietTypography.bodyMedium.copyWith(
                color: _inkDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Email hoặc số điện thoại',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập email hoặc số điện thoại'
                  : null,
            ),
            const SizedBox(height: 12),

            // Trường 2: Mật khẩu
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_loading,
              onFieldSubmitted: (_) => _login(),
              style: DauVietTypography.bodyMedium.copyWith(
                color: _inkDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF6E6A64),
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
            ),
            const SizedBox(height: 6),

            // Quên mật khẩu?
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : () => context.go('/auth/forgot'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Quên mật khẩu?',
                  style: DauVietTypography.labelMedium.copyWith(
                    color: const Color(0xFF9E1F24),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Thông báo lỗi nếu có
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEEC),
                  borderRadius: BorderRadius.circular(12),
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

            // Nút CTA Đăng nhập đỏ chu sa kèm họa tiết mây cổ và mũi tên >
            _buildPrimaryLoginButton(),
            const SizedBox(height: 14),

            // Dải phân cách "hoặc"
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE5DFD5))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'hoặc',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF7A736B),
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5DFD5))),
              ],
            ),
            const SizedBox(height: 12),

            // Nút Tiếp tục với Google
            _buildGoogleSignInButton(),

            // Chế độ Khách (demo) nếu được phép
            if (allowGuest) ...[
              const SizedBox(height: 10),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TextButton.icon(
                    onPressed: _loading ? null : _enterGuest,
                    icon: const Icon(
                      Icons.explore_rounded,
                      size: 16,
                      color: _crimsonPrimary,
                    ),
                    label: Text(
                      'Trải nghiệm ngay (Chế độ Khách)',
                      style: DauVietTypography.labelMedium.copyWith(
                        color: _crimsonPrimary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Chân trang: Chưa có tài khoản? Đăng ký >
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Chưa có tài khoản? ',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: const Color(0xFF5A534A),
                      fontSize: 13.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => context.go('/register'),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Đăng ký',
                          style: DauVietTypography.bodyMedium.copyWith(
                            color: const Color(0xFFB51D22),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFFB51D22),
                        ),
                      ],
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

  Widget _buildPrimaryLoginButton() {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD6262C),
                _crimsonPrimary,
                _crimsonDark,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _crimsonPrimary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: _loading ? null : _login,
            borderRadius: BorderRadius.circular(26),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Họa tiết vân mây truyền thống ở 2 góc dưới nút
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ButtonCloudMotifPainter(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        Expanded(
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Đăng nhập',
                                    style: DauVietTypography.labelLarge
                                        .copyWith(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
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

  /// Nút Google: web render bằng GIS `renderButton`; mobile hiển thị nút trắng
  /// bo tròn có biểu tượng chữ G 4 màu chuẩn thiết kế.
  Widget _buildGoogleSignInButton() {
    final webButton = ref
        .read(googleSignInGatewayProvider)
        .buildSignInButton(
          onError: (e) {
            if (!mounted) return;
            final msg = 'Không khởi tạo được Google Sign-In: $e';
            if (_error != msg) {
              setState(() => _error = msg);
            }
          },
        );
    if (webButton != null) return webButton;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _loading ? null : _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _inkDark,
          side: const BorderSide(color: Color(0xFFE5DFD5), width: 1.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _GoogleGLogoPainter(),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Tiếp tục với Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.labelLarge.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
            ),
          ],
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
      hintStyle: DauVietTypography.bodyMedium.copyWith(
        color: const Color(0xFF7B746C),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6E6A64)),
      suffixIcon: suffix,
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _inputBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _inputBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _crimsonPrimary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 1.5,
        ),
      ),
    );
  }
}

/// Vẽ 2 tia nắng vàng nhỏ góc trên bên phải chữ "trở lại!".
class _SparkleRaysPainter extends CustomPainter {
  const _SparkleRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFFF6A821)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFD47A0E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round;

    // Tia đứng hơi nghiêng phải
    final ray1 = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..lineTo(size.width * 0.18, size.height * 0.05)
      ..lineTo(size.width * 0.44, size.height * 0.16)
      ..close();
    canvas.drawPath(ray1, fillPaint);
    canvas.drawPath(ray1, strokePaint);

    // Tia ngang nghiêng phải
    final ray2 = Path()
      ..moveTo(size.width * 0.34, size.height * 0.88)
      ..lineTo(size.width * 0.84, size.height * 0.40)
      ..lineTo(size.width * 0.98, size.height * 0.64)
      ..close();
    canvas.drawPath(ray2, fillPaint);
    canvas.drawPath(ray2, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ gợn mây trắng kem nhô lên ở góc trái trên của thẻ đăng nhập.
class _TopCardCloudCapPainter extends CustomPainter {
  const _TopCardCloudCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBF9F5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.08,
        size.width * 0.56,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.18,
        size.width,
        size.height,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ họa tiết vân mây truyền thống ở 2 góc dưới của nút "Đăng nhập".
class _ButtonCloudMotifPainter extends CustomPainter {
  const _ButtonCloudMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    // Vân mây góc trái dưới
    final leftCenters = <Offset>[
      Offset(18, size.height + 2),
      Offset(42, size.height + 4),
      Offset(66, size.height + 6),
    ];
    for (final c in leftCenters) {
      canvas.drawCircle(c, 18, fillPaint);
      canvas.drawCircle(c, 18, strokePaint);
      canvas.drawCircle(c, 11, strokePaint);
    }

    // Vân mây góc phải dưới
    final rightCenters = <Offset>[
      Offset(size.width - 18, size.height + 2),
      Offset(size.width - 42, size.height + 4),
      Offset(size.width - 66, size.height + 6),
    ];
    for (final c in rightCenters) {
      canvas.drawCircle(c, 18, fillPaint);
      canvas.drawCircle(c, 18, strokePaint);
      canvas.drawCircle(c, 11, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ biểu tượng chữ G 4 màu chuẩn Google.
class _GoogleGLogoPainter extends CustomPainter {
  const _GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.21;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Đỏ (góc trên)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.35, 1.55, false, paint);

    // Vàng (góc trái)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.30, 1.25, false, paint);

    // Xanh lá (góc dưới)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.85, 1.45, false, paint);

    // Xanh dương (góc phải + thanh ngang)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 1.00, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.41,
        size.width * 0.46,
        strokeWidth * 0.92,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
