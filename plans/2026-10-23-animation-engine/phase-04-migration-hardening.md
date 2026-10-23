# Phase 4 — Seed Migration, Versioning & Security Hardening

## Context Links

- `dau-viet-backend/src/main/resources/db/migration/` — existing V1–V13 patterns
- `dau-viet-backend/src/main/resources/db/migration/beforeEachMigrate.sql` — pre-migration callback
- `dau-viet-backend/src/main/resources/db/migration/V7__seed_default_lesson_template.sql` — seed data pattern
- `dau-viet-mobile/lib/features/learning/presentation/animations/content/bach_dang_938_tide_v1.dart` — source data for RIVER_TIDE seed
- `dau-viet-mobile/lib/features/learning/presentation/animations/content/hai_ba_trung_40_uprising_v1.dart` — source data for JOURNEY_MAP seed 1
- `dau-viet-mobile/lib/features/learning/presentation/animations/content/ly_thai_to_1010_relocation_v1.dart` — source data for JOURNEY_MAP seed 2
- `docs/API_SPEC.md` — API contract
- `docs/DATABASE_DESIGN.md` — DB design
- `docs/LEARNING_ENGINE_DESIGN.md` — learning engine
- Phase 1 file — animation engine domain/API
- Phase 2 file — snapshot integration + Flutter runtime

## Overview

- **Priority:** P1
- **Status:** pending
- **Effort:** 2h

**Verification notes (2026-10-23):**
- V14 schema is implemented — `animation_scene_versions.published_by` is `NOT NULL REFERENCES users(id)` (NOT nullable). V15 must either insert a system/admin user first OR relax the column. Decision needed before writing the seed.
- `animation_scenes.created_by`/`updated_by` are `REFERENCES users(id)` (nullable allowed — but V14 has no explicit `NOT NULL` here, confirmed).
- `historical_events` has NO seed data in V1 — scene `event_id` will be `NULL` unless V15 also seeds events. Decide: allow `event_id NULL` (schema already permits it — `event_id UUID REFERENCES historical_events(id)` without NOT NULL).
- `AbstractPostgresIT.clearAuthoringTables` already cleans animation tables — ITs exist.

Seed the 3 existing Dart-coded animations as database records, handle all versioning edge cases, apply security bounds, and update documentation.

## Key Insights

- The 3 Dart animation definitions contain real data: `bachDang938TideV1` (6 steps, river scene), `haiBaTrung40UprisingV1` (6 steps, map scene, 3 locations, 2 routes), `lyThaiTo1010RelocationV1` (5 steps, map scene, 2 locations, 1 route). These must be translated to manifest JSON — NOT copied as code.
- Seed mechanism choice: V15 SQL migration with deterministic UUIDs is simpler and more reliable than a separate import command — no runtime dependency, applies atomically with schema, works on fresh + existing DBs via `ON CONFLICT DO NOTHING`.
- Immutable trigger already prevents UPDATE/DELETE on published versions — enforced at DB level.
- Legacy `animationKey` snapshots continue to work because `HistoricalAnimationRegistry` is untouched.

## Requirements

### Functional

1. V15 Flyway migration: seed 2 `animation_templates` (RIVER_TIDE, JOURNEY_MAP) + 3 `animation_scenes` + 3 `animation_scene_versions` with deterministic UUIDs and manifest JSON.
2. Seed data is idempotent — `ON CONFLICT DO NOTHING` on all inserts.
3. Versioning cases handled:
   - Case 1: Attempt pins a scene version — archive scene does NOT delete version.
   - Case 2: Scene archive → no new publishes, but existing version remains accessible.
   - Case 3: Asset referenced in manifest cannot be retired while version references it (add to EVIDENCE_IN_USE-style scan or document policy).
   - Case 4: Old app gets unknown rendererCode → fallback to text READ (no crash).
   - Case 5: Legacy `animationKey` → `HistoricalAnimationRegistry` still works.
   - Case 6: Concurrent publish → serialized by pessimistic lock, unique constraint backstop.
4. Security bounds enforced: MIME types on assets, JSON size limit, depth limit, object count limit.
5. Malformed JSON → 400, not 500.
6. Concurrent publish → serialized, no duplicate version_no.
7. No executable code in manifest — only whitelisted operations.
8. Docs updated: API_SPEC.md, DATABASE_DESIGN.md, LEARNING_ENGINE_DESIGN.md.

