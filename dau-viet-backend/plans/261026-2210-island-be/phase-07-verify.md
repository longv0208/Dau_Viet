# Phase 07 — Full verification + report

**Priority:** P1 · **Status:** pending · **Depends on:** Phase 06

## Context

- Build: `.\mvnw.cmd -B -ntp verify` from `dau-viet-backend/`. JAVA_HOME already `E:\Java\jdk-21` — do NOT override.
- Testcontainers needs Docker — check `docker info` first; if Docker unavailable (known env blocker per memory), run `.\mvnw.cmd -B -ntp -DskipTests package` and record ITs as blocked-by-env, listing exact commands for user to run.

## Steps

1. `git status` — confirm only expected files changed; no stray edits to V1–V31 or unrelated files.
2. `git diff --stat` sanity vs plan file lists.
3. `.\mvnw.cmd -B -ntp verify` — full suite (existing ITs + new). Green required. Failed tests → fix per failure, re-run; never ignore.
4. If green: `detect_changes()` via GitNexus optional sanity (CLAUDE.md says MUST before commit — we are NOT committing; skip commit entirely).
5. Write completion summary INTO `plans/reports/` (executor convention — planner wrote plan; implementer writes `{type}-{date}-island-be-01.md` report there): files changed, endpoints, error codes, test counts, unresolved questions.

## Checklist before declaring done

- [ ] `mvn verify` green (or documented env blocker + exact repro cmd)
- [ ] V32 in both migration dirs, identical
- [ ] `clearAuthoringTables` covers 4 new user tables
- [ ] All 10 new ErrorCode values mapped + exercised
- [ ] API_SPEC/DATABASE_DESIGN/changelog updated
- [ ] No commit/push performed
- [ ] No negative amount in `reward_transactions` anywhere (grep migration + code)

## Known residual risks

- `dau-viet-db` mirror missing V22–V28 (pre-existing drift — reported, not fixed).
- Wallet bridge correctness assumes bridge-before-first-debit invariant (enforced by service entry points) — flag for GAME-07 reviewer when they add admin adjust / other debit sources.
- `min_account_level` is a forward-compat stub (all seeds =1, `levelOf` returns 1) — GAME-07 must implement real level calc before raising any SKU above 1.
