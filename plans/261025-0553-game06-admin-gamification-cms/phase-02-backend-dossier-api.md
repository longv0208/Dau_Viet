# Phase 02 — Backend: Historical Dossier Admin API + V28 `historical_dossier_versions`

## Context Links

- Spec: Module B trong yeu cau goc.
- Entity hien tai: `HistoricalDossier` (mutable title/summary/description/sourceJson/assetId/status/dossierVersion; immutable `canonicalCode` + `id`), `EventDossier` (composite PK eventId+dossierId, sort_order, unlock_on='EVENT_COMPLETED'), `UserDossierUnlock` (PK user+dossier, pin dossierVersion).
- Schema V22: `historical_dossiers`, `event_dossiers`, `user_dossier_unlocks` da co.
- Read side learner: `DossierService` + `DossierQueryRepository` — lazy reconcile + visibility rule (DRAFT invisible, ARCHIVED chi khi da unlock).
- Fan-out: `EventMilestoneRecorder.fanOutDossierUnlocks` dung `findEventCompletedDossierIds` + `d.getDossierVersion()` (current version luc unlock — khong phai version tai luc event complete).

## Overview

- Priority: P1
- Status: pending
- Effort: 6h
- Them admin CRUD cho `historical_dossiers` + `event_dossiers` links + tao `historical_dossier_versions` (V28) de truy vet noi dung moi lan publish. Khong thu hoi unlock cu.

## Key Insights

- `canonicalCode` la `updatable=false` + UNIQUE — admin chi set luc tao, khong doi. Khi update title khong dong den canonical.
- `event_dossiers.sort_order` da co — dung cho `displayOrder` (khong can them cot). PK (event,dossier) -> khong the duplicate link.
- `user_dossier_unlocks.dossier_version` pin version — khi admin edit dossier PUBLISHED + republish, `dossier_version` tang, nhung unlock cu giu version cu. Bang `historical_dossier_versions` can snapshot full `title/summary/description/sourceJson/assetId` tai moi publish de audit + doc version pinned.
- Archive dossier: set status=ARCHIVED. Learner da unlock van thay (DossierService detail check `unlocked || status != ARCHIVED`). Khong xoa `user_dossier_unlocks`, khong xoa `event_dossiers`.
- Fan-out dossier khi link moi: `EventReconcileService` da lazy reconcile khi learner mo dossier list — dossier PUBLISHED link vao event learner da completed se duoc unlock lan ke tiep learner fetch list. Khong can admin reconcile endpoint cho dossier (chi can neu muon thu cong — optional).
- Asset FK `asset_id REFERENCES assets(id)` — validate assetId ton tai + state ACTIVE truoc khi publish.

## Requirements

### Dossier CRUD

- GET `/api/v1/admin/dossiers` — filter `type`, `status`, `q` (canonicalCode/title), pagination + sort (`updatedAt,desc`, `title`, `canonicalCode`). Tra `PageResponse<AdminDossierSummaryResponse>` chua `eventCount` (so event_dossiers link).
- POST `/api/v1/admin/dossiers` — tao DRAFT. Body: `canonicalCode` (regex `^[a-z0-9][a-z0-9-]{1,119}$`, unique), `dossierType`, `title`, `summary`, `description`, `source{title,author,citation,url,reliability}`, `assetId`.
- GET `/api/v1/admin/dossiers/{id}` — detail + `events: [{eventId, title, displayOrder}]` + `versions: [{version, publishedAt}]`.
- PUT `/api/v1/admin/dossiers/{id}` — update cac field mutable (title, summary, description, sourceJson, assetId, dossierType). Chap nhan khi DRAFT hoac PUBLISHED (sau do can publish lai de ra version moi — draft-in-place khi PUBLISHED se co `pendingChanges` flag trong response). Body co `expectedRowVersion` (optional, optimistic lock qua `@Version` tren entity — can them `@Version`).
- POST `/api/v1/admin/dossiers/{id}/publish` — validate (title/type/source/asset/canonicalCode OK) → set `status=PUBLISHED`, `dossierVersion = max(version)+1`, `publishedAt=now()` → insert `historical_dossier_versions` snapshot → commit.
- POST `/api/v1/admin/dossiers/{id}/archive` — `status=ARCHIVED`. Khong dong `event_dossiers`, `user_dossier_unlocks`.

