---
title: "Phase 06 — Tests (backend + admin + flutter)"
description: "Unit + MockMvc backend tests, vitest admin tests, flutter widget tests for HTML_WEBVIEW pipeline."
status: pending
priority: P1
effort: 3h
---

# Phase 06 — Tests

## Context Links

- Backend test precedent: `dau-viet-backend/src/test/java/com/dauviet/animation/` (verify existing test folder structure with `Glob`)
- Admin test precedent: `dau-viet-admin/src/features/animations/animation-types.test.ts`, `scene-preview.test.tsx`, `animation-picker.test.tsx` + MSW handlers in `src/test/msw/handlers.ts` + fixtures in `src/test/fixtures.ts`
- Flutter test precedent: `dau-viet-mobile/test/learning/animation_runtime_test.dart` (`_embedded`, `_readActivity`, `_pumpRead`), `read_renderer_manifest_test.dart`
- Test seam: `DauVietAudioService.isTestEnvironment` (dau-viet-mobile/lib/core/audio/dau_viet_audio_service.dart)

## Overview

- Priority: P1 — required by Definition of Done.
- Status: pending.
- Brief: cover validation rejections, import/replace/publish/learner fetch (backend), dropzone + sandboxed preview + picker (admin), dispatch + fetch + checksum (flutter). No Playwright.

## Key Insights

- `webview_flutter` does NOT run in `flutter test` — must use the `webViewBuilder` injection seam (Phase 05).
- Backend `MockMvc` multipart test precedent: search for `@WebMvcTest`/`MockMvc` + `MockMultipartFile` patterns (mirror existing `AdminAssetController` tests if any).
- `HtmlDocumentValidator` regex blocklist needs positive + negative cases — especially `xmlns="http://www.w3.org/..."` and `data:` URIs which MUST pass.
- Immutability: asserting `animation_scene_version_html` UPDATE raises is a JPA-level concern — write integration test against a real DB (Testcontainers if already used) OR trust the V14 pattern (validated by existing tests if `animation_scene_versions` immutability is already covered — check, mirror).

## Requirements

### Backend (`dau-viet-backend/src/test/java/com/dauviet/animation/`)

**`HtmlDocumentValidatorTest.java`** (unit, no Spring context):
- accepts `.html` lowercase + `.HTM` uppercase + `text/html`, `text/plain`, `application/octet-stream` MIME.
- accepts self-contained HTML with `<!DOCTYPE html>` + inline `<style>` + inline `<script>` + `data:` URIs.
- accepts SVG `xmlns="http://www.w3.org/2000/svg"` and `xmlns:xlink` — these are NOT fetches.
- rejects `.txt`, `.exe`, empty file, >max-bytes file.
- rejects non-UTF-8 bytes (e.g. UTF-16 BOM with non-ASCII).
- rejects HTML missing `<html` and `<!doctype`.
- rejects `<script src="https://cdn.example.com/x.js">` with `code=EXTERNAL_REF` + line number in message.
- rejects `<link rel="stylesheet" href="https://...">`.
- rejects `<img src="http://example.com/x.png">` and `<img src="//example.com/x.png">` (protocol-relative).
- rejects `<img src="./local.png">` and `<img src="/abs.png">` (relative paths — no filesystem).
- rejects `fetch(` + `XMLHttpRequest` + `import('https://...')`.
- rejects `url(http://` and `url(//` in CSS.
- rejects `<base href`, `<meta http-equiv="refresh"`, `@import "http://..."`.
- accepts `<img src="data:image/png;base64,...">`.

