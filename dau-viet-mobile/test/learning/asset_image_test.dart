import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/learning_asset_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_attempt_repository.dart';

// PNG trong suốt 1x1 hợp lệ.
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
  Widget buildApp(FakeAttemptRepository repo, {String? alt}) {
    return ProviderScope(
      overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: LearningAssetImage(assetId: 'asset-1', altText: alt),
        ),
      ),
    );
  }

  group('LearningAssetImage', () {
    testWidgets('bytes hợp lệ → render Image.memory', (tester) async {
      final repo = _AssetRepo()..bytes = _pngBytes;
      await tester.pumpWidget(buildApp(repo));
      await tester.pump(); // FutureBuilder resolve.
      await tester.pump(); // decode frame.

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
    });

    testWidgets('404 → fallback alt-text, không crash', (tester) async {
      final repo = _AssetRepo()
        ..error = const ApiException(
          ApiError(code: 'ASSET_NOT_FOUND', message: 'không có'),
          statusCode: 404,
        );
      await tester.pumpWidget(
        buildApp(repo, alt: 'Tranh khắc gỗ bãi cọc Bạch Đằng'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tranh khắc gỗ bãi cọc Bạch Đằng'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('bytes rỗng → fallback mặc định', (tester) async {
      final repo = _AssetRepo()..bytes = const <int>[];
      await tester.pumpWidget(buildApp(repo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Không tải được hình ảnh.'), findsOneWidget);
    });
  });
}

class _AssetRepo extends FakeAttemptRepository {
  List<int> bytes = const <int>[];
  Object? error;

  @override
  Future<List<int>> getAssetBytes(String assetId) async {
    if (error != null) throw error!;
    return bytes;
  }
}
