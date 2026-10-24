# Phase 07 — Backend ITs

## Context Links

- Existing ITs tham chieu: `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonIT.java`, `AdminEvidenceIT.java`, `historicalevent/admin/AdminEventIT.java`, `collection/EventCompletionIT.java`, `collection/CollectionIT.java`.
- Base class: `com.dauviet.AbstractPostgresIT` (Testcontainers Postgres, neu Docker available).
- Convention: IT suffix, dung MockMvc hoac TestRestTemplate — xem `AdminEventIT` de clone.

## Overview

- Priority: P1
- Status: pending
- Effort: 2h
- ITs cho cac endpoint Phase 01-03 + lazy reconcile verify.

## Requirements (test matrix)

### AdminCompletionPolicyIT

- `list_returnsAllVersions` — tao event + policy v1 PUBLISHED + v2 DRAFT -> list tra 2.
- `create_firstDraft_v1` — event chua co policy -> POST tra v1 DRAFT.
- `create_fromPublished_v2_copyOnWrite` — event co PUBLISHED v1 -> POST tra DRAFT v2 voi field copy tu v1.
- `updateDraft_204or200` — PUT DRAFT thanh cong.
- `updatePublished_rejects` — PUT tren PUBLISHED -> 400/409.
- `validate_invalidLesson_returns400or200validFalse` — validate endpoint tra errors cho lesson DRAFT/ARCHIVED/sai event/duplicate/overlap.
- `publish_archivesOldPublishesNew_atomic` — sau publish: 1 PUBLISHED v_moi, cu ARCHIVED.
- `publish_staleExpectedVersion_returns409`.
- `publish_concurrent_oneWins` — 2 thread call publish cung policy -> 1 thanh cong.
- `publish_draftOfAnotherEvent_returns404`.
- `unauthenticated_401`, `learnerRole_403` — security.

### AdminDossierIT

- `create_success_201`, `create_duplicateCanonical_409`.
- `update_draft_succeeds`, `update_published_bumpsNothing` (PUT PUBLISHED chi sua DRAFT-view — dossierVersion giu nguyen cho den publish).
- `publish_createsVersionRow` — sau publish: `historical_dossier_versions` co row moi voi `dossier_version = d.dossierVersion`.
- `publish_invalidSource_400` — thieu `source.title` -> 400.
- `publish_nonexistentAsset_400` — assetId khong ton tai -> 400.
- `archive_keepsUnlocks` — tao dossier PUBLISHED + insert `user_dossier_unlocks` truoc -> archive -> row unlock van con.
- `listEvents_returnsLinked` — PUT event links -> GET `/dossiers/{id}` tra `events[]` dung.
- `replaceEventLinks_validatesPublished` — link dossier DRAFT -> 400.
- `replaceEventLinks_doesNotRevokeUnlocks` — unlink sau khi learner da unlock -> `user_dossier_unlocks` row van con.
- `replaceEventLinks_draftLearnerPicksUpOnNextList` — learner da completed event + admin link dossier PUBLISHED moi -> `GET /me/collection/dossiers` lan tiep tra dossier unlocked (lazy reconcile qua `EventReconcileService`).

### AdminItemRuleIT

- `validate_validRule_returnsValidTrue`.
- `validate_eventScopedItemRejectsGlobalRule` — item scope EVENT_SCOPED + rule `{type:"LESSON_COUNT",threshold:1}` -> `acceptsRule=false`.
- `validate_doesNotWriteDb` — sau validate DB khong co rule moi.
- `history_returnsRevisionsDesc` — publish 3 lan -> history tra 3 entries desc revision, dung `active` flag.
- `detail_includesScopeField` — GET item tra `scope`.

### Reconcile (existing — khong can test moi)

- Da co `ItemRuleEngineIT` + `ItemUnlockIT` — bao phu.

## Implementation Steps

1. `AdminCompletionPolicyIT.java` — `src/test/java/com/dauviet/collection/`.
2. `AdminDossierIT.java` — cung package.
3. `AdminItemRuleIT.java` — `src/test/java/com/dauviet/reward/`.
4. Helper: extend `AbstractPostgresIT`, dung `@BeforeEach` seed admin user + JWT, seed event/lesson/dossier toi thieu.
5. Chay `./mvnw -pl dau-viet-backend verify -Dtest='*Admin*IT'` (hoac fail-safe IT plugin).

## Todo List

- [ ] `AdminCompletionPolicyIT`.
- [ ] `AdminDossierIT`.
- [ ] `AdminItemRuleIT`.
- [ ] `./mvnw -pl dau-viet-backend verify` — ITs pass.

## Success Criteria

- Moi test case tren xanh.
- Concurrent publish test deterministic (lock chuan).
- Lazy reconcile pick up link moi duoc verify (test dac biet quan trong — dung spec).

## Risk Assessment

- Docker khong available -> ITs skip; doc `backend-runbook.md` + record. Khong co IT thi unit test services (AssertJ + Mockito) cho `AdminCompletionPolicyService`/`AdminDossierService`/`AdminItemService.validateRule`.

## Security Considerations

- Tests dung user thuong + admin user rieng; negative tests `learnerRole_403` bat buoc.

## Next Steps

- Phase 08 — admin UI tests + docs + final verify.