### Event-Dossier links

- GET `/api/v1/admin/events/{eventId}/dossiers` — list linked, moi row: `{dossierId, canonicalCode, title, type, status, displayOrder}`.
- PUT `/api/v1/admin/events/{eventId}/dossiers` — replace toan bo list. Body: `[{dossierId, displayOrder}]`. Validate: moi dossier ton tai + status PUBLISHED (khong cho link DRAFT/ARCHIVED). Service xoa link cu khong co trong list, insert/update `sort_order`. **Khong** trigger reconcile thu cong — lazy se cover.
- Validate input: `displayOrder` >= 0, khong duplicate trong list, `dossierId` khong duplicate.

### Publish validation rules

- `title` not blank, `dossierType` hop le, `source.title` not blank + `source.reliability` trong `{HIGH,MEDIUM,LOW,UNASSESSED}` (kiem tra enum EvidenceReliability hien co — CONFIRM).
- `assetId` neu co: ton tai + state `ACTIVE` (doc `Asset` entity — CONFIRM field name).
- `canonicalCode` van unique (da co UNIQUE constraint — bat `DataIntegrityViolationException` -> 409).

## Architecture

### V28 schema (de xuat)

```sql
-- V28__historical_dossier_versions.sql
CREATE TABLE historical_dossier_versions (
    id UUID PRIMARY KEY,
    dossier_id UUID NOT NULL REFERENCES historical_dossiers(id),
    dossier_version INTEGER NOT NULL,
    dossier_type VARCHAR(16) NOT NULL,
    title VARCHAR(255) NOT NULL,
    summary TEXT,
    description TEXT,
    source_json JSONB,
    asset_id UUID,
    status VARCHAR(16) NOT NULL,
    published_at TIMESTESTAMPTZ NOT NULL DEFAULT now(),
    published_by UUID REFERENCES users(id),
    CONSTRAINT chk_dv_type CHECK (dossier_type IN ('PERSON','LOCATION','ARTIFACT','CONTEXT')),
    CONSTRAINT chk_dv_status CHECK (status IN ('PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_dv_source CHECK (source_json IS NULL OR jsonb_typeof(source_json) = 'object'),
    CONSTRAINT ux_dossier_version UNIQUE (dossier_id, dossier_version)
);
CREATE INDEX idx_dv_dossier ON historical_dossier_versions(dossier_id);
-- Backfill version 1 cho cac dossier hien PUBLISHED
INSERT INTO historical_dossier_versions
    (id, dossier_id, dossier_version, dossier_type, title, summary,
     description, source_json, asset_id, status, published_at, published_by)
SELECT gen_random_uuid(), id, dossier_version, dossier_type, title, summary,
       description, source_json, asset_id, status, updated_at, created_by
  FROM historical_dossiers WHERE status = 'PUBLISHED';
```

### Files moi

| File | Muc dich |
|------|----------|
| `collection/api/AdminDossierController.java` | `/api/v1/admin/dossiers` CRUD + publish/archive + `/{eventId}/dossiers` link endpoints (dung sub-path `/events/{eventId}/dossiers` thay vi rieng — nhat quan voi policy). |
| `collection/api/dto/AdminDossierDtos.java` | `AdminDossierSummaryResponse`, `AdminDossierDetailResponse`, `AdminDossierUpsertRequest`, `AdminDossierPublishRequest`, `DossierSourceInput`, `AdminEventDossierLinkRequest`, `AdminEventDossierLinkResponse`. |
| `collection/application/AdminDossierService.java` | Business: list/get/create/update/publish/archive + link list/replace. |
| `collection/domain/HistoricalDossierVersion.java` | Entity cho bang moi (read+insert, khong update). |
| `collection/infrastructure/persistence/HistoricalDossierVersionRepository.java` | findByDossierIdOrderByDossierVersionDesc + save. |
| `db/migration/V28__historical_dossier_versions.sql` | Schema + backfill. |

