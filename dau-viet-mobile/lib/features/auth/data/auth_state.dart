import 'auth_api_client.dart';

/// Trạng thái phiên đăng nhập của app.
/// - [AuthStatus.unknown]: đang khôi phục phiên lúc mở app (splash chờ).
/// - [AuthStatus.guest]: chế độ khách — chỉ hợp lệ khi USE_MOCK=true.
/// - [AuthStatus.authenticated]: đã login backend thật.
/// - [AuthStatus.unauthenticated]: chưa đăng nhập.
enum AuthStatus { unknown, guest, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserProfileDto? profile;

  const AuthState._(this.status, this.profile);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.guest() : this._(AuthStatus.guest, null);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);
  const AuthState.authenticated(UserProfileDto profile)
    : this._(AuthStatus.authenticated, profile);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
