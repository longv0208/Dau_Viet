# Phase 05 — Tests + Stub extensions + MSW + e2e journey

**Priority:** P1 · **Status:** pending · **Effort:** 3h

## Context links

- Stub `scripts/e2e-backend-stub.mjs` — in-memory node:http server; cần thêm events publish/archive, lessons preview/publish/versions, learner `/content`.
- MSW `src/test/msw/handlers.ts` + `fixtures.ts` — mirror admin API cho unit tests.
- Playwright `tests/e2e/*.spec.ts` — pattern login → wizard → builder; webServer `next dev --port 3100` + stub `:8081`.
- Vitest 87/87 đang pass; cần giữ xanh.

## Overview

Mở rộng stub trung thực (preview thật strip answer keys, publish thật tạo version record), MSW cho unit tests của renderers/publish, và e2e journey `login → publish event → preview → validate → publish lesson → verify learner content`.

## Requirements

### Stub extensions (`scripts/e2e-backend-stub.mjs`)

- `POST /api/v1/admin/lessons/{id}/preview` — parse `lesson.draftJson` → run projection-equivalent (xóa `validation`, `evidenceRefs`, `stage.requiredEvidenceIds`, hidden keys trong `config`/`feedback`) → trả `{ lessonId, lessonVersionId:null, versionNo:null, content: <projection> }`. Implement `projectSnapshot(node)` JS mirror `LearnerProjectionService` (~40 LOC, hidden keys constant list).
- `POST /api/v1/admin/lessons/{id}/publish` — body `{expectedRowVersion?}` → run `/validate` logic; errors → 422 `DRAFT_SCHEMA_INVALID` `details.errors[]`; ARCHIVED → 409 `INVALID_STATUS_TRANSITION`; stale rowVersion → 409 `OPTIMISTIC_LOCK_CONFLICT`; event DRAFT → 422 `details.errors=[{code:"EVENT_NOT_PUBLISHED",...}]`. Thành công → push version record `{lessonVersionId:uuid, lessonId, versionNo:lessons.length+1 | ++, status:"PUBLISHED", publishedAt:NOW, snapshot:projection}` vào `lessonVersions[]` array mới + `lesson.currentVersionId` + `status="PUBLISHED"` + `rowVersion++`. Trả `PublishResponse`.
- `POST /api/v1/admin/lessons/{id}/archive` — status="ARCHIVED".
- `GET /api/v1/admin/lessons/{id}/versions` — list cho A-15 sau này (low priority, optional).
- `GET /api/v1/lessons/{id}/content` — learner endpoint: yêu cầu Bearer; lesson phải `PUBLISHED` + `currentVersionId` → trả `LearnerLessonContent { lessonId, lessonVersionId, versionNo, content: <version.snapshot> }`; không tồn tại → 404 `LESSON_NOT_PUBLISHED`.
- Projection phải thực sự strip — e2e verify "no answer keys in preview" bằng cách assert `correctOptionIds` không xuất hiện trong DOM.

### MSW handlers

- `POST /admin/lessons/:id/preview` → fixture `previewFixture` (draft-with-hidden-keys đã strip sẵn).
- `POST /admin/lessons/:id/validate` → canned `{ready:true|false, errors:[], warnings:[], summary:{...}}`.
- `POST /admin/lessons/:id/publish` → success `PublishResponse`; có option error fixture.
- `POST /admin/events/:id/publish` + `/archive`.
- `GET /lessons/:id/content` → `LearnerLessonContent` fixture.

### Unit tests (vitest)

- `publish-readiness-card.test.tsx` — render Map summary, errors vs warnings sections, click error → `onJump` called với resolved ids.
- `preview-renderers.test.tsx` (gộp):
  - ReadView renders `config.text` paragraphs.
  - MultipleChoiceView renders options KHÔNG đánh dấu đúng (không có `data-correct`).
  - EvidenceSelectView hiển thị chips từ `visibleEvidenceIds`.
  - UnsupportedActivity renders type name + JSON.
  - Không hiển thị `validation`/`correctOptionIds` nếu input có (defense — strip lại ở renderer nếu cần, nhưng chủ yếu tin backend).
- `publish-page.test.tsx` — render metadata; click Publish → mutation called; success shows versionNo; 422 `EVENT_NOT_PUBLISHED` → link `/events/{id}` + VN text; 409 → "Tải lại" button.
- `event-publish-button.test.tsx` — DRAFT hiển thị nút; click + confirm → invalidate `qk.events.detail`; PUBLISHED không hiển thị.

### E2E spec `tests/e2e/publish-journey.spec.ts`

