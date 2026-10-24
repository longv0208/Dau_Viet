# Phase 01 — Flyway V22 Schema + Seed

## Context Links

- Brief: `plans/261025-0224-game-04-event-completion-dossiers/brief.md` sections 5, 8, 9, 19.
- Contract: `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` section 2.4 (schema sketch), section 8 (policy versioning), section 9 (dossier design).
- Reference migrations: `dau-viet-backend/src/main/resources/db/migration/V20__seed_events_lessons.sql` (slug re-resolution, DO block idiom), `V10__user_evidence_collection.sql` (UNIQUE + dedup index style), `V21__gamification_energy.sql`.
- Rules: `docs/GAMIFICATION_BUSINESS_RULES.md` EVT-01..07, section 7.2 mastery threshold default 70.

## Overview

- Priority: P1 (blocks everything).
- Status: pending.
- Create `V22__event_progress_and_dossiers.sql`: 5 new tables + constraints + idempotent seed of policies and dossiers for the 3 V20 sample events.

## Key Insights

- `mastery_threshold` is `smallint`, nullable, default 70 (contract line 101). Null = event never evaluates mastered.
- PK of `user_event_progress` is composite `(user_id, event_id, milestone)` — allows COMPLETED + MASTERED rows for same pair.
- Max-one-PUBLISHED-per-event enforced by partial unique index `WHERE status='PUBLISHED'`, not a constraint (contract line 104).
- `user_dossier_unlocks` PK `(user_id, dossier_id)` — one canonical dossier owned once even across events; `event_id` column = provenance of first unlock.
- Seed must resolve event IDs by slug AFTER insert (V20 pattern lines 67-69) — event rows may already exist via `EventSeedService`.
- `asset_id` in `historical_dossiers`: verify `assets` table schema (V3) before FK; nullable per brief.

## Requirements

Tables (contract 2.4 + brief 5/8):

1. `event_completion_policies` — id uuid PK, event_id FK historical_events, policy_version int NOT NULL, status text CHECK IN (DRAFT,PUBLISHED,ARCHIVED), required_lesson_ids jsonb NOT NULL, optional_lesson_ids jsonb NOT NULL DEFAULT '[]', mastery_threshold smallint CHECK (null OR 0..100) DEFAULT 70, published_at timestamptz, created_at/updated_at timestamptz DEFAULT now(). UNIQUE(event_id, policy_version). Partial unique index `uq_event_policy_one_published ON event_completion_policies(event_id) WHERE status='PUBLISHED'`.
2. `user_event_progress` — user_id FK users, event_id FK historical_events, milestone text CHECK IN (EVENT_COMPLETED, EVENT_MASTERED), policy_version int NOT NULL, required_snapshot jsonb NOT NULL, granted_at timestamptz DEFAULT now(). PK(user_id, event_id, milestone).
3. `historical_dossiers` — id uuid PK, canonical_code text UNIQUE NOT NULL, dossier_type text CHECK IN (PERSON,LOCATION,ARTIFACT,CONTEXT), title text NOT NULL, short_description text, preview_description text, detail_description text, source_json jsonb NOT NULL, asset_id uuid NULL (FK assets.id if compatible — verify V3), status text CHECK IN (DRAFT,PUBLISHED,ARCHIVED) DEFAULT DRAFT, version int NOT NULL DEFAULT 1, created_at/updated_at.
4. `event_dossiers` — event_id FK historical_events, dossier_id FK historical_dossiers, unlock_on text NOT NULL DEFAULT 'EVENT_COMPLETED' CHECK (unlock_on='EVENT_COMPLETED'), created_at. PK(event_id, dossier_id).
5. `user_dossier_unlocks` — user_id FK users, dossier_id FK historical_dossiers, event_id FK historical_events NOT NULL, granted_at timestamptz DEFAULT now(), dossier_version int NOT NULL. PK(user_id, dossier_id). Index on (user_id) for list query, on (event_id) for per-event count.

Indexes: `ix_policies_event_status (event_id, status)`; `ix_dossiers_type_status (dossier_type, status)`; `ix_event_dossiers_dossier (dossier_id)`.

Seed (single DO block, all `ON CONFLICT DO NOTHING` / `WHERE NOT EXISTS`):