### Non-functional

- Seed manifests must produce pixel-identical behavior to the existing Dart-coded animations (verified via Flutter widget tests).
- Idempotent seed — safe to run multiple times.

## Architecture

### Seed Strategy: V15 SQL Migration

Chosen over Java import command because:
- Atomic with schema (no partial state).
- Deterministic UUIDs prevent duplication across environments.
- No runtime code path to maintain.
- Follows existing V7 seed pattern.

Trade-off: SQL is verbose for JSON manifest — mitigate by keeping manifest compact (no unnecessary whitespace, use consistent key ordering).

### Seed Data Details

**Templates:**

| code | name | renderer_code | capabilities |
|------|------|--------------|-------------|
| `RIVER_TIDE` | Thủy triều và bãi cọc | `RIVER_TIDE` | `{"waterControl":true,"boatAnimation":true,"stakeField":true}` |
| `JOURNEY_MAP` | Bản đồ hành trình | `JOURNEY_MAP` | `{"markerPlacement":true,"routeDrawing":true,"locationExplorer":true}` |

**Scenes (3):**

1. `bach_dang_938_tide_v1` → RIVER_TIDE, event_id → Bạch Đằng 938 event
   - 6 steps: Chuẩn bị → Nước dâng → Dụ địch vào bãi → Nước rút → Phản công phối hợp → Tổng kết
   - initialState: waterLevel=0.30, boatProgress=0, boatCount=3, stakes[9 items], decoyProgress=0, counterattackProgress=0, hasWaterControl=true, obstructed=false, showSequenceSummary=false
   - Prediction: reveal waterLevel=0.22, boatsObstructed=true, highlightStakes=true
   - Disclaimer: Bảo tàng Lịch sử Quốc gia source

2. `hai_ba_trung_40` → JOURNEY_MAP, event_id → Hai Bà Trưng event
   - 6 steps: Bối cảnh → Khởi nghĩa bùng lên → Quy tụ lực lượng → Hướng về Luy Lâu → Khám phá bản đồ → Ý nghĩa
   - 3 locations: hat_mon(0.30,0.62), me_linh(0.48,0.42), luy_lau(0.72,0.34)
   - 2 routes: gather(hat_mon→me_linh via 0.40,0.55), advance(me_linh→luy_lau via 0.60,0.40)
   - Prediction: reveal highlighted luy_lau
   - Disclaimer: Bảo tàng Lịch sử Quốc gia source

3. `ly_thai_to_1010` → JOURNEY_MAP, event_id → Lý Thái Tổ event
   - 5 steps: Hoa Lư — kinh đô cũ → Cân nhắc dời đô → Đại La được chọn → Dời đô năm 1010 → Thăng Long
   - 2 locations: hoa_lu(0.28,0.70), dai_la(0.62,0.40)
   - 1 route: relocation(hoa_lu→dai_la via 0.45,0.58)
   - Prediction: reveal highlighted dai_la
   - Disclaimer: Bảo tàng Lịch sử Quốc gia source

## Related Code Files

### Create

| File | Purpose |
|------|---------|
| `dau-viet-backend/src/main/resources/db/migration/V15__seed_animation_engine.sql` | Seed templates + scenes + versions |
| `dau-viet-backend/src/test/java/com/dauviet/animation/AnimationSeedIT.java` | Verify seed data integrity |

### Modify

| File | Change |
|------|--------|
| `docs/API_SPEC.md` | Add animation endpoints table |
| `docs/DATABASE_DESIGN.md` | Add animation tables to ERD + table list |
| `docs/LEARNING_ENGINE_DESIGN.md` | Add animation engine section |
| `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_registry.dart` | Keep as legacy fallback — no change needed (verify only) |

## Implementation Steps

### Step 1: V15__seed_animation_engine.sql

