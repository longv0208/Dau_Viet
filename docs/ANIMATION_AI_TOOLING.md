# Animation AI Tooling — Integration Report

Date: 2026-10-24 (re-verified same day). Scope: tooling integration only — no product code, DB, or animation engine touched.

## Status matrix

| Tool | Installed | Connected | Verified | Notes |
|---|---|---|---|---|
| PixiJS Agent Skills (26) | YES | n/a | YES | From `pixijs/pixijs-skills` → `.agents/skills/pixijs-*`, junction-linked to `.claude/skills/`. All 26 dirs contain valid `SKILL.md` frontmatter; all appear in the Skill tool catalog (pixijs, pixijs-application, pixijs-assets, pixijs-scene-*, pixijs-events, pixijs-filters, pixijs-blend-modes, pixijs-performance, pixijs-ticker, pixijs-environments, pixijs-migration-v8, pixijs-math, pixijs-color, pixijs-html-source, pixijs-custom-rendering, pixijs-accessibility, pixijs-create, pixijs-core-concepts). Covers PixiJS v8 |
| Motion Design Skill | YES | n/a | YES | `LottieFiles/motion-design-skill` → `.agents/skills/motion-design`. SKILL.md verified — timing/easing/choreography/Disney principles; works with GSAP/Lottie/CSS |
| GitNexus skill group | YES | n/a | YES | `.claude/skills/gitnexus/` holds 6 real (non-junction) skill dirs — `gitnexus-cli/debugging/exploring/guide/impact-analysis/refactoring`, all with SKILL.md. Untouched by this task |
| Lottie Creator MCP | YES | NO — CONNECTION_CLOSED | PARTIAL | `lottiefiles-creator` in `~/.claude.json` (`npx -y @lottiefiles/creator-mcp@latest`). Spawns OK: `WebSocket server listening on 127.0.0.1:3847` + stdio MCP. It is a **bridge**: `claude mcp list` shows CONNECTION_CLOSED until Creator is open in browser with local MCP enabled. Status: `WAITING_FOR_USER` |
| Rive CLI | YES | n/a | YES | v1.7.0 via official `https://releases.rive.app/cli/install.ps1` → `C:\Users\FPTSHOP\.rive\bin\rive.exe`. `rive --version` → `rive 1.7.0` (exit 0). Commands: create / preview / docs / samples / schema / inspect / push / pull / library / ls / login. `login` needed only for publish/push/ls — offline authoring works without it |
| Figma MCP | YES | NEEDS_AUTH | REGISTERED | Plugin `figma@claude-plugins-official` v2.2.157 → `plugin:figma:figma https://mcp.figma.com/mcp` — `claude mcp list`: `! Needs authentication`. Read-only verify call (`authenticate`/`complete_authentication` tools visible but gated). Status: `WAITING_FOR_USER` — run `/mcp` → figma → OAuth |
| GSAP readiness | n/a | n/a | READY | No install needed now. Will `npm i gsap` inside future HTML animation workspace. Technically compatible with HtmlDocumentValidator when vendored inline |

## Rive CLI install — what was verified

