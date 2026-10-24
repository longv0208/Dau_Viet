---
title: "Phase 05 — Flutter WebView player + dispatch"
description: "Add webview_flutter, LearningApiClient.getAnimationHtml, HtmlAnimationPlayer widget, and ReadRenderer dispatch for HTML_WEBVIEW."
status: pending
priority: P1
effort: 3h
---

# Phase 05 — Flutter WebView Player + Dispatch

## Context Links

- Audit: `plans/reports/researcher-261024-1623-flutter-read-audit.md` (§1, §4, §5, §8)
- Dispatch site: `dau-viet-mobile/lib/features/learning/presentation/renderers/read_renderer.dart` (lines ~79-99)
- Asset bytes fetch precedent: `dau-viet-mobile/lib/features/learning/presentation/renderers/learning_asset_image.dart` (`fetchLearningAssetBytes`)
- API client: `dau-viet-mobile/lib/features/learning/data/learning_api_client.dart` (`getAssetBytes`)
- Test seam precedent: `dau-viet-mobile/lib/core/audio/dau_viet_audio_service.dart` (`isTestEnvironment` flag)
- Test helpers: `dau-viet-mobile/test/learning/animation_runtime_test.dart` (`_embedded`, `_readActivity`, `_pumpRead`)
- pubspec: `dau-viet-mobile/pubspec.yaml` — no `webview_flutter` yet, no `crypto` yet.

## Overview

- Priority: P1.
- Status: pending.
- Brief: Flutter app renders an `HtmlAnimationPlayer` widget when the embedded envelope's `rendererCode == 'HTML_WEBVIEW'`; fetches published HTML via authenticated endpoint, verifies sha256, loads into a locked-down `WebView`.

## Key Insights

- Envelope shape from SnapshotBuilder: `config['animationManifest'] = {manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` — `sceneVersionId` is what we need for `GET /api/v1/animation-versions/{id}/html`.
- `parseManifestDetailed` only unwraps `embedded['manifest']` — does NOT expose `sceneVersionId`. Must read it ourselves in `read_renderer` (or extend parse result).
- `webview_flutter` does NOT run in `flutter test` → need a test seam. Precedent exists: `DauVietAudioService.isTestEnvironment` gates plugin usage. Apply same pattern OR inject `WebViewBuilder` callback.
- For sha256 verification: `crypto` package is the canonical choice (`sha256.convert(bytes)`). Add `crypto: ^3.0.3` to pubspec.
- `JavaScriptMode.unrestricted` is required for self-contained animations; `NavigationDelegate.onNavigationRequest → prevent` blocks ALL navigation so external links/iframes cannot load.
- `loadHtmlString(html, baseUrl: 'about:blank')` — no file access, no remote origin.
- `JavascriptChannel` is OPTIONAL — accept it for `DauVietChannel` with whitelisted message types only (`READY`, `PLAYBACK_STARTED`, `PLAYBACK_PAUSED`, `PLAYBACK_FINISHED`, `RUNTIME_ERROR`); cap payload size; never send tokens. Minimal viable: omit channel in v1, add later if needed — but spec says "expose play/pause/replay controls if window.DauVietAnimation exists" — keep as OPTIONAL bridge detection via `runJavaScriptReturningResult('typeof window.DauVietAnimation')` post-load. KISS: implement only if tests demand it; otherwise gate behind a TODO.

## Requirements

### Dependencies

`pubspec.yaml`:
```yaml
webview_flutter: ^4.10.0
crypto: ^3.0.6
```

### API client

In `LearningApiClient`:

```dart
Future<List<int>> getAnimationHtml(String versionId) async {
  // same auth path as getAssetBytes
  // GET /api/v1/animation-versions/{versionId}/html
  // Dio ResponseType.bytes
}
```

