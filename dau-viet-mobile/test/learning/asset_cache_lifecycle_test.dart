import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
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

void main() {
  setUp(clearLearningAssetCacheForTest);

  Widget buildAppWithKey(_AssetRepo repo, Key key) => ProviderScope(
    overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: Scaffold(
        body: LearningAssetImage(key: key, assetId: 'a1'),
      ),
    ),
  );

  testWidgets('fetch lỗi KHÔNG bị cache — lần sau retry được', (tester) async {
    final repo = _AssetRepo()
      ..error = const ApiException(ApiError(code: 'NET', message: 'lost'));
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không tải được hình ảnh.'), findsOneWidget);
    expect(repo.calls, 1);

    // Sửa lỗi mạng → widget mới phải fetch lại thật (cache lỗi đã evict).
    repo
      ..error = null
      ..bytes = _pngBytes;
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w2')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, greaterThan(1));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('đổi session owner → cache cũ bị drop, fetch lại', (
    tester,
  ) async {
    final repo = _AssetRepo()..bytes = _pngBytes;
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w1')));
    await tester.pump();
    await tester.pump();
    final callsAfterFirst = repo.calls;

    // Đổi owner → cache clear → widget mới phải gọi repo lại.
    resetLearningAssetCacheForSession('user-2');
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w2')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, greaterThan(callsAfterFirst));
  });

  testWidgets('giữ nguyên owner → cache dùng lại, không refetch', (
    tester,
  ) async {
    resetLearningAssetCacheForSession('user-1');
    final repo = _AssetRepo()..bytes = _pngBytes;
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w1')));
    await tester.pump();
    await tester.pump();
    final callsAfterFirst = repo.calls;

    // Widget mới cùng session → cache hit, không gọi thêm.
    await tester.pumpWidget(buildAppWithKey(repo, const Key('w2')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, callsAfterFirst);
  });
}

class _AssetRepo extends FakeAttemptRepository {
  List<int> bytes = const <int>[];
  Object? error;
  int calls = 0;

  @override
  Future<List<int>> getAssetBytes(String assetId) async {
    calls++;
    if (error != null) throw error!;
    return bytes;
  }
}
