# code-reviewer report - TASK-0003 Phase 3 harness (post-fix re-review)

- Role: code-reviewer
- Task: TASK-0003
- Reported at: 2026-10-09T07:24+07:00
- Reported by: code-reviewer (subagent)
- Input fingerprint: manual walk of `harness.ps1`, `ResumeFinish.psm1`, `State.psm1`, `Progress.psm1`, `Fingerprint.psm1`, `task.schema.json`, `run-tests.ps1`, `task.json` (all three), `handoff.md`, `AGENT_WORKFLOW.md`, plus `evidence-verify-20261009-072352.json` and `harness-self-test-20261009-072352.log`. Also ran `resume` and `finish` on TASK-0003 to confirm current gating behavior.

## Verdict

PASS. The earlier FAIL findings (two P1s, five P2s) are addressed and verified. `harness-self-test` gate ran under pwsh 7.6.6 at 07:23:52 and reports 66/66 PASS (log at `.harness/runs/TASK-0003/harness-self-test-20261009-072352.log`). `verify` evidence `evidence-verify-20261009-072352.json` shows `status=passed`, `stale=false` at time of run. AC-5 and AC-7 are now satisfied with concrete artifacts (`docs/AGENT_WORKFLOW.md` role-mapping section; live drill documented in handoff). Task is not yet `done` — `reviewRefs` and the latest verify evidence path still need to be wired into `tasks/TASK-0003/task.json` before `finish` can succeed.

## Findings (ranked)

### P0 — none

### P1 — none

The two earlier P1s are closed:

- `Get-FinishBlockers` no longer skips review on `risk=tiny`. `ResumeFinish.psm1` line 162-169 reads `policy.requireIndependentReview` from `Cfg` (defaults to `$true` when the property is absent, which is the safe direction). Test at `run-tests.ps1` lines 247-262 (`tiny lane still requires reviewRefs`) pins this behavior.
- AC-to-evidence mapping is now enforced via `Test-AcCoverage` (`ResumeFinish.psm1` 57-138). Two coverage paths are supported: explicit `task.acEvidence["AC-N"]` map (every listed path must exist on disk), and a fallback that scans `evidenceRefs`/`reviewRefs`/`roleReports`/`handoffRef` files for a literal `AC-N` mention. Handles both `IDictionary` (test fixtures) and `PSCustomObject` (deserialized JSON) shapes correctly. Test assertions at `run-tests.ps1` 264-309 cover all four combinations: uncovered blocks, explicit map with existing path covers, explicit map with missing path does not cover, and fallback content-mention covers.

### P2 — repo-wide fingerprint makes evidence stale on unrelated edits

`Get-InputFingerprint` hashes every tracked/staged/untracked file in the repo plus `tasks/<TaskId>/task.json`. Verified live: the 07:23:52 verify recorded `inputFingerprint=65ce8c...`, but a subsequent edit to `design/DESIGN_PLAN_PHASES.md` and three `design/assets/*` files (untouched by TASK-0003 scope) drifted the digest to `45018469...`. `resume` now reports `evidence fingerprint stale` and `finish` blocks with `stale evidence: fingerprint drift`. This is the contract working as designed — `finish` requires a fresh verify at the moment of finish — but it means `finish` is only green inside a narrow window. Documented in the runbook already; not a regression, just worth noting that any agent working in parallel will trip this.

### P2 — `Write-Evidence` and `Write-ProgressDoc` now atomic but `.bak` cleanup is best-effort

`Write-Evidence` (`harness.ps1` 39-56) and `Write-ProgressDoc` (`Progress.psm1` 85-96) both use temp+rename+backup-restore correctly. However, `Remove-Item -LiteralPath $bak -Force` after a successful restore is not wrapped — if the rename succeeded but cleanup failed (e.g. file locked by AV scan), the `.bak.<guid>` file is left behind. Harmless because the next write creates a fresh `.bak.<guid>` (no overwrite), but `.harness/runs/` will accumulate orphaned backups over time. Fix is a `try/catch` around the cleanup or a periodic sweep. Non-blocking.

### P2 — `Invoke-NewHandoff` writes non-atomically when target does not exist