Journey đầy đủ (≤90s):
1. `login(page)` — reuse helper (copy từ `builder.spec.ts` hoặc extract `tests/e2e/helpers.ts`).
2. Tạo event mới qua `/events/new` → status DRAFT → click "Xuất bản sự kiện" → status PUBLISHED.
3. Tạo lesson qua wizard cho event đó (dùng helper `createLesson`).
4. Builder: thêm CONTEXT stage + READ activity + EVIDENCE stage + MC activity (question + ≥2 options + tick required) → Lưu.
5. Click "Xem trước" → preview page → assert stage chips + activity title + không có `correctOptionIds` trong DOM.
6. Về lesson → click "Xuất bản" → `/lessons/{id}/publish` → click "Kiểm tra xuất bản" → ready → click "Xuất bản" → confirm → assert `versionNo` hiển thị.
7. Click "Kiểm tra nội dung learner" → `GET /lessons/{id}/content` → assert `versionNo` trả về trùng.
8. Republish: quay lại builder → sửa READ text → lưu → publish lại → `versionNo` = 2.

### e2e DRAFT-event blocking test

- Tạo event mới (KHÔNG publish) → tạo lesson → fill đủ → publish → expect 422 + text "Sự kiện cha chưa xuất bản" + link tới event editor.

## Architecture

- `helpers.ts` mới — export `login(page)`, `createLesson(page,title)`, `publishEvent(page)`; refactor specs hiện có để reuse (không bắt buộc — chỉ khi tiện; nếu refactor, chạy lại specs cũ).
- Stub `projectSnapshot` — mirror `LearnerProjectionService`:
  ```js
  const HIDDEN = new Set(["correctOptionIds","multiCorrect","correctPairs","expectedOrder","requiredEvidenceIds","expectedHypothesis","answerKey","answer","key","expected"]);
  function project(node) { /* deep copy + strip */ }
  ```

## Related files

**Create**
- `tests/e2e/helpers.ts` (~40 LOC)
- `tests/e2e/publish-journey.spec.ts` (~120 LOC)
- `src/features/lessons/preview/__tests__/preview-renderers.test.tsx` (or co-located `*.test.tsx`)
- `src/features/lessons/builder/publish-readiness-card.test.tsx`
- `src/features/lessons/publish/publish-page.test.tsx`
- `src/features/events/event-publish-button.test.tsx`

**Modify**
- `scripts/e2e-backend-stub.mjs` — preview/publish/versions/learner-content + events publish/archive
- `src/test/msw/handlers.ts` — thêm handlers
- `src/test/msw/fixtures.ts` — preview/publish/content fixtures

## Implementation steps

1. Stub: thêm `projectSnapshot(node)` + endpoints (`preview`, `publish`, `archive`, `versions`, learner `content`, `events/{id}/publish`, `events/{id}/archive`). Sắp xếp để route matching không xung đột — lesson sub-routes check trước `lessonMatch` generic.
2. MSW handlers + fixtures.
3. Unit tests — vitest, Testing Library, jsdom; assert DOM text/absence.
4. `helpers.ts` — extract login/createLesson/publishEvent; refactor `builder.spec.ts` + `evidence-authoring.spec.ts` optional.
5. `publish-journey.spec.ts` — full journey; assert each step.
6. Run gates:
   - `npm run lint` → 0 warnings
   - `npx tsc --noEmit` → clean
   - `npm test` → all unit tests pass
   - `npm run build` → success
   - `npx playwright test` → all specs pass (full suite; tolerate cold-compile flake đã ghi)
7. Viết `task0017-{date}-publish-preview-report.md` vào `plans/reports/` — VN, gates table, AC mapping, unresolved.

## Todo list

- [ ] Stub: `projectSnapshot` + preview endpoint
- [ ] Stub: publish endpoint + version store + republish versionNo++
- [ ] Stub: archive lesson + events publish/archive
- [ ] Stub: learner `GET /api/v1/lessons/{id}/content`
- [ ] MSW handlers + fixtures
- [ ] `helpers.ts` + `publish-journey.spec.ts`
- [ ] Unit tests (4 files)
- [ ] Gates pass + report VN

## Success criteria

- Stub projection strip `correctOptionIds`, `validation`, `evidenceRefs`, `requiredEvidenceIds` — e2e assert DOM.
- Stub publish tạo `lessonVersions[]` record + bump `versionNo`; republish → +1.
- Learner `/content` yêu cầu Bearer + lesson PUBLISHED → 404 khi DRAFT.
- E2E full journey ≤ 90s, pass.
- Unit tests cover renderer presence/absence of hidden keys, readiness card sections, publish error paths.
- Gates: lint/tsc/vitest/build/playwright xanh.

## Risks

- Stub `projectSnapshot` diverging từ backend Java — giữ nguyên `LEARNER_HIDDEN_KEYS` list từ `DraftSchema.java` (đọc lại để chắc); add comment trong stub: "mirror of LearnerProjectionService — keep in sync".
- Playwright cold-compile flake đã ghi ở TASK-0015/16 — không phải blocker; tài liệu trong report nếu gặp lại.
- `helper.ts` refactor có thể break specs cũ — nếu refactor, chạy lại full suite trước khi báo cáo.
- `expectedRowVersion` test case: tạo lesson → manually bump `lesson.rowVersion` qua PATCH trong stub hoặc call PATCH song song — đơn giản skip trong e2e; cover ở unit test (mock apiFetch throw 409).
