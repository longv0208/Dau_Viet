# Plan: Issue #35 — Chuỗi 4 giai đoạn, chấm tự động 100%

## Gap đã xác nhận (scout 3 module, HEAD 2544112)

| Gap | File |
|---|---|
| STAGE_ALLOWED_ACTIVITIES thiếu VIEW_IMAGE→EVIDENCE, MC→DISCOVERY/HYPOTHESIS | `DraftSchema.java:45-56`, `draft-model.ts:40-50` |
| DragOrder/Matching chỉ chấm nhị phân, không maxAttempts/PARTIAL | `ScoredHandlers.java:69-154` |
| `matchedCount` sai (trả submitted.size thay số cặp đúng) | `ScoredHandlers.java:~108` |
| maxAttempts chưa validate ở DragOrder/Matching/MC/ReasoningConnect | `SimpleActivityValidators.java` |
| Admin validator thiếu MATCHING/HYPOTHESIS_CHOICE/VERIFICATION; preset thiếu stage | `draft-local-validator.ts`, `template-form.tsx:66-71` |
| version-detail-view truyền raw snapshot → MATCHING trống | `version-detail-view.tsx:60` |
| Mobile: không parse correctPositions/attemptsLeft; hypothesis không đọc priorOutputs; celebration nhầm CONTRADICTED | `attempt_dtos.dart`, `lesson_player_screen.dart`, `hypothesis_renderer.dart` |
| 4 bài seed thiếu chuỗi + 4 nhóm dấu vết | V20, V29 migrations |

## Quyết định đã chốt với user
- `maxAttempts` default DRAG_ORDER/MATCHING: 3.
- PARTIAL DRAG_ORDER: ≥50% vị trí đúng (bỏ nhánh "lệch 1 cặp liền kề").
- HYPOTHESIS_CHOICE giữ không chấm (chấm ở VERIFICATION).
- version-detail-view: chỉ fix render pairs→leftItems/rightItems, admin vẫn xem đáp án.

## Phases
1. Backend: DraftSchema + ScoredHandlers (PARTIAL/maxAttempts/correctPositions) + validators + tests + HiddenKeyLeakIT draft mở rộng.
2. Admin: draft-model sync, validators, editors maxAttempts, preset 7 stage, version-detail fix, stub/fixtures.
3. Mobile: DTO typed fields, feedback + verdict UI, HypothesisRenderer priorOutputs, inline feedback renderers, tests.
4. Seed: V51 migration 4 bài đủ chuỗi + 4 nhóm evidence; template preset; docs.

## Verify
- Backend `mvn test` (ScoredHandlersTest, HiddenKeyLeakIT, LearningFlow2IT).
- Admin `npm test` / lint gates.
- Mobile `flutter test`.
- AC→check mapping trong brief.md.