**`AnimationHtmlServiceTest.java`** (MockMvc or @WebMvcTest):
- `POST /admin/animation-scenes/html-import` valid → 201 + `SceneResponse` + db has `animation_scene_html` row.
- `POST html-import` with `<script src>` → 422 + `errors[0].code=EXTERNAL_REF`.
- `POST html-import` oversize → 413 or 422.
- `PUT /{id}/html-draft` happy path → replaces content + sha256, bumps `rowVersion`.
- `PUT /{id}/html-draft` stale `expectedRowVersion` → 409.
- `PUT /{id}/html-draft` on RIVER_TIDE scene → 409 InvalidStatusTransition.
- `GET /{id}/html-draft` returns `text/html` body for CONTENT_ADMIN; 401 anon; 403 LEARNER (verify SecurityConfig is enforced — `@WebMvcTest` includes it).
- `POST /{id}/publish` → version + `animation_scene_version_html` row inserted; `sha256` matches draft.
- `POST /{id}/publish` second time → new version; first version row content UNCHANGED.
- `POST /{id}/duplicate` → new scene has its own `animation_scene_html` row with same content.
- `GET /api/v1/animation-versions/{versionId}/html`:
  - 200 for LEARNER role + correct bytes + headers (`nosniff`, `text/html`, CSP).
  - 401 unauthenticated.
  - 404 unknown versionId.
  - 404 versionId exists but is RIVER_TIDE (no html row).

### Admin (`dau-viet-admin/`)

**`html-import-dropzone.test.tsx`** (vitest + jsdom):
- Renders drop zone + hidden input.
- `dragenter`/`dragover` adds `isDragActive` class.
- `drop` with `.html` file → `onFileAccepted` called with file.
- `drop` with `.txt` → inline error "Chỉ chấp nhận tệp .html", `onFileAccepted` NOT called.
- File >15 MB → error, `onFileAccepted` NOT called.
- Click → triggers input click.

**`html-scene-editor.test.tsx`** (vitest + MSW):
- MSW handler `GET /api/proxy/admin/animation-scenes/:id/html-draft` returns `text/html` blob.
- Renders title, file info, iframe with `sandbox="allow-scripts"` attr; verify `allow-same-origin` NOT present.
- Viewport toggle changes iframe width.
- Reload button refetches.
- Replace dropzone → `PUT` handler → iframe src updates.
- PublishSection wired (validate → publish handler hit).

**`animation-picker.test.tsx`** (extend existing):
- MSW fixture returns PUBLISHED HTML scene → appears in list with `Hoạt họa HTML` label.

**`animation-library.test.tsx`** (new or extend):
- Renders `HtmlImportDropzone`.
- Successful import (MSW 201) → `router.push` called with `/animations/{id}/edit`.
- 422 → `errors[]` shown.

**MSW additions** in `src/test/msw/handlers.ts`:
```ts
http.post('/api/upload/html-scene', ...)  // 201 or 422
http.put('/api/upload/html-scene/:id', ...)
http.get('/api/proxy/admin/animation-scenes/:id/html-draft', ...)
http.get('/api/proxy/admin/animation-scenes/:id', ...)  // for editor
```

### Flutter (`dau-viet-mobile/test/learning/`)

**`html_animation_player_test.dart`**:
- `HtmlAnimationPlayer` renders loading state initially (pumpWidget + verify spinner).
- With mocked `AttemptRepository.getAnimationHtml` returning valid bytes → renders `HtmlAnimationPlayer` (or stub key).
- Checksum mismatch → error state + retry button.
- Repo throws → error state.
- `webViewBuilder` injectable: pass `(_) => Container(key: Key('stub-webview'))` and assert `find.byKey(Key('stub-webview'))` after successful load.

**`read_renderer_html_test.dart`** (new file or extend `animation_runtime_test.dart`):
- `config.animationManifest` envelope with `rendererCode='HTML_WEBVIEW'` + `sceneVersionId` + `manifest.html` → `find.byType(HtmlAnimationPlayer)`.
- Two distinct fixture HTMLs produce same runtime type (sanity — same WebView type for any HTML).
- Missing `sceneVersionId` → `_UnsupportedAnimationNotice` shows.
- `RIVER_TIDE` rendererCode still dispatches to `HistoricalAnimationPlayer` (regression).
- Legacy `animationKey` fallback still works when `animationManifest` absent (regression).

**Manifest DTO test**:
- Parsing `rendererCode='HTML_WEBVIEW'` manifest populates `dto.html.{filename,sizeBytes,sha256}`.
- Parsing RIVER_TIDE leaves `dto.html == null`.

### Fixtures

`test/learning/fixtures/`:
- `simple_html_animation.html` — minimal `<!DOCTYPE html><html><body>Hi</body></html>` (under 1 KB).
- `scripted_html_animation.html` — inline `<script>` with `window.DauVietAnimation` stub (under 2 KB).
- These DO NOT go through `HtmlDocumentValidator` — they are Flutter-side fixtures only (validator runs on backend).

