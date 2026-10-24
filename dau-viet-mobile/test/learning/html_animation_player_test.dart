import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dau_viet_mobile/core/api/api_client.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_api_client.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/html_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_manifest_dto.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/read_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HTML_WEBVIEW runtime — cùng MỘT runtime phục vụ nhiều file HTML khác
/// nhau (không code riêng per-file). Test: fetch → sha256 verify →
/// loadHtmlString (qua webViewBuilder seam), error/retry, và
/// ReadRenderer dispatch đúng nhánh HTML.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const htmlA =
      '<!doctype html><html><body><canvas id="a"></canvas></body></html>';
  const htmlB =
      '<!doctype html><html><body><svg id="b"></svg></body></html>';

  String sha256Of(String html) => sha256.convert(utf8.encode(html)).toString();

  LearningApiClient fakeApi(List<int> bytes) => _FakeLearningApiClient(bytes);

  AnimationManifestDto htmlManifest(String sha) =>
      AnimationManifestDto.fromJson({
        'schemaVersion': 2,
        'rendererCode': 'HTML_WEBVIEW',
        'rendererVersion': 1,
        'title': 'test',
        'disclaimer': 't',
        'html': {'sizeBytes': 100, 'sha256': sha},
      });

  Widget app(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('HtmlAnimationPlayer', () {
    testWidgets('hai file HTML khác nhau dùng CHUNG một runtime — '
        'cùng widget, khác nội dung, cả hai load thành công',
        (tester) async {
      for (final html in [htmlA, htmlB]) {
        await tester.pumpWidget(app(HtmlAnimationPlayer(
          sceneVersionId: 'v-${html.hashCode}',
          manifest: htmlManifest(sha256Of(html)),
          apiOverride: fakeApi(utf8.encode(html)),
          webViewBuilder: (context, controller) =>
              const SizedBox(key: Key('fake-webview')),
        )));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake-webview')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('sha256 mismatch → error pane, không mount webview',
        (tester) async {
      await tester.pumpWidget(app(HtmlAnimationPlayer(
        sceneVersionId: 'v1',
        manifest: htmlManifest('0' * 64), // sai checksum cố ý
        apiOverride: fakeApi(utf8.encode(htmlA)),
        webViewBuilder: (context, controller) =>
            const SizedBox(key: Key('fake-webview')),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsNothing);
      expect(find.textContaining('không khớp'), findsOneWidget);
    });

    testWidgets('fetch rỗng → error + nút Thử lại', (tester) async {
      await tester.pumpWidget(app(HtmlAnimationPlayer(
        sceneVersionId: 'v1',
        manifest: htmlManifest(sha256Of(htmlA)),
        apiOverride: fakeApi(const []),
        webViewBuilder: (context, controller) =>
            const SizedBox(key: Key('fake-webview')),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('ReadRenderer HTML dispatch', () {
    testWidgets('config.animationManifest rendererCode=HTML_WEBVIEW → '
        'slot HTML mount và truyền đúng sceneVersionId từ envelope',
        (tester) async {
      String? capturedVersionId;
      final act = ActivityRefDto(
        id: 'a1',
        config: {
          'title': 'Bài đọc',
          'body': 'Nội dung.',
          'animationManifest': {
            'manifest': {
              'schemaVersion': 2,
              'rendererCode': 'HTML_WEBVIEW',
              'rendererVersion': 1,
              'title': 'Bạch Đằng HTML',
              'disclaimer': 'test',
              'html': {
                'filename': 'bd.html',
                'sizeBytes': htmlA.length,
                'sha256': sha256Of(htmlA),
              },
            },
            'sceneVersionId': 'ver-1',
            'versionNo': 3,
            'rendererCode': 'HTML_WEBVIEW',
            'rendererVersion': 1,
          },
        },
        feedback: const {},
      );
      await tester.pumpWidget(app(ReadRenderer(
        activity: act,
        submitting: false,
        onSubmit: (_) async {},
        htmlPlayerFactory: (versionId, manifest) {
          capturedVersionId = versionId;
          return SizedBox(key: const Key('slot-player'), child: Text(versionId));
        },
      )));
      await tester.pump();
      expect(find.byKey(const Key('slot-player')), findsOneWidget);
      expect(capturedVersionId, 'ver-1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('HtmlAnimationPlayer tự fetch qua learningApiClientProvider '
        'khi không có apiOverride (provider override)', (tester) async {
      // Provider override để fetch trả bytes thật — path production của
      // _HtmlSceneSlot: HtmlAnimationPlayer không apiOverride sẽ read
      // learningApiClientProvider từ ref.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          learningApiClientProvider
              .overrideWithValue(fakeApi(utf8.encode(htmlA))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlAnimationPlayer(
                sceneVersionId: 'ver-9',
                manifest: htmlManifest(sha256Of(htmlA)),
                webViewBuilder: (context, controller) =>
                    const SizedBox(key: Key('fake-webview')),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HTML manifest thiếu sceneVersionId → notice an toàn',
        (tester) async {
      final act = ActivityRefDto(
        id: 'a2',
        config: {
          'body': 'Bài đọc.',
          'animationManifest': {
            'manifest': {
              'schemaVersion': 2,
              'rendererCode': 'HTML_WEBVIEW',
              'rendererVersion': 1,
              'title': 'Lỗi pin',
              'disclaimer': 't',
              'html': {'sizeBytes': 10, 'sha256': sha256Of(htmlA)},
            },
            // THIẾU sceneVersionId — snapshot hỏng.
          },
        },
        feedback: const {},
      );
      await tester.pumpWidget(app(ReadRenderer(
        activity: act,
        submitting: false,
        onSubmit: (_) async {},
      )));
      await tester.pump();
      expect(find.byType(HtmlAnimationPlayer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Client giả: trả bytes cấu hình sẵn cho endpoint html; constructor
/// super cần ApiClient bất kỳ nhưng method đích đã override.
class _FakeLearningApiClient extends LearningApiClient {
  final List<int> _bytes;
  _FakeLearningApiClient(this._bytes)
      : super(ApiClient.fromConfig(baseUrl: 'http://test'));

  @override
  Future<List<int>> getAnimationHtmlBytes(String versionId) async => _bytes;
}
