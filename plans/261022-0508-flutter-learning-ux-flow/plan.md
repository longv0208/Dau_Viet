---
title: "Flutter learning flow — feedback gate, outcome semantics, dynamic dashboard"
description: "Submit → Feedback → explicit Continue; correct outcome mapping; resume-aware entry; no hard-coded Bạch Đằng in real mode; idempotent submit + complete."
status: pending
priority: P1
effort: 4h
branch: main
tags: [flutter, learning, mobile, ux, idempotency]
created: 2026-10-22
---

# TASK-0019 — Flutter learning UX flow

Backend contract stays authoritative. No Map/Rewards/Shop/Island work. Mock mode stays isolated.

## Audit findings (current state)

- `lesson_player_screen.dart` already calls `getCurrent()` after every non-final submit and swaps `_state.current` → learner is **auto-advanced** the moment feedback arrives; the feedback card renders inside the new activity's bottom bar.
- Outcome mapping: `correct = outcome != 'INCORRECT'` → PARTIAL / CONTRADICTED / acknowledged-ack are treated as "green correct" — wrong visual/copy signal.
- `Idempotency-Key` is minted per answer; network retry with same answer re-uses key correctly (tested). However, on `ApiException` other than network the pending `_pendingAnswer` is kept — pressing Submit again re-uses old key with possibly different payload → backend can return `409 IDEMPOTENCY_CONFLICT`.
- `submitting=true` is never cleared on the success path when `activityCompleted || next != null` — after `setState` builds new `_PlayerState`, `submitting` defaults to false (OK), but on the `getCurrent` failure path the player falls through with `lastCorrect=true` (misleading).
- `LessonEntryScreen` always shows `BẮT ĐẦU KHÁM PHÁ` — no `resumed` / progress-aware label, no in-progress indicator.
- `LearnerDashboardScreen` hard-codes `/campaign/evt_bach_dang_938` for both empty-state and error-state CTAs (lines 288, 297). Resume card already reads real `myProgressProvider` but provides no eventId/lessonId forward.
- `AttemptSummaryDto` carries `lessonId` — usable for resume navigation; `eventId` is NOT in the DTO → empty-state dashboard CTA cannot deep-link without another fetch.
- `LessonResultScreen` calls only `getResult` — does not handle `RESULT_NOT_FOUND` before complete (edge case, low priority).
- `MockAttemptRepository` returns fixed demo activities; does not exercise INCORRECT/PARTIAL branches (fine — mock stays demo).

## Implementation steps (per-file changes)

### 1. `lib/features/learning/presentation/lesson_player_screen.dart` — feedback-then-continue gate

Goal: after every submit, show feedback on the SAME activity; learner presses explicit "Tiếp tục" to advance.

- Extend `_PlayerState` with `SubmitResultDto? lastResult` (or persist `next`/`completionReady` already there) — already has `completionReady`; keep.
- Add `bool awaitingContinue` (or reuse `lastResult != null && advanced == false` semantics — KISS: explicit flag).
- In `_applyResult`:
  - Always set `submitting:false`, `feedbackText:text`, `lastCorrect:<computed>`.
  - If `res.completion.complete` → `completionReady:true`, `awaitingContinue:false` (final, show HOÀN THÀNH).
  - Else if `res.activityCompleted || res.next != null` → `awaitingContinue:true`; **do NOT** call `getCurrent` yet.
  - Else (INCORRECT/retry) → `awaitingContinue:false`, stay on activity.
- New `_onContinue()`: only when `awaitingContinue`; set `submitting:true` briefly; call `getCurrent`; on success replace `_state` with new current (clear feedback); on failure set `feedbackText` to network error and `awaitingContinue:true` so user can retry.
- `_buildBottomBar`: when `awaitingContinue`, render `DongSonButton(label:'TIẾP TỤC ›', onPressed:_onContinue)` — replaces the `HOÀN THÀNH` button while not `completionReady`.
- Disable the activity renderer's submit while `awaitingContinue` (pass `submitting || awaitingContinue` into `ActivityRenderer.submitting`).

### 2. Outcome semantics mapping — `lesson_player_screen.dart` + helper

Add helper in same file (or `renderer_base.dart` if reused):

```dart
enum FeedbackTone { success, info, warning, error }
({String text, FeedbackTone tone}) outcomeFeedback(SubmitResultDto r, ActivityRefDto a) {
  final fb = a.feedbackText(r.evaluation.feedbackCode);
  final out = r.evaluation.outcome ?? '';
  return switch (out) {
    'COMPLETED' || 'SUPPORTED' => (fb ?? 'Chính xác!', FeedbackTone.success),
    'PARTIAL'                  => (fb ?? 'Đúng một phần, thử lại.', FeedbackTone.warning),
    'CONTRADICTED'             => (fb ?? 'Chưa thuyết phục, xem lại.', FeedbackTone.warning),
    'INCORRECT'                => (fb ?? 'Chưa đúng, hãy thử lại.', FeedbackTone.error),
    _                          => (fb ?? 'Đã ghi nhận.', FeedbackTone.info), // acknowledgment (READ/VIEW_IMAGE)
  };
}
```

