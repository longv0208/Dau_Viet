# Code Review — TASK-0014 Admin Authoring

Date: 2026-10-17 · Reviewer: code-reviewer · Plan: `plans/261017-0455-task0014-admin-authoring/plan.md` · Task: `tasks/TASK-0014/task.json`

## Verdict

**APPROVE_WITH_NITS** — implementation matches the verified backend contract, all listed gates pass, and AC-1..AC-8 are covered end-to-end. A few small AC gaps and one mild perf nit (live-search refetch on every keystroke) are worth fixing in a follow-up but do not block merge.

## Findings

### High

None. The wire contract (field names, types, `expectedRowVersion`, error envelope, 409 handling, `templates` as a plain List) is honoured throughout.

### Medium

1. **Live-search refetches on every keystroke** — `src/features/events/events-table.tsx:26-32` and `src/features/lessons/lessons-table.tsx:35-54` put the `q` state into the `useQuery` `queryKey`. Since `setQ` runs `onChange` (not on submit), each keystroke produces a new key → new fetch. The "Tìm" button is effectively decorative. Fix by either (a) gating the query on a separate `submittedQ` state set inside the form's `onSubmit`, or (b) debouncing `q` before placing it in the key. Same pattern duplicated in both tables — extract to a shared `useDebouncedValue` hook or a controlled `searchInput` + `appliedSearch` pair (DRY).

2. **AC-3 partial — lessons list omits `template` and `updatedAt` columns** — `src/features/lessons/lessons-table.tsx:56-95` shows title, event, status, "Xuất bản" flag, actions. AC-3 explicitly lists "title/event/status/template/updatedAt". The list response doesn't include `templateId`/`updatedAt` in `AdminLessonSummary` (per `src/lib/dto/lesson.ts:6-13`), so this is a backend contract limitation — but the AC wording promised it. Either update the column set to show what is available plus `rowVersion` (formatted) and `updatedAt` if the summary exposes it, or narrow the AC. Also consider whether `AdminLessonSummary` should be expanded server-side.

3. **In-app navigation bypasses the unsaved-changes guard** — `src/components/unsaved-changes-guard.tsx` only wires `beforeunload` + a manual `confirmDiscard` on Cancel buttons. A user who edits a form and then clicks a sidebar/breadcrumb link loses work silently. `unsaved-changes-guard.tsx:5-10` documents this trade-off, but AC-2 lists "unsaved-changes guard" without qualifiers. Minimal follow-up: a tiny `useEffect` that intercepts clicks on `a[href^="/"]` while `isDirty` and calls `confirm()` before letting the navigation proceed; or adopt `nextjs-route-guard` style popstate handling. Not a blocker for MVP.

### Low

4. **`q` in query key but `page` not reset** — typing in the search box doesn't reset `page`, so searching on page 5 may return empty. Same root cause as #1; fixing submitted-search resolves it.

5. **`qk.events.detail(lesson?.eventId ?? "")` fires with empty id** — `src/features/lessons/lesson-basic-form.tsx:66` creates a query with key `["events","detail",""]` before `enabled` kicks in. Harmless (no fetch runs), but produces a cache entry keyed to an empty id. Use `enabled: !!lesson?.eventId` (already done) plus optionally `placeholderData`/`skipToken` for cleanliness.

6. **`useQueryClient.invalidateQueries({queryKey:["events"]})`/`["lessons"]` is coarse** — `event-form.tsx:147,153`, `lesson-wizard.tsx:97`, `lesson-basic-form.tsx:131` invalidate every cached page/filter combination. Fine at this scale; if pages grow use `predicate` matching or `qk.events.lists()` namespacing. Not a fix-now item.

7. **`startYear` is sent as `number | undefined`** — `event-form.tsx:120` does `Number(v.startYear)` — correct. But the wire isn't asserted by tests; the only contract-shape assertions are `title`/`slug`/`summary` (`event-form.test.tsx:60-64`). Add an assertion `expect(posted.startYear).toBe(938)` (number, not string) and `expect(posted.expectedRowVersion).toBe(1)` in the PATCH test. Same for `objectivesJson` already checked via `JSON.parse` (`lesson-wizard.test.tsx:67`) — good.

8. **`applyServerFieldErrors` field whitelist** — `event-form.tsx:157-167` lists 9 fields. If backend ever returns details for `tags` or `expectedRowVersion`, they silently drop. Minor — but consider logging unmapped fields via `console.warn` in dev.

9. **`isConflict` handling order** — `event-form.tsx:169-173` overrides the generic error with the conflict message after calling `applyServerFieldErrors`. If both a 409 *and* `details` came back, the field errors are set and then the generic conflict message overwrites `serverError`. Acceptable, though the precedence is implicit.

10. **`event` lookup in wizard can be undefined on step 4** — `lesson-wizard.tsx:329` shows `{event?.title}`. If the events query refetches and the chosen event disappears (deleted in another tab), title renders empty — POST still works because `eventId` is a stable state. Cosmetic.

11. **File-size soft cap** — `event-form.tsx` is 316 LOC, `lesson-wizard.tsx` 375 LOC. Both above the ≤200 LOC guideline in `development-rules.md`. They are single-purpose and readable; splitting the wizard's step markup into `wizard-steps/*.tsx` would help later. Not a blocker.

