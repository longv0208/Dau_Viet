// Stub for non-web platforms — `google_sign_in_web` pulls in `dart:js_interop`
// and `package:web`, neither of which exists on Android/iOS. Any member access
// should be unreachable: the provider checks `kIsWeb` before touching it.
import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class GoogleSignInPlugin {
  Stream<GoogleSignInUserData?>? get userDataEvents =>
      throw UnsupportedError('web only');
  Future<void> initWithParams(SignInInitParameters params) =>
      throw UnsupportedError('web only');
  Future<GoogleSignInUserData?> signInSilently() =>
      throw UnsupportedError('web only');
  Future<GoogleSignInTokenData> getTokens({required String email}) =>
      throw UnsupportedError('web only');
  Future<void> signOut() => throw UnsupportedError('web only');
  Widget renderButton({Object? configuration}) =>
      throw UnsupportedError('web only');
}

// Mirrors `google_sign_in_web/web_only.dart` facade shape.
Widget renderButton({Object? configuration}) =>
    throw UnsupportedError('web only');
