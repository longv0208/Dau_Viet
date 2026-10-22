import 'dart:async';

import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_api_client.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/learning_asset_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_attempt_repository.dart';

final _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

/// Controller mô phỏng phiên auth — set state trực tiếp (không đi qua
/// AuthRepository thật); đổi profile.id ↔ đổi user đăng nhập.
/// Notifier state chỉ gán được sau build() → initial user truyền qua ctor.
class _FakeSession extends AuthSessionController {
  _FakeSession(this._initialUser);
  final String? _initialUser;

  @override
  AuthState build() => _initialUser == null
      ? const AuthState.unauthenticated()
      : _authed(_initialUser);

  static AuthState _authed(String id) => AuthState.authenticated(
    UserProfileDto(id: id, email: '$id@x.dev', role: 'LEARNER'),
  );

  void setUser(String id) => state = _authed(id);
}

void main() {
  // Cache bytes là module-level — reset mỗi test để không lẫn kết quả.
  setUp(clearLearningAssetCacheForTest);

  // Mỗi ProviderScope mới tạo AuthSessionController mới → cần seed user TRƯỚC
  // khi widget đọc cache (build đầu tiên). Container riêng để set state mà
  // không cần widget.
  ProviderContainer makeContainer(_AssetRepo repo, _FakeSession session) {
    return ProviderContainer(
      overrides: [
        attemptRepositoryProvider.overrideWithValue(repo),
        authSessionProvider.overrideWith(() => session),
      ],
    );
  }

  Widget appFor(ProviderContainer c, {Key? key}) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      home: Scaffold(
        body: LearningAssetImage(key: key, assetId: 'a1'),
      ),
    ),
  );

  testWidgets('fetch lỗi → nút "Thử tải lại" fetch lại thật, ảnh hiện', (
    tester,
  ) async {
    final repo = _AssetRepo()
      ..error = const ApiException(ApiError(code: 'NET', message: 'lost'));
    final c = makeContainer(repo, _FakeSession('user-A'));
    addTearDown(c.dispose);
    await tester.pumpWidget(appFor(c));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tải được hình ảnh.'), findsOneWidget);
    expect(find.text('Thử tải lại'), findsOneWidget);
    expect(repo.calls, 1);

    // Sửa lỗi mạng → bấm retry → fetch mới chạy, ảnh render.
    repo
      ..error = null
      ..bytes = _pngBytes;
    await tester.tap(find.text('Thử tải lại'));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, greaterThan(1));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
    'user A tải ảnh → unmount hết widget → user B login → fetch lại đúng phiên',
    (tester) async {
      final session = _FakeSession('user-A');
      final repo = _AssetRepo()..bytes = _pngBytes;
      final c = makeContainer(repo, session);
      addTearDown(c.dispose);
      await tester.pumpWidget(appFor(c));
      await tester.pump();
      await tester.pump();
      final callsAfterA = repo.calls;

      // Unmount toàn bộ widget ảnh (về dashboard không có ảnh) rồi đổi user.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      session.setUser('user-B');

      // Mount lại cùng assetId — owner mới được sync TRƯỚC cache lookup nên
      // entry của user-A không được dùng lại → fetch mới.
      await tester.pumpWidget(appFor(c));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, greaterThan(callsAfterA));
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('stale in-flight của phiên cũ không phủ cache phiên mới', (
    tester,
  ) async {
    final session = _FakeSession('user-A');
    final repo = _AssetRepo()..hang(); // request đầu treo, resolve bằng tay
    final c = makeContainer(repo, session);
    addTearDown(c.dispose);
    await tester.pumpWidget(appFor(c));
    await tester.pump();
    expect(repo.calls, 1);

    // Đổi phiên trong lúc fetch user-A còn đang bay (không cần unmount —
    // listener + tag đều xử lý). Fetch mới của phiên B được queue.
    session.setUser('user-B');
    await tester.pump();
    await tester.pump();
    expect(repo.calls, 2);

    // Request của phiên A resolve muộn với bytes rác — KHÔNG được ghi đè.
    repo.completer.complete(<int>[1, 2, 3]); // bytes sai của phiên A
    await tester.pump();
    await tester.pump();
    // Phiên B đang chờ fetch thật → vẫn loading/fallback, không phải ảnh A.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('giữ nguyên owner → cache dùng lại, không refetch', (
    tester,
  ) async {
    final session = _FakeSession('user-1');
    final repo = _AssetRepo()..bytes = _pngBytes;
    final c = makeContainer(repo, session);
    addTearDown(c.dispose);
    await tester.pumpWidget(appFor(c, key: const Key('w1')));
    await tester.pump();
    await tester.pump();
    final callsAfterFirst = repo.calls;

    // Widget mới cùng session → cache hit, không gọi thêm.
    await tester.pumpWidget(appFor(c, key: const Key('w2')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, callsAfterFirst);
    expect(find.byType(Image), findsOneWidget);
  });
}

class _AssetRepo extends FakeAttemptRepository {
  List<int> bytes = const <int>[];
  Object? error;
  int calls = 0;

  /// hang() → request đầu tiên treo tới khi complete() — mô phỏng in-flight
  /// kéo dài qua ranh giới phiên. Các request sau resolve theo bytes/error.
  final Completer<List<int>> completer = Completer<List<int>>();
  bool _hangFirst = false;
  void hang() => _hangFirst = true;

  @override
  Future<List<int>> getAssetBytes(String assetId) {
    calls++;
    if (_hangFirst && calls == 1 && !completer.isCompleted) {
      return completer.future;
    }
    return Future.sync(() {
      if (error != null) throw error!;
      return bytes;
    });
  }
}
