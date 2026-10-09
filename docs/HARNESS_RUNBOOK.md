# Harness runbook

Operational guide for the vibe-coding harness under `scripts/harness/`. The contract lives in `plans/2026-10-09-no-issue-vibe-coding-harness/harness-contract.md`; this runbook is procedure, not policy.

## Setup

### PowerShell 7 (pwsh) install

The runner targets `pwsh` for both local and CI. Windows PowerShell 5.1 (`powershell.exe`) works for `doctor`, `status`, `resume`, `progress`, `new-handoff` and schema/fingerprint paths, but `verify` invokes `pwsh` for the `harness-self-test` gate.

Install on Windows (admin shell):

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Or download the MSI from https://github.com/PowerShell/PowerShell/releases and install.

Verify:

```powershell
pwsh --version    # expect 7.x
```

If `pwsh` is unavailable, `doctor` reports `pwsh.ok=false` and `verify` fails the `harness-self-test` gate with `executable not found: pwsh`. That is honest failure  -  do not mark N/A to bypass.

### Repo prerequisites

- Git on PATH (`git --version`).
- `.harness/config.json` present at repo root.
- Tasks under `tasks/TASK-XXXX/task.json` matching `.harness/schemas/task.schema.json`.

## Daily commands

```powershell
# Inspect environment (pwsh / git / modules / gitnexus probe)
pwsh -File scripts/harness/harness.ps1 doctor

# Show one task or list all
pwsh -File scripts/harness/harness.ps1 status -TaskId TASK-0003
pwsh -File scripts/harness/harness.ps1 status

# Move ready|blocked|draft -> implementing, capture baseCommit + inputFingerprint
pwsh -File scripts/harness/harness.ps1 start -TaskId TASK-0003

# Run applicable gates; writes evidence to .harness/runs/<task>/evidence-verify-<runId>.json
pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0003

# Inspect resume readiness; if blocked, transition back to resumeFrom
pwsh -File scripts/harness/harness.ps1 resume -TaskId TASK-0003

# Regenerate docs/PROGRESS.md as a view (do not hand-edit)
pwsh -File scripts/harness/harness.ps1 progress

# Scaffold handoff from template
pwsh -File scripts/harness/harness.ps1 new-handoff -TaskId TASK-0003

# Gate task -> done (requires gates passed + evidence fresh + review + handoff)
pwsh -File scripts/harness/harness.ps1 finish -TaskId TASK-0003
```

On a machine without pwsh, substitute `powershell` for `pwsh` for `doctor`, `status`, `resume`, `progress`, `new-handoff`. `verify` will still call `pwsh` internally for `harness-self-test`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Unexpected harness error (see stderr) |
| 2 | doctor preconditions unmet (pwsh or git missing) |
| 3 | verify gate failed |
| 4 | verify detected stale fingerprint mid-run |
| 5 | finish blocked (gates / review / handoff / stale evidence) |
| 6 | resume reported dep errors or stale evidence |

## Update and pin GitNexus

`.harness/config.json` → `gitnexus.version` holds the expected version. On update:

1. Install the new binary (`npm i -g gitnexus` or upstream package).
2. Run `gitnexus --version` and `gitnexus --help` manually.
3. Update `gitnexus.version` in `.harness/config.json` to the new string.
4. Run `harness.ps1 doctor`  -  it probes `--version`/`--help` and reports `available`, `version`, `reason`, `fallback`.
5. Smoke `gitnexus analyze` (or upstream equivalent) against the pinned flags only. Do not invoke flags not present in `--help` of the pinned build.

If GitNexus is absent, doctor reports `fallback=targeted-search`. Continue work using `rg` and manual symbol tracing; record the fallback in the task brief.

## Lock recovery

State writes use `.harness/locks/<TASK-ID>.lock` containing the owner PID. On crash:

1. Confirm the owner PID is gone: `Get-Process -Id <pid>` returns an error.
2. `harness.ps1` will refuse to delete a live lock; for a dead PID older than 30 min, `Enter-TaskLock` removes and re-acquires automatically.
3. If a lock is fresh but the owner is dead (PID reused), delete manually only after confirming the PID has exited:

```powershell
Remove-Item .harness/locks/TASK-XXXX.lock
```

Never delete a lock with a live PID just because it is "old enough"  -  the timeout is a safety hint, not a license.

## Resume drill

From a fresh session, before editing:

```powershell
pwsh -File scripts/harness/harness.ps1 resume -TaskId TASK-XXXX
```

`resume` reports JSON with: `status`, `resumeFrom`, `headSha`, `inputFingerprint`, `gateConfigHash`, `deps[]`, `staleReasons[]`, `nextAction`.

Interpreting output:

- `staleReasons` non-empty → evidence is stale; rerun `verify` before finishing. Do not mark done from memory.
- `deps` non-empty → wait for or land the missing dependency first.
- `exit 6` = something is stale or blocked. Address each reason; do not bypass.
- `exit 0` = safe to continue; if status was `blocked`, it has been moved back to `resumeFrom`.

If `.harness/runs/<task>/` was wiped, all evidence is missing  -  resume reports each missing `evidenceRef` and `verify` must be re-run. This is the intentional evidence-lost path.

## Reindex and fallback

When GitNexus is enabled and you suspect the index is stale:

1. Re-run indexing per pinned version's documented command (`analyze`, etc.).
2. Compare `git status` before and after  -  generated AGENTS/skills/hooks must not overwrite tracked source.
3. Record the index HEAD + dirty fingerprint in the task brief if the task relied on graph output.

If GitNexus is unavailable or output looks wrong:

- Use `rg` / `find_symbol` / `find_referencing_symbols` for direct lookups.
- Trace HTTP boundaries by hand (Flutter/Next.js → Java paths).
- Broaden tests where impact is uncertain; log the gap in the role report.

## CI triage

`.github/workflows/harness.yml` runs the same entrypoint. When a run fails:

1. Download `.harness/runs/` artifact for the failing task.
2. Identify the failed `gateId` in `evidence-verify-<runId>.json`.
3. Reproduce locally with the same `command/args/cwd` from the evidence record.
4. Fix the cause; do not downgrade a gate or silence the test to make it pass.
5. If a log referenced by evidence has expired, the evidence is stale  -  re-run `verify`.

## Commit and push authority

The harness never commits or pushes on its own. After `finish` reports `done`:

- The user reviews the diff.
- The user runs `git add`/`git commit`/`git push` (or delegates to a git-manager agent).
- Commit messages follow conventional commits; no AI references; no secrets.

## Evidence freshness rules

Evidence is valid only while:

- `headSha` and `inputFingerprint` in the latest `evidence-verify-*.json` match the current working tree.
- `gateConfigHash` matches the current `.harness/config.json` hash.
- Every file in `evidenceRefs`, `reviewRefs`, `handoffRef` exists on disk.
- The evidence record itself is not flagged `stale=true`.

Any edit to tracked or in-scope untracked input, any HEAD move, or any config change invalidates prior evidence. Rerun `verify` after edits. The harness blocks `finish` with exit 5 and prints each blocker.
