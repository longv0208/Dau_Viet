# code-reviewer report - TASK-0003 Phase 3 harness

- Role: code-reviewer
- Task: TASK-0003
- Reported at: 2026-10-09T06:45+07:00
- Reported by: code-reviewer (subagent)
- Input fingerprint: n/a (manual code walk of `harness.ps1`, `ResumeFinish.psm1`, `Progress.psm1`, `run-tests.ps1`, templates, runbook)

## Verdict

FAIL - cannot move TASK-0003 to `done` as-is. Two contract deviations in `finish` gating let a task reach `done` with missing review (tiny lane) or missing AC coverage (all lanes); both are explicit contract conditions. Fix is small. Separately, AC-5 and AC-7 are still pending per the implementer's own handoff, so the task is not done regardless of the code findings.

## Findings (ranked)

### P1 - `Get-FinishBlockers` skips reviewRefs check on `risk=tiny`

`ResumeFinish.psm1` line 75:
```powershell
if ($Task.risk -ne 'tiny' -and (-not $Task.reviewRefs -or $Task.reviewRefs.Count -eq 0)) {
  $errs += "no independent reviewRefs (risk=$($Task.risk) requires review)"
}
```
Contract (`harness-contract.md` lane table, and `AGENT_WORKFLOW.md` line 13) requires `review` for tiny lane too: `Brief, kiểm tra liên quan, review`. The code lets a tiny docs-only task reach `done` with zero review. Either drop the `risk -ne 'tiny'` clause or read the requirement from `policy.requireIndependentReview` in config (already present and set to `true`). Fix: remove the risk guard; rely on `policy.requireIndependentReview` and let per-risk overrides live in config.

### P1 - No AC-to-evidence mapping check in `finish`

Contract line 53: "mỗi AC phải map test hoặc manual check ... artifact cụ thể." Workflow line 27: "Runner chỉ finish khi ... AC có coverage."

`Get-FinishBlockers` checks gates/review/handoff/files-on-disk but never inspects `acceptanceCriteria` nor validates that each AC has an evidence/artifact mapping. A task could pass `finish` with every AC unproven as long as the generic gates were green. Minimal fix consistent with the data model: require `evidenceRefs` non-empty AND require each AC id to appear in at least one evidence record or a role report's AC-mapping table — or explicitly document that AC mapping is enforced only via the review report and add a reviewer-side assertion. Right now neither the runner nor the tests exercise this.

### P2 - `docs` evidence not gated at finish

Contract: "Docs/handoff là required evidence trước finish." Only `handoffRef` is enforced. There's no `docsRef` or changelog/PROGRESS regeneration check. Acceptable for MVP if review covers docs, but combined with the missing AC-mapping check this widens the "done without proof" surface. Fix: when `policy.requireDocs` (new flag) is set, require either a `docsEvidenceRef` field or a passing `progress` regen on the same run.

### P2 - PROGRESS.md write is not atomic

`Progress.psm1` line 81: `[System.IO.File]::WriteAllText($OutPath, ...)` — direct overwrite. `Write-TaskAtomic` already implements temp+rename; `Write-ProgressDoc` should reuse the same helper or pattern. Same for `Write-Evidence` (`harness.ps1` line 44) and `Invoke-NewHandoff` (line 282). Mid-write crash leaves a truncated PROGRESS.md that looks authoritative.

### P2 - `resume` auto-transitions `blocked` without gating on staleReasons

`harness.ps1` lines 255-258: if status is `blocked` and deps are clean, it transitions to `resumeFrom` regardless of `staleReasons`. The transition is logged, exit 6 still emitted, and `finish` still blocks downstream — but the side-effect happens before the caller has decided whether the stale reasons are acceptable. Safer: only transition when `staleReasons.Count -eq 0`. Alternatively document the current behavior in the runbook ("resume clears `blocked` even when evidence is stale"). Currently the runbook says "`exit 0` = safe to continue; if status was `blocked`, it has been moved back to `resumeFrom`" — implying the transition only happens on success, which is not what the code does.

### P2 - `Test-StatusTransition` permits `done -> done`

`State.psm1` line 121: `if ($From -eq $To) { return $true }` — short-circuits before the status-order check, so `finish` on an already-`done` task re-runs cleanly and rewrites timestamps. Low risk, but a `done` task should either refuse `finish` or require an explicit `-Force`. Trivial fix: `if ($From -eq 'done' -and $To -ne 'done') { ... }` or explicitly guard in `Invoke-Finish`.

### P2 - Resume staleReasons empty when no prior verify evidence

Already noted by tester (P2). When `LatestEvidence` is `$null` and `Task.evidenceRefs` is empty, `Get-ResumeStaleReasons` returns no stale reason even though "no verify evidence" is itself a blocker for `finish`. Either emit a `stale` entry like `no prior verify evidence` or add a top-level `hasVerifyEvidence` field to the resume JSON.

### P2 - PROGRESS.md silently skips task dirs without `task.json`