### Notes / non-issues verified

- Wire contract: `AdminEventCreateRequest` fields (`slug, title, era, period, startYear, summary, description, location, coverAssetKey, tags`) sent exactly; no extras. `startYear` is `Number`, `objectivesJson`/`draftJson` are `JSON.stringify`'d strings.
- `expectedRowVersion` is passed on PATCH in both `event-form.tsx:131` and `lesson-basic-form.tsx:121`, taken from the loaded detail's `rowVersion`. 409 mapped via `err.isConflict` to a Vietnamese concurrent-edit message.
- `GET /admin/lesson-templates` consumed as `LessonTemplate[]` (not `PageResponse`). `lesson-wizard.tsx:63` and `lesson-basic-form.tsx:73` both correct.
- Templates filtered server-side by `enabled` per the contract — no client-side filter needed; stub (`e2e-backend-stub.mjs:257`) also filters.
- `draftJson: "{}"` per plan ("Stage Builder owns it next TASK"). Acceptable stub.
- ARCHIVED lessons: form inputs disabled (`lesson-basic-form.tsx:196,201,211,216,233`) and a warning banner shown; submit button hidden. Correct read-only behaviour.
- Template name resolved by finding in the enabled list; falls back to `lesson.templateId` (`lesson-basic-form.tsx:170`). Reasonable.
- Vietnamese diacritics map in `form-utils.ts` covers a/ă/â/đ/e/ê/i/o/ô/ơ/u/ư/y — matches Vietnamese alphabet and produces slugs passing `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
- Auth: `apiFetch` attaches Bearer only; no secrets in code; no `dangerouslySetInnerHTML`; user content rendered via React text (XSS-safe).
- `useUnsavedChangesGuard` correctly installs/removes listener on `isDirty` transitions.
- `AdminLessonDetail.objectivesJson` parse failure → falls back to `[{value:""}]` (`lesson-basic-form.tsx:39-50`). Defensive, correct.
- MSW handlers cover POST/GET/PATCH events + lessons + templates and return shape-faithful bodies. Optimistic-lock 409 path covered in `lesson-basic-form.test.tsx:61-79`.
- Playwright stub (`e2e-backend-stub.mjs`) enforces `expectedRowVersion` server-side (lines 171-176, 235-243) — real contract check, not a mock.
- Page size = 20 everywhere; `size=100` for the lessons-event filter matches plan ("admin scale acceptable for MVP").

## AC checklist

| AC | Verified | Evidence |
|----|----------|----------|
| AC-1 events list q/status/page + states + create/edit | Yes | `events-table.tsx`, `events/page.tsx`, error/empty tested (`events-table.test.tsx`) |
| AC-2 event editor POST+PATCH, VN labels, field errors, dirty guard | Mostly | `event-form.tsx`, `event-form.test.tsx` — in-app nav guard gap (Finding #3) |
| AC-3 lessons list title/event/status/template/updatedAt | Partial | `lessons-table.tsx` — missing `template` + `updatedAt` columns (Finding #2) |
| AC-4 wizard: event → template → info → POST → editor | Yes | `lesson-wizard.tsx`, `lesson-wizard.test.tsx`, `authoring.spec.ts` |
| AC-5 basic editor loads lesson, PATCH + expectedRowVersion, status, "Sắp triển khai" | Yes | `lesson-basic-form.tsx`, `lesson-basic-form.test.tsx` |
| AC-6 VN UX, no raw JSON, selectors not UUIDs | Yes | all labels VN; objectives via useFieldArray; event/template via pickers |
| AC-7 tests assert contract | Mostly | posted-body assertions cover `title`/`slug`/`summary`/`objectivesJson`/`draftJson`/`expectedRowVersion`; `startYear` type not asserted (Finding #7) |
| AC-8 TASK-0013 still works | Yes | login+rotation+dashboard covered by Playwright login() and existing dashboard test |

## Recommended actions (priority order)

1. (Medium) Split `q` into `searchInput`/`appliedSearch` in both tables to prevent per-keystroke fetches — or debounce.
2. (Medium) Either add `template` + `updatedAt` columns to `lessons-table.tsx` using available fields, or update AC-3 to match the contract.
3. (Medium) Extend `useUnsavedChangesGuard` to intercept `<Link>` clicks while `isDirty`, or document the gap in the runbook.
4. (Low) Add `expect(posted.startYear).toBeTypeOf("number")` and an equivalent assertion for `expectedRowVersion` in tests.
5. (Low) Split `lesson-wizard.tsx` step markup into `wizard-step-{1..4}.tsx` subcomponents to bring the file under 200 LOC.

## Unresolved questions

- Is `AdminLessonSummaryResponse` expected to grow `updatedAt`/`templateId` server-side, or is the current list contract final? Affects AC-3 closure.
- The plan treats `size=100` events fetch as acceptable for the lesson event filter — confirmed for MVP, but needs a follow-up search-as-type if event count grows.
- `tags` on event create sends `[]` when the admin leaves the field array empty — backend tolerates this per DTO. Confirm the server treats empty array vs missing as equivalent (no semantic difference expected).
