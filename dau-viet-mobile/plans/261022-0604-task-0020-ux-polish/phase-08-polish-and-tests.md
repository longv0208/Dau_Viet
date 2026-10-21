# Phase 08 — Polish sweep + focused tests

## Overview

- Priority: P1
- Status: pending
- Goal: last-mile polish across all phases + a small set of widget
  tests that lock in the bug fixes and contracts. Verify existing 129
  tests still pass.

## Files

Modify:
- `test/learning/lesson_player_test.dart` — extend only if existing
  helpers allow; otherwise create a NEW focused test file:
- `test/learning/renderer_polish_test.dart` (new) — widget tests for
  the MATCHING precedence fix + evidence chip counter + recap fallback.
- `test/fakes/fake_attempt_repository.dart` — only if it needs an
  `onGetAttemptContent` hook (check current file: it already returns
  `content` field — already sufficient).

## Polish sweep — apply across all renderer files

1. Reduced-motion: every `AnimatedContainer`, `AnimatedOpacity`,
   `TweenAnimationBuilder`, `Hero` introduced must respect
   `MediaQuery.of(context).disableAnimations`. Wrap once in
   `renderer_base.dart`:

   ```dart
   Duration animDuration(BuildContext c, [int ms = 150]) =>
       MediaQuery.of(c).disableAnimations
           ? Duration.zero
           : Duration(milliseconds: ms);
   ```

   Use `animDuration(context)` everywhere instead of hard-coded
   durations.
2. Rebuild reduction:
   - `Key` `_OrderTile`/`_MatchTile`/`_OptionTile`/`_EvidenceTile` with
     `ValueKey(id)` so lists reuse elements instead of full rebuilds.
   - Convert per-row setState calls that only touch one tile into
     `ValueKey` + localized state where trivial — only if it does not
     complicate logic; current full-renderer `setState` is acceptable
     at this size (YAGNI).
3. Haptics — confirm only added on:
   - MCQ option tap
   - Matching left/right tap
   - Drag-order `onReorderStart` and up/down button
   - Evidence tile tap
   - Reflection option select
   NOT on text-input focus, scroll, or long-press.
4. Typography: confirm `SectionLabel` used for all section labels;
   `headlineSmall` for questions; `bodyMedium`/`bodySmall` for content
   — no inline `GoogleFonts` calls in renderers.
5. Parchment visual direction: confirm all card surfaces use
   `DauVietColors.parchmentContainer`, `outlineVariant`, `cinnabarRed`,
   `imperialGold` — no raw Material `Colors.blue`, `Colors.grey`, etc.
   (whitelist: `Colors.white` for inner tile backgrounds — already the
   existing pattern).
6. Player screen — confirm these TASK-0019 invariants unchanged:
   - `_submit` early-return chain incl. `completionReady`.
   - `PopScope(canPop: !_hasUnsentInput)` + `_confirmExit` +
     `_exitDialogOpen`.
   - `_needsFreshKey` lifecycle (`true` after authoritative response /
     `IDEMPOTENCY_CONFLICT`).
   - `ref.invalidate(myProgressProvider)` on complete + on `_exitNow`.
   - `submitting: st.submitting || st.awaitingContinue ||
     st.completionReady` passed to `ActivityRenderer`.
   - Activity keyed `ValueKey(cur.activity!.id)`.
7. `lesson_result_screen.dart` — confirm the simple view still works
   when `initialResult` is provided but content fetch fails.

## Focused widget tests (add to `test/learning/renderer_polish_test.dart`)

Use `FakeAttemptRepository` + `ProviderScope` + `MaterialApp` pump.

1. MATCHING precedence regression:
   - Pump `MatchingRenderer` with `submitting=true` after seeding
     `_pairs` (drive one pair via taps first with `submitting=false`,
     then rebuild with `submitting=true`).
   - Tap the paired right tile → verify `_pairs` still contains the
     pair (via `tester.takeException()` / a captured answer payload
     check through `onSubmit` not being called).
   - Simpler assertion: pump with `submitting=true` directly after
     creating state via `tester.state` — set `_pairs` reflectively NOT
     allowed; drive via taps first, then `pump` with new widget.
2. DRAG_ORDER:
   - Pump with 3 items; tap "Đưa lên" on second item; verify submitted
     `orderedIds` matches new order via `onSubmit` callback capture.
   - `submitting=true` → tap reorder buttons → no `onSubmit` triggered.
3. EVIDENCE_SELECT:
   - Build `LessonContentDto` with `evidence[]` of 3 entries;
     `visibleEvidenceIds` contains all 3, `minRequired: 2`.
   - Tap 1 tile → SubmitBar disabled. Tap 2nd → enabled. Verify
     `selectedEvidenceIds` payload on submit.
4. RECAP fallback:
   - Pump `LessonResultScreen` with `initialResult` + repository whose
     `getAttemptContent` throws → view renders without `RecapSection`,
     no exception, `'HOÀN THÀNH BÀI HỌC'` visible.
   - Pump with content containing `centralQuestion` + `objectives` →
     `'NHỮNG GÌ BẠN VỪA HỌC'` label present.
5. MCQ:
   - `multiSelect=false` → tap two options → only last stays selected.
   - `multiSelect=true` → tap two → both selected.
   - `submitting=true` → tap → no change.

Existing test helper notes (from `fake_attempt_repository.dart`):
- `content` field is already public — set it directly for evidence
  tests.
- `submittedAnswers` captures payloads — use to assert contract.
- `onGetCurrent` callable lets you script activity progression.

## Verification commands (must all pass)

```
dart format .
flutter analyze
flutter test
```

Expected: 129 existing + new tests pass, 0 analyze issues.

## Todo

- [ ] Add `animDuration` helper to `renderer_base.dart`; apply.
- [ ] Add `ValueKey`s on list-child widgets.
- [ ] Sanity-check reduced-motion path on every new animation.
- [ ] Re-verify TASK-0019 invariants in `lesson_player_screen.dart`
      (read-only audit — no edits expected beyond viewInsets padding).
- [ ] Create `test/learning/renderer_polish_test.dart` with the 5
      focused cases above.
- [ ] `dart format`, `flutter analyze`, `flutter test` all green.

## Risks

- Rebuild-scope refactor could regress dirty-tracking — do NOT
  refactor `setState` granularity; keep current pattern.
- New tests must not rely on the mock repo (MockAttemptRepository is
  demo-only) — use `FakeAttemptRepository`.
