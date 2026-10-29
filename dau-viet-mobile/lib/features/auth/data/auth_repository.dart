import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_storage.dart';
import 'auth_api_client.dart';
import 'auth_state.dart';

/// Quản lý phiên đăng nhập thật với Spring Boot.
/// - login/logout/restore/refresh-on-401.
/// - Refresh được serialize qua 1 Future dùng chung để tránh race khi nhiều
///   request 401 đồng thời.
/// - Refresh reuse/revoked (401) → xóa session local, emit unauthenticated.
class AuthRepository {
  final AuthApiClient _api;
  final TokenStorage _storage;

  AuthTokens? _tokens;
  UserProfileDto? _profile;
  Future<AuthTokens?>? _refreshInFlight;

  AuthRepository(this._api, this._storage) {
    // ApiClient đọc token qua static hook — mỗi request tự lấy token mới nhất.
    ApiClient.authTokenProvider = () => _tokens?.accessToken;
  }

  UserProfileDto? get profile => _profile;
  bool get hasValidAccessToken => _tokens != null && !_tokens!.isAccessExpired;

  /// Gọi một API call đã authed; nếu 401 thử refresh 1 lần rồi retry.
  /// Refresh fail → clear session và ném lại lỗi.
  Future<T> withAuth<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (!e.isUnauthorized || _tokens == null) rethrow;
      final refreshed = await refresh();
      if (refreshed == null) rethrow;
      return call();
    }
  }

  /// Issue #34 — đăng ký bước 1: tạo REGISTER_VERIFY challenge + gửi OTP.
  /// Chưa có user/session cho tới khi verifyRegisterOtp thành công.
  Future<OtpChallengeDto> requestRegisterOtp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _api.requestRegisterOtp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  /// Đăng ký bước 2: verify OTP → backend tạo user → lưu token + /users/me.
  Future<AuthState> verifyRegisterOtp({
    required String email,
    required String otpCode,
  }) async {
    final AuthTokenDto dto =
        await _api.verifyRegisterOtp(email: email, otpCode: otpCode);
    await _storeTokens(dto);
    return _loadProfileAfterLogin();
  }

  /// Gửi lại OTP (REGISTER_VERIFY | PASSWORD_RESET).
  Future<OtpChallengeDto> resendOtp({
    required String email,
    required String purpose,
  }) {
    return _api.resendOtp(email: email, purpose: purpose);
  }

  /// Forgot kickoff — server luôn 200.
  Future<void> forgotPassword({required String email}) {
    return _api.forgotPassword(email: email);
  }

  /// Reset mật khẩu qua OTP; server revoke toàn bộ refresh token cũ.
  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) {
    return _api.resetPassword(
      email: email,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  /// Google Sign-In: idToken đã lấy từ google_sign_in SDK.
  Future<AuthState> loginWithGoogle({required String idToken}) async {
    final AuthTokenDto dto = await _api.loginWithGoogle(idToken: idToken);
    await _storeTokens(dto);
    return _loadProfileAfterLogin();
  }

  Future<AuthState> login(String email, String password) async {
    final AuthTokenDto dto = await _api.login(email, password);
    await _storeTokens(dto);
    return _loadProfileAfterLogin();
  }

  Future<AuthState> _loadProfileAfterLogin() async {
    try {
      _profile = await _api.me();
    } catch (_) {
      _profile = null; // token ok nhưng /me lỗi — vẫn cho vào, profile sau.
    }
    return _profile == null
        ? const AuthState.unauthenticated()
        : AuthState.authenticated(_profile!);
  }

  /// Khôi phục phiên khi mở app: đọc storage → refresh nếu access hết hạn →
  /// /users/me. Storage trống hoặc refresh fail → unauthenticated.
  Future<AuthState> restore() async {
    final saved = await _storage.read();
    if (saved == null) {
      _tokens = null;
      return const AuthState.unauthenticated();
    }
    _tokens = saved;
    if (saved.isAccessExpired) {
      final refreshed = await refresh();
      if (refreshed == null) return const AuthState.unauthenticated();
    }
    try {
      _profile = await _api.me();
      return AuthState.authenticated(_profile!);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await clearSession();
        return const AuthState.unauthenticated();
      }
      // Mất mạng khi restore: giữ phiên "đã login nhưng chưa có profile" —
      // app vẫn cho vào, call sau sẽ retry/refresh.
      return AuthState.authenticated(
        const UserProfileDto(id: '', email: '', role: 'LEARNER'),
      );
    }
  }

  /// Refresh access token; serialize để không gọi song song.
  /// Trả null nếu refresh thất bại (reuse/revoked/expired) — session cleared.
  Future<AuthTokens?> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final Future<AuthTokens?> task = _doRefresh();
    _refreshInFlight = task;
    return task.whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthTokens?> _doRefresh() async {
    final current = _tokens;
    if (current == null) return null;
    try {
      final AuthTokenDto dto = await _api.refresh(current.refreshToken);
      await _storeTokens(dto);
      return _tokens;
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isForbidden) {
        await clearSession();
        return null;
      }
      rethrow; // lỗi mạng — giữ session, caller tự retry
    }
  }

  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // Logout best-effort — token hết hạn/mất mạng vẫn clear local.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _tokens = null;
    _profile = null;
    await _storage.clear();
  }

  Future<void> _storeTokens(AuthTokenDto dto) async {
    final int expiry =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + dto.expiresIn;
    _tokens = AuthTokens(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken,
      accessExpiresAt: expiry,
    );
    await _storage.save(_tokens!);
  }
}
