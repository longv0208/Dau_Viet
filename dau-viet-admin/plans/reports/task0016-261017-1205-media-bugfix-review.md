# Code Review — TASK-0016 Media Bugfix (Đợt 2)

## Scope
- Files reviewed: 12 (modified + new) listed in the brief; SecurityConfig + AssetService cross-checked for backend invariants.
- LOC: ~700 changed.
- Focus: P1 blob-URL auth fetch, P2 multipart upload route, P3 learner content endpoint, P4 strict-401 stub + e2e.

## Overall Assessment
Solid bugfix round. The authenticated-fetch→blob pipeline, dedicated multipart route, and learner endpoint all deliver what the brief asks. Code is small, focused, and consistent with existing BFF/proxy patterns. A few minor issues below — none are blockers, one is worth fixing soon (revoke timing in `use-asset-object-url`).

## Critical Issues
None.

## High Priority
None.

## Medium Priority

### M1 — `use-asset-object-url.ts` — object URL revoked too late on success path
**File:** `src/features/assets/use-asset-object-url.ts:36-46`

The cleanup captures `objectUrl` correctly for cancellation/unmount, but on the success path the URL is stored in local `objectUrl` and only revoked when `contentUrl` changes or unmount fires. That's correct in principle, but the variable is captured by closure — if `fetchAssetBlob` resolves, the assignment to `objectUrl` happens *inside* `.then` on a `let` declared outside. That works (closure captures the binding), but there is one subtle leak: `setState({ src: objectUrl, ... })` is called *before* the cleanup can revoke it, and on unmount the cleanup uses the *current* value of `objectUrl`. That's fine.

The real edge is **StrictMode double-effect** in dev: React mounts → effect runs → cleanup → effect runs again. The first fetch isn't cancelled mid-flight, just flagged. If both `.then` callbacks run, the first sees `cancelled=true` and returns early without creating a URL. Good. But if `fetchAssetBlob` resolves *after* the second effect's fetch, the first `.then` returns early — also good. So StrictMode is handled correctly.

**Actual issue:** there is no explicit revocation when the component stays mounted but `contentUrl` prop changes to a *different* value. The cleanup *does* run and revoke — effect dep is `[contentUrl]` — so this is also fine. No bug.

However, there's a subtle case: `URL.createObjectURL` is called inside `.then` *after* the cancelled check. If cancellation happens *between* `createObjectURL` and `setState`, the URL is stored in `objectUrl` and the cleanup will revoke it — correct. If cancellation happens *before* `createObjectURL` runs (race), then `cancelled=true` short-circuits the whole `.then` and no URL is created. Correct.

**Verdict:** implementation is actually correct. Flagging as reviewed-and-clear; no change needed.

### M2 — `use-asset-object-url.ts:31` — loading state flicker on `contentUrl` change
When `contentUrl` changes from one valid URL to another, the cleanup revokes the old URL, but `setState({ src: null, loading: true, error: false })` runs synchronously inside the new effect — so the user sees a brief loading state even if the image is already in memory. Minor UX nit; acceptable for now.

### M3 — `asset-api.ts:59,87` — naive `replace(/^\/api\/v1/, "")` on `contentUrl`
If backend ever returns a `contentUrl` that doesn't start with `/api/v1` (e.g. absolute URL, or prefixed differently by an env override), the regex silently no-ops and produces a broken proxy path. Currently the backend hardcodes `/api/v1/admin/assets/{id}/content` (`AssetService.java:149`), so it's safe today — but consider validating or splitting on the prefix explicitly to fail loud rather than silently constructing `/api/proxyhttps://...`.

## Low Priority

### L1 — `api/upload/assets/route.ts` — no explicit `altText` size cap
The route reads the entire body as `arrayBuffer` and forwards it. `altText` is bounded by `MAX_BODY` (12 MB), so a rogue client could still send a 12 MB "altText" — backend truncates via DB column anyway. Acceptable; just noting.

### L2 — `api/upload/assets/route.ts:67-72` — upstream `set-cookie` filtered, good; but `content-length` also filtered (correct for streamed `upstream.body`)
`content-length` is in `HOP_BY_HOP` set. Good — `upstream.body` is a stream, so a stale upstream `content-length` would be wrong. Correct handling.

### L3 — `LearnerAssetController.java:43` — `safeName` identical to `AdminAssetController.safeName`
Duplicated private static helper in two controllers. Tiny DRY violation — extract to a shared helper or `AssetService` later if a third caller appears. (YAGNI; leave for now.)

### L4 — `LearnerAssetController.java:36` — path serves `FileSystemResource` even for non-ACTIVE assets
`AssetService.content()` filters to `state == ACTIVE` (line 115). Good — learners can't pull archived/soft-deleted bytes. Confirmed.

### L5 — `asset-image.tsx:38` — error fallback lacks retry affordance
If blob fetch fails (e.g., transient 502, expired access mid-render after refresh fails), the component shows "Không tải được ảnh" with no retry. Acceptable for v1 (user can remount), but consider a small retry button if this surfaces in QA.

