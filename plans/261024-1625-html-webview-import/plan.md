---
title: "HTML WebView Animation Import"
description: "Allow admins to upload a self-contained HTML file that becomes a published animation scene rendered inside a Flutter WebView (rendererCode HTML_WEBVIEW)."
status: implemented
priority: P1
effort: 16h
branch: main
tags: [animation, html, webview, flutter, admin, backend]
created: 2026-10-24
---

# HTML WebView Animation Import

## Goal

Admin drag-drops ONE self-contained `.html` (≤15 MB configurable, UTF-8, inline CSS/JS/media only, NO external resources) → system auto-creates an `HTML_WEBVIEW` scene draft → iframe-sandboxed admin preview → publish (immutable version) → pick in Lesson Builder → Flutter fetches published HTML via authenticated endpoint + renders in `webview_flutter`.

Non-goals: per-scene renderer code, deleting `RIVER_TIDE`/`JOURNEY_MAP`, Playwright, commits/push.

## Phase Index

| # | Phase | Effort | Status |
|---|-------|--------|--------|
| 01 | [Migration + backend model](phase-01-migration-backend-model.md) | 2h | done |
| 02 | [Backend API (import / draft / publish / learner fetch)](phase-02-backend-api.md) | 3h | done |
| 03 | [Admin import UI (dropzone + BFF upload route)](phase-03-admin-import-ui.md) | 2h | done |
| 04 | [Admin preview + publish integration](phase-04-admin-preview-publish.md) | 2h | done |
| 05 | [Flutter WebView player + dispatch](phase-05-flutter-webview.md) | 3h | done |
| 06 | [Tests (backend + admin + flutter)](phase-06-tests.md) | 3h | done (ITs BLOCKED: no Docker) |
| 07 | [Docs + verification](phase-07-docs-verification.md) | 1h | done (MOBILE_E2E BLOCKED: no device) |

## Key Decisions (encoded from audits)

- **V19** adds `animation_scene_html` (draft, per scene) + `animation_scene_version_html` (immutable, per version) + `html-webview` template row. Immutability trigger mirrors `trg_animation_scene_versions_immutable` (V14).
- `draft_json` for HTML scenes: minimal JSON `{schemaVersion:2, rendererCode:'HTML_WEBVIEW', title, disclaimer, sourceReferences:[], html:{filename,sizeBytes,sha256}}`. `AnimationManifestValidator` gets an `HTML_WEBVIEW` branch that validates ONLY this shape (skips steps/stakes/map/assets checks). Add `HTML_WEBVIEW` to `RENDERER_CODES`.
- Publish reuses existing `POST /{id}/publish`; for `HTML_WEBVIEW` the publish service additionally copies draft HTML → version HTML row (same TX). Checksum covers snapshot JSON + `html.sha256` inside manifest.
- Duplicate copies `draft_json` + `animation_scene_html` row.
- Learner fetch: NEW `GET /api/v1/animation-versions/{versionId}/html` (authenticated, published-only, `text/html; charset=utf-8`, `X-Content-Type-Options: nosniff`, restrictive CSP).
- Admin BFF: new `POST /api/upload/html-scene` + `PUT /api/upload/html-scene/[id]` multipart forwarders (cap ~16 MB) mirroring `src/app/api/upload/assets/route.ts`.
- Flutter: new `HtmlAnimationPlayer` widget + `webview_flutter: ^4.x`; dispatch in `ReadRenderer` BEFORE registry resolve when `rendererCode == 'HTML_WEBVIEW'`; verify `sha256(bytes) == manifest.html.checksum`; `JavaScriptMode.unrestricted`, `NavigationDelegate → prevent` for ALL requests, no file access.
- Admin iframe preview: `<iframe sandbox="allow-scripts">` (NO `allow-same-origin`) + `srcDoc` from blob URL fetched via `GET html-draft`.

## AC Mapping

| AC | Phase | Check |
|----|-------|-------|
| Upload .html ≤15 MB, UTF-8, no external refs → scene draft created | 02, 03 | Backend validation tests + admin dropzone test |
| Admin sees sandboxed iframe preview of draft HTML | 04 | Vitest: iframe `sandbox` attr present, no `allow-same-origin` |
| Publish creates immutable version (cannot edit HTML of published version) | 01, 02 | Trigger test + publish service test (v1 bytes unchanged after v2) |
| Lesson Builder can pick published HTML scene | 04 (no code change if list shows PUBLISHED + label map) | Picker test shows HTML scene selectable |
| Flutter fetches published HTML via auth endpoint + renders in WebView | 05 | Widget test: dispatch, checksum match, error state |
| Existing RIVER_TIDE/JOURNEY_MAP scenes unaffected | 01, 02, 05 | Regression: existing publish + Flutter runtime tests still pass |

## Risks

| Risk | Mitigation |
|------|------------|
| 15 MB HTML in JSONB `draft_json` bloats DB | HTML stored in dedicated `TEXT` column, NOT `draft_json`; draft_json only carries metadata (`filename,sizeBytes,sha256`) |
| `webview_flutter` cannot run in `flutter test` | Wrap `WebViewWidget` in injectable builder / guard with `isTestEnvironment`-style flag (pattern exists in `DauVietAudioService`) |
| Admin BFF 2 MiB cap blocks upload | Dedicated `/api/upload/html-scene` route bypasses JSON proxy |
| External-resource validation false-positives | Conservative regex list + clear Vietnamese error w/ line snippet; iterate in tests |
| `multipart` limit too low | Raise `spring.servlet.multipart` to `16MB`/`18MB` in `application.yml` |

## Unresolved Questions

None blocking; see phase files for per-phase notes.