## Related Code Files

### Create
- `dau-viet-backend/src/test/java/com/dauviet/animation/manifest/HtmlDocumentValidatorTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/animation/application/AnimationHtmlServiceTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/animation/api/AdminAnimationSceneHtmlControllerTest.java` (or merge into existing controller test)
- `dau-viet-backend/src/test/java/com/dauviet/animation/api/LearnerAnimationVersionControllerTest.java`
- `dau-viet-admin/src/features/animations/html-import-dropzone.test.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/html-scene-editor.test.tsx`
- `dau-viet-admin/src/features/animations/animation-library.test.tsx` (if not exists)
- `dau-viet-mobile/test/learning/html_animation_player_test.dart`
- `dau-viet-mobile/test/learning/read_renderer_html_test.dart`
- `dau-viet-mobile/test/learning/fixtures/simple_html_animation.html`
- `dau-viet-mobile/test/learning/fixtures/scripted_html_animation.html`

### Modify
- `dau-viet-admin/src/test/msw/handlers.ts` — add HTML scene endpoints.
- `dau-viet-admin/src/test/fixtures.ts` — add `htmlSceneFixture` + `htmlScenePageFixture`.
- `dau-viet-admin/src/features/lessons/builder/activity-editors/animation-picker.test.tsx` — add HTML scene case.
- `dau-viet-mobile/test/learning/animation_runtime_test.dart` — add manifest DTO parsing cases OR keep separate in `read_renderer_html_test.dart`.

## Implementation Steps

1. Write `HtmlDocumentValidatorTest` first — drives validator correctness.
2. Write `AnimationHtmlServiceTest` (or `@SpringBootTest` slice) covering all endpoints + publish + duplicate.
3. Write `LearnerAnimationVersionControllerTest` — auth, 200, headers, 404s.
4. Add MSW handlers + fixtures.
5. Write `html-import-dropzone.test.tsx` + `html-scene-editor.test.tsx` + extend `animation-picker.test.tsx`.
6. Write Flutter fixture files + `html_animation_player_test.dart` + `read_renderer_html_test.dart`.
7. Run all: `mvn -pl dau-viet-backend test`, `pnpm vitest run`, `flutter test`.

## Todo

- [ ] Backend: `HtmlDocumentValidatorTest` — all regex cases.
- [ ] Backend: `AnimationHtmlServiceTest` — import + replace + publish + duplicate.
- [ ] Backend: `LearnerAnimationVersionControllerTest` — auth + headers + 404.
- [ ] Admin: MSW handlers + fixtures.
- [ ] Admin: `html-import-dropzone.test.tsx`.
- [ ] Admin: `html-scene-editor.test.tsx`.
- [ ] Admin: `animation-picker.test.tsx` HTML case.
- [ ] Admin: `animation-library.test.tsx` import flow.
- [ ] Flutter: HTML fixtures.
- [ ] Flutter: `html_animation_player_test.dart`.
- [ ] Flutter: `read_renderer_html_test.dart` (dispatch + fallback + regression).
- [ ] All suites green.

## Success Criteria

- `mvn -pl dau-viet-backend test` — all tests pass including new HTML coverage.
- `cd dau-viet-admin && pnpm vitest run` — all tests pass including new HTML coverage.
- `cd dau-viet-mobile && flutter test` — all tests pass including new HTML coverage.
- Zero failures; new coverage includes: validator regex blocklist (10+ cases), immutability (v1 unchanged after v2 publish), iframe sandbox attr, WebView dispatch, checksum verify.

## Risks

- MockMvc + multipart on Windows path — use `MockMultipartFile` (no filesystem).
- JPA `@Lob` String fields may lazy-load — set `fetch = EAGER` or `@Transactional` on test.
- `isTestEnvironment` flag — must NOT leak into production code path; verify it's a private const-like static.

## Security Considerations

- Tests must include NEGATIVE auth cases (401 anon, 403 wrong role).
- Immutability test asserts `animation_scene_version_html` row v1 remains identical after v2 publish — validates immutability trigger + no accidental UPDATE.