- Replace `res.evaluation.outcome != 'INCORRECT'` boolean with `FeedbackTone` driving card color/border (success=green, warning=amber, error=red, info=ink-muted).
- Update `_defaultFeedback` accordingly (fallback if `feedbackText` is null).

### 3. `lib/features/learning/presentation/lesson_entry_screen.dart` — start vs resume

- Watch `myProgressProvider`; find `AttemptSummaryDto` matching `widget.lessonId`.
- Button label logic:
  - `attempt == null` → `BẮT ĐẦU KHÁM PHÁ`
  - `attempt.status == 'IN_PROGRESS' && progress.completedRequired > 0` → `TIẾP TỤC BÀI HỌC (${completedRequired}/${totalRequired})`
  - else → `BẮT ĐẦU LẠI` (edge: resume after abandon — backend decides).
- Show small progress chip `Đã học X/Y hoạt động` above the button when attempt exists.
- After `startOrResume`, navigate `pushReplacement('/learning/attempt/${started.attemptId}')` (already correct).
- Do NOT show new attempt card when `myProgress` fails — fall back silently to "BẮT ĐẦU KHÁM PHÁ" and let `startOrResume` resume server-side (backend is authoritative anyway).

### 4. `lib/features/dashboard/presentation/learner_dashboard_screen.dart` — dynamic nav

- Replace hard-coded `/campaign/evt_bach_dang_938` in both empty and error branches.
- Add `eventsProvider`-style fetch (see `features/events/data/events_providers.dart`): pick the first PUBLISHED event → `/campaign/${event.id}`. If empty, hide the CTA entirely (no fake nav).
- Resume card CTA already correct (`/learning/attempt/${attempt.attemptId}`) — keep.
- Source: `api_events_repository.dart` `listEvents({page:0,size:1})` or similar — verify by reading `events_providers.dart` before coding.

### 5. Idempotent retry + resume-on-error — `lesson_player_screen.dart`

- On `ApiException` where `e.error.code == 'IDEMPOTENCY_CONFLICT'` → mint fresh `_pendingKey` + retry once automatically; surface error only if second attempt also fails.
- On network error during `_load()` → already shows `AsyncStateView.error(onRetry:_load)` (correct); preserve.
- On `_complete` failure → reset `_completing:false`, keep `completionReady:true` so user can retry; surface error in feedback card.
- `_confirmExit`: when `awaitingContinue`, treat back as "leave feedback visible" (no auto-advance) — pop directly is fine since submission is persisted.

### 6. `lib/features/learning/presentation/renderers/renderer_base.dart` (optional)

- Add `FeedbackTone` enum + small `FeedbackCard` widget so `lesson_player_screen` doesn't duplicate parchment styling; reuse existing `ParchmentCard`.

## Files to create

None — all changes land in existing files (KISS).

## Tests to update / add

- `test/learning/lesson_player_test.dart` — update two tests:
  - "submit đúng → refetch current render activity kế" — now expects feedback + `TIẾP TỤC` button; tap it, then verify next activity renders.
  - Add: PARTIAL → amber warning + stays on same activity (no `getCurrent` call).
  - Add: `awaitingContinue` → activity submit disabled until continue tapped.
- `test/learning/idempotency_test.dart` — add IDEMPOTENCY_CONFLICT → auto-mint new key + retry once.
- `test/learning/resume_test.dart` — already covers cursor; add widget test for LessonEntry resume label.
- `test/fakes/fake_attempt_repository.dart` — add `completeCalls` reset; allow `onSubmit` to record `getCurrent` invocations count for "no auto-advance" assertions.

## Backend contract gaps to flag

- `AttemptSummaryDto` lacks `eventId`/`lessonTitle` — resume card shows generic "Bài học đang học dở". Acceptable for TASK-0019 but worth surfacing to BA/PO.
- `SubmitResultDto.next` is currently informational only; we always refetch `/current`. That's fine — keeps cursor authoritative.
- `feedbackCode` depends on activity.feedback map being populated — if missing, falls back to hard-coded copy per outcome. Confirmed shape `feedback: {'correct':..., 'wrong':...}` may not match server codes — verify a few real lesson snapshots during implementation.

## Risks / non-goals

- No Map/Rewards/Island/Shop changes.
- No offline answer queue (deferred).
- Existing `mock`/`mock_lesson_repository.dart` flows untouched.
- Don't break `lesson_result_screen.dart` route — `pushReplacement` with `extra:result` still works.

## Open questions

- Should `acknowledged` outcome (READ/VIEW_IMAGE submit `{}`) show a feedback card at all, or skip straight to Continue? Recommend showing subtle info card "Đã ghi nhận" — keeps the gate consistent.
- Does the dashboard need a "browse events" fallback when `myProgress.inProgress` is empty AND events list is empty? (Likely a rare state — recommend just hiding the CTA.)
