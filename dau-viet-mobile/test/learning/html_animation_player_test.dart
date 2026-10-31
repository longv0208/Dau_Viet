import 'dart:async';
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
import 'package:webview_flutter/webview_flutter.dart';

/// HTML_WEBVIEW runtime — cùng MỘT runtime phục vụ nhiều file HTML khác
/// nhau (không code riêng per-file). Test: fetch → sha256 verify →
/// loadHtmlString (qua webViewBuilder seam), error/retry, và
/// ReadRenderer dispatch đúng nhánh HTML.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const htmlA =
      '<!doctype html><html><body><canvas id="a"></canvas></body></html>';
  const htmlB = '<!doctype html><html><body><svg id="b"></svg></body></html>';

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
        'cùng widget, khác nội dung, cả hai load thành công', (tester) async {
      for (final html in [htmlA, htmlB]) {
        await tester.pumpWidget(
          app(
            HtmlAnimationPlayer(
              sceneVersionId: 'v-${html.hashCode}',
              manifest: htmlManifest(sha256Of(html)),
              apiOverride: fakeApi(utf8.encode(html)),
              webViewBuilder: (context, controller) =>
                  const SizedBox(key: Key('fake-webview')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake-webview')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('sha256 mismatch → error pane, không mount webview', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest('0' * 64), // sai checksum cố ý
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsNothing);
      expect(find.textContaining('không khớp'), findsOneWidget);
    });

    testWidgets('fetch rỗng → error + nút Thử lại', (tester) async {
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(const []),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets(
      'didUpdateWidget đổi sceneVersionId → invalidate pending + load lại',
      (tester) async {
        // Giữ fetch đầu pending — response v1 đến sau khi widget đã đổi sang v2
        // phải bị generation guard bỏ qua (không mount webview của v1).
        final completer1 = Completer<List<int>>();
        final api1 = _FakeLearningApiClient.completer(completer1.future);
        await tester.pumpWidget(
          app(
            HtmlAnimationPlayer(
              key: const Key('p'),
              sceneVersionId: 'v1',
              manifest: htmlManifest(sha256Of(htmlA)),
              apiOverride: api1,
              webViewBuilder: (context, controller) =>
                  const SizedBox(key: Key('fake-webview')),
            ),
          ),
        );
        await tester.pump();
        // Đổi sang v2 — request mới chạy ngay, v1 vẫn pending.
        final api2 = _FakeLearningApiClient(utf8.encode(htmlB));
        await tester.pumpWidget(
          app(
            HtmlAnimationPlayer(
              key: const Key('p'),
              sceneVersionId: 'v2',
              manifest: htmlManifest(sha256Of(htmlB)),
              apiOverride: api2,
              webViewBuilder: (context, controller) =>
                  const SizedBox(key: Key('fake-webview')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // v2 load xong trước → ready.
        expect(find.byKey(const Key('fake-webview')), findsOneWidget);
        // Giờ v1 resolve — tag đã cũ, không được ghi đè state.
        completer1.complete(utf8.encode(htmlA));
        await tester.pump();
        expect(find.byKey(const Key('fake-webview')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dispose khi fetch pending → không crash, không setState', (
      tester,
    ) async {
      final completer = Completer<List<int>>();
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: _FakeLearningApiClient.completer(completer.future),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pump();
      // Unmount trước khi resolve.
      await tester.pumpWidget(app(const SizedBox(key: Key('empty'))));
      completer.complete(utf8.encode(htmlA));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate PLAYBACK_FINISHED chỉ fire onFinished một lần', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state =
          tester.state(find.byType(HtmlAnimationPlayer))
              as dynamic; // _HtmlAnimationPlayerState
      // JS gửi FINISHED 3 lần (loop/replay spam) — chỉ 1 callback.
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_FINISHED'),
      );
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_FINISHED'),
      );
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_FINISHED'),
      );
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('invalid JS messages (type lạ, JSON hỏng, oversize) bị drop', (
      tester,
    ) async {
      var finished = 0;
      String? runtimeError;
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
            onFinished: () => finished++,
            onRuntimeError: (m) => runtimeError = m,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      state.handleJsMessageForTest(const JavaScriptMessage(message: 'EXPLOIT'));
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: '{"type":"EXPLOIT"}'),
      );
      state.handleJsMessageForTest(
        const JavaScriptMessage(
          message: '{"type":"PLAYBACK_FINISHED","extra":"x"}',
        ),
      ); // hợp lệ
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: '{broken json'),
      );
      state.handleJsMessageForTest(
        JavaScriptMessage(message: 'x' * 20000),
      ); // oversize
      await tester.pump();
      expect(finished, 1); // chỉ message hợp lệ được nhận
      expect(runtimeError, isNull);
    });

    testWidgets('message từ session cũ (sau khi đổi versionId) bị drop', (
      tester,
    ) async {
      // FIX-03: controller cũ detach; message sót lại của document A đến
      // khi B đang load không được fire callback của phiên B.
      var finished = 0;
      final completerA = Completer<List<int>>();
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            key: const Key('p'),
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: _FakeLearningApiClient.completer(completerA.future),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pump();
      // Đổi sang v2 trong lúc A còn pending.
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            key: const Key('p'),
            sceneVersionId: 'v2',
            manifest: htmlManifest(sha256Of(htmlB)),
            apiOverride: fakeApi(utf8.encode(htmlB)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      // B ready; FINISHED của phiên B (hợp lệ) fire 1 lần.
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_FINISHED'),
      );
      await tester.pump();
      expect(finished, 1);
      // FINISHED thứ hai (idempotent) — không thêm.
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_FINISHED'),
      );
      await tester.pump();
      expect(finished, 1);
      // A resolve trễ — document cũ không được hiển thị/fire thêm.
      completerA.complete(utf8.encode(htmlA));
      await tester.pump();
      expect(finished, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error callback của session CŨ (builtFor cũ) bị drop — '
        'B không bị A làm lỗi', (tester) async {
      // FIX (stale WebView callback): controller cũ bị detach cùng widget,
      // nhưng callback sót lại phải bị builtFor guard loại. Đóng vai
      // callback session cũ bằng builtFor < generation hiện hành.
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            key: const Key('p'),
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      final int staleGen = state.controllerGenerationForTest as int;

      // Đổi sang v2 — generation tăng, v1 callback trở thành stale.
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            key: const Key('p'),
            sceneVersionId: 'v2',
            manifest: htmlManifest(sha256Of(htmlB)),
            apiOverride: fakeApi(utf8.encode(htmlB)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);

      // Error đến trễ mang builtFor của session v1 → bị drop, B không lỗi.
      state.handleWebResourceErrorForTest(
        const WebResourceError(
          errorCode: -1,
          description: 'A failed',
          isForMainFrame: true,
        ),
        staleGen,
      );
      await tester.pump();
      // B vẫn ready — không error pane.
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      expect(find.textContaining('không tải được'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error callback của session HIỆN TẠI hiển thị error đúng', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      final int currentGen = state.controllerGenerationForTest as int;
      state.handleWebResourceErrorForTest(
        const WebResourceError(
          errorCode: -1,
          description: 'fail',
          isForMainFrame: true,
        ),
        currentGen, // đúng session — phải hiển thị error
      );
      await tester.pump();
      expect(find.textContaining('không tải được'), findsOneWidget);
      expect(find.byKey(const Key('fake-webview')), findsNothing);
    });

    testWidgets('error callback đến sau dispose không crash', (tester) async {
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      final int gen = state.controllerGenerationForTest as int;
      // Unmount.
      await tester.pumpWidget(app(const SizedBox(key: Key('empty'))));
      // Callback sót lại sau dispose → bỏ qua, không setState/crash.
      state.handleWebResourceErrorForTest(
        const WebResourceError(
          errorCode: -1,
          description: 'late',
          isForMainFrame: true,
        ),
        gen,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('READY/PLAYBACK_STARTED không fire callback nào', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        app(
          HtmlAnimationPlayer(
            sceneVersionId: 'v1',
            manifest: htmlManifest(sha256Of(htmlA)),
            apiOverride: fakeApi(utf8.encode(htmlA)),
            webViewBuilder: (context, controller) =>
                const SizedBox(key: Key('fake-webview')),
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(HtmlAnimationPlayer)) as dynamic;
      state.handleJsMessageForTest(const JavaScriptMessage(message: 'READY'));
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_STARTED'),
      );
      state.handleJsMessageForTest(
        const JavaScriptMessage(message: 'PLAYBACK_PAUSED'),
      );
      await tester.pump();
      expect(finished, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadRenderer HTML dispatch', () {
    for (final completed in [false, true]) {
      for (final reading in [
        {'body': 'Tư liệu sau hoạt ảnh.'},
        {'passage': 'Đoạn sử liệu cần đọc.'},
        <String, String>{},
      ]) {
        testWidgets('Continue preserves reading before submit: '
            'completed=$completed, keys=${reading.keys}', (tester) async {
          var submissions = 0;
          final immersiveStates = <bool>[];
          ActivityRefDto activity(String id) => ActivityRefDto(
            id: id,
            completed: completed,
            config: {
              ...reading,
              'animationManifest': {
                'manifest': {
                  'schemaVersion': 2,
                  'rendererCode': 'HTML_WEBVIEW',
                  'rendererVersion': 1,
                  'title': 'Test scene',
                  'html': {'sizeBytes': 100, 'sha256': sha256Of(htmlA)},
                },
                'sceneVersionId': 'ver-reading',
              },
            },
            feedback: const {},
          );
          Widget renderer(String id) => app(
            ReadRenderer(
              activity: activity(id),
              submitting: false,
              onSubmit: (_) async {
                submissions++;
              },
              onImmersiveChanged: immersiveStates.add,
              htmlPlayerFactory: (_, _) =>
                  const SizedBox(key: Key('reading-scene')),
            ),
          );
          await tester.pumpWidget(renderer('read-a'));
          await tester.pump();
          expect(find.byKey(const Key('reading-scene')), findsOneWidget);
          await tester.ensureVisible(find.text('Tiếp tục'));
          await tester.tap(find.text('Tiếp tục'));
          await tester.pumpAndSettle();
          expect(submissions, 0);
          expect(find.byKey(const Key('reading-scene')), findsNothing);
          expect(find.byType(Image), findsWidgets);
          for (final text in reading.values) {
            expect(find.text(text, findRichText: true), findsOneWidget);
          }
          expect(immersiveStates, [true, false]);
          await tester.ensureVisible(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
          await tester.tap(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
          await tester.pump();
          expect(submissions, 1);

          // Reusing the state for another activity must restore the scene.
          await tester.pumpWidget(renderer('read-b'));
          await tester.pump();
          expect(find.byKey(const Key('reading-scene')), findsOneWidget);
          expect(immersiveStates.last, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('config.animationManifest rendererCode=HTML_WEBVIEW → '
        'slot HTML mount và truyền đúng sceneVersionId từ envelope', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        app(
          ReadRenderer(
            activity: act,
            submitting: false,
            onSubmit: (_) async {},
            htmlPlayerFactory: (versionId, manifest) {
              capturedVersionId = versionId;
              return SizedBox(
                key: const Key('slot-player'),
                child: Text(versionId),
              );
            },
          ),
        ),
      );
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningApiClientProvider.overrideWithValue(
              fakeApi(utf8.encode(htmlA)),
            ),
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
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-webview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HTML manifest thiếu sceneVersionId → notice an toàn', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        app(
          ReadRenderer(
            activity: act,
            submitting: false,
            onSubmit: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(HtmlAnimationPlayer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Client giả: trả bytes cấu hình sẵn cho endpoint html; constructor
/// super cần ApiClient bất kỳ nhưng method đích đã override.
class _FakeLearningApiClient extends LearningApiClient {
  final List<int>? _bytes;
  final Future<List<int>>? _pending;
  _FakeLearningApiClient(List<int> bytes)
    : _bytes = bytes,
      _pending = null,
      super(ApiClient.fromConfig(baseUrl: 'http://test'));
  _FakeLearningApiClient.completer(Future<List<int>> pending)
    : _bytes = null,
      _pending = pending,
      super(ApiClient.fromConfig(baseUrl: 'http://test'));

  @override
  Future<List<int>> getAnimationHtmlBytes(String versionId) =>
      _pending ?? Future.value(_bytes ?? const []);
}

// WebViewController không phải interface → không fake trực tiếp được.
// JS-message path được test qua `handleJsMessageForTest` trên state thật
// (xem các test PLAYBACK_FINISHED/READY ở trên).
