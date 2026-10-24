---
title: "Phase 02 — Backend API (import / draft / publish / learner fetch)"
description: "Add multipart import + draft replace + learner fetch endpoints, HTML validator, and publish/duplicate extensions."
status: pending
priority: P1
effort: 3h
---

# Phase 02 — Backend API

## Context Links

- Audit: `plans/reports/researcher-261024-1623-backend-animation-audit.md` (§5, §6, §11, §12, §13)
- Controller: `dau-viet-backend/src/main/java/com/dauviet/animation/api/AdminAnimationSceneController.java`
- Multipart precedent: `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminAssetController.java`
- Service: `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationSceneService.java` (duplicate at L164)
- Publish: `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationScenePublishService.java`
- Validator: `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/AnimationManifestValidator.java` + `AnimationManifestSchema.java` (`RENDERER_CODES`, `TOP_LEVEL_KEYS`)
- Errors: `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationExceptions.java`
- Auth: `common/config/SecurityConfig.java` — `/api/v1/admin/**` → `CONTENT_ADMIN`; `anyRequest().authenticated()` covers learner path.
- `application.yml`: `spring.servlet.multipart` currently `10MB/12MB` → bump.

## Overview

- Priority: P1.
- Status: pending.
- Brief: backend can ingest HTML, persist draft, publish immutably, and serve published HTML to authenticated learners.

## Key Insights

- `RENDERER_CODES` is a `Set.of(...)` in `AnimationManifestSchema` — adding `'HTML_WEBVIEW'` unlocks template creation; validator needs a dedicated `validateHtml` branch.
- `PublishService.publish` already wraps everything in one TX; insert `animation_scene_version_html` inside the same TX.
- `manifestChecksum` stays `sha256(canonical snapshotJson)`; the snapshot's `html.sha256` field covers content integrity end-to-end (Flutter verifies `sha256(bytes) == snapshot.html.sha256`).
- SnapshotBuilder (§8) already embeds `manifest.*` + `sceneVersionId/versionNo/rendererCode/rendererVersion` — no change needed; `sceneVersionId` is what Flutter uses to fetch HTML.
- `anyRequest().authenticated()` already gates `/api/v1/animation-versions/*/html` — no SecurityConfig edit.

## Requirements

### Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/v1/admin/animation-scenes/html-import` | CONTENT_ADMIN | Multipart `{file, title?, eventId?}` → creates scene + draft html row → `SceneResponse` (201) |
| PUT | `/api/v1/admin/animation-scenes/{id}/html-draft` | CONTENT_ADMIN | Multipart `{file}` + `expectedRowVersion` → replace draft html |
| GET | `/api/v1/admin/animation-scenes/{id}/html-draft` | CONTENT_ADMIN | Returns `text/html` draft bytes for admin iframe preview |
| GET | `/api/v1/animation-versions/{versionId}/html` | authenticated (any role) | Returns `text/html` of PUBLISHED version |

### Response headers for both HTML GETs
- `Content-Type: text/html; charset=utf-8`
- `X-Content-Type-Options: nosniff`
- `Cache-Control: no-store` (admin draft); `Cache-Control: private, max-age=3600` (published — immutable so cacheable)
- `Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; media-src data:; font-src data:; connect-src 'none'; frame-ancestors 'none'` — defense-in-depth even though admin uses iframe `sandbox` and Flutter uses WebView.
- `Content-Disposition: inline` (NOT attachment — Flutter WebView consumes body directly).

### Draft JSON shape (auto-generated)

```json
{
  "schemaVersion": 2,
  "rendererCode": "HTML_WEBVIEW",
  "rendererVersion": 1,
  "title": "<from request or filename>",
  "disclaimer": "Hoạt họa tải lên bởi quản trị viên; nội dung do tác giả HTML chịu trách nhiệm.",
  "sourceReferences": [],
  "html": { "filename": "x.html", "sizeBytes": 12345, "sha256": "abc..." }
}
```

### HtmlDocumentValidator rules (all → `HtmlValidationException`, messages in Vietnamese for admin display)

1. Extension `.html` or `.htm` (case-insensitive).
2. Declared MIME ∈ `text/html`, `text/plain`, `application/octet-stream` (then sniff — must decode as UTF-8 and contain `<html` or `<!doctype`).
3. Non-empty, `sizeBytes ≤ ${dauviet.animations.html.max-bytes}` (default `15 * 1024 * 1024`).
4. UTF-8 decodable (strict `CharsetDecoder` with `CodingErrorAction.REPORT`).
5. Contains `<html` or `<!doctype` (case-insensitive).
6. REJECT external deps — line-number + snippet in error. Patterns:
   - `src\s*=\s*["']?\s*(https?:)?//`
   - `href\s*=\s*["']?\s*(https?:)?//` (exclude `mailto:`, `tel:`, `#`)
   - `url\(\s*["']?\s*(https?:)?//`
   - `<script[^>]+src\s*=` unless `src="data:` (always reject — `<script src>` implies external)
   - `fetch\s*\(`, `XMLHttpRequest`, `import\s*\(\s*['"]https?`
   - `<img|<source|<link|<video|<audio|<iframe` with `src`/`href` matching `^\.?\.?/` or bare filename without `data:` — relative paths count as external (no filesystem in WebView)
   - `<base\s+href`
   - `@import\s+['"]?(https?:)?//`
   - `<meta\s+http-equiv=["']?refresh`

