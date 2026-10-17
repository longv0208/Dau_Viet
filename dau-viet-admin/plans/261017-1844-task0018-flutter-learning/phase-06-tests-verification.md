# Phase 06 — Tests + Verification + Report

## Context links

- Tat ca phases 01-05; `docs/CODING_RULES.md`; `docs/AGENT_WORKFLOW.md` (gates, honest verification)
- Existing tests: `test/{api_client,events_dto,events_repository,asset_resolver,mock_mode,campaign_detail,...}_test.dart`
- Moi truong: Flutter 3.47.7 + Dart 3.13.5 da verify; Docker KHONG co → backend IT/Testcontainers + real-backend e2e ghi NOT VERIFIED (policy reason, khong claim).

## Overview

- Priority: P0 (gate cuoi)
- Status: pending
- Unit + widget tests cho data layer va journey; chay day du `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, build; viet verification report trung thuc (verified / not verified + ly do).

## Key insights

- Test strategy theo brief: test co mock Dio adapter (khong call backend that). KHONG dung fake data/mocks de "pass" — fixture JSON phai khop EXACT records backend (copy shape tu research report).
- `flutter_secure_storage` khong chay trong unit test → TokenStorage wrapper co seam inject (in-memory fake cho test — seam o constructor, khong pha prod path).
- Widget tests dung `ProviderScope` override repository → `FakeAttemptRepository` trong test (test fixture, KHONG phai mock repo cua app — mock repo chi cho USE_MOCK demo).
- Coverage muc tieu: DTO parse 100% contract fields; answer payload builders per type; idempotency key rules; error mapping; auth refresh-on-401; player flow happy + INCORRECT + resume + complete.

## Requirements

### Unit tests (khong can backend)

- `learning_dtos_test.dart`: parse fixture `AttemptStartResponse`, `CurrentActivityResponse` (activity null), `SubmitActivityResponse` (next null + next co learnerConfig), `CompleteAttemptResponse`, `LessonResultResponse`, `AttemptSummaryResponse`, `MyProgressResponse`, `LearnerLessonContent` — assert field names khop records.
- `answer_payload_test.dart`: moi renderer tra payload dung shape contract (MCQ `selectedOptionIds`, MATCHING `pairs[{leftId,rightId}]`, DRAG_ORDER `orderedIds`, CER 3 fields, EXPLORE_MAP `markerId`, ...).
- `idempotency_test.dart`: cung answer → cung key; doi answer → key moi; retry giu key.
- `api_client_test.dart` (mo rong): POST body + Bearer header; envelope parse `{code,message,details(object),traceId}`; 409 IDEMPOTENCY_CONFLICT.
- `auth_repository_test.dart`: login luu token; 401 → refresh → retry; refresh fail → session expired + clear storage; logout idempotent.
- `error_mapper_test.dart`: 400/401/403/404/409/422/5xx/network → UiError dung copy key.

### Widget tests

- `lesson_list_test.dart`: list that tu fake repo; empty → "Chưa có bài học được xuất bản".
- `lesson_player_test.dart`: render per type tu fixture config (MCQ, MATCHING, DRAG_ORDER, CER, EVIDENCE_SELECT toi thieu); unsupported type → unsupported view; submit → feedback hien `feedback[feedbackCode]`; Continue → next activity render.
- `player_flow_test.dart`: INCORRECT → thu lai; `exhausted` → continue; next==null → Hoan thanh → complete → result screen hien score.
- `resume_test.dart`: `resumed:true` + cursor giua lesson → render dung activity; app kill simulation = moi build voi attempt state.
- `mock_mode_test.dart` (mo rong): USE_MOCK=false → guest an, mock repo khong tao; USE_MOCK=true → demo routes con.
- `asset_image_test.dart`: bytes → image; 404 → placeholder + altText semantics.

### Gates (chay that, ghi ket qua)

1. `flutter pub get`
2. `dart format lib test` (hoac `flutter format`)
3. `flutter analyze` — 0 errors (warnings chap nhan neu khong blocker)
4. `flutter test` — toan bo pass
5. `flutter build apk --debug` (hoac `flutter build web` neu toolchain thieu — chon 1 target chay duoc, ghi ro)
6. `git diff --check` — khong whitespace loi

### Verification report

Ghi vao `plans/reports/verification-261017-task0018-flutter-learning.md`: tung gate, command, tool version, ket qua that; muc "NOT VERIFIED" cho backend IT/real-backend e2e + manual checklist cho user chay tay (backend len → register → journey).

## Architecture

```
test/learning/learning_dtos_test.dart
test/learning/answer_payload_test.dart
test/learning/idempotency_test.dart
test/auth/auth_repository_test.dart
test/core/error_mapper_test.dart
test/learning/lesson_list_test.dart
test/learning/lesson_player_test.dart
test/learning/player_flow_test.dart
test/learning/resume_test.dart
test/learning/asset_image_test.dart
test/fixtures/*.json                     (response fixtures khop backend records)
```

## Related code files

Create: cac test file + fixtures + `test/fakes/fake_attempt_repository.dart` + `test/fakes/in_memory_token_storage.dart`.
Modify: `test/api_client_test.dart`, `test/mock_mode_test.dart` (mo rong), file nao test cu bi vo do ApiError.details doi type.

## Implementation steps

1. Tao fixtures JSON tu research report tables (nho nhat du field).
2. Fakes: `FakeAttemptRepository` (scripted responses), `InMemoryTokenStorage`.
3. Viet unit tests theo list tren — DTO truoc, roi idempotency/error/auth.
4. Widget tests player dung `ProviderScope(overrides:[attemptRepositoryProvider...])`.
5. Chay tung gate; fail thi sua theo ket qua, khong bo qua.
6. Viet verification report; cap nhat `plan.md` status cac phase + `tasks/TASK-0018/task.json` status khi duyet xong.
7. Manual checklist (cho user): start backend + register + login + journey + resume.

## Todo list

- [x] Fixtures + fakes (repo, token storage)
- [x] Unit tests: DTO, payload, idempotency, error mapper, auth repo
- [x] Widget tests: list, renderers, feedback, flow, resume, asset image, mock split
- [x] `flutter pub get` + format + analyze (0 errors)
- [x] `flutter test` all pass
- [x] Build 1 target thanh cong
- [x] Verification report + plan status + task.json
- [x] Manual e2e checklist cho user

## Success criteria

- Toan bo gate 1-6 pass va ghi duoc evidence that trong report.
- Khong test nao fake pass (fixture sai shape, skip, expect tam thuong).
- NOT VERIFIED items co ly do policy ro rang (Docker thieu, can user chay backend).

## Risk assessment

- `flutter_secure_storage` trong widget test → da seam in-memory; verify test khong cham plugin that.
- Build APK can Android toolchain → fallback `flutter build web`; ghi target da chay.
- Test fixture drift khoi backend → giu fixture sinh tu research report; reviewer doi chieu records.

## Security considerations

- Fixtures khong chua token/email that; answer keys trong fixture la data test, khong phai production content.

## Next steps

Bao cao ve caller: trang thai phase, gates, NOT VERIFIED, manual checklist.
