# Animation AI Tooling — Integration Report

Date: 2026-10-24. Scope: tooling integration only — no product code, DB, or animation engine touched.

## Status matrix

| Tool | Installed | Connected | Verified | Notes |
|---|---|---|---|---|
| PixiJS Agent Skills (26) | YES | n/a | YES | From `pixijs/pixijs-skills` → `.agents/skills/pixijs-*` + symlinked to `.claude/skills/`. Skills available: application, assets, scene-*, events, filters, blend-modes, performance, ticker, environments, migration-v8, math, color, html-source, custom-rendering, accessibility, create, core-concepts |
| LottieFiles Motion Design Skill | YES | n/a | YES | `LottieFiles/motion-design-skill` → `.agents/skills/motion-design` + `.claude/skills/motion-design`. Covers timing/easing/choreography/Disney principles |
| Lottie Creator MCP | YES | NO (needs browser bridge) | PARTIAL | Registered as `lottiefiles-creator` in `~/.claude.json` (`npx -y @lottiefiles/creator-mcp@latest`). Spawns successfully — `WebSocket server listening on 127.0.0.1:3847` + stdio MCP. `claude mcp list` shows CONNECTION_CLOSED because server is a **bridge**: needs Creator open in browser + Settings → MCP → Enable local MCP. Status: `WAITING_FOR_USER` |
| Rive CLI | NO | n/a | n/a | `BLOCKED` — no official Windows distribution. rive.app/cli documents shell-script installer (macOS/Linux only); not on winget/scoop/npm. Need manual binary from https://rive.app/community/downloads or use Rive web editor + `.riv` runtime export |
| Figma MCP | YES | NEEDS_AUTH | REGISTERED | `claude plugin install figma@claude-plugins-official` v2.2.157 → registered `plugin:figma:figma https://mcp.figma.com/mcp`. `claude mcp list` reports `! Needs authentication` — user must run `/mcp` → figma → OAuth in browser. Status: `WAITING_FOR_USER` |
| GSAP readiness | n/a | n/a | READY | Docs at gsap.com/docs/v3 — no install needed now (will `npm install gsap` inside HTML animation workspace when created). Compatible with PixiJS in HTML pages |

## Environment

- OS: Windows 11 (`win32`), PowerShell 5.1
- Node v22.17.1, npm/npx 10.9.2, Claude Code 2.1.310
- Java JDK 21 for backend
- Docker running (`dauviet-postgres` healthy)

## Commands executed

```
npx -y skills add https://github.com/pixijs/pixijs-skills        # 26 skills
npx -y skills add LottieFiles/motion-design-skill                # 1 skill
claude mcp add lottiefiles-creator -- "npx -y @lottiefiles/creator-mcp@latest"
claude plugin install figma@claude-plugins-official
claude mcp list                                                  # verification
winget search rive                                               # Rive CLI lookup
```

## Existing tools untouched

- `gitnexus` skill still present in `.claude/skills/` — unaffected.
- `ccs-image-analysis`, `ccs-websearch` MCP connected — unaffected.
- `open-design`, `pencil` MCP already failing before this task (system-level, unrelated).
- `.claude/.backup/skills-20251024-…` snapshot taken before changes.

## File changes (this task only)

- `.agents/skills/pixijs*/`, `.agents/skills/motion-design/` — 27 new skill directories
- `.claude/skills/` — symlinks to the above (27)
- `.claude/.backup/skills-20251024-*/` — backup snapshot
- `~/.claude.json` — added `lottiefiles-creator` + `plugin:figma:figma` MCP entries (project-local scope)
- `docs/ANIMATION_AI_TOOLING.md` — this report

Pre-existing dirty working tree (31 files: admin animation UI, backend animation service, mobile) is **not** from this task — left untouched.

## Manual steps user must do

1. **Lottie Creator**: open https://creator.lottiefiles.com → sign in → Settings → MCP Settings → Enable local MCP → Creator will reach `ws://127.0.0.1:3847`. Once open, `claude mcp list` should show `lottiefiles-creator` connected.
2. **Figma**: run `/mcp` inside Claude Code → select `figma` → finish OAuth in browser. After that Figma read tools become available.
3. **Rive**: no Windows CLI — either (a) download Windows binary manually from https://rive.app/community/downloads if published later, (b) use `rive.app` web editor + export `.riv` for runtime, or (c) skip Rive and rely on PixiJS + Lottie + GSAP stack.
4. **open-design/pencil** MCP failures are pre-existing — separate issue.

## Tool routing guide

- **PixiJS** → 2D historical scenes, maps, effects, interactive hotspots (WebGL/WebGPU)
- **GSAP** → timelines, easing, sequencing inside HTML pages
- **Rive** → mascot/character animations with state machines (once CLI/binary available)
- **Lottie** → micro-animations, UI feedback, reward/celebration effects
- **Motion Design skill** → timing/easing/choreography review
- **Figma** → read design frames, layout, image specs
- **Lottie Creator** → natural-language Lottie animation generation

## Readiness for HTML Animation

Environment **partially ready**:

- Authoring skills (PixiJS 26 skills, motion-design, Figma read) — READY
- Lottie generation — needs browser bridge open
- Rive — BLOCKED on Windows (fallback: use Lottie or PixiJS for characters)
- HTML packaging toolchain — not yet set up (separate task: `webview_flutter` integration, asset pipeline, sandbox bridge contract)
- GSAP/PixiJS runtime — will be vendored into the HTML package when that workspace exists

**Next concrete step**: when ready to build HTML animations, create a dedicated `dau-viet-animation-sandbox/` workspace with `vite` + `pixi.js` + `gsap` and a `window.dauviet` JS bridge contract for progress reporting — keep it isolated from `dau-viet-mobile` until the Flutter embed path is decided.
