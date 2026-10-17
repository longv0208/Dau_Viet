# Phase 01 — Contracts + Data Layer (DTOs, ApiClient auth, token storage, attempt repo)

## Context links

- Research: `plans/reports/research-261017-1844-task0018-flutter-contracts.md` (EXACT DTO + handler contracts)
- `docs/API_SPEC.md` §2 (learner endpoints), `docs/LEARNING_ENGINE_DESIGN.md` §13 (evaluation semantics)
- `docs/backend-flutter-contract-notes.md`
- TASK-0017 report: `plans/reports/final-261017-1740-matching-derangement-accepted-sequences-readiness.md`

## Overview

- Priority: P0 (nen tang cho moi phase sau)
- Status: pending
- Tao data layer that cho auth + learning trong `dau-viet-mobile`; mo rong `ApiClient` ho tro POST + Bearer; secure token storage; (neu duyet G1) endpoint attempt-scoped content trong `dau-viet-backend`.

## Key insights

- `ApiClient` hien chi co `get()` — can them `post(path, body, headers)` va co che gan `Authorization: Bearer` qua token provider (khong hard-code token trong client).
- `ApiError.details` hien la `String?` nhung backend tra **object** (vi du `details.errors[]`, `details.missing`) — phai doi sang `Map<String,dynamic>?`/`Object?` de khong mat thong tin khi parse.
- Refresh flow: `POST /auth/refresh {refreshToken}` → cap token moi; reuse/revoked → 401 + family revoked (logout local). Access TTL 900s — nen refresh proactive khi 401 lan dau (retry 1 lan) hoac khi het han theo `expiresIn`.
- Token storage: can them package `flutter_secure_storage` (khong co san trong pubspec; shared_preferences cung chua co — chon flutter_secure_storage cho tokens).
- Idempotency-Key la **header optional**; backend persist + replay response khi same key + same payload (`request_hash` = SHA-256 canonical(answer)). Client mint UUID v4; key MOI cho answer moi, giu NGUYEN key khi retry cung payload.

## Requirements

- Auth repository: `login(email,password)`, `register(...)`, `refresh()`, `logout()`, `restore()`; emit session state cho Riverpod.
- Learning API client + DTOs khop EXACT records (xem research report).
- `AttemptApiClient`: startOrResume, getAttempt, getCurrent, submit(activityId, answer, idempotencyKey), complete(idempotencyKey), getResult, myAttempts, myProgress.
- `LessonApiClient`: listForEvent, getMetadata, getContent (+ getAttemptContent neu backend co).
- ApiException map day du HTTP status → code tu envelope.

### Backend (chi khi user duyet G1 — neu khong duyet thi bo muc nay)

- `GET /api/v1/attempts/{attemptId}/content` → `LearnerLessonContent` cua **pinned** `lessonVersionId`; owner-only; reuse `LearnerProjectionService.project()` + snapshot cua version da pin.
- File: `LearnerAttemptController` (1 mapping), `LearnerAttemptService` (method `getContent(userId, attemptId)`), khong migration.
- Regression test (unit/WebMvc, khong can Docker): mock start v1 → publish v2 → service tra version v1. Postgres IT: ghi NOT VERIFIED neu thieu Docker.

## Architecture

```
core/api/api_client.dart      + post(), + auth token provider hook
core/api/api_error.dart       details: String? -> Map<String,dynamic>?
core/auth/token_storage.dart  flutter_secure_storage wrapper (access+refresh+expiry)
features/auth/data/auth_api_client.dart      /auth/login|register|refresh|logout
features/auth/data/auth_repository.dart      session restore + refresh-on-401
features/auth/data/auth_state.dart           sealed/enum: unknown|guest|authenticated
features/learning/data/learning_dtos.dart    attempt/activity/submit/result/progress DTOs
features/learning/data/learning_api_client.dart
features/learning/data/attempt_repository.dart (USE_MOCK seam nhu events)
features/learning/data/mock_attempt_repository.dart
```

Mobile giu pattern hien tai: `XApiClient` (HTTP + parse) → `XRepository` (interface) → provider switch `USE_MOCK`.

