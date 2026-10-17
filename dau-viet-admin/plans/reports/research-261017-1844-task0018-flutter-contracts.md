# research-261017-1844-task0018-flutter-contracts

Khao sat codebase thuc cho TASK-0018 (Flutter real learning). Nguon: backend java truc tiep + docs/API_SPEC.md + TASK-0017 final report.

## Learner endpoints (da verify trong code)

`LearnerAttemptController` `/api/v1`:

| Method | Path | Response record |
|---|---|---|
| POST | `/lessons/{lessonId}/attempts` | `AttemptStartResponse{attemptId, lessonVersionId, status, resumed, currentStageId, currentActivityId}` |
| GET | `/attempts/{id}` | `AttemptProgressResponse{attemptId, lessonVersionId, status, currentStageId, currentActivityId, progress{completedRequired,totalRequired}, completion}` |
| GET | `/attempts/{id}/current` | `CurrentActivityResponse{stage{id,type,title}, activity{id,type,instruction,config(JsonNode),feedback(JsonNode)}, progress}` — activity null khi het required |
| POST | `/attempts/{id}/activities/{activityId}/submissions` body `{answer:JsonNode}` header `Idempotency-Key` (optional) | `SubmitActivityResponse{status, evaluation{outcome,completed,output,feedbackCode}, activityCompleted, progress, next{stageId,activityId,activityType,learnerConfig}, completion}` |
| POST | `/attempts/{id}/complete` header `Idempotency-Key` | `CompleteAttemptResponse{attemptId,status,alreadyCompleted,completedAt,completion,progress}` |
| GET | `/attempts/{id}/result` | `LessonResultResponse{attemptId,lessonVersionId,status,score(BigDecimal),result(JsonNode),completedAt,startedAt}`; score = completion % 0-100 |
| GET | `/me/attempts?status&page&size` (size<=50) | `PageResponse<AttemptSummaryResponse{attemptId,lessonId,lessonVersionId,status,currentStageId,currentActivityId,progress,startedAt,lastActiveAt,completedAt}>` |
| GET | `/me/progress` | `MyProgressResponse{inProgress[AttemptSummary], completedCount}` |

`LearnerLessonController`: `GET /events/{eventId}/lessons` → `List<LearnerLessonListItem{id,title,centralQuestion}>`; `GET /lessons/{id}` → `LearnerLessonMetadata{id,title,centralQuestion,eventId,currentVersionId,versionNo,publishedAt}`; `GET /lessons/{id}/content` → `LearnerLessonContent{lessonId,lessonVersionId,versionNo,content(JsonNode)}` — content = projected snapshot: `stages[]` + `evidence[]` + `assets[]` + `objectives` + `completion`.

`LearnerAssetController`: `GET /api/v1/assets/{id}/content` → bytes (authenticated, ACTIVE only). Khong co metadata endpoint cho learner — metadata di kem trong `assets[]` embed cua snapshot (`id,storageKey,mimeType,sizeBytes,originalFilename,altText`).

`AuthController`: `POST /auth/register {email,password,displayName?,role?}` → 201 `UserProfileDto`; `POST /auth/login {email,password}` → `{accessToken,tokenType:"Bearer",expiresIn,refreshToken,refreshExpiresIn}`; `POST /auth/refresh {refreshToken}` → cap moi (rotation + family revoke on reuse); `POST /auth/logout {refreshToken}` → 204 idempotent. Tat ca token o BODY (khong cookie). `GET /users/me` → `{id,email,displayName,role,status,emailVerifiedAt,createdAt}`.

Error envelope: `{code,message,details(object),traceId}`; header `X-Request-Id` tren moi response.

## Activity contracts (handlers da verify)

| Type | answer payload client gui | Danh gia server | outcome/completed |
|---|---|---|---|
| READ | `{}` (bat ky well-formed) | — | COMPLETED, output `{viewed:true}` |
| VIEW_IMAGE | `{}` | imageAssetId phai trong snapshot.assets | COMPLETED |
| MULTIPLE_CHOICE | `{selectedOptionIds:[...]}` | set-equality `correctOptionIds` (fallback `multiCorrect`); id la → IllegalArgument (400) | COMPLETED/INCORRECT; `maxAttempts`(def 1) het → `exhausted:true`, van completed |
| EVIDENCE_SELECT | `{selectedEvidenceIds:[...]}` | ⊆ snapshot.evidence ∩ `visibleEvidenceIds` | completed khi >= `minRequired` (def 1); chua du → IN_PROGRESS |
| MATCHING | `{pairs:[{leftId,rightId}...]}` | pair-set vs `correctPairs`; id la → 400 | COMPLETED/INCORRECT |
| DRAG_ORDER | `{orderedIds:[...]}` | order-equality `expectedOrder`/`correctOrder` ∪ `acceptedSequences` | COMPLETED/INCORRECT |
| HYPOTHESIS_CHOICE | `{hypothesisId, evidenceIds[]}` | hypothesisId ∈ config.hypotheses; evidenceIds ⊆ snapshot | luon COMPLETED (khong cham) |
| VERIFICATION | `{revise:true}` hoac bat ky | doc hypothesis moi nhat tu priorOutputs | SUPPORTED(completed)/PARTIAL/CONTRADICTED; khong echo key |
| REASONING_CONNECT | `{relations:[{from,to,relation}]}` | from/to ∈ nodes, relation ∈ allowedRelations | COMPLETED hoac 400 |
| EXPLORE_MAP | `{markerId}` | ∈ config.markers; tich luy qua priorOutputs | completed khi >= `minMarkers` (def = all) |
| CER | `{claim,evidenceIds[],reasoning}` | claim+reasoning >=20 chars moi field | COMPLETED; output echo claim/reasoning/filtered evidenceIds |
| REFLECTION_PROMPT | `{text}` (non-empty,<=4000) hoac `{optionId}` | optionId ∈ config.options neu co | COMPLETED |

