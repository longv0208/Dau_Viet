# Phase 04 — Evidence admin APIs

## Context links
- `V3__authoring_publishing_evidence_assets.sql` (evidences schema)
- `docs/DATABASE_DESIGN.md` §3 (evidences row)
- `phase-01-draft-schema-contract.md` (evidenceRefs in activities)

## Overview
- Priority: P1
- Status: pending
- CRUD + archive for `evidences` rows. Evidence is bound to an `event_id`, optionally an `asset_id`. No destructive delete — soft-archive only. Reject archive when referenced by a published lesson snapshot.

## Requirements
- Endpoints under `/api/v1/admin/evidences` (plural, consistent with `/events`, `/lessons`).
- Optimistic locking on PATCH/archive via `expectedRowVersion` (requires V6 to add `row_version` to `evidences`).
- Status: `DRAFT → APPROVED → ARCHIVED`; `DRAFT → ARCHIVED`. `APPROVED → DRAFT`? — Disallow (once approved, only archive).
- `asset_id` optional; if supplied, must reference `assets.id` (existence check, any state — asset lifecycle handled elsewhere).
- Reference validation at publish-check: see phase-02 (evidence must exist + match lesson's event + status ∈ {DRAFT, APPROVED}).
- Archive prevention: refuse to archive evidence referenced by any lesson's `current_version_id` snapshot (must check `lesson_versions.snapshot_json` for the evidence id; JSONB `@>` or `jsonb_path_exists` query).

## Endpoint surface

```
GET    /api/v1/admin/evidences?eventId=&status=&q=&page=&size=&sort=
       -> 200 PageResponse<EvidenceSummaryDto>
POST   /api/v1/admin/evidences
       body { eventId, title, evidenceType, description?, sourceTitle, sourceAuthor?, sourceUrl?, sourceCitation?, sourcePublishedAt?, reliability?, relevance?, assetId? }
       -> 201 EvidenceDto (status=DRAFT)
GET    /api/v1/admin/evidences/{id}
       -> 200 EvidenceDto
PATCH  /api/v1/admin/evidences/{id}
       body { title?, evidenceType?, description?, sourceTitle?, sourceAuthor?, sourceUrl?, sourceCitation?, sourcePublishedAt?, reliability?, relevance?, assetId?, expectedRowVersion }
       -> 200 EvidenceDto (not allowed when status=ARCHIVED → 409)
POST   /api/v1/admin/evidences/{id}/approve
       -> 200 (DRAFT→APPROVED)
POST   /api/v1/admin/evidences/{id}/archive
       body { expectedRowVersion? }
       -> 200 (any→ARCHIVED); 409 EVIDENCE_IN_USE if referenced by published snapshot
```

No DELETE endpoint — admin UI should not expose hard delete; V3 has no `ON DELETE CASCADE` semantics that would be safe.

## Entity + repo

`Evidence` JPA entity:
```java
@Entity @Table(name="evidences")
class Evidence {
    @Id UUID id;
    @Column(name="event_id", nullable=false, updatable=false) UUID eventId;
    String title;
    @Column(name="evidence_type") String evidenceType;   // free-form VARCHAR(48) — keep as String (e.g., DOCUMENT, PHOTO, ARTIFACT, INSCRIPTION); not enum — open set
    String description;
    @Column(name="source_title", nullable=false) String sourceTitle;
    @Column(name="source_author") String sourceAuthor;
    @Column(name="source_url") String sourceUrl;
    @Column(name="source_citation") String sourceCitation;
    @Column(name="source_published_at") LocalDate sourcePublishedAt;
    String reliability;          // HIGH/MEDIUM/LOW/UNASSESSED/null
    String relevance;
    @Column(name="asset_id") UUID assetId;
    @Enumerated(STRING) EvidenceStatus status;   // DRAFT/APPROVED/ARCHIVED
    @Column(name="created_by", updatable=false) UUID createdBy;
    @CreationTimestamp Instant createdAt;
    @UpdateTimestamp Instant updatedAt;
    @Version @Column(name="row_version") Long rowVersion;   // NEW via V6
}
enum EvidenceStatus { DRAFT, APPROVED, ARCHIVED }
```

`EvidenceRepository extends JpaRepository<Evidence,UUID>, JpaSpecificationExecutor<Evidence>`:
- `boolean existsByIdAndEventIdAndStatusIn(UUID id, UUID eventId, Collection<EvidenceStatus> statuses)` — used by publish-check
- `@Query("select count(lv) > 0 from LessonVersion lv where jsonb_path_exists(lv.snapshotJson, '$.** ? (@ == \"' || :evidenceId || '\")')")` — evidence-in-use check; simpler alternative: scan `evidenceRefs` text occurrences via `lv.snapshotJson LIKE %:evidenceId%` — choose the LIKE approach (KISS, evidence id is unique string).

Decision: use `LIKE '%"' || :evidenceId || '"%'` on `snapshot_json::text` joined on lessons.current_version_id — conservative, simple, correct.

## V6 migration

`V6__evidences_row_version.sql`:
```sql
ALTER TABLE evidences ADD COLUMN row_version BIGINT NOT NULL DEFAULT 0;
```
Single statement, backwards-compatible. No other schema changes needed for TASK-0009.

## DTOs

```java
public record EvidenceDto(UUID id, UUID eventId, String title, String evidenceType,
    String description, String sourceTitle, String sourceAuthor, String sourceUrl,
    String sourceCitation, LocalDate sourcePublishedAt, String reliability,
    String relevance, UUID assetId, String status, Long rowVersion,
    UUID createdBy, Instant createdAt, Instant updatedAt) {}

public record EvidenceSummaryDto(UUID id, UUID eventId, String title,
    String evidenceType, String status, String reliability, Long rowVersion) {}

public record EvidenceUpsertRequest(@NotNull UUID eventId, @NotBlank String title,
    @NotBlank String evidenceType, String description, @NotBlank String sourceTitle,
    String sourceAuthor, String sourceUrl, String sourceCitation,
    LocalDate sourcePublishedAt, String reliability, String relevance, UUID assetId) {}

public record EvidencePatchRequest(String title, String evidenceType, String description,
    String sourceTitle, String sourceAuthor, String sourceUrl, String sourceCitation,
    LocalDate sourcePublishedAt, String reliability, String relevance, UUID assetId,
    Long expectedRowVersion) {}
```

## Service

`com.dauviet.lesson.application.EvidenceService` (or under `historicalevent.admin` — choose `lesson` since used primarily by lessons): mirrors `AdminEventService` style.

- `create`: validate `eventId` exists (404 `EVENT_NOT_FOUND`); `assetId` non-null → exists (404 `ASSET_NOT_FOUND`); `reliability` ∈ {HIGH,MEDIUM,LOW,UNASSESSED,null} → 400.
- `patch`: `load` + `checkVersion` + refuse if `status=ARCHIVED` (409 `INVALID_STATUS_TRANSITION`); `assetId` change → exists check.
- `approve`: `DRAFT→APPROVED` only; otherwise 409.
- `archive`: check in-use by published snapshot → 409 `EVIDENCE_IN_USE` with `details.lessonIds`; else set ARCHIVED.

## Files

Create:
- `dau-viet-backend/src/main/resources/db/migration/V6__evidences_row_version.sql`
- `com/dauviet/lesson/domain/Evidence.java`, `EvidenceStatus.java`, `EvidenceNotFoundException.java`, `EvidenceInUseException.java`
- `com/dauviet/lesson/infrastructure/persistence/EvidenceRepository.java`
- `com/dauviet/lesson/application/EvidenceService.java`
- `com/dauviet/lesson/api/AdminEvidenceController.java`
- `com/dauviet/lesson/api/dto/Evidence*.java` (4 records)
- `com/dauviet/lesson/api/mapper/EvidenceMapper.java`

Modify:
- `ErrorCode`: add `EVIDENCE_NOT_FOUND`, `EVIDENCE_IN_USE`, `ASSET_NOT_FOUND`
- `GlobalExceptionHandler`: handlers for `EvidenceNotFoundException` (404), `EvidenceInUseException` (409)

## Implementation steps
1. V6 migration.
2. `Evidence` entity + `EvidenceStatus` + `EvidenceRepository`.
3. DTOs + mapper.
4. `EvidenceService` with `create/patch/approve/archive/get/list`.
5. `AdminEvidenceController` (pagination like AdminEventController).
6. Error codes + handlers.
7. Wire `existsByIdAndEventIdAndStatusIn` into `DraftValidator` publish-level check.

## Todo
- [ ] V6 migration applied
- [ ] Entity + repository + spec-based list
- [ ] Service + controller (6 endpoints)
- [ ] In-use check (snapshot_json LIKE)
- [ ] Approve/archive transitions + error codes
- [ ] Wire to DraftValidator publish check

## Success criteria
- Approve a DRAFT evidence → 200 status APPROVED.
- Archive evidence referenced by a `lesson_versions.snapshot_json` (published) → 409 `EVIDENCE_IN_USE`.
- Patch evidence without `expectedRowVersion` → succeeds; with stale → 409.
- Publish-check on lesson referencing missing evidence id → `FieldError` path `stages[i].activities[j].config.visibleEvidenceIds[k]`, code `EVIDENCE_NOT_FOUND`.

## Risks
- `snapshot_json` LIKE scan over large table — fine for MVP (admin ops only). Index `(event_id,status)` already exists for direct lookups.
- `evidence_type` open string — drift risk; document common values in API_SPEC but don't constrain at DB level (matches V3 design).

## Security
- `asset_id` only stores reference; no asset bytes exposure.
- Source URLs — return as-is to admin only; never include in learner payload (handled in TASK-0010 preview).