- Installer: `https://releases.rive.app/cli/install.ps1` (220 lines, inspected before running).
- Safety: SHA-256 tarball checked against `manifest.json`; tar members rejected if containing `..`, `\`, `:` or leading `/`; extracted `rive.exe` rejected if symlink; installs only into `%USERPROFILE%\.rive` (`versions/<ver>/rive.exe`, hardlink muxer in `bin/`); adds `%USERPROFILE%\.rive\bin` to **User** PATH (no admin needed).
- Result: `rive 1.7.0` on `windows-x64`, stream `stable`.
- Note: earlier conclusion "no Windows CLI" was outdated — rive.app/agents now ships this installer.

## Skills inventory & duplicates (step 4)

- `.agents/skills/` — 27 real dirs (26 pixijs-* + motion-design). **Source of truth.**
- `.claude/skills/` — 28 entries: 27 junctions → `.agents/skills/*` (not byte copies — delete a junction safely removes only the link) + 1 real dir `gitnexus/` (pre-existing).
- `.claude/.backup/skills-20261024-1643/` — full pre-change snapshot (27 pixijs/motion dirs + gitnexus). Byte-duplicate of `.agents/skills` — kept as rollback point per task constraint; safe to delete manually once setup is stable.
- No stray/duplicate SKILL.md outside these three roots.

## MCP manual steps still required from user

1. **Figma**: in Claude Code run `/mcp` → select `figma` → complete OAuth in browser. After that `get_design_context` etc. become callable.
2. **Lottie Creator**: open https://creator.lottiefiles.com → Settings → MCP Settings → Enable local MCP; keep Creator tab open while using the bridge. Then `lottiefiles-creator` will show Connected.
3. **open-design / pencil** MCPs also CONNECTION_CLOSED — pre-existing, unrelated to this task (separate desktop apps).

## PixiJS + GSAP self-contained HTML vs HtmlDocumentValidator (step 5 — technical read, no code changes)

Validator: `dau-viet-backend/.../manifest/HtmlDocumentValidator.java` — runs BEFORE persistence, rejects:

- `<script src=…>`, `<link href=…>`, `@import`, ES `import … from` URL/relative, dynamic `import('http|//|.|…')` — **PixiJS/GSAP must be vendored as inline `<script>` text, not src.**
- Any `src`/`href` attribute whose value is `http(s)://`, `//`, `./`, `../`, or ends with a media/code extension — images/fonts/audio must be `data:` URIs (or inline SVG).
- `fetch(`, `XMLHttpRequest`, `new WebSocket|EventSource|RTCPeerConnection`, `navigator.sendBeacon|share`, `window.open`, `location.assign/replace/href=`, `<iframe>`, `<form>`, `<object|embed|applet>`, `<base href>`, `<meta http-equiv=refresh>`, `localStorage|sessionStorage|indexedDB.open|caches.open|serviceWorker`, reporting APIs — **all banned**.
- Also: strict UTF-8, `.html/.htm` only, `≤ 15 MB` (`dauviet.animations.html.max-bytes`), must contain `<html` or `<!doctype`, max 10 errors reported.

Consequences for PixiJS+GSAP bundle:

- **Compatible** — both are pure JS, bundle to a single inline `<script>` block fine (pixi.js min ~400-500 KB, gsap ~70 KB; well under 15 MB).
- PixiJS v8 default workers/WebWorkers for some features must be disabled (workers create blob URLs — blob: `src=` is not explicitly banned but network-less is safest; `preference:'webgl'` renderer works without workers).
- GSAP `window`/`document` usage fine; avoid plugins that lazy-load.
- Assets: raster art → base64 `data:image/png;…` or inline SVG; fonts → `data:font/woff2;…` in `@font-face`; audio → `data:audio/…`.
- Must not call `localStorage` (save state must flow via the `window.dauviet` postMessage bridge, not storage), no `fetch` for telemetry.
- Verdict: **YES, technically compatible** — single-file PixiJS+GSAP HTML passes the validator if built with everything inlined and zero external/network/storage calls. Constraint set is strict but achievable; the future sandbox workspace should include a lint step mirroring these regexes to fail fast before upload.

## File changes (this task)

- `C:\Users\FPTSHOP\.rive\` — new (rive CLI; outside repo)
- `%PATH%` (User env) — added `C:\Users\FPTSHOP\.rive\bin`
- `docs/ANIMATION_AI_TOOLING.md` — this report
- Nothing else; `.agents/skills`, `.claude/skills`, `.claude/.backup`, `~/.claude.json` unchanged since prior session. 31 dirty product files in `git status` are pre-existing user work.

## Readiness for HTML Animation

- Authoring: PixiJS 26 skills + motion-design + Rive CLI ready now; Figma pending OAuth; Lottie bridge pending Creator tab.
- Runtime: PixiJS+GSAP confirmed compatible with `HtmlDocumentValidator` — green path for the HTML-animation pipeline.
- Still missing (separate task): `dau-viet-animation-sandbox/` workspace with vite + vendored pixi.js/gsap + `window.dauviet` bridge contract + a pre-upload lint mirroring validator rules.
- Blockers remaining: Figma OAuth (user), Lottie local MCP toggle (user), open-design/pencil MCP (unrelated pre-existing).