`feedbackCode` tra ve la KEY trong `activity.feedback` — renderer resolve `feedback[feedbackCode]` de hien thi (co the null). IllegalArgumentException cua handler → 400.

Learner config shapes sau projection (TASK-0017): MCQ `options[]` + `multiSelect`; MATCHING `leftItems[]`/`rightItems[]` (deranged, KHONG pairs); DRAG_ORDER `items[]` shuffled; EVIDENCE_SELECT `visibleEvidenceIds` + `minRequired`; VERIFICATION `visibleSourceIds`; HYPOTHESIS `hypotheses[{id,label?}]`; EXPLORE_MAP `markers[]`; CER `rubric.criteria` (requiredEvidenceIds bi strip); REFLECTION `options[]`?/`prompt`.

## Version pinning — GAP da xac nhan

`GET /lessons/{id}/content` LUON tra `current_version_id` (version moi nhat). Attempt pin `lessonVersionId` luc start; resume sau republish → content mismatch. `/attempts/{id}/current` tra dung pinned snapshot NHUNG chi 1 activity + khong kem `evidence[]`/`assets[]` embed → renderer EVIDENCE_SELECT/VERIFICATION/VIEW_IMAGE thieu metadata neu chi dung endpoint nay.

Quyet dinh de xuat: them endpoint moi `GET /api/v1/attempts/{attemptId}/content` (read-only, owner-only) tra `LearnerLessonContent` cua pinned `lessonVersionId`. Thay doi backend toi thieu: 1 method trong LearnerAttemptService + 1 mapping trong LearnerAttemptController; reuse `projection.project()` + `snapshotOf()`. Regression test: start v1 → publish v2 → GET attempts/{id}/content van tra v1. Neu khong them: fallback duy nhat la render theo `/current` + `next.learnerConfig` (khong co evidence embed → EVIDENCE_SELECT/VERIFICATION chi hien thi id) — KHONG du cho journey.

## Mobile hien tai — tai san va gaps

Co san: Dio `ApiClient` (chi GET, chua co POST/header auth), `ApiConfig` (API_BASE_URL + USE_MOCK dart-define), `ApiError`/`ApiException` khop envelope (details hien la String? — backend tra object, can sua thanh dynamic/Map), `AsyncStateView`, theme DauViet, DongSonButton/ParchmentCard/ShimmerProgressBar/Tactile3DCard/ShakeAnimationWidget/mascot/BiteSizedCompletionModal/GoldConfettiOverlay/AmbientAtmosphereOverlay, Riverpod pattern repository (events: `EventsRepository` + `ApiEventsRepository` + `MockEventsRepository` + provider switch USE_MOCK). `AssetResolver` hien chi map event cover → bundle asset local.

Thieu: POST trong ApiClient; Bearer attach + refresh interceptor; secure token storage (chua co flutter_secure_storage/shared_preferences trong pubspec); auth session provider; learning DTO/repository that; lesson list + player + renderer registry; attempt flow; asset image fetch co auth. AuthScreen hien fake (guest + Google/EduID → thang dashboard). 6 man learning mock hard-code answer keys (`isCorrect`, `correctRight`, `_correctOrder`) — phai refactor thanh data-driven renderers nhan config + nhan feedback tu server (bo het answer keys).

Router hien tai: `/`, `/auth`, `/dashboard`, `/timeline`, `/campaign/:eventId`, `/traces/:eventId`, `/learning/*` (6 mock screens doc lap), `/rewards/*`, meta screens. Can them `/learning/lesson/:id` (list+start) va `/learning/attempt/:id` (player). Splash dieu huong cung `/auth` sau 2.5s — can session restore branch.

Moi truong: Flutter 3.47.7 + Dart 3.13.5 da cai (chay duoc `flutter pub get/analyze/test`). Docker KHONG co → backend IT Testcontainers khong chay duoc local; backend `spring-boot:run` van can Postgres (docker compose) → real-backend e2e local kha nang KHONG VERIFY duoc, ghi ro trong plan. Learner account: khong co seed — tao qua `/auth/register` khi backend chay.

## Unresolved / can hoi user

1. Version-pinned content: dong y them `GET /attempts/{id}/content` backend (doc-only) hay chap nhan gioi han current-version o MVP? De xuat: them — high-risk nho, dong goi phase 1.
2. Guest mode: brief noi guest = mock only. Xac nhan USE_MOCK=true giu demo mock; USE_MOCK=false bat buoc login (khong guest).
3. EXPLORE_MAP: contract ro ({markerId}, markers[] + minMarkers) nhung UI map that can base image — bai Bạch Đằng co map asset trong design assets nhung lesson co reference khong ro; de xuat render marker list don gian (khong map image) trong phase 3 neu thoi gian, nguoc lai unsupported state.

EOF
