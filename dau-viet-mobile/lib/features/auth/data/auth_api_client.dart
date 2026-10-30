import '../../../core/api/api_client.dart';

/// DTO trả về từ POST /api/v1/auth/login và /auth/refresh.
class AuthTokenDto {
  final String accessToken;
  final String tokenType;
  final int expiresIn; // seconds
  final String refreshToken;
  final int refreshExpiresIn;

  const AuthTokenDto({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshToken,
    required this.refreshExpiresIn,
  });

  factory AuthTokenDto.fromJson(Map<String, dynamic> json) => AuthTokenDto(
    accessToken: json['accessToken'] as String? ?? '',
    tokenType: json['tokenType'] as String? ?? 'Bearer',
    expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
    refreshToken: json['refreshToken'] as String? ?? '',
    refreshExpiresIn: (json['refreshExpiresIn'] as num?)?.toInt() ?? 0,
  );
}


/// Metadata của một OTP challenge (202 từ /auth/register, /auth/otp/resend).
class OtpChallengeDto {
  final String email;
  final String? otpPurpose;
  final int otpTtlSeconds;
  final int resendCooldownSeconds;

  const OtpChallengeDto({
    required this.email,
    this.otpPurpose,
    required this.otpTtlSeconds,
    required this.resendCooldownSeconds,
  });

  factory OtpChallengeDto.fromJson(Map<String, dynamic> json) => OtpChallengeDto(
    email: json['email'] as String? ?? '',
    otpPurpose: json['otpPurpose'] as String?,
    otpTtlSeconds: (json['otpTtlSeconds'] as num?)?.toInt() ?? 300,
    resendCooldownSeconds: (json['resendCooldownSeconds'] as num?)?.toInt() ?? 60,
  );
}

/// Hồ sơ người dùng hiện tại — GET /api/v1/users/me.
class UserProfileDto {
  final String id;
  final String email;
  final String? displayName;
  final String role;
  final String? status;
  final String? createdAt;

  const UserProfileDto({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.status,
    this.createdAt,
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String?,
    role: json['role'] as String? ?? 'LEARNER',
    status: json['status'] as String?,
    createdAt: json['createdAt'] as String?,
  );
}

/// Client mỏng cho nhóm endpoint `/api/v1/auth` + `/users/me`.
/// Token nằm trong BODY (không cookie) theo contract backend.
class AuthApiClient {
  final ApiClient _client;

  const AuthApiClient(this._client);

  Future<AuthTokenDto> login(String email, String password) async {
    final json = await _client.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthTokenDto.fromJson(json);
  }

  /// Issue #34: register giờ chỉ TẠO challenge OTP (202) — user chưa tồn tại
  /// cho tới khi verifyRegisterOtp thành công.
  Future<OtpChallengeDto> requestRegisterOtp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final json = await _client.post(
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
      },
    );
    return OtpChallengeDto.fromJson(json);
  }

  /// Verify OTP đăng ký → backend tạo user + trả token pair (200).
  Future<AuthTokenDto> verifyRegisterOtp({
    required String email,
    required String otpCode,
  }) async {
    final json = await _client.post(
      '/api/v1/auth/register/verify',
      body: {'email': email, 'otpCode': otpCode},
    );
    return AuthTokenDto.fromJson(json);
  }

  /// Gửi lại OTP — purpose: REGISTER_VERIFY | PASSWORD_RESET.
  Future<OtpChallengeDto> resendOtp({
    required String email,
    required String purpose,
  }) async {
    final json = await _client.post(
      '/api/v1/auth/otp/resend',
      body: {'email': email, 'purpose': purpose},
    );
    return OtpChallengeDto.fromJson(json);
  }

  /// Forgot kickoff — luôn 200 (anti-enumeration).
  Future<void> forgotPassword({required String email}) async {
    await _client.post(
      '/api/v1/auth/password/forgot',
      body: {'email': email},
    );
  }

  /// Reset — verify OTP + đặt mật khẩu mới + revoke refresh tokens (204).
  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    await _client.post(
      '/api/v1/auth/password/reset',
      body: {'email': email, 'otpCode': otpCode, 'newPassword': newPassword},
    );
  }

  /// Google Sign-In — gửi idToken (Android/iOS) hoặc accessToken (Flutter
  /// Web, nơi plugin chỉ trả OAuth2 access token). Backend chấp nhận cả hai
  /// (Issue #41).
  Future<AuthTokenDto> loginWithGoogle({
    String? idToken,
    String? accessToken,
  }) async {
    final json = await _client.post(
      '/api/v1/auth/google',
      body: {
        'idToken': ?idToken,
        'accessToken': ?accessToken,
      },
    );
    return AuthTokenDto.fromJson(json);
  }

  Future<AuthTokenDto> refresh(String refreshToken) async {
    final json = await _client.post(
      '/api/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthTokenDto.fromJson(json);
  }

  /// Logout idempotent — 204. Lỗi mạng vẫn ném ra để caller quyết định.
  Future<void> logout(String refreshToken) async {
    await _client.post(
      '/api/v1/auth/logout',
      body: {'refreshToken': refreshToken},
    );
  }

  Future<UserProfileDto> me() async {
    final json = await _client.get('/api/v1/users/me');
    return UserProfileDto.fromJson(json);
  }
}
