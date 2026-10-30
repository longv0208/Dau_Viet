import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Bộ thông tin đăng nhập Google trả về từ plugin.
/// - Android/iOS: [idToken] là JWT ký bởi Google (aud = OAuth client app).
/// - Flutter Web: plugin dùng OAuth2 Token Client → thường chỉ có
///   [accessToken]; [idToken] null. Backend /auth/google chấp nhận cả hai.
typedef GoogleSignInCredentials = ({String? idToken, String? accessToken});

/// Abstraction over google_sign_in so widget tests can substitute a fake —
/// the real plugin touches platform channels unavailable in tests.
abstract class GoogleSignInGateway {
  /// Interactive sign-in; returns credentials or null when the user cancels.
  /// Throws [GoogleSignInNotConfiguredException] khi thiếu client id, các
  /// lỗi platform khác ném nguyên trạng để UI map thông báo cụ thể.
  Future<GoogleSignInCredentials?> signIn();

  /// Best-effort sign-out so a later attempt can pick a different account.
  Future<void> signOut();
}

/// Ném khi Google OAuth client id chưa được cấu hình cho platform hiện tại —
/// UI hiển thị thông báo rõ ràng thay vì lỗi chung "Không kết nối được...".
class GoogleSignInNotConfiguredException implements Exception {
  final String message;
  const GoogleSignInNotConfiguredException(this.message);
  @override
  String toString() => message;
}

class GoogleSignInGatewayImpl implements GoogleSignInGateway {
  // Android/iOS: serverClientId (Web client id của backend) truyền qua
  // --dart-define=GOOGLE_SERVER_CLIENT_ID để idToken có aud đúng.
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  // Flutter Web: google_sign_in_web KHÔNG hỗ trợ serverClientId (plugin ném
  // AssertionError). Bắt buộc clientId của Web OAuth client — truyền qua
  // --dart-define=GOOGLE_WEB_CLIENT_ID (fallback GOOGLE_CLIENT_ID) hoặc thẻ
  // <meta name="google-signin-client_id"> trong web/index.html.
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _genericClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get _effectiveWebClientId =>
      _webClientId.isNotEmpty ? _webClientId : _genericClientId;

  late final GoogleSignIn _signIn = _build();

  static GoogleSignIn _build() {
    if (kIsWeb) {
      // Trên web: chỉ clientId — KHÔNG truyền serverClientId (AssertionError).
      // null → plugin đọc <meta name="google-signin-client_id"> từ index.html.
      return GoogleSignIn(
        scopes: const ['email', 'openid', 'profile'],
        clientId:
            _effectiveWebClientId.isEmpty ? null : _effectiveWebClientId,
      );
    }
    return GoogleSignIn(
      scopes: const ['email', 'openid', 'profile'],
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
  }

  @override
  Future<GoogleSignInCredentials?> signIn() async {
    if (kIsWeb && _effectiveWebClientId.isEmpty) {
      // Nhanh tay báo rõ thay vì để plugin ném lỗi khó hiểu — meta tag có
      // thể vẫn cứu được, nhưng thiếu cả hai nguồn cấu hình thì fail-fast.
      // Vẫn thử signIn() vì meta tag trong index.html có thể đã được set:
      // chỉ throw khi plugin không trả account được — xử lý bên dưới.
    }
    final GoogleSignInAccount? account;
    try {
      account = await _signIn.signIn();
    } catch (e) {
      if (kIsWeb && _effectiveWebClientId.isEmpty) {
        throw const GoogleSignInNotConfiguredException(
          'Google Sign-In chưa được cấu hình cho web '
          '(thiếu GOOGLE_WEB_CLIENT_ID / meta google-signin-client_id).',
        );
      }
      rethrow;
    }
    if (account == null) return null; // user cancelled
    final auth = await account.authentication;
    return (idToken: auth.idToken, accessToken: auth.accessToken);
  }

  @override
  Future<void> signOut() => _signIn.signOut();
}

final googleSignInGatewayProvider = Provider<GoogleSignInGateway>(
  (ref) => GoogleSignInGatewayImpl(),
);