```sql
-- Step 1a: bootstrap system user for published_by/created_by/updated_by
-- (V2 has NO seed admin; animation_scene_versions.published_by is NOT NULL).
-- Password hash is a deterministic bcrypt of a throwaway passphrase — the
-- account is for FK references, not for login (disable via a flag/role if
-- the schema supports it; otherwise document as system-only).
INSERT INTO users (id, email, password_hash, display_name, status, created_at, updated_at)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'system@dauviet.local',
    '$2a$10$SystemSeedPlaceholderHashOnlyForForeignKeyRef0000000000000',
    'System Seed',
    'ACTIVE',
    now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- Step 1b: Templates (deterministic UUIDs)
INSERT INTO animation_templates (id, code, name, description, renderer_code,
    renderer_version, schema_version,
    capabilities_json, default_config_json, enabled)
VALUES
  ('a1b2c3d4-0000-4000-8000-000000000001', 'RIVER_TIDE',
   'Thủy triều và bãi cọc',
   'Mô phỏng tương tác mực nước sông, thuyền và vật cản ngầm.',
   'RIVER_TIDE', 1, 1,
   '{"waterControl":true,"boatAnimation":true,"stakeField":true,"decoySupport":true,"counterattackSupport":true,"sequenceSummary":true}'::jsonb,
   '{"canvas":{"aspectRatio":1.6,"width":800,"height":500}}'::jsonb,
   true),
  ('a1b2c3d4-0000-4000-8000-000000000002', 'JOURNEY_MAP',
   'Bản đồ hành trình',
   'Bản đồ schematic với địa điểm, tuyến đường và khám phá tương tác.',
   'JOURNEY_MAP', 1, 1,
   '{"markerPlacement":true,"routeDrawing":true,"locationExplorer":true,"tapToExplore":true}'::jsonb,
   '{"canvas":{"aspectRatio":1.6,"width":800,"height":500}}'::jsonb,
   true)
ON CONFLICT (code) DO NOTHING;

-- Step 1c: Scenes — event_id LEFT NULL because no historical_events are
-- seeded yet (V1 creates the table only). When events are seeded, admins
-- can link scenes via PATCH. Deterministic UUIDs.
INSERT INTO animation_scenes (id, template_id, event_id, title, draft_json,
    status, current_version_id, created_by, updated_by, row_version)
VALUES
  ('b1b2c3d4-0000-4000-8000-000000000001',
   'a1b2c3d4-0000-4000-8000-000000000001',
   NULL,
   'Trận Bạch Đằng năm 938',
   '{...manifest JSON...}'::jsonb,
   'PUBLISHED',
   'c1b2c3d4-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001',
   1),
  ('b1b2c3d4-0000-4000-8000-000000000002',
   'a1b2c3d4-0000-4000-8000-000000000002',
   NULL,
   'Khởi nghĩa Hai Bà Trưng năm 40',
   '{...manifest JSON...}'::jsonb,
   'PUBLISHED',
   'c1b2c3d4-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001',
   1),
  ('b1b2c3d4-0000-4000-8000-000000000003',
   'a1b2c3d4-0000-4000-8000-000000000002',
   NULL,
   'Lý Thái Tổ dời đô năm 1010',
   '{...manifest JSON...}'::jsonb,
   'PUBLISHED',
   'c1b2c3d4-0000-4000-8000-000000000003',
   '00000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-000000000001',
   1)
ON CONFLICT (id) DO NOTHING;

-- Step 1d: Scene versions — composite-FK shape must match:
-- UNIQUE (scene_id, version_no) + UNIQUE (id, scene_id). Checksum via
-- SHA-256 of canonical snapshot_json — compute in a Java helper during
-- migration authoring, then hard-code hex (no in-SQL hashing needed).
INSERT INTO animation_scene_versions
    (id, scene_id, version_no, schema_version, renderer_code, renderer_version,
     snapshot_json, manifest_checksum, published_at, published_by)
VALUES
  ('c1b2c3d4-0000-4000-8000-000000000001',
   'b1b2c3d4-0000-4000-8000-000000000001', 1, 1, 'RIVER_TIDE', 1,
   '{...manifest JSON for Bạch Đằng...}'::jsonb,
   '<64-hex-sha256>',
   now(),
   '00000000-0000-4000-8000-000000000001'),
  -- ... hai_ba_trung_40, ly_thai_to_1010
ON CONFLICT (scene_id, version_no) DO NOTHING;
```

The manifest JSON for each scene is generated by translating the Dart `HistoricalAnimationDefinition` to the manifest schema — same data, different format. Write a one-time conversion or hand-craft the JSON.

