# Progress

generated: 2026-10-09T07:36:11.5170772+07:00 by scripts/harness/harness.ps1 progress

View-only - derived from `tasks/*/task.json`. Do not edit task status here.

| Task | Type | Risk | Status | Next action |
|---|---|---|---|---|
| TASK-0001 | docs | tiny | done | Phase 2: implement harness runner (scripts/harness/harness.ps1) and GitNexus adapter; first real module task = bootstrap dau-viet-backend. |
| TASK-0002 | harness | normal | done | Phase 3: resume/orchestration drill, GitNexus live test on bootstrapped backend, evidence freshness across sessions. P1 cwd-allowlist bug fixed and verified (sibling-dir bypass blocked). |
| TASK-0003 | harness | normal | done | Collect fresh code-reviewer verdict on post-fix code (prior FAIL at 0645 has been addressed). Then `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0003` on a pwsh-7 host to record passing evidence (harness-self-test needs pwsh). Then `finish`. |

