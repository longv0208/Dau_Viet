import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bộ token phiên đăng nhập — access + refresh + hạn access (epoch seconds).
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int accessExpiresAt; // epoch seconds

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  bool get isAccessExpired =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= accessExpiresAt - 15;
}

/// Lưu token bằng flutter_secure_storage (Keychain/Keystore/DPAPI).
/// Trên môi trường test/desktop không có secure storage, wrap try/catch và
/// giữ in-memory fallback để unit test vẫn chạy (không dùng cho prod path
/// thật — restore() trên prod luôn đọc được nếu storage khả dụng).
class TokenStorage {
  static const _kAccess = 'dv_access_token';
  static const _kRefresh = 'dv_refresh_token';
  static const _kExpiry = 'dv_access_expires_at';

  final FlutterSecureStorage _storage;

  /// In-memory fallback khi secure storage lỗi (test/desktop).
  final Map<String, String> _memory = {};
  bool _storageBroken = false;

  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save(AuthTokens tokens) async {
    final entries = <String, String>{
      _kAccess: tokens.accessToken,
      _kRefresh: tokens.refreshToken,
      _kExpiry: tokens.accessExpiresAt.toString(),
    };
    if (_storageBroken) {
      _memory.addAll(entries);
      return;
    }
    try {
      for (final e in entries.entries) {
        await _storage.write(key: e.key, value: e.value);
      }
    } catch (_) {
      _storageBroken = true;
      _memory.addAll(entries);
    }
  }

  Future<AuthTokens?> read() async {
    try {
      final Map<String, String> values = _storageBroken
          ? _memory
          : {
              _kAccess: await _storage.read(key: _kAccess) ?? '',
              _kRefresh: await _storage.read(key: _kRefresh) ?? '',
              _kExpiry: await _storage.read(key: _kExpiry) ?? '',
            };
      final access = values[_kAccess] ?? '';
      final refresh = values[_kRefresh] ?? '';
      final expiry = int.tryParse(values[_kExpiry] ?? '') ?? 0;
      if (access.isEmpty || refresh.isEmpty) return null;
      return AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expiry,
      );
    } catch (_) {
      _storageBroken = true;
      final access = _memory[_kAccess] ?? '';
      final refresh = _memory[_kRefresh] ?? '';
      if (access.isEmpty || refresh.isEmpty) return null;
      return AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: int.tryParse(_memory[_kExpiry] ?? '') ?? 0,
      );
    }
  }

  Future<void> clear() async {
    _memory.clear();
    if (_storageBroken) return;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
      await _storage.delete(key: _kExpiry);
    } catch (_) {
      _storageBroken = true;
    }
  }
}