**Important (verified):** `V2__users_and_auth.sql` does NOT contain a seed admin user — `users` requires `email`/`password_hash` NOT NULL and there is no INSERT. `animation_scene_versions.published_by` is `NOT NULL` in V14. Two acceptable resolutions:
   - **Option A (recommended):** V15 first inserts a deterministic system user (`id='00000000-0000-4000-8000-000000000001'`, email `system@dauviet.local`, password_hash=random-hex placeholder, role via `user_roles`) then uses it as `published_by`/`created_by`/`updated_by`.
   - **Option B:** ALTER `published_by` to nullable in V15 — simpler but weakens audit trail; NOT recommended since lesson_versions keeps `published_by` NOT NULL.
   Choose Option A; flag the bootstrap user clearly in the migration comment.

### Step 2: Generate manifest JSON for each scene

For each of the 3 Dart files, hand-translate to manifest JSON:

**bach_dang_938_tide_v1 manifest:**
```json
{
  "schemaVersion": 1,
  "rendererCode": "RIVER_TIDE",
  "rendererVersion": 1,
  "title": "Trận Bạch Đằng năm 938",
  "learningObjective": "Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều, việc dụ thuyền địch và thời điểm phản công phối hợp trong chiến thắng Bạch Đằng.",
  "canvas": {"aspectRatio": 1.6, "width": 800, "height": 500},
  "assets": [],
  "objects": [
    {"id":"stake_01","type":"STAKE","position":{"x":0.42,"y":0.0},"scale":1.0,"rotation":0,"visible":true,"layer":1,"properties":{"length":0.20}},
    ... (9 stakes total)
    {"id":"boat_01","type":"BOAT","position":{"x":1.05,"y":0.0},"scale":1.0,"rotation":0,"visible":true,"layer":2},
    {"id":"decoy_01","type":"DECOY","position":{"x":1.10,"y":0.0},"scale":1.0,"rotation":0,"visible":false,"layer":2},
    {"id":"counter_01","type":"BOAT","position":{"x":-0.08,"y":0.0},"scale":1.0,"rotation":0,"visible":false,"layer":2}
  ],
  "initialState": {
    "waterLevel": 0.30, "boatProgress": 0.0, "boatCount": 3,
    "decoyProgress": 0, "counterattackProgress": 0,
    "hasWaterControl": true, "obstructed": false, "showSequenceSummary": false,
    "highlightStakes": false
  },
  "steps": [
    {"id":"step_01","title":"Chuẩn bị","narration":"...","durationMs":1100,
     "targetState":{"waterLevel":0.30,"boatProgress":0.0,"boatsObstructed":false},
     "easing":"easeInOut","effects":[]},
    ... (6 steps)
  ],
  "interactions": {"prediction": {...}},
  "disclaimer": "Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng chính xác trận đánh.",
  "sourceReferences": ["Bảo tàng Lịch sử Quốc gia — \"Ngô Quyền và chiến thắng Bạch Đằng năm 938\" (baotanglichsuquocgia.vn)."]
}
```

(Similar translation for hai_ba_trung_40 and ly_thai_to_1010 — locations become MARKER objects, routes become ROUTE objects.)

### Step 3: Versioning edge case tests

Write `AnimationSeedIT` verifying:
- Seed templates exist with correct renderer_code.
- Seed scenes exist with status=PUBLISHED + current_version_id set.
- Seed versions exist with correct manifest_json + checksum.
- Re-running migration is safe (idempotent).
- Scene archive → version still readable.
- Version cannot be updated (trigger fires).

### Step 4: Security hardening checklist

- [ ] `animationSceneVersionId` input is UUID-validated at API layer.
- [ ] Manifest JSON size bounded at controller level (request body size limit).
- [ ] Malformed JSON → 400 with `VALIDATION_ERROR`.
- [ ] Concurrent publish → unique constraint violation → 409.
- [ ] `draft_json` NEVER returned in learner-facing responses.
- [ ] `LEARNER_HIDDEN_KEYS` does not strip animation manifest fields.
- [ ] Asset retirement blocked when scene version references it (document policy or add scan).
- [ ] `rendererCode` whitelist enforced at both backend validator AND Flutter registry.
- [ ] No eventId/lessonId branching in generic renderers/handlers.

### Step 5: Documentation updates

