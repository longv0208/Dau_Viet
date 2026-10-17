# Phase 04 — Submission / Idempotency / Progression / Completion / Result

## Context links

- Phase 01 (AttemptRepository + DTOs), phase 03 (player + renderers + feedback banner)
- `docs/API_SPEC.md` §2 (submit/complete/result), `docs/LEARNING_ENGINE_DESIGN.md` §13
- Research report — submit contract + idempotency semantics (`plans/reports/research-261017-1844-task0018-flutter-contracts.md`)
- TASK-0011/0012 semantics: `Idempotency-Key` header optional; scope (user,operation,key); `request_hash` = SHA-256(attemptId|activityId|canonical(answer)); same key + same payload → 200 replay; same key + diff payload → 409 `IDEMPOTENCY_CONFLICT`

## Overview

- Priority: P0
- Status: pending
- Gan flow submit day du vao player: mint/keep idempotency key dung luat, hien feedback tu server, tien cursor theo `next`, retry giu nguyen answer + key, complete khi server bao xong, result screen tu `/attempts/{id}/result`.

## Key insights

- Submit request: `POST /attempts/{attemptId}/activities/{activityId}/submissions`, body `{answer:<JsonNode>}`, header `Idempotency-Key: <uuid>` — HEADER, khong phai field trong body.
- Luat key: answer MOI (noi dung thay doi) → mint key moi (uuid v4). Retry cung answer (network fail / timeout / 5xx) → GIu nguyen key cu → server replay 200 neu da ghi. Khong gui lai key khi user sua answer (→ 409 IDEMPOTENCY_CONFLICT neu giu sai).
- Implementation: `PlayerNotifier` giu `(activityId, answer, key)` trong state; `submit()` dung key dang luu; chi regenerate khi `onAnswerChanged` nhan payload khac payload cu.
- Response `SubmitActivityResponse`: `status`, `evaluation{outcome,completed,output,feedbackCode}`, `activityCompleted`, `progress`, `next{stageId,activityId,activityType,learnerConfig}` (null khi het), `completion`. `next` la cursor drive — KHONG tu suy luan activity tiep.
- INCORRECT + chua `exhausted` → giu cursor, cho thu lai (key MOI vi answer moi). `exhausted:true` → activityCompleted van true → hien feedback + Continue.
- EVIDENCE_SELECT chua du `minRequired` → `completed:false`, outcome IN_PROGRESS → giu state, hien hint, khong gioi han so lan.
- VERIFICATION outcome PARTIAL/CONTRADICTED → `completed:false`, cursor giu → cho revise (HYPOTHESIS submit lai → VERIFICATION lai).
- EXPLORE_MAP: submit `{markerId}` tung cai → `completed` khi du `minMarkers`; `output.discoveredMarkerIds` de hien da mo.
- Complete: `POST /attempts/{id}/complete` + `Idempotency-Key` (mint 1 lan cho lan complete dau, keep qua retry). `alreadyCompleted:true` → hien trang thai, khong double reward UI.
- Result: `GET /attempts/{id}/result` → `{score (0-100 = completion%), result(JsonNode), completedAt, startedAt}`; `result` free-form → render defensive (key co san: completion detail neu co; fallback hien score + time).
- 404 `ATTEMPT_NOT_FOUND` (foreign/expired) → friendly + ve lesson entry; 409 `ATTEMPT_ALREADY_COMPLETED` → thang result screen; 422/`VALIDATION_FAILED`/`INVALID_*` → hien `message` + giu answer.

## Requirements

- `PlayerNotifier.submit()`: disable UI, optimistic state `submitting`; giu answer + key; catch error → khoi phuc `answering` voi answer cu (keep user input).
- Retry: nut "Thử lại" tren error dung CUNG answer + CUNG key (chi mang/5xx; 4xx khong retry — hien message).
- Continue chi xuat hien khi `activityCompleted && next != null`; bam → swap sang `next` (resolve stage/activity tu snapshot embed: `next.activityId` lookup trong `stages[].activities[]`).
- "Hoan thanh bai hoc" khi `next == null && activityCompleted` → `complete()` → result route.
- `LessonResultScreen(attemptId)`: GET result → hien score, thoi gian, completion; CTA ve campaign/dashboard; reuse `BiteSizedCompletionModal` + `GoldConfettiOverlay` khi completion 100%.
- Offline/network drop: giu state; banner offline; khong mat answer; khong auto-retry spam.
- Answer serialize: renderer tra `Map<String,dynamic>` dung shape contract (phase 03 bang); player goi thang — khong transform.