## Related code files

Modify:
- `dau-viet-mobile/lib/core/api/api_client.dart` (add post + auth)
- `dau-viet-mobile/lib/core/api/api_error.dart` (details object)
- `dau-viet-mobile/pubspec.yaml` (+ flutter_secure_storage; uuid neu can sinh idempotency key)

Create:
- `lib/core/auth/token_storage.dart`
- `lib/features/auth/data/{auth_api_client.dart, auth_repository.dart, auth_state.dart}`
- `lib/features/learning/data/{learning_dtos.dart, learning_api_client.dart, attempt_repository.dart, mock_attempt_repository.dart}`
- `lib/features/learning/data/learning_providers.dart`
- Backend (neu G1): method `getContent` trong `LearnerAttemptService.java`, mapping trong `LearnerAttemptController.java`, test `LearnerAttemptContentTest`/`*IT` (ghi ro neu khong chay duoc).

## Implementation steps

1. `flutter pub add flutter_secure_storage` (va `uuid` neu chua co — check `dart pub add uuid`).
2. Sua `ApiError.details` → `Map<String,dynamic>?`; cap nhat `api_client_test.dart`/`events_dto_test.dart` neu bi anh huong.
3. `ApiClient`: them `post(path, {body, headers})`, `setAuthToken(String?)` hoac interceptor doc tu TokenStorage; giu nguyen `get()` API.
4. `TokenStorage`: read/write access+refresh+expiry; `clear()`; singleton qua provider.
5. `AuthApiClient` + `AuthRepository`: login/refresh/logout/restore; refresh-on-401 wrapper cho cac call authed (don gian: retry 1 lan sau refresh, reuse detection → session expired → logout local).
6. `learning_dtos.dart`: `AttemptStartDto`, `AttemptProgressDto`, `CurrentActivityDto` (stage/activity/progress), `SubmitResultDto` (evaluation/next/completion), `CompleteResultDto`, `LessonResultDto`, `AttemptSummaryDto`, `MyProgressDto`, `LessonListItemDto`, `LessonMetadataDto`, `LessonContentDto` (content giu `Map<String,dynamic>` vi snapshot la free-form JSON).
7. `LearningApiClient` + `AttemptRepository` interface + `MockAttemptRepository` (giu journey mock hien co cho USE_MOCK) + providers.
8. (G1) Backend endpoint + unit test.

## Todo list

- [ ] pubspec: flutter_secure_storage + uuid
- [ ] ApiError.details object; ApiClient.post + bearer
- [ ] TokenStorage + auth state providers
- [ ] AuthApiClient/AuthRepository (login/register/refresh/logout/restore)
- [ ] Learning DTOs + api client + repository + mock + providers
- [ ] (G1) `GET /attempts/{id}/content` backend + test (hoac ghi quyet dinh fallback)
- [ ] `flutter pub get` + `dart format` + `flutter analyze` sach

## Success criteria

- `flutter analyze` 0 errors; DTO unit-parse duoc fixture JSON mau khop records backend.
- Auth repository login/refresh/logout chay duoc voi backend stub gia lap (widget/unit test voi Dio mock adapter).
- USE_MOCK=true khong doi hanh vi hien co.

## Risk assessment

- Auth refresh race (nhieu request 401 dong thoi): serialize refresh bang 1 Future chia se trong repository.
- flutter_secure_storage tren Windows test: wrap try/catch, fallback in-memory cho unit test (khong cho prod path).
- G1 neu khong them endpoint: ghi ro han che — player phai gioi han content hien thi hoac mismatch version; van giu correct submit vi server dung pinned snapshot.

## Security considerations

- Tokens trong flutter_secure_storage (keystore/DPAPI), khong shared_preferences plaintext, khong log.
- Refresh reuse detection → xoa session local ngay.
- Khong gui idempotency key/log nhat ki kem PII.

## Next steps

Phase 02 dung auth_repository + lesson/attempt api clients de noi journey Login → Event → Lesson list → Start/Resume.
