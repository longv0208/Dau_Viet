# Phase 01 — Backend: Event Completion Policy Admin API

## Context Links

- Spec: task spec Module A trong yeu cau goc.
- Entity: `dau-viet-backend/src/main/java/com/dauviet/collection/domain/EventCompletionPolicy.java` — `updatable=false` tren `id`, `eventId`, `policyVersion`, `requiredLessonIdsJson`, `optionalLessonIdsJson`, `publishedAt`. Chi `status` + `masteryThreshold` mutable.
- Repository: `EventCompletionPolicyRepository` (chi co `findPublishedByEventId`).
- DB: `V22__event_completion_dossiers.sql` — `event_completion_policies` table + `ux_event_policy_published` partial unique index da co. `chk_policy_threshold` CHECK 0..100.
- Pattern tham chieu: `AdminEventService.publish()` / `archive()` (DRAFT→PUBLISHED→ARCHIVED, InvalidStatusTransitionException).
- SecurityConfig: `/api/v1/admin/**` -> `hasRole("CONTENT_ADMIN")` (da xac minh).

## Overview

- Priority: P1 (blocker cho Admin UI Gamification tab)
- Status: pending
- Effort: 5h
- Them admin CRUD + validate + publish cho `event_completion_policies`. Published immutable; thay doi = DRAFT moi (copy-on-write) -> publish -> archive row cu.

## Key Insights

- `requiredLessonIdsJson`/`optionalLessonIdsJson` `updatable=false` -> khong PATCH DRAFT; phai INSERT row moi (DRAFT v_next) hoac bypass bang `@Modifying @Query`. Chon: **tao DRAFT moi** (copy-on-write ro rang, audit-friendly, khong pha entity contract).
- `masteryThreshold` map `Short` (SMALLINT) — request DTO nhan Integer 0..100, service convert sang Short. `null` = event khong xet mastered.
- `findByIdForUpdate` tren `HistoricalEvent` (dung `HistoricalEventRepository` — can them method hoac dung `EntityManager` + `LockModeType.PESSIMISTIC_WRITE`). Lock event row serialize concurrent publish.
- Optimistic lock chong stale publish: request publish kem `expectedPolicyVersion`; neu `max(policy_version)` cua event da > expected -> 409.
- `EventMilestoneRecorder.fanOutDossierUnlocks` doc `findEventCompletedDossierIds` + `historical_dossiers.status='PUBLISHED'` — publish policy moi khong tu thu hoi grant cu (dung contract EVT-05).

## Requirements

- GET `/{eventId}/completion-policies` — list moi version (DRAFT/PUBLISHED/ARCHIVED), sort `policyVersion desc`.
- GET `/{eventId}/completion-policies/{policyId}` — detail.
- POST `/{eventId}/completion-policies` — tao DRAFT moi. Body: `requiredLessonIds`, `optionalLessonIds`, `masteryThreshold`. Neu co PUBLISHED hien tai -> copy-on-write sang DRAFT `policyVersion = published.policyVersion + 1`; neu chua co gi -> v1. Tra `AdminCompletionPolicyResponse` + status 201.
- PUT `/{eventId}/completion-policies/{policyId}` — chi duoc khi `status=DRAFT`. Cap nhat `requiredLessonIds`, `optionalLessonIds`, `masteryThreshold` qua copy-on-write sang row DRAFT moi, xoa DRAFT cu, giu `policyVersion`. **Thuc te**: vi fields `updatable=false`, phai (a) xoa DRAFT cu + insert DRAFT moi voi cung `policy_version`, hoac (b) cho phep edit bang @Modifying native query. Chon (a) cho ro rang (khong tao draft lap: chi 1 DRAFT tai mot thoi diem — enforce bang service).
- POST `/{eventId}/completion-policies/{policyId}/validate` — dry-run. Tra `AdminPolicyValidationResponse` chua `valid: bool`, `errors: [{code,message,field?}]`, `warnings: [string]`, `diff: {from:{…}, to:{…}}` (so sanh voi PUBLISHED hien tai neu co).
- POST `/{eventId}/completion-policies/{policyId}/publish` — atomic: lock event -> revalidate -> archive PUBLISHED cu -> publish DRAFT -> commit. Tra `AdminCompletionPolicyResponse` cua version moi PUBLISHED.

### Validation rules (chay trong `validate` + re-run trong `publish`)

- `eventId` ton tai + status `PUBLISHED` (khong cho publish policy cho event DRAFT/ARCHIVED).
- `requiredLessonIds` >= 1, khong duplicate, moi lesson: ton tai + `eventId` match + `status=PUBLISHED`.
- `requiredLessonIds` ∩ `optionalLessonIds` = ∅.
- `optionalLessonIds` khong duplicate, moi lesson thuoc event + PUBLISHED.
- `masteryThreshold` null hoac 0..100.
- Khong qua 1 PUBLISHED per event — enforce bang partial unique (da co) + lock.