Surface through `AttemptRepository.getAnimationHtml` (or new repo method — mirror `getAssetBytes` plumbing via `learning_asset_image.dart`'s `fetchLearningAssetBytes` pattern).

### `HtmlAnimationPlayer` widget

`lib/features/learning/presentation/animations/html_animation_player.dart`:

- Input: `AnimationManifestDto manifest`, `String sceneVersionId`, `String playbackMode`.
- State machine: `loading → ready | error`.
- On `initState`: call `ref.read(attemptRepositoryProvider).getAnimationHtml(versionId)` (with `withAuth` wrap when `!ApiConfig.useMock` — same as `fetchLearningAssetBytes`).
- Verify `sha256.convert(bytes)` == `manifest.html.sha256` (read from manifest DTO — extend `AnimationManifestDto` with `html` block field `{filename,sizeBytes,sha256}`).
- On success: `_controller.loadHtmlString(utf8.decode(bytes), baseUrl: 'about:blank')`.
- `WebViewController` config:
  - `setJavaScriptMode(JavaScriptMode.unrestricted)`
  - `setBackgroundColor(Colors.transparent)`
  - `setNavigationDelegate(NavigationDelegate(onNavigationRequest: (_) => NavigationDecision.prevent))`
  - No `setAllowsFileAccess` (defaults off; explicit `false` if API exists for clarity).
- UI: aspect-ratio 16:9 container, `WebViewWidget(controller: ...)`, reload button on error state, optional replay FAB.
- `DauVietAudioService.isTestEnvironment` flag pattern: if test env, return a placeholder `Container(key: Key('html-animation-test-stub'))` instead of `WebViewWidget` — lets widget tests verify dispatch/loading/error/checksum without instantiating the plugin.

### Manifest DTO extension

`lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart`:

Add `html` field:

```dart
class HtmlManifestBlock {
  final String filename;
  final int sizeBytes;
  final String sha256;
}

class AnimationManifestDto {
  ...
  final HtmlManifestBlock? html;  // non-null iff rendererCode == 'HTML_WEBVIEW'
}
```

Parser: when `rendererCode == 'HTML_WEBVIEW'`, read `json['html']` block into `HtmlManifestBlock`.

### ReadRenderer dispatch

In `read_renderer.dart` (lines ~79-99) BEFORE `manifestRenderer.resolve`:

```dart
final embedded = config['animationManifest'];
final String? sceneVersionId =
    embedded is Map ? embedded['sceneVersionId'] as String? : null;

if (manifestPresent &&
    manifestDto != null &&
    manifestDto.rendererCode == 'HTML_WEBVIEW' &&
    sceneVersionId != null &&
    manifestDto.html != null) {
  animation = HtmlAnimationPlayer(
    manifest: manifestDto,
    sceneVersionId: sceneVersionId,
    playbackMode: playbackMode,
  );
} else {
  // existing renderer path
}
```

Update `unsupportedManifest` condition accordingly (HTML scene missing `sceneVersionId` or `html` block → unsupported notice).

### Test seam

```dart
// lib/features/learning/presentation/animations/html_animation_player.dart
class HtmlAnimationPlayer extends StatefulWidget {
  final WebViewBuilder? webViewBuilder;  // injectable for tests
  ...
}

typedef WebViewBuilder = Widget Function(WebViewController controller);
```

Default: `WebViewWidget.new`. Tests pass a stub builder. Combined with `isTestEnvironment` flag from `DauVietAudioService` for the fetch-vs-plugin bypass.

## Related Code Files

### Create
- `dau-viet-mobile/lib/features/learning/presentation/animations/html_animation_player.dart`

### Modify
- `dau-viet-mobile/pubspec.yaml` — add `webview_flutter`, `crypto`.
- `dau-viet-mobile/lib/features/learning/data/learning_api_client.dart` — `getAnimationHtml(versionId)`.
- `dau-viet-mobile/lib/features/learning/data/attempt_repository.dart` (or wherever `getAssetBytes` lives — `learning_api_client.dart` audit says `repo.getAssetBytes`) — expose `getAnimationHtml`.
- `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart` — `HtmlManifestBlock` + `html` field.
- `dau-viet-mobile/lib/features/learning/presentation/renderers/read_renderer.dart` — dispatch branch.
- Possibly `lib/features/learning/data/learning_dtos.dart` — if a `getAnimationHtml` repo signature lives there (verify; audit says fetch is via `LearningApiClient`).

## Implementation Steps

1. `flutter pub add webview_flutter crypto`.
2. Extend `AnimationManifestDto` with `HtmlManifestBlock` + parser.
3. Add `LearningApiClient.getAnimationHtml(versionId)` returning `Future<List<int>>` (Dio `ResponseType.bytes`, Bearer auth via `ApiClient._authOptions`).
4. Expose through `AttemptRepository` (or whichever repo owns `getAssetBytes`); mirror the `withAuth` wrapping logic.
5. Write `HtmlAnimationPlayer` — StatefulWidget, fetch → sha256 → WebView, test seam via `webViewBuilder`.
6. Wire dispatch in `read_renderer.dart` — read `sceneVersionId` from `config['animationManifest']` envelope.
7. Run `flutter pub get` + `flutter analyze` for compile check.

## Todo

- [ ] pubspec deps added.
- [ ] `HtmlManifestBlock` + manifest DTO extension.
- [ ] `LearningApiClient.getAnimationHtml`.
- [ ] `AttemptRepository.getAnimationHtml` (or equivalent plumbing).
- [ ] `HtmlAnimationPlayer` widget (states, checksum, test seam).
- [ ] ReadRenderer dispatch.
- [ ] `flutter analyze` clean.
- [ ] Manual run on emulator — verified HTML loads + renders.

## Success Criteria

- `flutter pub get` resolves `webview_flutter ^4.x` and `crypto ^3.x`.
- Dispatch: `READ` activity whose `config.animationManifest.rendererCode == 'HTML_WEBVIEW'` mounts `HtmlAnimationPlayer`; other rendererCodes unchanged.
- `HtmlAnimationPlayer` calls `getAnimationHtml` once with the embedded `sceneVersionId`; on 200 verifies sha256 vs `manifest.html.sha256`; on mismatch shows error.
- WebView loads `loadHtmlString` — script runs (`JavaScriptMode.unrestricted`), but `NavigationDelegate` blocks any external request.
- In `flutter test`, `HtmlAnimationPlayer` does not instantiate the plugin (stub builder or `isTestEnvironment` path).

## Risks

- `webview_flutter` increases APK/IPA size — acceptable (no alternative for arbitrary HTML).
- `sha256` of UTF-8-encoded bytes — must hash the raw response bytes, NOT re-encoded string (avoid newline normalization). Compute on `List<int>` directly.
- WebView on Android needs `minSdkVersion >= 19` (webview_flutter requires 19+); verify `android/app/build.gradle` — Flutter default is 21+, no change expected.
- `baseUrl: 'about:blank'` — if animations use `document.baseURI`-relative resources they will fail; that's by design (block external).

## Security Considerations

- `NavigationDelegate.prevent` on ALL requests prevents any external resource load — defense-in-depth alongside backend validator.
- No `JavascriptChannel` exposure of sensitive APIs (channel is OPTIONAL; if added, only accept whitelisted message types).
- HTML bytes are authenticated — same Bearer flow as `getAssetBytes`.
- Never log HTML body; log only versionId + sha256 prefix.
