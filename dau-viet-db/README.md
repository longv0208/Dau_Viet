# Dấu Việt — MVP PostgreSQL schema (Flyway)

Based on `docs/DATABASE_DESIGN.md` and BA MVP learning framework. Technical implementation proposal, not a fully BA-approved schema.

**Existing repo has `V1__create_historical_events.sql`. Do NOT replace or edit V1.** Copy V2–V4 into `dau-viet-backend/src/main/resources/db/migration/` and run Spring Boot/Flyway normally.

- V2: `users`, `auth_refresh_tokens` (LEARNER/CONTENT_ADMIN, hashed refresh tokens)
- V3: `assets`, `evidences`, `lesson_templates`, `lessons`, `lesson_versions` (draft JSON, versioned immutable snapshots)
- V4: `learner_attempts`, `activity_attempts`, `idempotency_records`, `lesson_results`, `user_evidence`, `reward_transactions`

**Intentional data-model decisions:**
- No separate `stages` / `activities` tables for MVP; they live in `lessons.draft_json` and immutable `lesson_versions.snapshot_json`.
- No data or table hard-coded for Bạch Đằng 938.
- Auth roles are `LEARNER`, `CONTENT_ADMIN` per database-design document. If application code uses `ADMIN`, reconcile names before implementing auth.
- Snapshot validation (schemas/graph/rules), learner ownership, idempotency replay/hash checks, and cross-table business invariants MUST be enforced by Spring Boot services; SQL constraints alone are insufficient.
- `user_evidence.evidence_id` references a live evidence row; preserve referenced rows and published evidence metadata (embed in snapshot/version pin) to avoid historical content changing.
- DB stores timestamps as `timestamptz`. Configure JDBC/session/application to UTC.
- `reward_transactions` records positive grants only. It is not a general wallet/spending ledger.

**Out of MVP schema:** island, shop, inventory, energy. Those features appear in Flutter demo but are not baseline in `DATABASE_DESIGN.md`. Introduce only after BA/PO confirmation.

**Open decisions from `DATABASE_DESIGN.md`:** attempts/replay policy, XP eligibility, draft resume, archive rules, media snapshot strategy, score/reward rules. Avoid inventing them in persistence code.

**Verification:** SQL files have been statically reviewed, but PostgreSQL/Flyway execution was not available in the file-generation environment. Run migrations on an empty throwaway DB (with existing V1 first) and `mvnw verify` before merging. Keep migration checksums intact once deployed.
