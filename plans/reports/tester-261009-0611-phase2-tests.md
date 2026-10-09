# Tester Report: TASK-0002 Phase-2 Harness Independent Verification

- Date: 2026-10-09 06:11+07:00
- Repo: C:/Users/Admin/Desktop/4user/DauViet
- Branch: master (unborn HEAD, no commits)
- Toolchain: Windows PowerShell 5.1.26100.7019 only; pwsh (PowerShell 7) NOT installed; node v24.11.1; git 2.52.0.windows.1
- Verdict: FAIL — one P1 defect found (module-gate wiring broken); all other checks pass.

## Environment caveat

- pwsh 7 missing on this machine. The harness honestly reports `harness-self-test: failed` (not silently N/A), which is correct-by-contract but means no local verify run can fully "pass". Docs (`docs/AGENT_WORKFLOW.md` line 63) already disclose this.

## Checks

### 1. Test suite — `powershell -File tests/harness/run-tests.ps1`

- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/harness/run-tests.ps1`
- Result: `Total: 38  Pass: 38  Fail: 0`, exit 0.
- Covers fingerprint (unborn/excluded/edit/staged/rename/delete), state schema+transitions+lock, runner (success/nonzero/timeout/missing-exe/cwd-block/secret-redact), gitnexus fallback, missing-task, verify-on-fixture. Re-ran after my probing to confirm no residue — still 38/38.

### 2. `harness.ps1 doctor` — exit 2

- Output JSON: `pwsh.ok=false` (Desktop 5.1), `git.ok=true`, `repo.unborn=true head=null` (matches `git status` "No commits yet"), `config.valid=true`, all 3 modules `status=uninitialized` (correct — `dau-viet-*` dirs absent), `gitnexus.available=true version=1.6.9 reason=probed ok`.
- Exit 2 = degraded (pwsh missing). Honest, no fake claims.
- Note: GitNexus reports `available=true probed ok` — implementation report claimed "adapter stub"; it actually probes and finds v1.6.9. Acceptable, but flag for reviewer.

### 3. `harness.ps1 status -TaskId TASK-0002` — exit 0

- Returns full task.json: status `implementing`, 7 ACs, scope 7 entries, evidenceRefs 2 files, nextAction names pwsh-missing blocker. Schema-valid.

### 4. `harness.ps1 verify -TaskId TASK-0002` — exit 3

- Output:
  - `task-schema: passed`
  - `app-build: not_applicable  docs-only scope: no module targeted` (correct — `modules` empty)
  - `harness-self-test: failed  executable not found: pwsh` (correct — pwsh absent, not masked as N/A)
- Evidence written to `.harness/runs/TASK-0002/evidence-verify-20261009-061253.json` — see §7.
- Honest failure propagation confirmed.

### 5. Failure-mode matrix

a) **Uninitialized module targeting** — created `tasks/TASK-9999/task.json` with `modules=["backend"]`, `scope=["dau-viet-backend/"]`, `status="ready"`. Verify → `module-backend: blocked  module backend uninitialized; bootstrap dependency required`, exit 3. PASS — no fake pass. (Note: needed `planPath` non-null — schema enforced, also good.)

b) **Mid-run fingerprint staleness** — Could NOT race mid-run (gates return too fast). Indirect evidence:
   - Unit test `PASS content edit changes digest` covers underlying digest fn.
   - `Invoke-Finish` (harness.ps1:248-260) compares `ev.inputFingerprint` vs current digest. After my probing, `finish` correctly reported `stale evidence: fingerprint drift since runId=20261009-061523` — proves the comparison runs and catches drift. PASS (indirect).

c) **Nonzero exit propagation** — direct `Invoke-HarnessGate` call with `node -e 'process.exit(7)'` returned `{status:failed, exitCode:7, reason:"nonzero exit: 7"}`. PASS at runner layer.

   However — see DEFECT-1 below for the resolver-wiring bug that prevents this path from being reached via `verify`.

### 6. `.github/workflows/harness.yml`

- `permissions: contents: read` — least privilege. ✓
- `actions/checkout@v4` with `persist-credentials: false`. ✓
- `actions/upload-artifact@v4` for logs (read-only upload). ✓
- `shell: pwsh` + calls `scripts/harness/harness.ps1` and `tests/harness/run-tests.ps1` — same runner as `.harness/config.json:runner.shell=pwsh`. ✓
- No deploy/publish/release steps. No `id-token`, no `packages: write`. ✓
- `concurrency.cancel-in-progress=true` — sensible.
- `continue-on-error: true` on Doctor step — reasonable since doctor exits 2 when env degraded; CI intent is to surface, not to gate on, the doctor output. Acceptable, but means doctor failure won't fail the job — verify step still runs.
- `timeout-minutes` set on job and steps. ✓

### 7. Evidence schema validation

- `.harness/schemas/evidence.schema.json` is JSON-schema draft 2020-12, `additionalProperties:false`, required list: `taskId,runId,scope,headSha,inputFingerprint,toolVersions,gates,status,at`.
- ajv not installed; did manual structural check on `evidence-verify-20261009-061253.json`:
  - all required fields present, no extra top-level keys
  - `taskId` matches `^TASK-[0-9]{4,}$`
  - `inputFingerprint` len 64 (sha256 hex)
  - `status="failed"` in enum `[passed,failed,stale]`
  - all 3 gates have required `gateId`+`status`; statuses (`passed`,`not_applicable`,`failed`) in enum; no extra props per `additionalProperties:false`
- PASS.

## Defects

### DEFECT-1 (P1, blocking module-gate execution)

- File: `C:/Users/Admin/Desktop/4user/DauViet/scripts/harness/harness.ps1` line 109.
- Code: `foreach ($g in @($mcfg.gates)) { $gates += [pscustomobject]@{ id=$g.id; gate=$g; applies=$true } }`
- Bug: `gate=$g` wraps the whole `{id,gate:{executable,...}}` entry. Downstream at line 180-181, `$gg = $g.gate` retrieves the entry, then `$gg.executable` returns `$null` → gate always reports "gate missing executable" without ever running the command.
- Fix: `gate=$g.gate`.
- Repro: patch `.harness/config.json` to set `modules.backend.status='initialized'` and add a gate `{id:'x',gate:{executable:'node',args:['-e','process.exit(7)']}}`; create task with `modules=["backend"]`; `verify` → `x: failed gate missing executable`. After fix would be `x: failed nonzero exit: 7`.
- Impact: once modules bootstrap, no module gate will ever execute — they'll all silently fail with "missing executable". Test matrix AC-4 / AC-7 not actually reachable.
- Severity: P1 — feature-blocking for Phase 3+. Currently masked because all 3 modules are `uninitialized` so `Resolve-Gates` takes the `blocked` branch (line 99-107) and never reaches line 109.

### DEFECT-2 (P3, minor)

- Doctor reports `gitnexus.available=true` — implementation report called this an "adapter stub"; it's actually doing a real probe. Harmless but documentation drift. Reviewer should confirm intended behavior vs `docs/AGENT_WORKFLOW.md`.

## Test matrix items NOT fully verified

- Mid-run fingerprint staleness during a single `verify` invocation — gates execute too fast to inject edit. Indirectly verified via `finish` path (fingerprint drift detection works).
- AC-2 transition `verifying → reviewing` and `reviewing → done` — `verify`/`finish` are separate subcommands, not state transitions; transitions appear driven by external `Set-TaskStatus`. Test suite covers `Set-TaskStatus` rules; live verify does NOT move task to `verifying` (status stayed `implementing` after verify). May be by design (state held by orchestrator), but worth confirming.
- `resume` subcommand — not exercised (no blocked task fixture resumed).

## Cleanup performed

- Removed `tasks/TASK-9999/`, `.harness/runs/TASK-9999/`, `dau-viet-backend/marker.txt`, `.harness/config.json.bak` (restored original `.harness/config.json`), `.harness/tmp/test-fail.log`. Working tree restored to pre-test state.

## Recommendations

1. Fix DEFECT-1 (`gate=$g.gate` at harness.ps1:109) before any module leaves `uninitialized`.
2. Add a unit test in `tests/harness/run-tests.ps1` covering module-gate resolution path — currently only the `uninitialized` branch is exercised end-to-end.
3. Decide whether `verify` should transition task status to `verifying`; document in `docs/AGENT_WORKFLOW.md` either way.
4. Clarify whether `gitnexus` probe returning `available=true` is desired in this phase, or stub should be hardcoded `false` until Phase 3.
5. Install pwsh 7 to actually exercise `harness-self-test` end-to-end before claiming green locally.

## Unresolved questions

- Is `verify` intentionally a non-mutating check (status stays `implementing`), or should it auto-set status=verifying? Spec unclear.
- Is `gitnexus.available=true` correct on this host — is GitNexus actually installed, or is the probe trivially returning ok? Worth a sanity check outside the harness.
- DEFECT-1 fix is trivial (one-line), but I'm scoped read-only — flag for implementation owner.
