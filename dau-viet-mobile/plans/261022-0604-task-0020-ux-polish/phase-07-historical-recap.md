# Phase 07 — Historical recap on LessonResultScreen

## Overview

- Priority: P2
- Status: pending
- Goal: a lightweight "what you just learned" recap built ONLY from
  data already present in the existing DTOs — no new backend, no
  hard-coded event content. Falls back to today's simple result view
  when there is not enough content.

## Available data (from real code — do not invent)

`LessonResultDto` (attempt_dtos.dart):
- `attemptId`, `lessonVersionId`, `status`, `score`, `result` (Map —
  server free-form: may contain `summary`, `message`, `reason`,
  `completedRequired`, `totalRequired`), `completedAt`, `startedAt`.
- Does NOT contain lesson title or content snapshot.

`LessonContentDto` — needs an extra fetch; recap therefore uses the
data path described below.

`AttemptRepository` (interface) already exposes:
- `getAttemptContent(attemptId)` — returns pinned `LessonContentDto`
  with `content` Map.
- `getLessonMetadata(lessonId)` — returns `LessonMetadataDto{ id, title,
  centralQuestion, eventId, currentVersionId, versionNo, publishedAt }`.
- `getResult(attemptId)` — already used by `_resultProvider`.

`LessonContentDto.content` shape (from projection):
- `stages[]` — `{id, type, title}`.
- `evidence[]` — `{id, title?, description?, source?|author?, ...}`.
- `assets[]` — `{id, altText?, ...}`.
- `objectives` — may or may not be present; read via `content['objectives']`
  defensively (`as List?`).
- `title`, `centralQuestion` — top-level keys may also exist in content
  Map (backend projection dependent); fall back to `LessonMetadataDto`.

## Strategy

The result screen currently receives `LessonResultDto?` via `extra` or
fetches it via `_resultProvider`. To get the recap data we must
**also** fetch `LessonContentDto` — cheap, single call, already
defined in the repo. Plan:

1. Extend `_resultProvider` into a small record provider that returns
   `({LessonResultDto result, LessonContentDto? content,
     LessonMetadataDto? meta})` — fetch all three in parallel with
   `Future.wait`. Meta is fetched via `result.attemptId` →
   `AttemptSummaryDto.lessonId` is NOT in `LessonResultDto`. Skip
   metadata unless `content.content['lessonId']` resolves; simpler —
   call only `getAttemptContent`, read title/centralQuestion from
   `content['title']` / `content['centralQuestion']` keys.
2. Pass the record to `_ResultView` — keep `initialResult` path working
   by letting it trigger a lazy `getAttemptContent` fetch too (same
   provider, keyed by attemptId).

## Files

Modify: `lib/features/learning/presentation/lesson_result_screen.dart`
Create: `lib/features/learning/presentation/recap_section.dart` —
small private widget file so result screen stays under 200 lines.

## Changes

1. `_resultProvider` — return `(result, content)` record:

```dart
final _recapProvider = FutureProvider.autoDispose
    .family<({LessonResultDto result, LessonContentDto? content}), String>(
  retry: _noRetry,
  (ref, attemptId) async {
    final repo = ref.watch(attemptRepositoryProvider);
    final call = <T>(Future<T> Function() f) =>
        ApiConfig.useMock ? f() : ref.read(authRepositoryProvider).withAuth(f);
    final result = await call(() => repo.getResult(attemptId));
    LessonContentDto? content;
    try {
      content = await call(() => repo.getAttemptContent(attemptId));
    } catch (_) {
      content = null; // recap optional — never block result view
    }
    return (result: result, content: content);
  },
);
```

2. `_ResultView` accepts `(result, content)` pair. Build body column:
   - Existing: icon, `'HOÀN THÀNH BÀI HỌC'`, score card, summary card,
     `'VỀ TRANG CHỦ'` button — keep all.
   - NEW below summary card, above the home button: `_RecapSection(
     result: result, content: content)` only when `content != null` AND
     at least one of (title | centralQuestion | objectives | stages |
     evidence) is non-empty.
3. `recap_section.dart` — private `RecapSection` StatelessWidget:
   - `SectionLabel('NHỮNG GÌ BẠN VỪA HỌC')` header.
   - Lesson title: `content.content['title'] as String?` →
     `headlineSmall`. Skip if absent.
   - Central question: `content.content['centralQuestion'] as String?`
     → italic `ancientCitation` in a parchment card.
   - Objectives: `content.content['objectives']` — if `List`, render
     each as `• {label|text}` lines under `'MỤC TIÊU'` SectionLabel.
   - Reading content: scan `content.stages` for CONTEXT-type stages
     with `config.body`/`config.text` — surface the first paragraph
     only (truncate at 240 chars + `...`), labeled `'BỐI CẢNH'`.
   - Evidence: `content.evidence` — render up to 3 entries with
     `title` + `evidenceSourceText` (reuse helper) under `'BẰNG CHỨNG
     CHÍNH'`. Do NOT include `requiredEvidenceIds`, correctness, or any
     answer keys.
   - Server result summary: re-display `result.result['summary']` at
     the bottom of the section if present (already shown above — do
     not duplicate; pick one location — the existing summary card stays
     ABOVE; recap section only renders title/centralQ/objectives/
     context/evidence).
   - Fallback: when `content` is null OR all five fields are
     empty/absent — return `SizedBox.shrink()` so the page looks
     identical to today.
4. Spacing: `SizedBox(height: 20)` between score/summary and recap.

## Explicit non-goals (YAGNI)

- No stage-by-stage breakdown per activity.
- No correctness reveal per activity.
- No images in recap (avoid extra asset fetches in result).
- No analytics, no share button, no confetti.

## Todo

- [ ] Add `_recapProvider` record (result+content) — keep `_resultProvider`
      for compatibility OR replace; if replacing, update
      `_ResultView` builder + `initialResult` shortcut to fetch content
      lazily.
- [ ] Create `recap_section.dart` with `RecapSection` widget.
- [ ] Wire `_ResultView` to render `RecapSection` between summary and
      home button.
- [ ] Fallback: empty/null content → no UI change vs today.
- [ ] `dart format` + analyze clean.

## Risks

- `LessonResultDto` has no `lessonId` — recap relies entirely on
  `getAttemptContent` returning the pinned snapshot. If backend doesn't
  serve content for completed attempts, the `try/catch` fallback keeps
  result view working.
- `content['objectives']` may be a `Map` not a `List` — defensive
  cast: `Object? o = content['objectives']; if (o is List) {...}`.