### Endpoint contracts

```jsonc
// GET /api/v1/admin/dossiers?type=PERSON&status=PUBLISHED&q=ngo&page=0&size=20
// -> PageResponse<AdminDossierSummaryResponse>
{
  "content": [{
    "id": "uuid", "canonicalCode": "ngo-quyen", "dossierType": "PERSON",
    "title": "Ngo Quyen", "summary": "...",
    "status": "PUBLISHED", "dossierVersion": 3, "assetId": "uuid|null",
    "eventCount": 2, "updatedAt": "..."
  }],
  "totalElements": 12, "totalPages": 1, "page": 0, "size": 20
}

// POST /api/v1/admin/dossiers
// body: { canonicalCode, dossierType, title, summary, description,
//         source: {title, author, citation, url, reliability}, assetId }
// -> 201 AdminDossierDetailResponse | 409 duplicate canonicalCode

// GET /api/v1/admin/dossiers/{id}
// -> AdminDossierDetailResponse {..., events: [{eventId, eventTitle, displayOrder}],
//                                versions: [{version, publishedAt}]}

// PUT /api/v1/admin/dossiers/{id}
// body: { title?, summary?, description?, source?, assetId?, clearAsset?,
//         dossierType?, expectedRowVersion? }
// -> 200 AdminDossierDetailResponse | 409 stale

// POST /api/v1/admin/dossiers/{id}/publish
// -> 200 AdminDossierDetailResponse (status=PUBLISHED, dossierVersion++,
//    + new row in historical_dossier_versions)

// POST /api/v1/admin/dossiers/{id}/archive
// -> 200 AdminDossierDetailResponse (status=ARCHIVED)

// GET /api/v1/admin/events/{eventId}/dossiers
// -> [{ dossierId, canonicalCode, title, dossierType, status, displayOrder }]

// PUT /api/v1/admin/events/{eventId}/dossiers
// body: [{ dossierId, displayOrder }]
// -> 200 list
```

### Transaction publish dossier

```java
@Transactional
publish(dossierId, adminId):
  d = dossiers.findByIdForUpdate(dossierId) or 404
  validate(d)  // title, source.title, source.reliability, asset exists+ACTIVE
  nextVersion = (max existing version) + 1
  d.dossierVersion = nextVersion
  d.status = PUBLISHED
  d.updatedAt = now()
  dossiers.save(d)
  versions.save(snapshot(d, nextVersion, adminId))
  return toDetail(d)
```

Them `@Lock(PESSIMISTIC_WRITE) findByIdForUpdate` vao `HistoricalDossierRepository`.

## Related Code Files

**Tao moi:**
- `dau-viet-backend/src/main/resources/db/migration/V28__historical_dossier_versions.sql`
- `dau-viet-backend/src/main/java/com/dauviet/collection/api/AdminDossierController.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/api/dto/AdminDossierDtos.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/application/AdminDossierService.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/domain/HistoricalDossierVersion.java`
- `dau-viet-backend/src/main/java/com/dauviet/collection/infrastructure/persistence/HistoricalDossierVersionRepository.java`

**Sua:**
- `HistoricalDossier.java` — them `@Version rowVersion` (optimistic lock), setter cho mutable fields neu chua co, factory `draft(...)`.
- `HistoricalDossierRepository.java` — them `findByIdForUpdate`, `findByCanonicalCode`, `search(type,status,q,pageable)`, `countLinkedEvents`.
- `EventDossierRepository.java` — them `findByEventIdOrderBySortOrderAsc`, `deleteByEventIdAndDossierIdIn`, `existsByEventIdAndDossierId`.
- `EventDossier.java` — them setter `setSortOrder` (PK van updatable=false).

