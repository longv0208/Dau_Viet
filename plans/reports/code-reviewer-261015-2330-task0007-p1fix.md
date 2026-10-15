# Code Review — TASK-0007 P1 fixes (commit c6bdb67 + working tree)

- Scope: `dau-viet-backend` auth — `RefreshTokenFamilyService` (new), `RefreshTokenService.rotate`, `RefreshTokenServiceTest`, `src/test/resources/application.yml`
- Note: the prompt described `revokeFamily(UUID)` 1-arg; the working tree has evolved — signature is `revokeFamily(UUID familyId, UUID excludeId)` and `revokeActiveByFamily` takes a matching `excludeId`. I reviewed the **current working tree** state.
- Prior context: `plans/reports/code-reviewer-261015-2204-task0007-auth.md`

## Verdict: PASS-WITH-NOTES

The P1 (family revoke silently rolled back on replay/locked) is correctly fixed via `REQUIRES_NEW` on a separate bean. The self-deadlock the prompt asked me to scrutinize is **already mitigated in the working tree** by the `excludeId` parameter on `revokeActiveByFamily`. However there is a **test-compile break** — two stale 1-arg `revokeFamily` calls in `RefreshTokenServiceTest` — that must be fixed before `mvn test` will run.

## Deadlock analysis (the crux)

Setup: outer `rotate` tx holds a `PESSIMISTIC_WRITE` row lock on `current` via `findByTokenHashForUpdate`. `familyService.revokeFamily` is `REQUIRES_NEW` → suspends outer, opens a new tx on another connection, runs the bulk `UPDATE`.

Without `excludeId`:
- Replay branch: `current` is committed-revoked → bulk update's `revoked_at IS NULL` predicate skips it → **no lock contention**. Safe even without `excludeId`.
- Locked-user branch: outer set `current.revokedAt = now` and saved (uncommitted). Inner tx sees the pre-commit snapshot → `current` still looks active → bulk `UPDATE` tries to lock that row → blocks on the outer tx's FOR UPDATE lock. Outer is suspended at the app layer waiting for the inner call to return; Postgres cannot see that wait, so no deadlock-detector cycle. Inner blocks until `statement_timeout` (default 0 → infinite) → **real self-hang**.

With `excludeId` (current code):
- Inner's `WHERE ... AND id <> :excludeId` excludes `current` regardless of its committed state → never contends the locked row → **deadlock avoided in both branches**. Correct fix.
- Other family rows are not locked by the outer tx → inner `UPDATE` proceeds, commits; outer resumes, throws `AuthenticationFailedException`, rolls back. Net effect: family rows revoked (committed), `current`'s uncommitted revoke reverts.

Residual semantic wart (minor, not a bug): in the locked-user branch, `current`'s row **stays active in the DB** after the outer rollback, even though the family is dead. Re-presenting it re-runs the same path and 401s again — the user-status check is the real gate, so no privilege escalation. If we want `current` to also die, we could call `revokeFamily` twice or handle it inside the inner tx — but current behavior is defensible and documented in the comment.

## Findings

### Critical — none

### High

- **H1 — `RefreshTokenServiceTest` does not compile against the 2-arg `revokeFamily`.**
  - `RefreshTokenServiceTest.java:111` — `verify(familyService, never()).revokeFamily(any());` — 1-arg call, no matching method.
  - `RefreshTokenServiceTest.java:133` — `verify(familyService).revokeFamily(old.getTokenFamilyId());` — 1-arg call, no matching method.
  - Fix:
    - L111 → `verify(familyService, never()).revokeFamily(any(), any());`
    - L133 → `verify(familyService).revokeFamily(old.getTokenFamilyId(), old.getId());`
  - Until fixed, `mvn -pl dau-viet-backend test` will fail at test-compile, so `AuthRefreshIT` (the actual end-to-end check of the REQUIRES_NEW behavior) won't even run.

### Medium

- **M1 — No negative-path assertion that `excludeId` semantics hold.** A future refactor that drops `excludeId` would reintroduce the deadlock and no unit test would catch it (mocks don't take real locks). The IT `AuthRefreshIT.replay_oldToken_401_familyRevoked` exercises the happy replay path against real Postgres, but the **locked-user branch has no IT coverage** — that's the branch where the deadlock would actually manifest. Suggest adding `AuthRefreshIT.lockedUser_refresh_401_familyRevoked`: create user, issue token, `UPDATE users SET status='LOCKED'`, POST refresh → 401, and assert a second family token (if any) is also dead. At minimum, assert the call returns rather than hanging (a `@Timeout(10)` on the test would surface a deadlock quickly).
- **M2 — Locked-user branch revokes the whole family, not just `current`.** Prompt asked if this is the right product call. Rationale in the code is theft-conservative (treat "user got locked since issue" as "account may be compromised — kill every live session"). Defensible, and consistent with the replay path. Worth a one-line note in `API_SPEC.md` so it's not re-litigated later. Not a blocker.

### Low

- **L1 — `application.yml` under `src/test/resources` is correctly scoped to tests.** No production leak risk; `JwtConfig` validates `>=32` bytes at bean creation, so the value only needs to satisfy that check, and the file is not packaged into the prod jar's `application.yml` (test classpath overrides). Confirmed safe.
- **L2 — `REQUIRES_NEW` opens a second DB connection per rotate-failure.** Fine at current scale; if contention ever becomes hot, consider `TransactionSynchronization` + after-commit event. Not worth changing now.
- **L3 — `RefreshTokenFamilyService` has no unit test of its own.** Acceptable — it's a 1-method delegation; coverage via the service test + IT is adequate.

## Checks the fix satisfies

- AC-5 (`rotate` revocation + family revoke on replay): satisfied at the code level; **needs the H1 test-compile fix before IT evidence is real**.
- AC-10 (`contextLoads` / green suite on CI): satisfied in principle — test-only `jwt-secret` of `>=32` bytes is the smallest possible fix.

## Recommended actions (in order)

1. Fix the two stale `revokeFamily` calls in `RefreshTokenServiceTest` (H1) — **blocks test compile**.
2. Re-run `mvn -pl dau-viet-backend verify` locally (Docker up) so `AuthRefreshIT` actually runs and the REQUIRES_NEW path is exercised against real Postgres. Current evidence is static-review only.
3. Optionally add `AuthRefreshIT.lockedUser_refresh_401_familyRevoked` (M1) to lock in the `excludeId` invariant.
4. Optionally document "family revoke on locked user" in `docs/API_SPEC.md` (M2).

## Unresolved questions

- Was the `excludeId` parameter part of c6bdb67 proper, or an uncommitted follow-up? `git status` shows only `tasks/TASK-0007/task.json` modified — so `RefreshTokenRepository` and `RefreshTokenFamilyService` with `excludeId` appear to be already committed; the review prompt described a slightly older snapshot. Confirm `c6bdb67` vs working tree is the intended state before harness `verify/finish`.
- `task.json` `nextAction` still says "Await local mvnw verify (Docker up)". That gate is unchanged by this review — still required.