## Architecture

### Files moi

| File | Muc dich |
|------|----------|
| `collection/api/AdminCompletionPolicyController.java` | REST controller `/api/v1/admin/events/{eventId}/completion-policies`. |
| `collection/api/dto/AdminCompletionPolicyDtos.java` | `AdminCompletionPolicyResponse`, `AdminCompletionPolicyUpsertRequest`, `AdminPolicyValidationResponse`, `PolicyIssue`. |
| `collection/application/AdminCompletionPolicyService.java` | Business logic: list/get/create/update-draft/validate/publish. |
| `collection/domain/PolicyValidationException.java` | 400 khi validation fail. |
| `historicalevent/infrastructure/persistence/HistoricalEventRepository.java` | **Sua** — them `@Lock(PESSIMISTIC_WRITE) findForUpdate(UUID id)`. |

### Endpoint contracts

```jsonc
// GET /api/v1/admin/events/{eventId}/completion-policies
// -> PageResponse<AdminCompletionPolicyResponse> hoac list don gian (su dung List)
[
  {
    "id": "uuid",
    "eventId": "uuid",
    "policyVersion": 2,
    "status": "DRAFT",
    "requiredLessonIds": ["uuid"],
    "optionalLessonIds": ["uuid"],
    "masteryThreshold": 70,
    "publishedAt": null,
    "createdAt": "2026-10-25T..."
  }
]

// POST /api/v1/admin/events/{eventId}/completion-policies
// body: { "requiredLessonIds": [...], "optionalLessonIds": [...], "masteryThreshold": 70 }
// -> 201 AdminCompletionPolicyResponse

// PUT /api/v1/admin/events/{eventId}/completion-policies/{policyId}
// body: same as POST + "expectedPolicyVersion" de bat stale-edit
// -> 200 AdminCompletionPolicyResponse (DRAFT moi, cung policyVersion)

// POST .../validate
// body: { "requiredLessonIds": [...], "optionalLessonIds": [...], "masteryThreshold": ... }
// hoac khong body = validate DRAFT hien tai
// -> 200 { "valid": true|false, "errors": [{code,message}], "warnings": [...], "diff": { "from": {...}, "to": {...} } }

// POST .../publish
// body: { "expectedPolicyVersion": 2 }
// -> 200 AdminCompletionPolicyResponse (PUBLISHED) | 409 stale | 400 invalid
```

### Transaction publish

```java
@Transactional
publish(eventId, policyId, expectedVersion):
  event = events.findForUpdate(eventId) or 404
  policy = policies.findById(policyId) or 404; check policy.eventId == eventId
  check policy.status == DRAFT
  if expectedVersion != null && maxVersion(eventId) != expectedVersion -> throw OptimisticLock
  errors = validateDraft(policy)
  if !errors.isEmpty -> 400 with details
  oldPublished = policies.findPublishedByEventId(eventId)
  if oldPublished: oldPublished.setStatus(ARCHIVED); save
  policy.status = PUBLISHED; policy.publishedAt = now(); save
  return toResponse(policy)
```

`publishedAt` hien `updatable=false` — them setter + bo `updatable=false` cho `status` va `publishedAt`, hoac dung `@Modifying @Query` JPQL update. **Chon**: them package-private setter, bo `updatable=false` chi tren `status` + `publishedAt` (publishedAt set mot lan luc publish).

## Related Code Files

**Tao moi:**
- `dau-viet-backend/src/main/java/com/dauviet/collection/api/AdminCompletionPolicyController.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/api/dto/AdminCompletionPolicyDtos.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/application/AdminCompletionPolicyService.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/domain/PolicyValidationException.java` (hoac dung `IllegalArgumentException` + error code — gon hon)

