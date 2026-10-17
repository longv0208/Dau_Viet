# Bao cao cuoi — Critical Content & Preview Bugfix

Ngay: 2026-10-17. Branch: `main`. Khong push/merge.

## Pham vi

Sua 6 nhom loi truoc TASK-0018 (Flutter), theo brief: MC contract, MATCHING/DRAG_ORDER lo dap an trong learner payload, preview thieu noi dung bang chung, ro state giua cac hoat dong cung loai, readiness cu sau khi luu draft, dong bo stub e2e + spec publish-journey.

## Loi da sua

### P1 — MC contract (correctOptionIds + multiSelect)
- Admin `multiple-choice-editor.tsx`: ghi canonical `correctOptionIds` + `multiSelect`; doc draft cu `multiCorrect` va chuan hoa khi luu (xoa `multiCorrect`).
- Backend `ScoredHandlers.java` (MultipleChoiceHandler): fallback `multiCorrect` khi `correctOptionIds` trong — draft cu van cham dung.
- `LearnerProjectionService`: them `multiCorrect` vao `LEARNER_HIDDEN_KEYS` — khong bao gio toi learner.

### P1 — MATCHING: config.pairs lo dap an
- `LearnerProjectionService.transformActivity`: xoa `pairs`, phat `leftItems`/`rightItems` doc lap — sort theo `Objects.hash(activityId|itemId)` (trai tang, phai giam) → khong the zip index de suy ra mapping.
- Khong mutate answer key (snapshot input giu nguyen — test `matching_inputSnapshotNotMutated`).
- Admin `MatchingActivityView`: render 2 cot doc lap tu `leftItems`/`rightItems`.

### P1 — DRAG_ORDER: items theo thu tu dung
- Projection hash-sort `items` deterministic; neu ket qua trung `expectedOrder`/`correctOrder`/thu tu goc thi dao 1 lan — thu tu hien thi khac thu tu dung, on dinh giua cac lan goi. Khong xay randomization subsystem.
- Snapshot giu `expectedOrder` phia server de cham diem (test `dragOrder_answerKeyStillGradesOriginalSequence`).

### P2 — Evidence preview placeholder
- `LessonService.preview()` goi `snapshotBuilder.build(...)` roi `learnerProjection.project(...)` — embed `evidence[]`/`assets[]` (title, description, source{title,author,url,citation,publishedAt}); try/catch fallback draft tran khi template loi.
- Admin: `types.ts` them `EmbeddedEvidence`/`EmbeddedAsset`; `resolve-evidence.ts` (`findEvidence`, `evidenceLabel`); EVIDENCE_SELECT/VERIFICATION render title + nguon + tac gia thay "Bang chung 1"/"Nguon 1"; missing evidence → fallback nhan chung, khong show UUID.
- Khong ro `requiredEvidenceIds` (strip trong projection).

### P2 — Preview state leak giua activities cung type
- `stage-view.tsx`: `<ActivityRenderer key={activity.id}>` — remount reset local state. Vitest regression: reorder → nav → back khoi phuc thu tu goc.

### P2 — Stale publish readiness
- `PublishReadinessCard` nhan prop `revision`; `useEffect` reset mutation + `checkedAt` khi revision doi (builder bump `state.revision` moi lan draft mutate). Khong chan edit; validate phia backend luc publish van la authoritative.

### Stub + e2e
- `e2e-backend-stub.mjs`: mirror projection (HIDDEN_KEYS + `multiCorrect`, `sortKey` hash Java-style, `transformActivity` MATCHING/DRAG_ORDER, `enrichDraft` embed evidence/assets) — dung cho ca preview va snapshot publish.
- `publish-journey.spec.ts` viet lai: same-event → draft API that → preview → validate → publish v1 → learner content dung hinh dang, khong ro key (assert ca `"pairs"`) → draft edit khong dong vao snapshot → republish v2. Spec 2: chan publish khi event DRAFT (EVENT_NOT_PUBLISHED).
- Sua test infra: selector stage chip `role="tab"`; nut "len" anchor `lên$` tranh match nham label chua "len" (trieu len); learner `/content` can Bearer — lay qua `/api/auth/session`; `items.sort()` mutate → copy `[...items].sort()`.
- `authoring.spec.ts`: `test.setTimeout(120s)` — cold dev-compile `/events/new` vuot 30s mac dinh (baseline cung 15–26s, khong phai regression).

## Bao ve learner (payload assertions)

Khong key nao sau xuat hien trong content learner hay DOM preview: `correctOptionIds`, `multiCorrect`, `correctPairs`, `expectedOrder`, `requiredEvidenceIds`, `pairs`. MATCHING: zip(leftItems[i], rightItems[i]) != mapping goc. DRAG_ORDER: cung tap items nhung thu tu != expected. MC radio single / checkbox multi.

## Ket qua verify

| Gate | Lenh | Ket qua |
|---|---|---|
| Backend unit | `./mvnw.cmd -q test "-Dtest=*Test"` | 162 tests, 0 fail, BUILD SUCCESS |
| Admin typecheck | `npx tsc --noEmit` | sach |
| Admin lint | `npm run lint` | sach |
| Admin unit | `npx vitest run` | 24 files / 108 tests pass |
| Admin build | `npm run build` | thanh cong |
| E2E publish-journey | `npx playwright test tests/e2e/publish-journey.spec.ts` | 2/2 pass |

- IT Postgres (`HiddenKeyLeakIT`, `AdminLessonPreviewIT`): KHONG chay duoc local — Docker khong kha dung. Bu bang unit tests + stub mirror + e2e; can chay lai tren CI/co Postgres that truoc khi merge.
- Full e2e suite: 12/13 khi chay cuoi cung (fail duy nhat la authoring timeout da sua bang setTimeout; user tu chay lai full suite).
- Stub khac biet backend that: stub mirror viet tay, khong phai Spring Boot — ket qua e2e chung minh contract phia client, khong thay the IT tren Postgres that.

## TASK-0018 blockers

- Khong blocker nao tu bugfix nay. Contract learner on dinh: MC `correctOptionIds`+`multiSelect`, MATCHING `leftItems`/`rightItems`, DRAG_ORDER items da xao tron on dinh, `evidence[]`/`assets[]` embed trong content.
- Flutter phai doc dung shape moi (khong con `pairs`, khong con items theo thu tu goc).
- Nen chay IT Postgres that truoc khi dong bo mobile.

## Cau hoi mo

- Can chay `AdminLessonPreviewIT`/`HiddenKeyLeakIT` tren moi truong co Docker/Postgres de xac nhan enrichment evidence tren backend that.
