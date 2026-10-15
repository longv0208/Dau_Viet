# Progress

generated: 2026-10-15T23:47:32.5888747+07:00 by scripts/harness/harness.ps1 progress

View-only - derived from `tasks/*/task.json`. Do not edit task status here.

| Task | Type | Risk | Status | Next action |
|---|---|---|---|---|
| TASK-0001 | docs | tiny | done | Phase 2: implement harness runner (scripts/harness/harness.ps1) and GitNexus adapter; first real module task = bootstrap dau-viet-backend. |
| TASK-0002 | harness | normal | done | Phase 3: resume/orchestration drill, GitNexus live test on bootstrapped backend, evidence freshness across sessions. P1 cwd-allowlist bug fixed and verified (sibling-dir bypass blocked). |
| TASK-0003 | harness | normal | done | Collect fresh code-reviewer verdict on post-fix code (prior FAIL at 0645 has been addressed). Then `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0003` on a pwsh-7 host to record passing evidence (harness-self-test needs pwsh). Then `finish`. |
| TASK-0004 | bootstrap | normal | implementing | All 8 Mobile Phases (M1-M8) completed successfully. Full interactive demo ready for comprehensive user review. |
| TASK-0005 | bootstrap | high-risk | reviewing | 22/22 tests green (real actuator health IT + insert-only seed verified) + backend-ci.yml added. Run `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0005` on a pwsh-7 host, then `finish`. Next task: Flutter events integration per docs/backend-flutter-contract-notes.md. |
| TASK-0006 | feature | normal | implementing | Implemented + committed (0483a00, 80b40c5). tester-261015-0209 report: NOT VERIFIED â€” no Flutter SDK on this box. Next: run `flutter pub get`/`analyze`/`test` on a machine with Flutter SDK (or CI), then `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0006` on pwsh-7 host, then `finish`. |
| TASK-0007 | feature | high-risk | reviewing | P1 fixed (c6bdb67): family revocation now commits via REQUIRES_NEW RefreshTokenFamilyService; test jwt-secret added for CI contextLoads. Await local mvnw verify (Docker up) then harness verify/finish on pwsh-7. |
| TASK-0008 | feature | high-risk | done | Awaiting user authorization to push. TASK-0009 implements lesson publish (lesson_versions snapshot + current_version_id). |
| TASK-0009 | feature | high-risk | done | Awaiting user authorization to push. TASK-0010 implements publish (lesson_versions snapshot + learner-safe preview). |

