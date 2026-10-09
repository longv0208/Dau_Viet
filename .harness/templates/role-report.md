# {ROLE} report - {TASK-ID}

- Role: {planner|tester|code-reviewer|docs-manager|implementer}
- Task: {TASK-ID}
- Reported at: {ISO-8601 timestamp}
- Reported by: {agent or human identifier}
- Input fingerprint: {sha256 from runner or "n/a"}

## Verdict

{PASS|FAIL|BLOCKED|INCOMPLETE - one line summary.}

## Findings

- {Factual finding with severity if applicable (P0/P1/P2).}
- {Another finding.}

## Evidence refs

- `{path/to/log-or-evidence}` - what it proves.

## AC mapping

| AC | Verdict | Evidence |
|---|---|---|
| AC-1 | {pass|fail|not-verified} | {artifact} |

## Limitations

- {What this report does NOT cover; tool unavailability; gaps in coverage.}

## Recommendations

- {Follow-up actions for implementer/lead.}
