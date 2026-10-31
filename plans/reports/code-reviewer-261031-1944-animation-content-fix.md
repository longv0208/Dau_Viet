# TASK-0042 independent review

## Outcome and scope

Approved for source handoff; no remaining blocking findings. Reviewed seven changed application/test/demo files (155 additions, 33 removals) and current plan, brief, task and validation evidence. No application edits by reviewer. Edge scouting used targeted references because attempted scout delegation hit the session agent limit; GitNexus/Serena unavailable.

## Resolved blocker

Initial review found that `LessonPlayerScreen` switched `ActivityRenderer` between different parent trees for immersive and reading layouts. The local activity ValueKey did not preserve READ state across reparenting, allowing reading to reset to animation.

The final repair uses a GlobalKey owned by the player state in the two mutually exclusive slots. It remains stable during layout changes and rotates only when activity ID changes, preserving existing remount/reset semantics for all renderers. Two parent-player regressions now exercise the actual transition at 390x844, including completed activities. Both verify no first-Continue submission, retained reading text, final acknowledgment once, and no framework exceptions.

## Edge cases and quality

- Removing the incomplete content detector retains body/passage/cover-only reading material and completed review. Existing cover rendering is unchanged.
- Parent review mode intercepts acknowledgment and returns to grid/continuation without server resubmission. Server authority remains intact.
- New renderer tests cover six combinations of body/passage/no text and incomplete/completed state, plus immersive callbacks and activity-ID reset.
- Mobile flex override removes the 260px column-axis reservation; desktop rules remain unchanged.
- No new API, database, reward, asset schema, event-specific renderer branch, dependencies or secrets.
- Pending guards and final acknowledgment boundary remain intact. No security/performance regression identified in this scoped change.

## Verification inspected

- Current `flutter-targeted.log` ends `+168: All tests passed!`; five suites include HTML player, runtime, historical player, READ manifest and LessonPlayer.
- Current analyzer log: six items, no issues.
- Reviewer independently checked every entry in `validation-fingerprint.json` against current SHA256: all match.
- Reviewer scoped `git diff --check`: exit 0 (CRLF conversion informational warnings only).
- Browser bounds/screenshots: 360x800, 390x844, 1280x840; mobile subtitle-to-controls gap 8px; no page errors.
- Numeric coverage/full release build not measured. Widget compilation and behavior coverage are appropriate to this narrow repair; no full build claim.

## Acceptance mapping

| AC | Review result |
|---|---|
| AC-1 | Supported by browser assertions and three screenshots of repaired source HTML |
| AC-2 | Supported by six renderer regressions and two real parent-player transitions |
| AC-3 | Supported by 168 passing tests, final acknowledgment/reset assertions and key rotation inspection |
| AC-4 | Scoped diff/whitespace and independent review pass; unrelated island/V65 edits excluded |

## Handoff limitations

- Existing uploaded/published HTML bytes remain pinned. Receiving the CSS change requires uploading/publishing a new scene version; repository edits alone do not update deployed copies.
- Native legacy scene overflows at the default 800x600 landscape test viewport before Continue; portrait 390x844 parent transitions pass. This preexisting native layout issue is outside the reported HTML mobile screen and is recorded in tester handoff.
- No authenticated running-app/backend E2E or deployment performed. Documentation/task handoff finalization belongs to parent/docs-manager.

## Unresolved questions

None blocking this source repair.
