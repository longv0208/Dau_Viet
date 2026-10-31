# TASK-0042 validation

Validated 2026-10-31 Asia/Saigon on Windows. HEAD `20abdce82d5c5707f0cf60feca7c07f166fe9500`; source includes uncommitted task changes. Existing island/V65 work preserved. Applied test and chrome-devtools skills; no TaskList API available.

## Outcomes

- Flutter final targeted suite: 168 passed, 0 failed, 0 skipped; exit 0. Six renderer regressions cover body/passage/cover-only content, new/completed activity review, no premature submission, final acknowledgment and activity reset. Two parent integration regressions validate phase retention through fullscreen-to-scroll reparenting at 390x844, completed false/true, with exception checks at initial scene, reading and acknowledgment.
- Final targeted analyzer: 6 files, no issues; exit 0.
- Browser: 360x800, 390x844, 1280x840 passed; no page errors. Mobile header-left 90.55px, subtitle-to-controls gap 8px. Caption and legend below canvas; no horizontal overflow; tide buttons usable.
- Scoped `git diff --check`: exit 0. LF/CRLF informational warnings only.
- Build: widget tests compile relevant Dart code. Full platform/release build N/A for narrow UI transition/CSS repair; not claimed.
- Coverage percentages: not measured. Explicit critical behavior assertions used; no repository-wide coverage claim.

## Commands and evidence

CWD `dau-viet-mobile`:

```text
flutter test test/learning/html_animation_player_test.dart test/learning/animation_runtime_test.dart test/learning/historical_animation_test.dart test/learning/read_renderer_manifest_test.dart test/learning/lesson_player_test.dart --reporter expanded
flutter analyze lib/features/learning/presentation/renderers/read_renderer.dart lib/features/learning/presentation/lesson_player_screen.dart test/learning/html_animation_player_test.dart test/learning/animation_runtime_test.dart test/learning/historical_animation_test.dart test/learning/lesson_player_test.dart
```

CWD repository root:

```text
node plans/261031-1944-animation-content-fix/verify-animation-layout.cjs
git diff --check -- demo/html-animations/bach-dang-938-demo.html dau-viet-mobile/lib/features/learning/presentation/renderers/read_renderer.dart dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart dau-viet-mobile/test/learning/html_animation_player_test.dart dau-viet-mobile/test/learning/animation_runtime_test.dart dau-viet-mobile/test/learning/historical_animation_test.dart dau-viet-mobile/test/learning/lesson_player_test.dart
```

Flutter 3.47.7, Dart 3.13.5, Node v22.17.1, Playwright 1.64.1, Chrome 156.0.8078.49. Final test execution approximately 9s after startup/dependency resolution; analyzer 3.9s. No performance requirement changed; no benchmark claimed. Dependency resolver reports 24 newer incompatible package versions; no dependency upgrade made.

Artifacts in `plans/261031-1944-animation-content-fix/`: `flutter-targeted.log`, `flutter-analyze.log`, `layout-results.json`, `layout-360x800.png`, `layout-390x844.png`, `layout-1280x840.png`, `validation-fingerprint.json`. Fingerprint includes current implementation/tests, manifest test and gate configuration SHA256. HTML hash `30E9A473FF86D0D74338EBC9A194D84EF66B9CA6BC76AA6B49C3BF45A495F602`; renderer hash `20AA337DF7A1B96482D0EC7AA06B9D96FB8EB50E13944A59E308D499256E68AD`; gate config hash `65CE2899F5410C2B592E50DC3B6F71CC6CE0772581C15EE4B1354E33524D86F7`.

## Initial failures and resolution

First run: 144 passed, 5 failed. Existing runtime/historical helpers and assertions searched stale label `TIẾP TỤC ›`; current pre-existing UI label is `Tiếp tục`. Parent authorized tester to update test-only labels (three substitutions per file). First repair rerun passed all 149. New renderer regressions passed in initial run as well. No application edits by tester.

Independent review then found parent reparenting could reset renderer state. Parent implemented stable GlobalKey and added two integration regressions. Expanded initial run: 166 passed, 2 failed at final exception assertion: native animation initial scene overflows 275px at default test desktop surface 800x600. Diagnostic assertion immediately after initial load confirms overflow predates Continue (`parent-phase-diagnostic.log`). Parent authorized explicit user-relevant 390x844/DPR1 fixture with teardown resets. Final frozen-source rerun passes all 168 with no caught exceptions at each phase. This does not establish native short-landscape support; native 800x600 overflow remains an observed limitation outside the reported HTML mobile screen repair.

Initial browser script asserted active tide phase immediately after click; animation changes phase asynchronously. Switched to Playwright auto-wait assertion; final three viewports pass. Screenshots visually inspected at 390px: compact header and legible caption/legend.

## AC mapping and limits

| AC | Evidence |
|---|---|
| AC-1 | Browser bounds/assertions and three screenshots |
| AC-2 | Six new HTML dispatch regressions and two parent mobile integration regressions, all passed |
| AC-3 | Renderer/parent regressions plus existing runtime/historical/manifest/player suites, 168 total passed |
| AC-4 | Scoped whitespace check passed; independent review remains parent-owned |

Standalone repository HTML was tested. Existing published scene bytes are pinned and unchanged; receiving CSS repair in an uploaded scene requires a new uploaded/published version. No authenticated running app/backend E2E or deployment performed.

## Next action

Independent code review, then docs/handoff. Reverify if implementation or test inputs change. Keep raw logs/screenshots local unless deliberately needed in Git.

## Unresolved questions

None blocking scoped mobile source validation. Published scene rollout remains an operational follow-up. Native animation at default 800x600 short-landscape surface produces a 275px initial-scene overflow; no claim of native desktop support from this validation.
