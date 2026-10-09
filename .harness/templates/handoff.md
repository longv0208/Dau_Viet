# {TASK-ID} handoff

{One-paragraph summary of the state the next session must know.}

## Intent

{What this task set out to do. One or two sentences, observable outcome.}

## What was done

- {Concrete change or artifact with path.}
- {Another change; keep each bullet factual.}

## Files changed or created

- `path/to/file` - role in this task.

## Assumptions and invariants

- {Assumption the next session relies on.}
- {Invariant that must not be violated (e.g. backend authoritative, no fake pass).}

## Acceptance criteria status

| AC | Status | Evidence ref |
|---|---|---|
| AC-1 | {done|pending|blocked} | {artifact path or "none"} |

## Checks actually run

- {Command or gate id, exit code observed, evidence path.}
- {Independent review report path and verdict.}

## Unresolved blockers

- {Blocker and owner; or "none".}

## Limitations

- {Honest limits: unavailable tool, environment quirk, partial coverage.}

## Next action

{One concrete next command or step, e.g. `pwsh -File scripts/harness/harness.ps1 resume -TaskId TASK-XXXX`. Do not list multiple alternatives.}
