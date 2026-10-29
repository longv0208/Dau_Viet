import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Abstraction over google_sign_in so widget tests can substitute a fake —
/// the real plugin touches platform channels unavailable in tests.
abstract class GoogleSignInGateway {
  /// Interactive sign-in; returns the Google idToken or null when the user
  /// cancels. Throws on platform/config errors.
  Future<String?> signInForIdToken();

  /// Best-effort sign-out so a later attempt can pick a different account.
  Future<void> signOut();
}

class GoogleSignInGatewayImpl implements GoogleSignInGateway {
  // serverClientId truyền qua --dart-define=GOOGLE_SERVER_CLIENT_ID; khi
  // rỗng plugin vẫn trả idToken với aud = Android/iOS OAuth client mặc định
  // (được whitelist trong GOOGLE_CLIENT_IDS phía backend).
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const ['email', 'openid', 'profile'],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );

  @override
  Future<String?> signInForIdToken() async {
    final account = await _signIn.signIn();
    if (account == null) return null; // user cancelled
    final auth = await account.authentication;
    return auth.idToken;
  }

  @override
  Future<void> signOut() => _signIn.signOut();
}

final googleSignInGatewayProvider = Provider<GoogleSignInGateway>(
  (ref) => GoogleSignInGatewayImpl(),
);
