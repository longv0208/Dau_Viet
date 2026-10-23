---
title: "Cinematic 2.5D Historical Experience Engine"
description: "Extend the data-driven animation engine with layered scene graph, camera, keyframe tracks, environment effects, audio cues, and a no-code admin editor — schemaVersion 2, backward compatible."
status: implementing
priority: P2
effort: 40h
branch: main
tags: [animation, cinematic, 2.5d, schema-v2, admin, flutter]
created: 2026-10-24
---

# Cinematic 2.5D Historical Experience Engine

Epic goal: turn the existing manifest-driven animation engine (V14/V15, schemaVersion 1) into a layered, camera-driven cinematic renderer with keyframe motion, environment effects, audio cues, and a no-code scene editor — while keeping every v1 scene playable.

## Hard constraints (audit-verified)

- No engine rewrite. Extend `AnimationManifestSchema`/`AnimationManifestValidator`, `AnimationManifestDto`, `HistoricalAnimationPlayer`, `ScenePreview`, not replace.
- Manifest is whitelisted DATA. No eventId branches in renderers/handlers.
- Published snapshots immutable (V14 trigger). Lesson attempts pin to published versions.
- Backend authoritative. No client-side grading/reward/completion changes.
- Legacy `animationKey` and `HistoricalAnimationRegistry` stay working.
- schemaVersion 1 snapshots must render unchanged on old and new runtimes.
- No Playwright; no commit/push; no new Dart file per event.
- Reduced-motion semantics preserved (skip tween → static state, 4s hold).

## Schema strategy

**Decision: extend, keep `schemaVersion: 1` → bump to `schemaVersion: 2` only when new features are used.** Rationale: V14 published snapshots (3 scenes seeded by V15) already render fine on the v1 parser. New fields are optional top-level keys; if absent the manifest is a v1 manifest. If any new key is present, `schemaVersion` must be ≥2 — validator enforces this so old clients fail loudly instead of silently ignoring camera/tracks.

New top-level keys (all optional, all whitelisted):

| Field | Shape | Notes |
|-------|-------|-------|
| `camera` | `{ initial: {x,y,zoom}, steps: [{target, durationMs, easing}] }` | `target` = `{x,y,zoom, focusObjectId?, focusLocationId?}`; normalized 0..1 center; zoom 0.5..3.0 |
| `tracks` | `[{ objectId, property, keyframes: [{tMs, value, easing?}] }]` | `property` ∈ {`position`,`scale`,`rotation`,`opacity`,`visible`}; `value` shape depends on property |
| `effects` | `[{ type, durationMs?, params? }]` | `type` ∈ {`WATER_RIPPLE`,`MIST`,`GLOW`,`ROUTE_REVEAL`,`FADE_IN`,`FADE_OUT`} — extends existing step-effects whitelist |
| `audio` | `[{ stepId, assetRef, cue: ENTER\|EXIT\|LOOP, volume, fadeMs? }]` | `assetRef` resolves to `assets[]` role AUDIO; lifecycle-safe (no play if skipped/muted) |
| `environment` | `{ waterLevel?, mist?, glow? }` | scene-level ambient overrides — RIVER only |

Validator additions (all path/code/message errors):
- `camera` bounds: x/y 0..1, zoom 0.5..3.0, focus refs must exist in `objects[]`/`map.locations[]`.
- `tracks`/`keyframes`: objectId must exist in `objects[]`; property whitelist; keyframe `tMs` ascending, within scene duration sum; value type-checked per property.
- `effects[].type` whitelist; `params` bounded JSON object.
- `audio[].assetRef` must resolve to `assets[]` entry with `role=AUDIO` and assetId ACTIVE; `volume` 0..1.
- `schemaVersion` rule: if any v2-only key present, `schemaVersion` must be ≥2.

## Phase files

| Phase | Title | Files |
|-------|-------|-------|
| 01 | Manifest schema v2 + validator | `phase-01-manifest-schema-v2.md` |
| 02 | Flutter runtime: camera + keyframe engine | `phase-02-flutter-camera-keyframes.md` |
| 03 | Flutter runtime: layered scene graph + effects | `phase-03-flutter-scene-graph-effects.md` |
| 04 | Flutter audio cues | `phase-04-flutter-audio-cues.md` |
| 05 | Admin editor: camera, tracks, effects, audio | `phase-05-admin-editor-v2.md` |
| 06 | Demo scenes + reduced-motion + docs | `phase-06-demo-scenes-docs.md` |

## Dependencies

- Phase 01 unblocks 02–05 (schema + validator define the contract).
- Phase 02 depends on 01 (DTO + parser must know v2 fields).
- Phase 03 depends on 02 (scene graph consumes camera/keyframe state).
- Phase 04 depends on 01 (audio whitelist + role check).
- Phase 05 depends on 01 (admin types mirror backend).
- Phase 06 depends on 02–05 (demos exercise everything).

## Success criteria

- All 3 V15 published scenes render identically on the new runtime (regression).
- At least 3 new demo scenes using camera+tracks+effects+audio (Bạch Đằng, Hai Bà Trưng, Lý Thái Tổ upgraded).
- Admin can edit every new field without touching JSON.
- `flutter test` / `mvn test` / `vitest` suites pass; widget tests cover camera, tracks, audio lifecycle, reduced-motion.
- Preview parity: `scene-preview.tsx` and Flutter `SceneRenderer` agree on geometry for every whitelisted field.
- Backend validator rejects unknown keys, out-of-range values, missing refs — including negative tests.

## Risks / unresolved questions

- Docker daemon still off → Testcontainers ITs remain blocked; MockMvc+unit tests only.
- Audio MIME type currently whitelisted to `image/png|jpeg|webp` — needs `audio/mpeg`/`audio/wav`/`audio/ogg` extension or a separate `asset_kind` gate (decision in Phase 01).
- Preview parity: admin preview is SVG; Flutter is CustomPainter — new camera/transform math must be duplicated carefully or centralized into a shared pure-Dart spec consumed by both (see Phase 02).
- Reduced-motion semantics for camera moves: jump to final camera state per step, not interpolate.