Line 306 in `harness.ps1`: `[System.IO.File]::Move($tmp, $outPath)` — fine. But the earlier `if (Test-Path $outPath) { exit 0 }` short-circuit at line 301 returns before any write, so the atomic-rename path is only exercised when the file does not yet exist. That's correct, but the code does not handle the case where two processes race to create the handoff (both see `not exists`, both write to distinct tmp files, second `Move` fails because `$outPath` now exists). Edge case is bounded — `Move` will throw, which propagates as a non-zero exit. Low risk for a single-agent runner; flagging for completeness.

### P2 — `Test-AcCoverage` fallback can be satisfied by accidental substring match

`$body -match [regex]::Escape($aid)` uses regex escaping so `AC-1` cannot match `AC-10`. Good. But the match is purely literal — a document that *mentions* AC-1 in passing (e.g. "AC-1 still pending") counts as coverage. The explicit `acEvidence` map is the intended primary mechanism; the fallback exists to avoid breaking legacy tasks. Acceptable per KISS, but document this in the runbook so reviewers know to prefer explicit maps.

## Earlier P2s — status

| Finding | Status | Note |
|---|---|---|
| `docs` evidence not gated | acknowledged | Contract does not require it; `policy.requireDocs` deferred. Acceptable. |
| Non-atomic writes | fixed | All three writers now use temp+rename+backup. |
| `resume` transitions blocked task on stale | fixed | `Invoke-Resume` line 276 gates on `-not $depErrs.Count -and -not $stale.Count`. |
| `done->done` allowed | fixed | `Test-StatusTransition` line 143 `if ($From -eq 'done') { return $false }` placed before the `From -eq $To` short-circuit. Asserted by `done->done rejected` and `done->implementing rejected`. |
| Resume silent on no prior evidence | fixed | `Invoke-Resume` line 254-256 adds `'no prior verify evidence found'` for non-draft tasks. |
| Silent task dir skip | fixed | `Invoke-Status` line 238 emits `Write-Verbose`; `Get-AllTasks` docstring documents the skip. |

## Positive observations

- `Test-AcCoverage` lazy-caches file contents (`$contentCache`), so a 20-artifact pool does not re-read the same file for every AC. Defensive `$Task.PSObject.Properties.Name -contains ...` checks let it handle both hashtable fixtures and PSCustomObject JSON without shape errors.
- `Test-TaskJsonSchema` validates `acEvidence` shape: keys must match declared AC ids, values must be non-empty arrays. The three real `task.json` files all carry well-formed `acEvidence` maps pointing at existing artifacts.
- `harness-self-test` log shows all 66 assertions passing under pwsh 7.6.6 — including the new edge cases (tiny-lane review, AC coverage in all four modes, `done` terminal, schema validation for `acEvidence`).
- `toolVersions.pwsh = "5.1.26100.7019"` in the outer verify evidence refers to the orchestrator script's `$PSVersionTable`, not the inner gate runner — the gate itself invoked `pwsh` (7.6.6) as required. Not a misrepresentation, but mildly confusing on first read.
- `handoff.md` for TASK-0003 is now a model entry: two rounds (initial + post-review-fix) called out explicitly, real exit codes quoted, "checks actually run" lists observable commands not vague claims, honest limitations section.
- `Invoke-Status` uses `Write-Verbose` for the skip — the right channel for a non-error informational message.
- `Enter-TaskLock` still refuses to delete live-PID locks; recovery bounded by `StaleMinutes`. No regression.

## Test coverage assessment

66 assertions total, 10 new in this round covering: tiny-lane review requirement, AC uncovered is a blocker, `acEvidence` with existing path satisfies coverage, `acEvidence` with missing path does not cover, content-mention fallback covers, `done→done` rejected, `done→implementing` rejected, `acEvidence` schema validation (bad key, empty array, valid map).

Gaps worth adding later (none blocking):
- Integration test: `finish` on a fully-clean task transitions to `done` and the resulting task.json no longer passes the same `Get-FinishBlockers` unchanged (post-`done`, `reviewRefs` and AC state must still hold).
- Fixture test asserting `resume` does not transition `blocked` when `staleReasons` is non-empty (currently covered by reading code; a fixture that sets up `staleReasons` + `status=blocked` would pin it).
- Test asserting `.bak` cleanup path is robust when `Remove-Item` fails (mocked via constrained runspace or skipped on Windows AV races — optional).

## Honesty review

