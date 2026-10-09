# TASK-0001: Documentation workflow pilot

## Goal

Verify the Phase 1 entry point and task workflow using real documentation checks before attempting application tasks.

## Acceptance criteria

- AC-1: Entry-point links resolve and identify all six product design documents.
- AC-2: Workflow lists backend/admin/mobile as uninitialized and makes no application build success claims.
- AC-3: Task JSON validates; independent review and handoff document results before finish.

Canonical wording and status are in [task.json](task.json). [Phase 1 plan](../../plans/2026-10-09-no-issue-vibe-coding-harness/phase-01-context-and-tasks.md).

## Verification mapping

| AC | Check | Expected outcome |
|---|---|---|
| AC-1 | Link validation and inspect README/context map | All local targets exist; six documents routed |
| AC-2 | Review config, README and workflow | Three uninitialized modules; no fake build/test claims |
| AC-3 | Schema validation, independent review and handoff inspection | Valid task, review artifacts and explicit next action |

## Constraints

Docs-only pilot, tiny risk, no application modules affected. Preserve existing product design files. The foundation configuration is already a prerequisite; this task tests the workflow documentation, not the harness implementation itself. Harness changes require their own verification.

## Current handoff

Task is ready. Evidence and review references are empty until checks actually run. Next: use the Phase 2 runner for verification, obtain independent review, and record a handoff before finish.
