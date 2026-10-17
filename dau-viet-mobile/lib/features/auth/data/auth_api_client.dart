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

/// Hồ sơ người dùng hiện tại — GET /api/v1/users/me.
class UserProfileDto {
  final String id;
  final String email;
  final String? displayName;
  final String role;

  const UserProfileDto({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String?,
    role: json['role'] as String? ?? 'LEARNER',
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

  Future<UserProfileDto> register({
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
    return UserProfileDto.fromJson(json);
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