- `tasks/TASK-0003/task.json` `status=implementing`, `reviewRefs=[]`, `evidenceRefs` lists the 06:53 verify but not the 07:24 one yet — accurate at the moment of writing; the handoff's "next action" correctly says a fresh review verdict is needed before `finish`. The task's `acEvidence` map points at real files.
- `handoff.md` correctly identifies the second review round was needed and the 0645 verdict was pre-fix.
- `AGENT_WORKFLOW.md` "Role mapping và orchestration" section (lines 31-48) satisfies AC-5: logical-role → agent-name table, sequential default, parallel preconditions (disjoint file ownership, no data dependency, merge plan).
- `docs/PROGRESS.md` regenerated at 06:55 (before the post-fix verify at 07:24). It still shows `TASK-0003 | implementing`, which is accurate. The next `progress` regen will pick up `done` when `finish` lands.
- The earlier `verify` evidence at 06:53:44 is still on disk. The fingerprint exclusion list correctly ignores `.harness/runs/` so old evidence does not self-invalidate. Good.
- No fake passes, no fabrication. Both runs (`resume`, `finish`) on TASK-0003 produced honest output — `resume` correctly reported stale fingerprint after the design/ edits, `finish` correctly listed the two real blockers (`stale evidence`, `no independent reviewRefs`).

## AC status

| AC | Reviewer verdict | Evidence |
|---|---|---|
| AC-1 resume reports state + stale | pass | `ResumeFinish.psm1` `Get-ResumeStaleReasons` covers fp drift, HEAD move, gate-config drift, evidence drift, missing on-disk refs; `Invoke-Resume` adds `no prior verify evidence found` for non-draft tasks. Verified live on TASK-0003. |
| AC-2 finish gates | pass | `Get-FinishBlockers` enforces verify evidence + review + handoff + on-disk refs + AC coverage. Review required for all lanes when `policy.requireIndependentReview=true`. |
| AC-3 PROGRESS regen | pass | `Write-ProgressDoc` atomic, `generated:` marker present, cycle+missing-dep detected. Silent skip documented in code comment + `Write-Verbose`. |
| AC-4 handoff template | pass | `.harness/templates/handoff.md` covers intent/files/assumptions/AC state/evidence refs/blockers/next command. |
| AC-5 role mapping docs | pass | `docs/AGENT_WORKFLOW.md` lines 31-48 added. |
| AC-6 runbook | pass | `docs/HARNESS_RUNBOOK.md` covers required sections (unchanged from prior review). |
| AC-7 fresh-session drill | pass | Documented in `handoff.md`; verified live in this session — `resume` exit 6 with stale reasons, `finish` exit 5 with blockers. |

## Recommended actions before `finish`

1. Append `.harness/runs/TASK-0003/evidence-verify-20261009-072352.json` to `tasks/TASK-0003/task.json` `evidenceRefs`.
2. Append this report's path (`plans/reports/code-reviewer-261009-0724-phase3-postfix.md`) to `tasks/TASK-0003/task.json` `reviewRefs`.
3. Re-run `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0003` — the fingerprint drift caused by `design/` edits will otherwise block `finish` on `stale evidence`. Once verify exits 0 with a new evidence file, run `finish`.
4. Regenerate `docs/PROGRESS.md` via `progress` after `finish` so the view reflects `done`.

## Unresolved questions

- Whether the repo-wide fingerprint scope is intentional. Currently an unrelated `design/` edit invalidates TASK-0003's verify evidence — correct under strict contract but potentially noisy on a multi-agent repo. A future enhancement could scope fingerprint to `task.scope` paths. Not blocking; document decision in `docs/DECISIONS.md` if taken.
- Whether `toolVersions.pwsh` should reflect the *gate* runner's version (the pwsh that ran `harness-self-test`) rather than the orchestrator's `$PSVersionTable`. Currently the field records the outer script's runtime — `5.1.26100.7019` — which is accurate but easy to misread as "pwsh 5.1 ran the gate". Minor clarity issue.

## Report metadata

- Reviewer: code-reviewer subagent (independent of the implementer per AGENT_WORKFLOW role mapping).
- Prior review: `plans/reports/code-reviewer-261009-0645-phase3-review.md` (FAIL).
- This report satisfies the `reviewRefs` requirement for TASK-0003 once wired into `task.json`.