## Architecture

```
features/learning/presentation/player/player_state.dart   (+submit/complete logic)
features/learning/presentation/player/retry_banner.dart   error + retry giu key
features/learning/presentation/lesson_result_screen.dart  score + detail + CTA
features/learning/data/idempotency.dart                   mint/keep key helper (uuid)
```

## Related code files

Modify:
- `lib/features/learning/presentation/lesson_player_screen.dart` (bottom bar states)
- `lib/features/learning/data/attempt_repository.dart` (submit/complete/result signatures + key param)
- `lib/app/router.dart` (`/learning/attempt/:attemptId/result` hoac result trong player — chon: route rieng de deep-linkable)

Create:
- `lib/features/learning/presentation/player/retry_banner.dart`
- `lib/features/learning/presentation/lesson_result_screen.dart`
- `lib/features/learning/data/idempotency.dart`

## Implementation steps

1. `idempotency.dart`: `Uuid` mint + `keyFor(activityId, answer)` — state holder `{String key, String answerJson}`; regenerate khi answerJson thay doi (so sanh canonical — encode sorted keys hoac so sanh Map deep).
2. `AttemptRepository.submit(attemptId, activityId, answer, idempotencyKey)` → parse `SubmitResultDto` (evaluation + next + progress + completion).
3. `AttemptRepository.complete(attemptId, key)` → `CompleteResultDto{alreadyCompleted,completedAt,completion,progress}`; `result(attemptId)` → `LessonResultDto`.
4. `PlayerNotifier`: state `{phase, answer, key, lastError}`; submit → thanh cong: phase `feedback`; fail: phase `answering` + error, giu answer+key.
5. Continue: doc `next`, lookup activity trong snapshot → set current; progress update tu `progress`.
6. Complete → navigate `/learning/attempt/{id}/result`; `alreadyCompleted` → hien nhe "Đã hoàn thành trước đó".
7. Result screen: fetch result; hien `score`, `startedAt`/`completedAt` formatted vi_VN; `result` keys co san render generically; confetti khi score==100.
8. Exit confirm trong player khi chua complete: pop → giu attempt (server-side); ve campaign.

## Todo list

- [ ] Idempotency mint/keep helper + uuid package
- [ ] submit/complete/result repository calls + DTO parse
- [ ] Player submit → feedback → continue theo `next`
- [ ] Retry giu answer + key; 4xx hien message khong retry
- [ ] Complete + result screen + confetti + CTA ve dashboard
- [ ] Exit confirm + resume sau app kill
- [ ] `flutter analyze` sach

## Success criteria

- Submit dung payload contract tung type; retry cung answer → cung `Idempotency-Key`; doi answer → key moi.
- INCORRECT → thu lai duoc; `exhausted` → di tiep; EVIDENCE_SELECT/VERIFICATION giu cursor khi `completed:false`.
- Complete idempotent (`alreadyCompleted` an toan); result hien score + metadata.
- Kill app giua attempt → mo lai → resume dung cursor (`resumed:true`, cung current activity).
- Network mat giua submit → answer khong mat; retry thanh cong khong tao duplicate (server replay).

## Risk assessment

- Canonical answer cho key comparison: dung `jsonEncode` tren normalized Map (deep-equal) — don gian, du cho MVP; neu answer co ordering (DRAG_ORDER orderedIds) ordering LA mot phan answer → khong sort list.
- `next` thieu `instruction`/`feedback` → phase 03 da resolve tu snapshot embed; verify bang test fixture.
- Attempt cua user khac (route share) → 404/403 → ve entry an toan.
- Timeout submit: keep pending state + key; retry bang tay.

## Security considerations

- Idempotency-Key random uuid, khong chua PII; khong log key kem user id.
- 403 owner-check → khong retry, thong bao khong co quyen.
- Khong cache `result`/`answer` xuong disk.

## Next steps

Phase 05: media asset fetch co auth + error envelope mapping toan cuc + mock split polish.