- Resolve event ids: `SELECT id INTO v_evt FROM historical_events WHERE slug='bach-dang-938'` etc. Skip block when null (event absent on prod-less DB).
- For each of 3 events: insert `event_completion_policies` policy_version=1, status=PUBLISHED, published_at=now(), mastery_threshold=70, required_lesson_ids = JSONB array of the event's published lesson ids resolved dynamically: `(select jsonb_agg(l.id) from lessons l where l.event_id = v_evt and l.status='PUBLISHED')`. Guard: only insert when that aggregate is non-null and non-empty (brief 9.1 — only seed policy when published lessons verified). `ON CONFLICT (event_id, policy_version) DO NOTHING`.
- Dossiers (PUBLISHED, source_json with real citations — reuse V20 evidence sources):
  - PERSON `ngo-quyen` — source ĐVSKTT Ngoai ky quyen 5.
  - PERSON `trung-trac`, `trung-nhi` — ĐVSKTT Ngoai ky quyen 3.
  - PERSON `ly-thai-to` — ĐVSKTT Ban ky quyen 2 (Chieu doi do).
  - LOCATION `song-bach-dang` — Bai coc khai quat citation (Bao tang LSQG, already in V20 ev_bd_2).
  - LOCATION `me-linh` — Ban quan ly di tich Me Linh (V20 ev_hb_2).
  - LOCATION `luy-lau` — Vien Han lam KHXH&NV (V20 ev_hb_3).
  - LOCATION `hoa-lu`, `dai-la` — ĐVSKTT Ban ky quyen 2 + Vien Han lam (V20 ev_lt_3).
  - ARTIFACT `coc-go-bach-dang` — only if sourced; V20 ev_bd_2 citation qualifies, else leave DRAFT.
  - Fixed UUIDs in `d7c00000-…` range (distinct from V20's d7b*), canonical_code UNIQUE is the real guard.
- `event_dossiers` links: bach-dang -> {ngo-quyen, song-bach-dang, coc-go-bach-dang}; hai-ba-trung -> {trung-trac, trung-nhi, me-linh, luy-lau}; ly-thai-to -> {ly-thai-to, hoa-lu, dai-la}. Resolve dossier ids by canonical_code. Only link PUBLISHED dossiers.
- No user_dossier_unlocks seed. No user_event_progress seed.

## Architecture

Pure DDL + idempotent DO-block seed; no Java in this phase. Mirror contract 2.4 exactly where brief and contract agree; add `version`/`dossier_version` columns for snapshot-on-unlock traceability (brief 8.1/8.3).

## Related Code Files

Create:
- `dau-viet-backend/src/main/resources/db/migration/V22__event_progress_and_dossiers.sql`

Read/verify:
- `V3__authoring_publishing_evidence_assets.sql` (assets table — FK target shape)
- `V10__user_evidence_collection.sql` (index/constraint style)
- `V20__seed_events_lessons.sql` (DO block + slug resolution)

## Implementation Steps

1. Read V3 assets table definition; decide `asset_id` FK (add `REFERENCES assets(id)` only if shape matches; otherwise plain uuid + comment).
2. Write DDL for 5 tables in dependency order: event_completion_policies -> user_event_progress -> historical_dossiers -> event_dossiers -> user_dossier_unlocks.
3. Add all CHECK constraints, UNIQUE, partial unique index, secondary indexes.
4. Write seed DO block: declare event/dossier UUID vars; insert dossiers with source_json `{"title":…, "author":…, "citation":…, "url":…, "reliability":"HIGH"}`; re-resolve events by slug; re-resolve dossiers by canonical_code; insert policies with dynamically aggregated required_lesson_ids guarded non-empty; insert event_dossiers links.
5. Ensure whole file re-runnable: every INSERT has ON CONFLICT guard; no DROP/DELETE/UPDATE of existing data.
6. No `published` policy mutation later — seed inserts directly as PUBLISHED (migration-time config, allowed since service-level publish validation is a GAME-06 concern; note in report).

## Todo List

- [ ] Verify assets schema for asset_id FK decision
- [ ] DDL: event_completion_policies + partial unique index
- [ ] DDL: user_event_progress
- [ ] DDL: historical_dossiers + UNIQUE(canonical_code)
- [ ] DDL: event_dossiers
- [ ] DDL: user_dossier_unlocks + indexes
- [ ] Seed: 3 policies via dynamic lesson aggregation (guarded)
- [ ] Seed: 9 dossiers with real citations (8 PUBLISHED + coc-go per source check)
- [ ] Seed: event_dossiers links
- [ ] File idempotent on re-run

## Success Criteria

- `mvnw flyway:migrate` or app boot applies V22 cleanly on fresh + seeded DB.
- Re-running migration is a no-op (Flyway checksum aside, DO block guards all inserts).
- `select * from event_completion_policies` shows 3 PUBLISHED rows, one per event.
- DB check: second PUBLISHED insert for same event fails on partial index.

## Risk Assessment

- Event missing (slug absent) -> guard each event block with `IF v_evt IS NOT NULL`.
- Lesson unpublished -> dynamic aggregate empty -> skip policy insert; log via `RAISE NOTICE`.
- assets FK shape mismatch -> keep asset_id as plain uuid, document.
- Fixed dossier UUID collision -> use dedicated `d7c*` prefix; ON CONFLICT (canonical_code) DO NOTHING anyway.

## Security Considerations

- No user data touched; no ownership rows seeded.
- source_json carries citation only — no secrets.

## Next Steps

- Phase 2 entities mirror these tables 1:1; Hibernate `ddl-auto=validate` in ITs will catch drift.
