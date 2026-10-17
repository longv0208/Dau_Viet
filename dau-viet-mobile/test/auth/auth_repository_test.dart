import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/core/auth/token_storage.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake AuthApiClient — điều khiển response từng endpoint, ghi call log.
/// Không đụng Dio/platform channel.
class _FakeAuthApiClient implements AuthApiClient {
  Object? loginError;
  Object? meError;
  Object? refreshError;
  Object? logoutError;

  AuthTokenDto loginResponse = const AuthTokenDto(
    accessToken: 'a1',
    tokenType: 'Bearer',
    expiresIn: 900,
    refreshToken: 'r1',
    refreshExpiresIn: 86400,
  );
  AuthTokenDto refreshResponse = const AuthTokenDto(
    accessToken: 'a2',
    tokenType: 'Bearer',
    expiresIn: 900,
    refreshToken: 'r2',
    refreshExpiresIn: 86400,
  );
  UserProfileDto profile = const UserProfileDto(
    id: 'u1',
    email: 'si.tu@dauviet.vn',
    role: 'LEARNER',
  );

  int loginCalls = 0;
  int meCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthTokenDto> login(String email, String password) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return loginResponse;
  }

  @override
  Future<UserProfileDto> register({
    required String email,
    required String password,
    String? displayName,
  }) async => profile;

  @override
  Future<AuthTokenDto> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshResponse;
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls++;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<UserProfileDto> me() async {
    meCalls++;
    if (meError != null) throw meError!;
    return profile;
  }
}

/// TokenStorage in-memory — không chạm flutter_secure_storage.
class _InMemoryTokenStorage extends TokenStorage {
  _InMemoryTokenStorage() : super(null);

  AuthTokens? saved;
  int clearCalls = 0;

  @override
  Future<void> save(AuthTokens tokens) async {
    saved = tokens;
  }

  @override
  Future<AuthTokens?> read() async => saved;

  @override
  Future<void> clear() async {
    clearCalls++;
    saved = null;
  }
}

ApiException _api401() => const ApiException(
  ApiError(code: 'UNAUTHORIZED', message: 'expired'),
  statusCode: 401,
);

void main() {
  late _FakeAuthApiClient api;
  late _InMemoryTokenStorage storage;
  late AuthRepository repo;

  setUp(() {
    api = _FakeAuthApiClient();
    storage = _InMemoryTokenStorage();
    repo = AuthRepository(api, storage);
  });

  group('login', () {
    test(
      'login thành công → lưu token + fetch profile → authenticated',
      () async {
        final state = await repo.login('si.tu@dauviet.vn', 'mat-khau');
        expect(state.status, AuthStatus.authenticated);
        expect(state.profile!.email, 'si.tu@dauviet.vn');
        expect(api.loginCalls, 1);
        expect(api.meCalls, 1);
        // Token đã lưu storage.
        expect(storage.saved, isNotNull);
        expect(storage.saved!.refreshToken, 'r1');
        expect(repo.hasValidAccessToken, isTrue);
      },
    );

    test(
      'login ok nhưng /me lỗi → vẫn unauthenticated (không crash)',
      () async {
        api.meError = Exception('down');
        final state = await repo.login('a@b.c', 'x');
        expect(state.status, AuthStatus.unauthenticated);
      },
    );

    test('login 401 → ném ApiException, không lưu token', () async {
      api.loginError = _api401();
      await expectLater(
        repo.login('a@b.c', 'sai'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.saved, isNull);
    });
  });

  group('restore', () {
    test('storage trống → unauthenticated', () async {
      final state = await repo.restore();
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('token còn hạn → /me → authenticated, không refresh', () async {
      storage.saved = AuthTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
        accessExpiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      );
      final state = await repo.restore();
      expect(state.status, AuthStatus.authenticated);
      expect(api.refreshCalls, 0);
      expect(api.meCalls, 1);
    });

    test('access hết hạn → refresh rồi /me → authenticated', () async {
      storage.saved = AuthTokens(
        accessToken: 'a-old',
        refreshToken: 'r-old',
        accessExpiresAt: 1, // hết hạn từ lâu
      );
      final state = await repo.restore();
      expect(state.status, AuthStatus.authenticated);
      expect(api.refreshCalls, 1);
      // Token mới đã lưu.
      expect(storage.saved!.accessToken, 'a2');
    });

    test('refresh 401 → clear session → unauthenticated', () async {
      storage.saved = AuthTokens(
        accessToken: 'a-old',
        refreshToken: 'r-revoked',
        accessExpiresAt: 1,
      );
      api.refreshError = _api401();
      final state = await repo.restore();
      expect(state.status, AuthStatus.unauthenticated);
      expect(storage.saved, isNull);
      expect(storage.clearCalls, greaterThan(0));
    });

    test('/me 401 sau restore → unauthenticated + clear', () async {
      storage.saved = AuthTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
        accessExpiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      );
      api.meError = _api401();
      final state = await repo.restore();
      expect(state.status, AuthStatus.unauthenticated);
      expect(storage.saved, isNull);
    });
  });

  group('withAuth — refresh-on-401', () {
    test('call 401 → refresh → retry call → trả kết quả', () async {
      await repo.login('a@b.c', 'x'); // có tokens
      var attempts = 0;
      final result = await repo.withAuth(() async {
        attempts++;
        if (attempts == 1) throw _api401();
        return 'data-ok';
      });
      expect(result, 'data-ok');
      expect(attempts, 2);
      expect(api.refreshCalls, 1);
    });

    test('call 401 + refresh fail → ném lại lỗi gốc + clear session', () async {
      await repo.login('a@b.c', 'x');
      api.refreshError = _api401();
      await expectLater(
        repo.withAuth(() async => throw _api401()),
        throwsA(isA<ApiException>()),
      );
      expect(storage.saved, isNull);
    });

    test('lỗi KHÔNG phải 401 → không refresh, ném thẳng', () async {
      await repo.login('a@b.c', 'x');
      await expectLater(
        repo.withAuth(
          () async => throw const ApiException(
            ApiError(code: 'SERVER_ERROR', message: 'down'),
            statusCode: 500,
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(api.refreshCalls, 0);
    });
  });

  group('logout', () {
    test('logout gọi API + clear session', () async {
      await repo.login('a@b.c', 'x');
      await repo.logout();
      expect(api.logoutCalls, 1);
      expect(storage.saved, isNull);
    });

    test('logout khi API lỗi vẫn clear local (idempotent)', () async {
      await repo.login('a@b.c', 'x');
      api.logoutError = Exception('network');
      await repo.logout();
      expect(storage.saved, isNull);
    });
  });
}
