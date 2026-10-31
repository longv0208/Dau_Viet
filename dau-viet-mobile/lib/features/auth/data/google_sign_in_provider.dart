import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'google_sign_in_provider_stub.dart'
    if (dart.library.js_interop) 'package:google_sign_in_web/google_sign_in_web.dart';
import 'google_sign_in_provider_stub.dart'
    if (dart.library.js_interop) 'package:google_sign_in_web/web_only.dart'
    as web_only;

/// Bộ thông tin đăng nhập Google trả về từ plugin.
/// - Android/iOS: [idToken] là JWT ký bởi Google (aud = OAuth client app).
/// - Flutter Web (GIS `renderButton`): [idToken] từ CredentialResponse;
///   `accessToken` được gọi lazy qua `getTokens()` khi backend cần.
typedef GoogleSignInCredentials = ({String? idToken, String? accessToken});

/// Abstraction over google_sign_in so widget tests can substitute a fake —
/// the real plugin touches platform channels unavailable in tests.
abstract class GoogleSignInGateway {
  /// Interactive sign-in for platforms that drive the flow themselves
  /// (Android/iOS native sheet). On web this throws [UnsupportedError] —
  /// web sign-in is driven by [buildSignInButton] + [credentialsStream].
  /// Returns credentials or null when the user cancels.
  Future<GoogleSignInCredentials?> signIn();

  /// Stream of credentials emitted by the web GIS button flow. On
  /// non-web platforms this is an empty stream — mobile sign-in uses
  /// [signIn] only.
  Stream<GoogleSignInCredentials> get credentialsStream;

  /// Widget that renders the platform's sign-in UI. Web returns the GIS
  /// `renderButton` widget; mobile returns null so the caller keeps its
  /// styled `OutlinedButton`. Pass [onError] to surface plugin init issues.
  Widget? buildSignInButton({void Function(Object error)? onError});

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

// ---------------------------------------------------------------------------
// Mobile (Android/iOS) implementation — wraps the cross-platform GoogleSignIn
// façade. Web is handled by [_WebGateway] below.
// ---------------------------------------------------------------------------

class GoogleSignInGatewayImpl implements GoogleSignInGateway {
  // Android/iOS: serverClientId (Web client id của backend) truyền qua
  // --dart-define=GOOGLE_SERVER_CLIENT_ID để idToken có aud đúng.
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  late final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const ['email', 'openid', 'profile'],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );

  @override
  Stream<GoogleSignInCredentials> get credentialsStream =>
      const Stream<GoogleSignInCredentials>.empty();

  @override
  Widget? buildSignInButton({void Function(Object error)? onError}) =>
      null;

  @override
  Future<GoogleSignInCredentials?> signIn() async {
    final account = await _signIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return (idToken: auth.idToken, accessToken: auth.accessToken);
  }

  @override
  Future<void> signOut() => _signIn.signOut();
}

// ---------------------------------------------------------------------------
// Web implementation — drives google_sign_in_web's GIS SDK directly so we
// can use renderButton + signInSilently and skip the deprecated
// `signIn()` (which forces a People API call to synthesize user profile).
// ---------------------------------------------------------------------------

class _WebGateway implements GoogleSignInGateway {
  // Web OAuth client id — truyền qua --dart-define=GOOGLE_WEB_CLIENT_ID
  // (fallback GOOGLE_CLIENT_ID) hoặc thẻ <meta name="google-signin-client_id">
  // trong web/index.html. Phải khớp whitelist dauviet.auth.google.client-ids.
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _genericClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get _effectiveClientId =>
      _webClientId.isNotEmpty ? _webClientId : _genericClientId;

  // Dùng instance do `registerWith` tạo (đã load SDK + đăng ký view factory)
  // — KHÔNG `GoogleSignInPlugin()` mới vì constructor đó chạy lại loader và
  // completer chia sẻ gây "Future already completed".
  GoogleSignInPlugin get _plugin =>
      GoogleSignInPlatform.instance as GoogleSignInPlugin;

  final _initCompleter = Completer<void>();
  Object? _initError;
  final _credentialsController =
      StreamController<GoogleSignInCredentials>.broadcast();
  // Kept for the lifetime of the gateway — cancel() is only reachable on
  // signOut, but the subscription must outlive it for the next sign-in.
  // ignore: unused_field
  StreamSubscription<GoogleSignInUserData?>? _userDataSub;

  _WebGateway() {
    unawaited(_init());
  }
  Future<void> _init() async {
    try {
      await _plugin.initWithParams(SignInInitParameters(
        clientId: _effectiveClientId.isEmpty ? null : _effectiveClientId,
        scopes: const ['email', 'openid', 'profile'],
      ));
      _userDataSub = _plugin.userDataEvents?.listen(
        _onUserData,
        onError: (_) {},
      );
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      // Silent re-auth for returning users — OneTap/FedCM prompt. Run after
      // init completes so a hanging prompt can't block the button render.
      try {
        unawaited(_plugin.signInSilently().catchError((_) => null));
      } catch (_) {}
    } catch (e) {
      _initError = e;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void _onUserData(GoogleSignInUserData? user) {
    if (user == null) return;
    // CredentialResponse carries idToken — accessToken stays lazy via
    // getTokens() to avoid forcing a People API call for the profile.
    unawaited(_emitCredentials(user));
  }

  Future<void> _emitCredentials(GoogleSignInUserData user) async {
    try {
      final tokens = await _plugin.getTokens(email: user.email);
      _credentialsController.add((
        idToken: tokens.idToken ?? user.idToken,
        accessToken: tokens.accessToken,
      ));
    } catch (_) {
      // Backend accepts idToken alone — emit what we have rather than fail.
      _credentialsController
          .add((idToken: user.idToken, accessToken: null));
    }
  }

  @override
  Stream<GoogleSignInCredentials> get credentialsStream =>
      _credentialsController.stream;

  @override
  Widget? buildSignInButton({void Function(Object error)? onError}) {
    return FutureBuilder<void>(
      future: _initCompleter.future,
      builder: (context, snap) {
        if (snap.hasError || _initError != null) {
          final err = snap.error ?? _initError ?? 'unknown';
          if (onError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onError(err);
            });
          }
          return const SizedBox.shrink();
        }
        // Future<void> completes with null → hasData stays false even when
        // done. Gate on connectionState instead.
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 50,
            child: Center(child: Text('Đang tải Google…')),
          );
        }
        // renderButton qua facade web_only — đảm bảo instance là singleton
        // do registerWith tạo, đã đăng ký 'gsi_login_button' view factory.
        try {
          return SizedBox(
            height: 50,
            child: web_only.renderButton(),
          );
        } catch (e) {
          if (onError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onError(e);
            });
          }
          return const SizedBox.shrink();
        }
      },
    );
  }

  @override
  Future<GoogleSignInCredentials?> signIn() async {
    // Web sign-in is driven by the GIS button → credentialsStream.
    // A programmatic popup here would re-enter the deprecated People-API
    // path, so refuse loudly instead of silently doing the wrong thing.
    throw UnsupportedError(
        'On web, use buildSignInButton() + credentialsStream.');
  }

  @override
  Future<void> signOut() async {
    try {
      await _plugin.signOut();
    } catch (_) {}
    // Subscription stays live for the next sign-in; the gateway has no
    // dispose hook because it lives for the app's lifetime.
  }
}

final googleSignInGatewayProvider = Provider<GoogleSignInGateway>(
  (ref) => kIsWeb ? _WebGateway() : GoogleSignInGatewayImpl(),
);
