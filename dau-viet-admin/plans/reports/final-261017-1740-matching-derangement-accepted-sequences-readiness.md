# Bao cao cuoi — TASK-0017 tiep theo: matching derangement, acceptedSequences, readiness

Ngay: 2026-10-17. Branch: `main`. Khong push/merge. Khong chay Playwright (bo qua theo yeu cau).

## Pham vi

Sua 3 nhom con lai truoc TASK-0018 Flutter:

1. MATCHING co the hien thi dung cap tren cung 1 hang do hash-sort doc lap.
2. `acceptedSequences` trong DRAG_ORDER chua bi strip — lo answer key qua preview + learner content.
3. Validation co the chay khi draft dang dirty/saving → ket qua cu hien thi nhu ap dung cho ban moi.
4. Legacy MCQ (`multiCorrect` khong `multiSelect`) phai render multi-select trong learner contract.

## Loi da sua

### P1 — MATCHING derangement dam bao khong cap dung tren cung hang

`LearnerProjectionService.transformMatching`:

- Giu contract `leftItems[]`/`rightItems[]` va server-side `pairs`/`correctPairs` nguyen.
- Left column van sort hash asc. Right column khong con sort doc lap — thay vao do sort cung hash asc roi **xoay vong (rotation) theo offset dau tien trong 1..n-1** sao cho khong hang nao co `right[i] == partner(left[i])`.
- Neu khong offset nao derange het (id set ben), fallback re-sort bang hash salted `activityId + "#r"` — van deterministic.
- Ap dung giong nhau cho `project()` (full lesson) va `projectActivity()` (single activity) vi ca hai deu di qua `transformActivity`.
- Khong mutate snapshot input; grading contract giu nguyen (`MatchingHandler` doc `correctPairs`/`pairs` phia server).

### P1 — `acceptedSequences` bi strip khoi learner payload

- Them `acceptedSequences` vao `DraftSchema.LEARNER_HIDDEN_KEYS` — strip recursive trong `config`/`feedback`/`validation`.
- Snapshot publish giu nguyen de `DragOrderHandler` cham cac chuoi chap nhan duoc (test `dragOrder_alternateAcceptedSequence_completes` da co san).
- Mirror trong admin MSW handlers + e2e stub (`e2e-backend-stub.mjs`).

### P2 — Validation chan khi dirty/saving

`PublishReadinessCard`:

- Props moi `dirty`, `saving` — BuilderPage truyen `state.dirty` va `saveMutation.isPending`.
- Khi dirty hoac dang luu: disable nut + doi label thanh "Kiem tra xuat ban (can luu truoc)" + note "chay tren ban nhảp da luu tren may chu".
- Message READY/NOT-READY doi thanh "Ban nhap da luu du/chua du dieu kien xuat ban" — ro rang ve doi tuong duoc validate.
- `revision` invalidation giu nguyen (reset mutation + `checkedAt` khi revision doi — tuc co save/edit thanh cong).
- Backend publish-time validation van authoritative.

### P2 — Legacy MCQ multi-select

`LearnerProjectionService.transformMultipleChoice`: neu `config.multiCorrect` la array >1 phan tu va `multiSelect` chua co → set `multiSelect=true` truoc khi `multiCorrect` bi strip boi LEARNER_HIDDEN_KEYS. Learner thay checkbox (multi) thay vi radio, khong thay answer ids.

Mirror trong MSW handlers + e2e stub.

## Test da them/cap nhat

### Backend `LearnerProjectionServiceTest` (16 → 21 tests)

- `matching_twoPairs_specificIds_neverShareRow` — regression voi ids `it-rani02`/`it-dddqfe`, `it-omc41x`/`it-wbrtxc` (dataset brief cung cap, hash-sort cu se align cap dung).
- `matching_fivePairs_noCorrectPairSharesRow`.
- `matching_manyGeneratedIds_noCorrectPairSharesRow` — quet 3 dataset generated-id.
- `matching_derangementStable_acrossRepeatedProjection` — deterministic.
- `dragOrder_stripsAcceptedSequences` — `acceptedSequences`, `expectedOrder`, `correctOrder` deu absent; `items` con nguyen.
- `multipleChoice_legacyMultiCorrect_emitsMultiSelect`.
- Helper `assertNoCorrectPairSharesRow` — bat buoc khong row nao co cap dung.

### Backend `ScoredHandlersTest` — giu nguyen

- `dragOrder_alternateAcceptedSequence_completes` da cover grading alternative sequences.
- `matching_correctPairSet_completes` / `matching_wrongPairs_incorrect` chung minh grading khong doi.
- `mcq_multiCorrectLegacy_*` cover fallback grading.

### Admin `PublishReadinessCard` test

- `blocks validation while dirty and clears stale READY after save` — validate → edit (dirty) → nut bi disable voi label ro → save → validate lai → READY ap dung cho ban da luu moi.

Fix tiep:

- `builder-page.test.tsx` "Chua san sang xuat ban — xem chi tiet" → `/chưa sẵn sàng xuất bản — xem chi tiết/i` (text doi).
- `publish-readiness-card.test.tsx` dau tien — text cap nhat tuong tu.
- Nut dirty label tranh match `/lưu nháp/i` cua nut Save → dat la "Kiem tra xuat ban (can luu truoc)".

## Mirror cap nhat

- `src/test/msw/handlers.ts`: `acceptedSequences` + MATCHING derangement rotation + legacy multiCorrect→multiSelect.
- `scripts/e2e-backend-stub.mjs`: giong MSW — `acceptedSequences` hidden, derangement rotation offset, multiSelect fallback.

## Ket qua verify

| Gate | Lenh | Ket qua |
|---|---|---|
| Backend unit | `./mvnw.cmd test "-Dtest=*Test"` | **168 tests, 0 fail, BUILD SUCCESS** |
| Admin typecheck | `npx tsc --noEmit` | sach |
| Admin lint | `npm run lint` | sach |
| Admin unit | `npx vitest run` | 108/109 pass; 1 flake `lesson-wizard` timeout 5s — pass khi chay rieng (khong lien quan thay doi) |
| Admin build | `npm run build` | thanh cong |
| Playwright | — | bo qua theo yeu cau user |

IT Postgres/Testcontainers: KHONG chay local — Docker khong kha dung tren may. Backend unit test coverage du cho projection + handler grading; IT nen chay tren CI truoc merge.

## Contract learner sau fix (cho TASK-0018)

- `MULTIPLE_CHOICE`: `config.options[]` + `multiSelect` (single→radio / multi→checkbox), khong `correctOptionIds`/`multiCorrect`.
- `MATCHING`: `config.leftItems[]` + `config.rightItems[]` — dam bao khong row nao la cap dung.
- `DRAG_ORDER`: `config.items[]` da xao tron deterministic; khong `expectedOrder`/`correctOrder`/`acceptedSequences`.
- `evidence[]`/`assets[]` embed cho renderer doc.

## Cau hoi mo

- Khong co. Neu can, chay `AdminLessonPreviewIT`/`HiddenKeyLeakIT` tren CI co Postgres de xac nhan end-to-end.