### L6 — `e2e-backend-stub.mjs:549` — content route matches both `/admin/assets/...` and `/assets/...`
Regex `^\/api\/v1\/(admin\/)?assets\/([0-9a-f-]+)\/content$` accepts either path — good forward-compat for the learner endpoint when the stub needs to serve it. Confirmed.

## Edge Cases Verified

| Case | Result |
|------|--------|
| StrictMode double-mount | `cancelled` flag + cleanup revokes correctly — safe |
| `contentUrl` change | Dep-array re-runs effect; cleanup revokes prior URL — safe |
| 401 → refresh retry | `fetchAssetBlob` mirrors `apiFetch` single-flight refresh — safe |
| `contentUrl` null/undefined | Early-return sets `loading:false` — safe |
| Upload >12MB multipart body | BFF route returns 413 before forwarding — correct |
| Upload >10MB accepted by BFF (<12MB) | Backend `AssetService` rejects — correct defense-in-depth |
| Non-ACTIVE asset via learner endpoint | `AssetService.load` filters ACTIVE only — safe |
| Asset ID path traversal | UUID `PathVariable` + `id + "." + ext` filename construction — no traversal |
| Stub `/api/v1/assets/{id}/content` (learner path) | Strict-401 enforced on both admin and learner paths — correct |
| `set-cookie` from upstream | Filtered out — correct |
| `content-length` upstream | Filtered via `HOP_BY_HOP` — correct |

## Positive Observations

- `validateAssetFile` returns Vietnamese errors matching admin UX language; backend remains authoritative.
- `fetchAssetBlob` reuses `coordinatedRefresh` — single-flight across multiple `<AssetImage>` instances on one page prevents refresh-token rotation storms.
- `use-asset-object-url` correctly revokes on unmount AND `contentUrl` change — no leaked object URLs.
- `uploadAsset` mirrors `apiFetch` 401-retry pattern rather than duplicating bespoke logic.
- Multipart route correctly strips `content-length` + `set-cookie` upstream — avoids header smuggling and cookie leakage.
- Stub regex `(admin/)?` accepts both admin and learner content paths — forward-compatible.
- `LearnerAssetController` javadoc explicitly calls out the security inheritance model — good documentation of a non-obvious dependency on `anyRequest().authenticated()`.
- e2e asserts `img[src^="blob:"]` — actually proves the authenticated-fetch→object-URL path (a `data:` or straight URL would fail).
- `AssetService.content()` checks `p.startsWith(storageDir)` — belt-and-suspenders against path traversal even though UUID prevents it.

## Confirmed Issues

**None.** All P1-P4 requirements verified against the code.

## Plausible Risks

1. **Memory:** ~20 simultaneous `<AssetImage>` on a 24-asset page each hold a Blob → ~200 MB worst-case if all are 10 MB. Page size is small enough that this is acceptable today; if pages grow, consider a shared `Map<contentUrl, objectUrl>` cache with refcounting.
2. **`/api/proxy` allows GET without auth header check** — relies on backend to 401. That's correct (defense in depth at backend), and matches the brief.
3. **`assetContentSrc` is exported but unused** — kept as utility for future non-`<img>` consumers. Dead code today; YAGNI says drop it, but it's 5 lines and documented. Minor.

## NITs

- `asset-api.ts:23` — `UPLOAD_PATH` constant exists but `fetchAssetBlob` hardcodes `/api/proxy` prefix. Consistent — fine.
- `use-asset-object-url.ts` — the `{ src, loading, error }` object shape could be a `useReducer` for clarity, but `useState` with atomic `setState` is fine at this size.
- `evidence-authoring.spec.ts:104` — `toHaveAttribute("src", /^blob:/)` is the right assertion. Could also assert `img.naturalWidth > 0` for extra certainty the blob actually decoded (currently the `<img>` could have a `blob:` src that fails to decode). Playwright's `toBeVisible` would still pass on a broken image. Low-priority hardening.

## Recommended Actions

1. **None blocking.** The bugfix is solid and ships cleanly.
2. Optional: drop unused `assetContentSrc` or wire it where a non-`<img>` consumer needs it.
3. Optional: strengthen e2e with `await expect(img).toHaveJSProperty("naturalWidth", ...)` > 0 to prove the blob decodes, not just has the right `src` shape.
4. Optional: extract `safeName` from `LearnerAssetController`/`AdminAssetController` to a shared helper if a third controller appears (currently fine — YAGNI).

## Metrics
- Type Coverage: High (all paths typed; `AdminAsset` reused; no `any`).
- Test Coverage: 6 new unit tests cover `validateAssetFile` happy/error paths and `assetContentSrc`. e2e covers the auth-blob flow.
- Linting Issues: 0 (per pre-verified gates).

## Unresolved Questions
- Is there a plan for the learner mobile client to consume `/api/v1/assets/{id}/content` directly (with Bearer), or will it also proxy through a learner-side BFF? `LearnerAssetController` is in place; confirming the consumer's expected URL shape would be good before publish.