**API_SPEC.md** — add section after Admin endpoints:
```markdown
| GET | `/admin/animation-templates` | List animation templates |
| POST | `/admin/animation-templates` | Create template |
| GET | `/admin/animation-templates/{id}` | Template detail |
| PATCH | `/admin/animation-templates/{id}` | Update template |
| GET | `/admin/animation-scenes` | List scenes |
| POST | `/admin/animation-scenes` | Create scene |
| GET | `/admin/animation-scenes/{id}` | Scene detail |
| PATCH | `/admin/animation-scenes/{id}` | Update scene metadata |
| PUT | `/admin/animation-scenes/{id}/draft` | Update draft manifest |
| POST | `/admin/animation-scenes/{id}/duplicate` | Duplicate scene |
| POST | `/admin/animation-scenes/{id}/validate` | Validate manifest |
| POST | `/admin/animation-scenes/{id}/publish` | Publish version |
| POST | `/admin/animation-scenes/{id}/archive` | Archive scene |
| GET | `/admin/animation-scenes/{id}/versions` | List versions |
| GET | `/admin/animation-scenes/{id}/versions/{versionId}` | Version detail |
| GET | `/admin/animation-scenes/{id}/versions/current` | Current version |
```

**DATABASE_DESIGN.md** — add `animation_templates`, `animation_scenes`, `animation_scene_versions`, `animation_scene_asset_refs` to table list + ERD.

**LEARNING_ENGINE_DESIGN.md** — add section describing animation engine integration with READ activity config.

## Todo List

- [ ] V15 seed migration written and tested on clean + existing DB
- [ ] 2 templates seeded with correct renderer codes
- [ ] 3 scenes seeded with correct manifests
- [ ] 3 scene versions published with checksums
- [ ] Seed is idempotent (ON CONFLICT DO NOTHING)
- [ ] `AnimationSeedIT` — all assertions pass
- [ ] Versioning cases 1-6 verified
- [ ] Security bounds checklist complete
- [ ] `docs/API_SPEC.md` updated
- [ ] `docs/DATABASE_DESIGN.md` updated
- [ ] `docs/LEARNING_ENGINE_DESIGN.md` updated
- [ ] `mvnw.cmd test` — all pass
- [ ] `flutter test` — all pass (existing tests unaffected)

## Success Criteria

- V15 migration runs successfully on both fresh and existing DB.
- `SELECT * FROM animation_templates` returns 2 rows.
- `SELECT * FROM animation_scenes WHERE status='PUBLISHED'` returns 3 rows.
- `SELECT * FROM animation_scene_versions` returns 3 rows with valid manifest JSON.
- Re-running migration doesn't duplicate or fail.
- Archive scene → version still readable via admin API.
- Concurrent publish → one succeeds, other gets 409 (unique constraint or optimistic lock).
- `AnimationManifestValidator` accepts all 3 seed manifests without errors.
- Flutter: `AnimationManifestDto.tryParse` parses all 3 seed manifests identically to Dart originals.
- All existing tests still pass (no regression).
- Docs updated with new tables, endpoints, and architecture notes.

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| No seed admin user (verified — V2 creates `users` table only) | V15 inserts a system user `00000000-0000-4000-8000-000000000001` first; all scene/version FKs reference it. |
| No seed historical_events (verified — V1 creates table only) | Scene `event_id` left NULL in seed; admins link via PATCH later. Do NOT subquery `WHERE slug=...` since the rows don't exist. |
| Manifest JSON translation introduces errors | Write `AnimationSeedIT` to parse and validate each seeded manifest against `AnimationManifestValidator` — catches typos. |
| Checksum computation differs between SQL and Java | Verified impl: `sha256(snapshotJson-text)` where `snapshotJson` is the JSON-string column stored verbatim (`AnimationScenePublishService.sha256` — UTF-8 + HexFormat). For seed: any tool that produces the final `snapshot_json` string produces the checksum — `echo -n '<manifest-json>' | sha256sum` is sufficient. The checksum is over what is STORED, not over canonical form, so the seed can use any stable formatting (compact no-whitespace recommended for diffability). |

## Security Considerations

- Seed uses deterministic UUIDs — no random data, fully reproducible.
- Manifest contains only whitelisted operations — no code execution.
- Asset refs in manifest are validated — cannot reference retired/missing assets.
- Scene draft never exposed to learners — only published snapshot manifest.
- Concurrent publish serialized by pessimistic lock — no race conditions.
- Malformed JSON rejected at controller boundary — 400 not 500.

## Next Steps

- All 4 phases complete → feature ready for code review.
- Update `docs/development-roadmap.md` with animation engine milestone.
- Consider future enhancements: additional renderers (BATTLE_FORMATION, TIMELINE_SCROLL), animation analytics, A/B testing.