**Khong sua:** `DossierService`, `DossierQueryRepository`, `UserDossierUnlock`, `EventMilestoneRecorder`, SecurityConfig, V22-V27.

## Implementation Steps

1. V28 migration file.
2. Entity `HistoricalDossierVersion` + repository.
3. Sua `HistoricalDossier` — them `@Version`, setters, factory draft.
4. Mo rong `HistoricalDossierRepository` (findForUpdate, findByCanonicalCode, JpaSpecificationExecutor cho search).
5. Mo rong `EventDossierRepository` (findByEventIdOrderBySortOrderAsc).
6. Sua `EventDossier` — setter sortOrder.
7. `AdminDossierDtos` — records cho moi request/response.
8. `AdminDossierService`:
   - `list(type, status, q, pageable)` — Specification filter + count event links subquery.
   - `get(id)` — detail + linked events + version history.
   - `create(req)` — validate canonical format -> build DRAFT -> save; bat DataIntegrityViolation -> 409.
   - `update(id, req)` — partial; expectedRowVersion check -> set fields -> save.
   - `publish(id, adminId)` — transaction lock + validate + version++ + snapshot.
   - `archive(id)` — set status.
   - `listEventLinks(eventId)` — join dossier + event_dossiers.
   - `replaceEventLinks(eventId, links)` — validate moi dossierId PUBLISHED -> delete + insert voi sort_order.
9. `AdminDossierController` — endpoints tren.
10. Compile check: `./mvnw -pl dau-viet-backend compile`.

## Todo List

- [ ] V28 SQL file.
- [ ] Entity `HistoricalDossierVersion` + repo.
- [ ] Sua `HistoricalDossier` (them @Version + setters + factory).
- [ ] Mo rong `HistoricalDossierRepository`.
- [ ] Sua `EventDossier` + `EventDossierRepository`.
- [ ] `AdminDossierDtos`.
- [ ] `AdminDossierService`.
- [ ] `AdminDossierController`.
- [ ] Compile pass.

## Success Criteria

- Tao dossier tra 201; canonicalCode trung -> 409 + message ro.
- Publish dossier tang `dossier_version` + ghi vao `historical_dossier_versions` dung noi dung.
- PUT dossier PUBLISHED khong tu dong tao version moi (chi sua DRAFT-view); phai bam publish.
- PUT link list: them/go link khong dong user_dossier_unlocks; dossier DRAFT/ARCHIVED -> 400.
- Archive dossier: learner da unlock van doc duoc (DossierService giu nguyen).
- Reconcile lazy pick up link moi: them test o Phase 07.

## Risk Assessment

- **canonical race**: hai admin tao cung canonicalCode -> DB UNIQUE bat, map sang 409.
- **Sort_order conflict**: hai PUT cung luc — `findForUpdate` tren event row hoac doc-ghi transaction ngan.
- **Asset retired sau publish**: van giu asset_id (khong null hoa) — admin co the update lai; doc-side da handle null-safe.
- **Dossier PUBLISHED da co unlock**: PUT chinh sua noi dung ngay ca khi da PUBLISHED -> co "pending changes" trang thai. Frontend hien "Co thay doi chua publish". Backend khong can field rieng — suy ra tu `dossierVersion` > `max(published version)`.

## Security Considerations

- CONTENT_ADMIN only qua `/api/v1/admin/**`.
- Khong expose `sourceJson` raw khi DRAFT cho learner (da xu ly o read-side).
- Validate `canonicalCode` regex server-side; khong de path traversal (khong dung cho URL path).
- `published_by` ghi user id cua admin cho audit.

## Next Steps

- Phase 04 dung link endpoints; Phase 05 dung dossier CRUD.
- IT o Phase 07 cover publish/archive/link/unlink/lazy reconcile.