### Service: `AnimationHtmlService` (new file under `application/`)

- `importHtml(MultipartFile file, String title, UUID eventId, UUID adminId) → SceneResponse`
  1. `HtmlDocumentValidator.validate(file)` → `ValidatedHtml{bytes, sha256, sizeBytes, filename, detectedTitle?}`.
  2. Find `html-webview` template via `templates.findByCode('html-webview')` → 500 if missing (V19 not applied).
  3. Build draft JSON (shape above).
  4. `scenes.save()` with `templateId`, `eventId`, `title`, `draftJson`, `status=DRAFT`.
  5. `sceneHtmlRepo.save(new AnimationSceneHtml(scene.id, content, sha256, sizeBytes, filename, now))`.
  6. Return `mapper.toSceneResponse`.
- `replaceHtmlDraft(UUID sceneId, MultipartFile file, Long expectedRowVersion, UUID adminId)`
  1. `scenes.findById` → 404 if absent; must be `HTML_WEBVIEW` (template check) else `InvalidStatusTransitionException`.
  2. `checkVersion(expected)` — optimistic lock.
  3. Validate; upsert `animation_scene_html` row; regenerate `draft_json.html` block; `updatedBy=adminId`; `saveAndFlush`.
- `getDraftHtml(UUID sceneId) → AnimationSceneHtml` — for admin preview endpoint.
- `getPublishedHtml(UUID versionId) → AnimationSceneVersionHtml` — `versions.findById` → 404 if absent; `versionHtmlRepo.findById(versionId)` → 404 if absent.

### Validator branch in `AnimationManifestValidator`

```java
if ("HTML_WEBVIEW".equals(template.getRendererCode())) {
    return validateHtmlManifest(manifest, template);
}
```

`validateHtmlManifest` checks only:
- `schemaVersion` present, `>=1`, `<=CURRENT_SCHEMA_VERSION`.
- `rendererCode == 'HTML_WEBVIEW'` AND `== template.rendererCode`.
- `rendererVersion <= template.rendererVersion`.
- `title` non-empty ≤ `MAX_TITLE`.
- `disclaimer` present non-empty.
- `sourceReferences` present (array, may be empty — relax the non-empty rule for HTML only).
- `html` object with `filename`,`sizeBytes`,`sha256` (sha256 = 64-hex).
- Reject any other top-level keys not in `{schemaVersion,rendererCode,rendererVersion,title,learningObjective,disclaimer,sourceReferences,html}` (whitelist for HTML).

### Publish extension

In `AnimationScenePublishService.publish` after step 5 (existing manifest checksum calc), BEFORE insert:

```java
if ("HTML_WEBVIEW".equals(t.getRendererCode())) {
    AnimationSceneHtml draft = sceneHtmlRepo.findById(sceneId)
        .orElseThrow(() -> new InvalidStatusTransitionException("html draft missing"));
    AnimationSceneVersionHtml vh = new AnimationSceneVersionHtml();
    vh.setVersionId(saved.getId());           // set AFTER version insert (needs id)
    vh.setContent(draft.getContent());
    vh.setSha256(draft.getSha256());
    vh.setSizeBytes(draft.getSizeBytes());
    vh.setOriginalFilename(draft.getOriginalFilename());
    versionHtmlRepo.save(vh);
}
```

Skip `animation_scene_asset_refs` writes when `manifest.assets` absent (existing code already iterates empty list — verify).

### Duplicate extension

In `AnimationSceneService.duplicate` after `copy` save:

```java
sceneHtmlRepo.findById(id).ifPresent(draft -> {
    AnimationSceneHtml clone = new AnimationSceneHtml();
    clone.setSceneId(copy.getId());
    clone.setContent(draft.getContent());
    clone.setSha256(draft.getSha256());
    clone.setSizeBytes(draft.getSizeBytes());
    clone.setOriginalFilename(draft.getOriginalFilename());
    sceneHtmlRepo.save(clone);
});
```

### application.yml

```yaml
spring:
  servlet:
    multipart:
      max-file-size: 16MB
      max-request-size: 18MB
dauviet:
  animations:
    html:
      max-bytes: ${DAUVIET_ANIMATION_HTML_MAX_BYTES:15728640}   # 15 MiB
```

### Exceptions

Add to `AnimationExceptions`:

```java
public static class HtmlValidationException extends RuntimeException {
    private final List<ManifestFieldError> errors;
    // mirror ManifestValidationException shape; reuse ManifestFieldError
}
```

