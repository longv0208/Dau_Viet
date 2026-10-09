# Code Review: TASK-0002 Phase-2 Harness Implementation

- Date: 2026-10-09 06:20+07:00
- Repo: C:/Users/Admin/Desktop/4user/DauViet
- Branch: master (unborn HEAD)
- Scope: scripts/harness/**, .harness/{config.json,schemas/evidence.schema.json}, tests/harness/run-tests.ps1, .github/workflows/harness.yml, docs/AGENT_WORKFLOW.md, README.md, tasks/TASK-0002/task.json
- Plan: plans/2026-10-09-no-issue-vibe-coding-harness/phase-02-harness-and-gitnexus.md
- Contract: plans/2026-10-09-no-issue-vibe-coding-harness/harness-contract.md
- Reviewer: code-reviewer (independent, read-only)
- Verdict: **PASS with conditions** — TASK-0002 can move to `reviewing`; not yet `done` until reviewRefs/handoffRef populated and one P1 fixed before any module bootstraps.

## Summary

Implementation is honest, modular, contract-aligned. Atomic-write, lock with stale-pid recovery, fingerprint coverage, and runner isolation are correctly built. No `Invoke-Expression`/shell-string eval. Workflow is least-privilege. Documentation is candid about pwsh-7-missing limitation. The prior tester's "P1 defect" at harness.ps1:109 is a false positive (see below); however this review found one real P1 in `Test-CwdAllowed` plus several P2s.

## Critical (P0)

None.

## High priority (P1)

### P1-1. cwd allowlist prefix-match bypass — `Runner.psm1:11`

```powershell
if (-not ($c.StartsWith($r,[System.StringComparison]::OrdinalIgnoreCase))) { return $false }
```

`StartsWith` without enforcing a trailing path separator means a sibling directory like `C:\repo-evil` passes the check for `RepoRoot=C:\repo`. The subsequent `TrimStart('\','/')` produces `-evil`, which doesn't match forbidden prefixes `.git`/`.gitnexus`, so the gate is allowed to run outside the repo root — exactly what the allowlist is meant to prevent.

Fix: compare against `$r + [IO.Path]::DirectorySeparatorChar` (after trim), or compute `$rel` and reject unless `$c -eq $r -or $rel -ne $c`:

```powershell
$r = (Resolve-Path $RepoRoot).Path.TrimEnd('\','/')
$c = (Resolve-Path $Cwd).Path.TrimEnd('\','/')
if ($c -ne $r -and -not $c.StartsWith("$r/",'OrdinalIgnoreCase') -and -not $c.StartsWith("$r\",'OrdinalIgnoreCase')) { return $false }
```

Add a regression test: `-WorkingDirectory 'C:\repo-evil'` (sibling of fixture) must be `blocked`.

### P1-2 (downgraded from tester's false positive, kept for tracking). Module-gate wiring at `harness.ps1:109` is correct

Confirmed by tracing: `Resolve-Gates` wraps each config gate `g` as `@{id=$g.id; gate=$g; applies=$true}`; the verify loop reads `$g.gate` back at line 180 — the stored object IS the gate, so `$gg.executable` resolves. The tester's repro assumed config gates were `{id, gate:{...}}` nested, but the schema is flat `{id, executable, args, cwd, timeoutSeconds}` per AGENT_WORKFLOW.md §"Module và gate". No code change needed. Action item is only to add a unit test that exercises the active-module gate path so this stays non-regressing once bootstrap lands.

## Medium (P2)

### P2-1. `runId` granularity is seconds — collision possible
`harness.ps1:147` `(Get-Date).ToString('yyyyMMdd-HHmmss')`. Two `verify` invocations in the same second produce identical `runId`, overwriting evidence/log files. Use `yyyyMMdd-HHmmss-fff` or append a GUID fragment.

### P2-2. `Write-TaskAtomic` is not strictly atomic on existing target
`State.psm1:71-78` moves `task.json` to `.bak` then moves `.tmp` to `task.json`. Between those two moves the canonical path is absent — a concurrent reader sees "file missing", and a crash leaves a stranded `.bak`. Acceptable for MVP single-writer under the lock, but either document the assumption or use `[System.IO.File]::Replace` (true atomic replace on NTFS).

### P2-3. `Protect-Secrets` misses `Bearer <token>` without `:`/`=`
`Runner.psm1:22` requires `[:=]` after `bearer`/`authorization`. Common form `Authorization: Bearer eyJ…` — actually `authorization:` matches, but bare `Bearer eyJ…` on its own line doesn't. Add a JWT-shaped pattern `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` and a generic `(?i)bearer\s+[A-Za-z0-9._-]{10,}`.

### P2-4. `finish` picks latest evidence by `LastWriteTime`, not `runId`
`harness.ps1:250` `Sort-Object LastWriteTime`. Any touch/edit reorders. Sort by filename (runId is lexically sortable) or read all `evidence-verify-*.json` and pick max `runId`.

### P2-5. `verify` does not transition task to `verifying`
Observed by tester; matches contract only if `verify` is deliberately non-mutating. Document the choice in `docs/AGENT_WORKFLOW.md` (currently ambiguous: §"Trạng thái" lists `verifying` but no path moves a task into it).

### P2-6. `Read-Task` doesn't enforce `schemaVersion` compat
Future `schemaVersion=2` files would silently pass `Test-TaskJsonSchema` (only presence is checked). Add `if ($Task.schemaVersion -ne 1) { $errs += 'schemaVersion:unsupported' }`.

### P2-7. Config/doc drift — `#requires` claim
`.harness/config.json:52` says "runner fails fast via #requires directive" — `harness.ps1` has no `#requires` line. Either add `#requires -Version 5.1` (minimum tested) or remove the claim. `docs/AGENT_WORKFLOW.md:63` accurately describes pwsh-7-missing status — keep that wording.

### P2-8. `Enter-TaskLock` rare TOCTOU between stale-check and `CreateNew`
Two racing writers could both pass "lock absent" then both attempt `CreateNew`; loser throws IOException (correct). But both could also delete the same lock file simultaneously — `Remove-Item` is idempotent, OK. Minor: tighten by performing CreateNew first, then on IOException reading existing owner to decide stale-recovery.

## Low (P3)

- `Get-GitStatusEntries` splits on "`0" — works because `-z` emits NUL; harmless but `-split "`0"` on a `string[]` already-split-by-Out-String pipeline is brittle. `& git ... | Out-String` was not used, so fine.
- `Invoke-Finish` reads `.harness/runs/<task>/` — if gate logs are large this dir grows unbounded; retention is external. Fine for MVP.
- `gitnexus.available=true probed ok` on this host — implementation is genuinely probing, not a stub. Either accept or gate behind `cfg.gitnexus.enabled`. Currently `enabled=false` in config but the probe runs anyway in `doctor`. Harmless but inconsistent.

## Edge cases reviewed (against contract fingerprint spec)

| Spec requirement | Status |
|---|---|
| tracked content hash | covered (`tracked:` items) |
| staged blob state | covered (`git ls-files -s`) |
| deleted tracked | covered (`deleted:` marker) |
| renamed | covered (`renamed:` from XY=R/C) |
| untracked nonignored | covered (`ls-files -o --exclude-standard`) |
| unborn HEAD | covered — `Get-HeadSha` returns `$null`, digest still computed |
| config/schema/task inputs | covered via `$extra` + task.json hash |
| excludes `.git/`, `.gitnexus/`, runs, locks, tmp, build outputs | covered via `ExclusionPrefixes`/`ExclusionGlobs` |
| filenames with spaces/Unicode | covered (NUL-delimited `ls-files -z`) |
| mid-run edit → stale | covered (fpBefore vs fpAfter) |
| run-log/status edits do not stale | covered — `.harness/runs/` is excluded |
| config/gate/lock/AC changes invalidate | covered — config+schema+task.json all hashed |

## Security review

- No `Invoke-Expression`, no `iex`, no `Invoke-Command -ScriptBlock` over untrusted strings.
- `ProcessStartInfo` uses `UseShellExecute=$false`, `CreateNoWindow=$true`, `RedirectStandard*` — correct.
- Argument array → `ArgumentList` on pwsh 7; on 5.1 falls back to manual quoting (basic but adequate since gates come from `.harness/config.json`, not user input).
- stdout/stderr are redacted before log write via `Protect-Secrets`.
- Workflow: `contents: read`, `persist-credentials: false`, no `id-token`, no `packages: write`, no deploy steps — least-privilege.
- cwd allowlist: see P1-1 — bypass via sibling directory.
- Lock protocol refuses to delete live-pid locks under `StaleMinutes` — safe.

## Honesty check

- README.md:33-38 correctly limits claims to "verified on dev machine (Windows PowerShell 5.1)" for `doctor`/`status`/tests; explicitly says `verify`/`start`/`resume`/`finish` need pwsh 7 for `harness-self-test`.
- docs/AGENT_WORKFLOW.md:63 discloses `pwsh 7` absence and `harness-self-test: failed` state — no overclaim.
- No claim of CI green: workflow exists but was never run remotely; docs don't claim otherwise.
- Markdown style: plain headings, no emojis — compliant.

## AC coverage vs phase-02 test matrix

| AC | Covered by | Gap |
|---|---|---|
| AC-1 subcommands + exit codes | run-tests "harness.ps1: missing task" + verify fixture | `start`/`resume`/`finish` exit paths untested end-to-end |
| AC-2 transitions | unit tests cover `Test-StatusTransition` matrix | `verify` non-mutating semantics undocumented (P2-5) |
| AC-3 fingerprint | thorough unit coverage | none |
| AC-4 scope selection | fixture `uninitialized → blocked` exercised | active-module gate path untested (needed once bootstrap lands) |
| AC-5 gitnexus adapter | covered — probe + fallback reason | `available=true` semantics vs `enabled=false` unclear |
| AC-6 runner failure modes | covered: nonzero/timeout/missing/cwd-block/redact | — |
| AC-7 CI least-privilege | manifest correct | never executed remotely — documented |

Rows not exercised from phase-02 test matrix:

- "Edit code giữa hoặc sau test → finish chặn" — `finish` staleness proven indirectly; no test asserts `exit 5`.
- "Edit chỉ run log/status → không stale vô hạn" — implicit via exclusion prefixes; not asserted.
- "Thiếu authorization regression cho auth task" — high-risk task gating not yet wired (Phase 3 scope).
- "CI và local cùng revision" — no remote run, correctly not claimed.

## Recommendations (prioritized)

1. Fix P1-1 (`Test-CwdAllowed` sibling-dir bypass) and add regression test — required before any module leaves `uninitialized`.
2. Add regression tests for: module-gate active path, `finish` exit 5 on stale evidence, sibling-dir cwd rejection.
3. Resolve P2-1 (runId milliseconds) and P2-4 (sort by runId).
4. Decide + document whether `verify` mutates state (P2-5).
5. Add `schemaVersion` value check to `Test-TaskJsonSchema` (P2-6).
6. Add `#requires -Version 5.1` or fix `config.json` note (P2-7).
7. Extend `Protect-Secrets` for bare `Bearer <jwt>` (P2-3).
8. Install pwsh 7 and re-run `tests/harness/run-tests.ps1` end-to-end before claiming local green.

## TASK-0002 disposition

- Can move `implementing → reviewing` once this review is referenced in `reviewRefs`.
- Cannot move to `done` yet: missing `reviewRefs`, missing `handoffRef`, and P1-1 should land first (cheap fix, prevents future security regression).
- `nextAction` already correctly states pwsh 7 install — keep that note.

## Unresolved questions

- Is `verify` intended to be read-only (status stays `implementing`) or should it set `verifying`? Contract is silent; current code is read-only.
- Should `Get-GitNexusStatus` honor `cfg.gitnexus.enabled=false` and skip probing entirely? Currently probes regardless.
- Should `Enter-TaskLock` block until timeout instead of fail-fast? Current fail-fast is fine for single-writer MVP.
- Should `run-tests.ps1` run under both `powershell` and `pwsh` in CI matrix once bootstrap lands? Currently Windows-only `pwsh`.
