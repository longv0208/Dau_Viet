---
title: "Data-driven Historical Animation Engine & No-code Animation Builder"
description: "Animation Template → Scene → Scene Version → Lesson Version → Learner Attempt; RIVER_TIDE + JOURNEY_MAP renderers; admin no-code builder."
status: pending
priority: P1
effort: 16h
branch: main
tags: [animation, engine, builder, backend, flutter, admin]
created: 2026-10-23
---

# Data-driven Historical Animation Engine & No-code Animation Builder

## Overview

Replace hard-coded `HistoricalAnimationRegistry` (3 compiled Dart scenes) with a data-driven engine: backend stores animation templates/scenes/versions, lesson snapshots embed immutable manifests, Flutter renders from manifest via typed renderers, admin provides a form-based no-code builder.

## Phases

| Phase | File | Status | Effort |
|-------|------|--------|--------|
| 1. Backend domain/DB/API | `phase-01-backend-domain-api.md` | completed | 5h |
| 2. Snapshot & Flutter runtime | `phase-02-snapshot-flutter-runtime.md` | completed | 4h |
| 3. Admin Animation Builder | `phase-03-admin-animation-builder.md` | completed | 5h |
| 4. Migration & hardening | `phase-04-migration-hardening.md` | completed (docs + V15 seed + AnimationSeedManifestTest; Postgres ITs pending Docker) | 2h |

**State on 2026-10-23 (post code-review):** all four phases implemented + reviewer findings fixed.
- Phase 1: V14 + `com.dauviet.animation` domain/services/controllers + `AnimationManifestValidator`.
- Phase 2: `ValidationContext`/`ReadValidator.validateAnimationRef`/`SnapshotBuilder.embedAnimationScenes`; Flutter `runtime/` registry + RIVER_TIDE/JOURNEY_MAP renderers bridging manifest → `HistoricalAnimationDefinition` (273/273 `flutter test`).
- Phase 3: admin `/animations` nav + library/picker/editor/versions screens, timeline + river + journey-map editors, live interactive preview, publish section with validate→publish gate, `AnimationPicker` replaces `animationKey` in `read-editor.tsx`. `tsc --noEmit` clean, `next lint` clean, vitest 138/138.
- Phase 4: `V15__animation_seed.sql` (system user + 2 templates + 3 published scenes, DRAFT→versions→current_version_id→PUBLISHED ordering to satisfy `chk_animation_scene_published_version`); `AnimationSeedManifestTest` validates each seeded manifest (3/3).
- **Review fixes (2026-10-23):** B1 V15 CHECK-constraint ordering; M1 checksum unified on canonical `snapshot_json::text` (publish service + V15 + docs); M2 `ANIMATION_SCENE_VERSION_MISMATCH` implemented (`sceneVersionToScene` map + `findIdAndSceneId`); m1 `initialState` seeds painters (`_seedRiver`/`_seedMap`); m2 `SnapshotBuilder` log.warn instead of silent-catch; m4 publish reads fresh `rowVersion` from query cache; m5 +8 `DraftValidatorTest` cases for all `validateAnimationRef` branches; m6 asset-refs "in use" semantic documented. Backend unit tests 203/204 — sole error is `DauVietApplicationTests` (Testcontainers) because the Docker daemon is off; all `*IT` integration tests remain unrun for the same reason.

## Key Dependencies

- Phase 1 → Phase 2: backend must expose scene version manifest before Flutter can resolve it.
- Phase 1 → Phase 3: admin builder consumes the same admin API.
- Phase 2 → Phase 4: seed data relies on manifest schema + renderer codes being stable.
- Phase 3 → Phase 4: builder UI produces manifests that must pass backend validation.

## Constraints

- No commit/push. No Playwright. Do not overwrite uncommitted mobile changes (router.dart, learner_dashboard_screen.dart, profile-screen.dart).
- Do not rewrite Learning Engine. Correctness/progress/reward stays backend-authoritative.
- No eventId-based renderer branching. Generic renderers only.
- No executable code in manifest — whitelisted ops only.