Wire in `GlobalExceptionHandler` → 422 with structured errors list.

## Related Code Files

### Create
- `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationHtmlService.java`
- `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/HtmlDocumentValidator.java`
- `dau-viet-backend/src/main/java/com/dauviet/animation/api/LearnerAnimationVersionController.java` (NEW learner controller, base `/api/v1/animation-versions`)

### Modify
- `dau-viet-backend/src/main/java/com/dauviet/animation/api/AdminAnimationSceneController.java` — add 3 endpoints.
- `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationSceneService.java` — extend `duplicate()`.
- `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationScenePublishService.java` — branch for `HTML_WEBVIEW`.
- `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/AnimationManifestValidator.java` — `validateHtmlManifest` branch.
- `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/AnimationManifestSchema.java` — add `HTML_WEBVIEW` to `RENDERER_CODES`; add `'html'` to `TOP_LEVEL_KEYS`; (optional) add `HTML_WEBVIEW → emptySet()` to `STATE_KEYS`.
- `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationExceptions.java` — add `HtmlValidationException`.
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` — map `HtmlValidationException` → 422 (check current mapping pattern for `ManifestValidationException`).
- `dau-viet-backend/src/main/resources/application.yml` — bump multipart, add `dauviet.animations.html.max-bytes`.

## Implementation Steps

1. Update `AnimationManifestSchema` (add `HTML_WEBVIEW`, add `'html'` to `TOP_LEVEL_KEYS`, optional `STATE_KEYS` entry).
2. Add `HtmlValidationException` to `AnimationExceptions` + handler mapping.
3. Write `HtmlDocumentValidator` — pure-Java, no Spring deps except `@Value` for max bytes.
4. Write `AnimationHtmlService` with import/replace/getters.
5. Wire admin endpoints in `AdminAnimationSceneController` (multipart `@RequestPart("file")`, `@RequestParam` for title/eventId/expectedRowVersion).
6. Create `LearnerAnimationVersionController` with single `GET /{versionId}/html`.
7. Update `AnimationManifestValidator` with `HTML_WEBVIEW` branch.
8. Update `AnimationScenePublishService` to copy draft html → version html inside same TX.
9. Update `AnimationSceneService.duplicate` to copy draft html.
10. Bump `application.yml` multipart limits + add `dauviet.animations.html.max-bytes`.

## Todo

- [ ] Schema constants + validator branch.
- [ ] `HtmlDocumentValidator` with regex blocklist + Vietnamese messages.
- [ ] `AnimationHtmlService` + repo injection.
- [ ] Admin endpoints (3) in `AdminAnimationSceneController`.
- [ ] Learner endpoint in new `LearnerAnimationVersionController`.
- [ ] Publish service copy step.
- [ ] Duplicate service copy step.
- [ ] `application.yml` updates.
- [ ] Exception mapping in `GlobalExceptionHandler`.
- [ ] `./mvnw -pl dau-viet-backend compile` clean.

## Success Criteria

- `POST /api/v1/admin/animation-scenes/html-import` accepts a valid self-contained `.html` and returns `SceneResponse` with `templateId` = html-webview template.
- Same endpoint rejects file with `<script src="https://cdn.example.com/x.js">` returning 422 with `path=html`, `code=EXTERNAL_REF`, message containing line snippet.
- `PUT /{id}/html-draft` swaps draft bytes (sha256 changes), preserving `expectedRowVersion` semantics (409 on stale).
- `GET /{id}/html-draft` returns `text/html` for CONTENT_ADMIN, 403 for LEARNER, 401 unauthenticated.
- `POST /{id}/publish` produces version row + `animation_scene_version_html` row with identical `sha256`/`content`.
- `GET /api/v1/animation-versions/{versionId}/html` returns same bytes for any authenticated role; returns 404 for unknown/unpublished id.
- `POST /{id}/duplicate` copies draft html — fetching the new scene's `html-draft` returns the same content.
- `mvn -pl dau-viet-backend test` passes existing tests.

## Risks

- Regex blocklist may flag legitimate `xmlns="http://www.w3.org/..."` — whitelist `xmlns` and `DOCTYPE` declarations explicitly; tests cover these cases.
- 15 MB multipart through Spring — `max-file-size=16MB` + `max-request-size=18MB` covers boundary overhead.
- `text/html` Content-Type could allow XSS if endpoint ever rendered inline in admin — mitigated by `sandbox` attr on iframe + `frame-ancestors 'none'` + serving raw bytes from BFF not admin origin.

## Security Considerations

- Validator runs BEFORE persistence — never store dodgy HTML.
- `frame-ancestors 'none'` in CSP prevents admin site being framed by uploaded HTML itself.
- Authentication required for learner endpoint — same as `/api/v1/assets/{id}/content`.
- No raw HTML logged (only metadata: filename, sizeBytes, sha256).