`Progress.psm1` line 13: `if (-not (Test-Path $tj)) { return }` inside `ForEach-Object`. A stray directory under `tasks/` (e.g. `TASK-0003.tmp/`, `.bak` from a crash) is silently dropped from the view. Contract says "missing task is error" for the dependency graph but is silent on orphan dirs — either is defensible; document it.

## Positive observations

- `Get-ResumeStaleReasons` covers the right signals: inputFingerprint drift, HEAD move, gateConfigHash drift, evidence fp/head drift, missing on-disk refs. Real teeth, not just a JSON emitter.
- `Write-TaskAtomic` correctly handles the Windows atomic-rename caveat via `.bak` fallback.
- `Enter-TaskLock` refuses to delete live-PID locks; dead-PID recovery is bounded by `StaleMinutes`. Matches contract.
- `cwd` allowlist still enforced in `Invoke-HarnessGate` (verified by the `cwd outside repo blocked` assertion).
- No `Invoke-Expression`; secrets pass through `Protect-Secrets` before landing in logs.
- `finish` exits 5 with a list of blockers — honest, actionable, machine-grepable.
- Handoff/runbook/role-report templates are thorough; the handoff explicitly marks AC-5 and AC-7 pending — no overclaim.
- Cycle detection in `Test-TaskDependencyGraph` is correct (DFS with visiting-state); missing-dep is flagged separately.
- `PROGRESS.md` carries the `generated:` marker and explicitly says "view only / not source of truth" — matches contract.

## Test coverage assessment

18 new assertions exercise the failure modes that matter: missing task, dep errors, five distinct `finish` blocker paths, stale fingerprint detection, dependency cycle, missing dep, handoff scaffold.

Gaps worth adding (none blocking, all cheap):
- Happy path: `finish` on a passing task transitions `done` and writes evidence.
- `resume` on a `blocked` task performs the transition only when staleReasons is empty (see P2 above).
- `Write-ProgressDoc` handles a `tasks/` directory containing a stray non-task dir (documents the current skip behavior).
- `Invoke-Finish` on `risk=tiny` task without `reviewRefs` produces a blocker (regression test for P1 #1).

## Honesty review

- `tasks/TASK-0003/task.json` `status=implementing`, AC-5/AC-7 pending in handoff — accurate.
- `phase3-implementation-notes.md` correctly disclaims "Not a verify evidence record."
- Runbook states `pwsh` is required for `verify` on Windows; does not overclaim PS 5.1 coverage.
- No claim of CI runs, no GitNexus liveness claim, no fabricated review refs.
- `reviewRefs: []` in task.json — correct at time of authoring; must be populated with this report's path before `finish`.

## AC status

| AC | Reviewer verdict | Evidence |
|---|---|---|
| AC-1 resume reports state + stale | pass (with P2 caveats on empty-evidence case) | `ResumeFinish.psm1`, test asserts fingerprint+resumeFrom |
| AC-2 finish gates | partial - review gap on tiny, no AC mapping check, no docs gate | `Get-FinishBlockers` |
| AC-3 PROGRESS regen | pass (P2: not atomic, silently skips non-task dirs) | `Progress.psm1`, `docs/PROGRESS.md` |
| AC-4 handoff template | pass | `.harness/templates/handoff.md` covers all fields |
| AC-5 role mapping docs | pending per implementer handoff | `docs/AGENT_WORKFLOW.md` unchanged |
| AC-6 runbook | pass | `docs/HARNESS_RUNBOOK.md` covers all required sections |
| AC-7 fresh-session drill | pending per implementer handoff | simulated via fixture tests only |

## Recommended actions before `finish`

1. Remove the `risk -ne 'tiny'` guard in `Get-FinishBlockers`; drive review requirement from `config.policy.requireIndependentReview`.
2. Decide and implement the AC-mapping rule: either (a) require `evidenceRefs` non-empty plus each AC id present in some role report's AC table, or (b) document in AGENT_WORKFLOW that the reviewer role report's AC-mapping table is the sole enforcement point. Add a regression test either way.
3. Gate the `blocked -> resumeFrom` transition in `Invoke-Resume` on `staleReasons.Count -eq 0`, or update the runbook to reflect the actual behavior.
4. Make `Write-ProgressDoc` and `Write-Evidence` use temp+rename (reuse the `Write-TaskAtomic` pattern).
5. Add `hasVerifyEvidence` (or equivalent) to resume output to disambiguate "no evidence yet" vs "evidence fresh."
6. Optional: reject `finish` on an already-`done` task unless `-Force`.
7. Perform the AC-5 doc update (role mapping in `AGENT_WORKFLOW.md`) and the AC-7 fresh-session drill before re-attempting `finish`.

## Unresolved questions

- Whether fingerprint scope intentionally includes `.harness/runs/` (tester's open question). If yes, every verify self-invalidates its predecessor — works, but means `inputFingerprint` is never a stable cross-call identifier. Confirm scope in `Fingerprint.psm1` exclusion list and document.
- Where docs-evidence gating should live: a new `docsRefs` field on task.json, or folded into `evidenceRefs`? Needs a planner decision before implementing finding #3.

TASK-0003 cannot move to `done` yet — AC-5 and AC-7 are pending by the implementer's own handoff, and the two P1 findings should land first.