**Sua:**
- `dau-viet-backend/src/main/java/com/dauviet/collection/domain/EventCompletionPolicy.java` — bo `updatable=false` tren `status`, `publishedAt`; them setter `setStatus`, `setPublishedAt`; them factory `EventCompletionPolicy.draft(UUID eventId, int version, List<UUID> required, List<UUID> optional, Short threshold, ObjectMapper)`.
- `dau-viet-backend/src/main/java/com/dauviet/collection/infrastructure/persistence/EventCompletionPolicyRepository.java` — them `findByEventIdOrderByPolicyVersionDesc`, `findTopByEventIdOrderByPolicyVersionDesc`, `findByEventIdAndStatus`.
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/infrastructure/persistence/HistoricalEventRepository.java` — them `findForUpdate` voi `@Lock(PESSIMISTIC_WRITE)`.

**Khong sua:** SecurityConfig, V22-V27, EventCompletionPolicyService (read-side), EventMilestoneRecorder.

## Implementation Steps

1. Sua `EventCompletionPolicy`: bo `updatable=false` tren `status`+`publishedAt`, them setters, them factory `draft(...)`, them `createdAt` (hien thieu — kiem tra DDL: V22 co `created_at` nhung entity chua map. Can them field `@CreationTimestamp createdAt`).
2. Mo rong `EventCompletionPolicyRepository` cac method tren.
3. Them `HistoricalEventRepository.findForUpdate` neu chua co (`@Lock(PESSIMISTIC_WRITE)`).
4. DTO `AdminCompletionPolicyDtos` (records):
   - `AdminCompletionPolicyResponse(id, eventId, policyVersion, status, requiredLessonIds, optionalLessonIds, masteryThreshold, publishedAt, createdAt)`
   - `AdminCompletionPolicyUpsertRequest(@NotEmpty requiredLessonIds, optionalLessonIds, @Min(0) @Max(100) masteryThreshold)`
   - `AdminPolicyValidationResponse(valid, errors:[{code,message}], warnings:[string], diff:{from,to})`
   - `AdminPolicyPublishRequest(expectedPolicyVersion)`
5. `AdminCompletionPolicyService`:
   - `list(eventId)` -> repo findByEventIdOrderByPolicyVersionDesc
   - `get(eventId, policyId)`
   - `create(eventId, req)` -> validate event + lesson refs -> build DRAFT `version = maxVersion+1`, status DRAFT, save
   - `updateDraft(eventId, policyId, req)` -> check status=DRAFT -> xoa -> tao moi voi cung `policyVersion`
   - `validate(eventId, policyId, req)` -> build errors[] theo rules; warnings: "learner da completed giu nguyen" khi `from` PUBLISHED ton tai
   - `publish(eventId, policyId, expectedVersion)` -> nhu transaction tren
6. `AdminCompletionPolicyController` — map endpoints, `@Validated`, `@Min/@Max` tren params.
7. Error mapping: `IllegalArgumentException` -> 400 (qua handler global co san). `InvalidStatusTransitionException` (reuse). `ObjectOptimisticLockingFailureException` -> 409.
8. Kiem tra `DossierService.list` lazy reconcile van hoat dong (policy PUBLISHED moi duoc pick-up ngay).

## Todo List

- [ ] Sua `EventCompletionPolicy` entity (bo updatable=false cho status/publishedAt, them setters + factory draft + createdAt).
- [ ] Mo rong `EventCompletionPolicyRepository`.
- [ ] Them `HistoricalEventRepository.findForUpdate`.
- [ ] Viet `AdminCompletionPolicyDtos`.
- [ ] Viet `AdminCompletionPolicyService`.
- [ ] Viet `AdminCompletionPolicyController`.
- [ ] Chay `./mvnw -pl dau-viet-backend compile` de kiem loi.

## Success Criteria

- Endpoint tra DRAFT/PUBLISHED/ARCHIVED list dung.
- POST tao DRAFT v1 khi event chua co policy; v2 copy-on-write khi da co PUBLISHED.
- PUT tren PUBLISHED tra 400/409; PUT tren DRAFT tao row moi cung policyVersion.
- POST validate tra `valid:false` khi thieu required, lesson sai event/status, duplicate, overlap, threshold ngoai range.
- POST publish atomic: 2 request publish dong thoi -> 1 thanh cong, 1 loi (lock + partial unique).
- Learner `EVENT_COMPLETED`/`user_dossier_unlocks` khong bi thu hoi khi publish policy moi.

## Risk Assessment

- **Concurrent publish**: hai admin bam publish cung luc -> giai quyet bang `findForUpdate` + partial unique index.
- **Stale edit**: admin A mo draft v2, admin B publish v2 roi -> A PUT phai 409. Giai quyet bang `expectedPolicyVersion` + check max version.
- **Lesson bi archive sau khi policy publish**: khong block — validate chi chay luc tao/sua/publish, khong retro-active (entitlement pinned).

## Security Considerations

- Moi endpoint duoi `/api/v1/admin/**` -> `hasRole("CONTENT_ADMIN")` da cover.
- Khong tra stack trace — dung `ApiError` envelope (san co).
- Khong expose `required_snapshot` cua learner cho admin (privacy — chi metadata lesson IDs).

## Next Steps

- Phase 02 dung `HistoricalDossier` tuong tu.
- Phase 04 admin UI consume cac endpoint nay.
