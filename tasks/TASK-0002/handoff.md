# TASK-0002 handoff

Phase 2 harness runner implemented, independently tested and reviewed.

## What was done

- `scripts/harness/harness.ps1` — entrypoint with `doctor|start|verify|status|resume|finish`, explicit exit codes (0/1/2/3/4/5), no Invoke-Expression.
- `scripts/harness/modules/State.psm1` — task load/save, schema check, atomic write (temp+rename+backup), lock with live-PID stale recovery.
- `scripts/harness/modules/Runner.psm1` — executable+args+cwd allowlist, async output capture, timeout+kill, nonzero propagation, secret redact.
- `scripts/harness/modules/Fingerprint.psm1` — unborn-safe HEAD sha + SHA-256 over tracked/staged/deleted/renamed/untracked + config inputs; exclusion list per contract.
- `scripts/harness/modules/GitNexus.psm1` — probe `--version`/`--help`; on absence returns `fallback=targeted-search` with reason; never claims graph verified when unavailable.
- `.harness/schemas/evidence.schema.json` — evidence record shape.
- `tests/harness/run-tests.ps1` — 38 plain-pwsh assertions covering failure-mode matrix.
- `.github/workflows/harness.yml` — PR + workflow_dispatch, `contents:read`, `persist-credentials:false`, artifact upload of `.harness/runs/`, no deploy/publish.

## Checks actually run

- `tests/harness/run-tests.ps1` — **38 pass / 0 fail** on Windows PowerShell 5.1.
- `harness.ps1 doctor` — exit 2; honest report (`pwsh.ok=false`, unborn HEAD, 3 modules uninitialized, GitNexus probed).
- `harness.ps1 status -TaskId TASK-0002` — exit 0.
- `harness.ps1 verify -TaskId TASK-0002` — `task-schema:passed`, `app-build:not_applicable`, `harness-self-test:failed (pwsh missing)` — honest, not fake N/A.
- Manual gate path test — activated fake `backend` module with `cmd /c echo ok` gate → `passed`. Confirms tester-reported "P1 bug" was a false positive.
- cwd-allowlist fix verified — `C:\repo-evil` rejected, `.git` rejected, real subdirs allowed.

## Independent reviews

- `tester-261009-0611-phase2-tests.md` — verdict FAIL on a claimed P1 that proved false positive on empirical run; all other checks passed.
- `code-reviewer-261009-0620-phase2-review.md` — verdict PASS with conditions; flagged real P1 (cwd allowlist StartsWith) which is now fixed and retested.

## Known limitations

- `pwsh` 7 not installed on this dev machine → `harness-self-test` gate fails locally by design. CI `windows-latest` ships pwsh — should pass there. Not yet verified remotely.
- `finish` cannot be fully exercised until a task reaches verify-green state on a machine with pwsh.
- `.harness/runs/` evidence is gitignored — Phase 2/3 decision needed whether to commit redacted summaries.
- Mid-run fingerprint race and `resume` subcommand are not covered by the current 38 tests.

## Next action

Phase 3: resume/orchestration drill across fresh session, live GitNexus run on a bootstrapped backend module, evidence freshness verification after edits. First real module task remains `bootstrap dau-viet-backend`.
