---
title: Fix animation spacing and preserve reading continuation
description: Remove mobile header blank space and keep post-animation reading material reachable.
status: completed
priority: P2
effort: 2h
branch: main
tags: [mobile, animation, regression]
created: 2026-10-31
---

# Scope and findings

Actual planning role: planner (planner-researcher alias unavailable). Normal risk; no API, database, ownership, reward or published-version changes.

- Mobile HTML header becomes a column but its left child inherits `flex: 1 1 260px`; the width-oriented basis reserves 260px vertically.
- Existing uncommitted demo edit attempts an override but contains orphan CSS declarations and an extra closing brace. Preserve the intended override and repair syntax.
- `ReadRenderer._onFinishAnimation` submits immediately for completed activities, skipping the reading phase during review. `_hasReadingContent` also omits supported aliases such as passage and callout. Reading phase already includes a cover image, so always opening it is the smallest consistent fix.
- Independent review found a parent lifecycle blocker: switching between immersive and scroll layouts recreated the renderer and reset its reading phase. `LessonPlayerScreen` now keeps a stable renderer `GlobalKey` across that layout switch, rotating the key only when the activity ID changes. Parent-level regressions cover new and completed activities without premature submit.
- No new image schema or event-specific branches. Preserve unrelated island edits and V65 migration.

# Impact

GitNexus, Serena and Context7 tools unavailable in session; no graph claims made. Targeted reference fallback: `activity_renderer.dart` dispatches to `ReadRenderer`; runtime, historical-animation, HTML-player and manifest tests instantiate it. `_onFinishAnimation` is used only by the immersive Continue button. Parent layout impact: the stable renderer key preserves state during immersive-to-reading reparenting for the same activity; rotating on activity ID change preserves reset semantics for every activity renderer. Two `lesson_player_test.dart` cases validate the real parent flow. CSS affects the standalone demo HTML and any future uploaded copy. Published HTML bytes are pinned; editing the repository demo does not update previously uploaded scene versions.

# TODO

- [x] Repair mobile `.tide-header__left` override and remove malformed orphan declarations; preserve desktop layout.
- [x] Make animation Continue open existing reading phase for incomplete and completed activities; remove obsolete content detector if unnecessary.
- [x] Add regression tests using existing HTML-player factory seam, checking zero submission on first Continue, text/cover visibility and submission on final acknowledgment.
- [x] Include passage-only, completed review and activity-switch reset coverage where existing fixtures support them.
- [x] Fix review-discovered parent reparenting blocker with a stable renderer key rotated per activity ID; add two parent regressions for new/completed activities.
- [x] Delegate targeted Flutter validation to tester; run diff whitespace and scope checks.
- [x] Delegate independent review; resolve blockers before final evidence.
- [x] Delegate relevant docs/handoff update; report pinned-scene deployment limitation honestly.

# Acceptance and verification

| AC | Outcome | Check/artifact |
|---|---|---|
| AC-1 | Mobile header controls follow subtitle without reserved blank height | Browser computed bounds/screenshot at 360x800, 390x844; desktop smoke; tester report |
| AC-2 | First Continue opens reading material including existing cover; no premature submit for new or completed READ | Renderer regressions for body/passage/completed state plus two real parent-player flow tests; tester report |
| AC-3 | Final acknowledgment submits once; activity changes reset animation phase; existing animation behavior remains usable | Five suites: HTML-player/runtime/historical/manifest/lesson-player, plus analysis of six edited Dart inputs; tester report |
| AC-4 | Scope preserves existing unrelated work and independent review has no blocker | git diff --check, scoped diff review, reviewer report |

# Handoff

Implementation owner: root. Tester then independent code-reviewer, then docs-manager. Implementation and final validation completed including the parent lifecycle fix: five Flutter suites passed 168/168, analysis of six edited Dart inputs found no issues, and three browser viewports passed. Independent reviewer approved the current source with no remaining blockers and verified current hashes. Scoped whitespace checks passed. Earlier evidence predating the parent fix is superseded by final reports. Handoff: `plans/261031-1944-animation-content-fix/handoff.md`. Task source of truth: `tasks/TASK-0042/task.json`. Brief retained in this plan directory to honor Markdown location policy.

# Unresolved questions

None blocking this source repair. Operational follow-up: upload/publish corrected HTML as a new scene version, bind it in a new lesson version, and rebuild the learner app. No live rollout performed; immutable published bytes remain unchanged. Native legacy animation at 800x600 has an observed pre-existing overflow outside this scoped HTML mobile repair.


