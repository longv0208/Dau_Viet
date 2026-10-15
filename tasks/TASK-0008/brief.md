# TASK-0008 — Historical Event & Lesson Management API

Continue developing the existing Dấu Việt project from the latest repository state.

**Mandatory:** Follow `AGENTS.md`, all project coding rules, BA/MVP requirements, existing architecture, and the established task/harness workflow. Do not repeat or redesign completed work.

## Objective

Implement backend CRUD and management APIs for Historical Events and Lessons, providing the foundation for the Admin CMS and future Lesson Builder.

All implementation must follow the existing PostgreSQL schema (Flyway V1–V4) and BA documents.

## Scope

### 1. Historical Event Management

Implement Admin APIs under `/api/v1/admin/events`:

- Create historical event.
- List events with pagination, search, and status filtering.
- Get event details.
- Update event metadata.
- Publish an event.
- Archive an event.

Use the existing `historical_events` table and domain model.

Preserve all existing event fields and relationships defined in the database and BA documents.

Requirements:

- Validate required fields and historical metadata.
- Enforce valid status transitions.
- Prevent unauthorized modifications.
- Prevent unsafe deletion of referenced events.
- Keep existing public event APIs backward compatible.
- Public APIs must only expose published events.
- Return clear validation and business errors.

Prefer archive over destructive deletion.

### 2. Lesson Management

Implement Admin APIs under `/api/v1/admin/lessons`:

- Create lesson associated with a Historical Event.
- List lessons with pagination and filtering.
- Get lesson details.
- Update lesson metadata.
- Update lesson draft.
- Archive lesson.

Implement using the existing:

- `lessons`
- `lesson_templates`
- `lesson_versions`

Requirements:

- Maintain HistoricalEvent → Lesson relationships.
- Validate lesson template references.
- Support `central_question`, learning objectives, and draft content.
- Store structured draft content in PostgreSQL JSONB.
- Validate JSON structure and supported schema versions.
- Prevent modification of published LessonVersion snapshots.
- Preserve the current published version when editing a draft.
- Respect the existing lesson status model.

### 3. Lesson Templates

Provide read-only Admin APIs to:

- List enabled lesson templates.
- Retrieve template details and configuration.

Use the existing `lesson_templates` table.

Do not implement template editing unless explicitly required by the BA documents.

### 4. Authorization

- All Admin management APIs require `CONTENT_ADMIN`.
- `LEARNER` users must receive HTTP 403.
- Unauthenticated requests must receive HTTP 401.
- Public Historical Event APIs remain accessible without authentication.

Reuse TASK-0007 authentication and authorization infrastructure.

### 5. Validation & Data Integrity

Ensure:

- Foreign key integrity.
- Consistent status transitions.
- Proper transaction boundaries.
- Optimistic locking where needed.
- Safe handling of concurrent updates.
- No hard-coded historical event IDs or lesson data.
- No destructive changes to existing migrations.
- No accidental deletion of referenced lessons, versions, or learner attempts.

If additional database fields or constraints are required, introduce a new Flyway migration rather than modifying V1–V4.

### 6. Testing

Implement tests covering:

- Event CRUD and status transitions.
- Lesson creation and draft editing.
- Lesson/Event relationship validation.
- Invalid template references.
- JSONB persistence.
- Admin authorization.
- Learner access denial.
- Public API backward compatibility.
- Concurrent update behavior.
- Existing authentication tests remain green.

Run the full backend verification suite.

### 7. Deliverables

- Historical Event Admin APIs.
- Lesson Admin APIs.
- Lesson Template read APIs.
- Required services, DTOs, repositories, and validation.
- OpenAPI/API documentation updates.
- Relevant automated tests.
- Updated task evidence and reports.

## Out of Scope

Do not implement:

- Next.js Admin UI.
- Flutter changes.
- Lesson publishing/version creation workflow (next task).
- Learning Engine.
- Activity submission and scoring.
- Rewards, Shop, Island, or Energy systems.

Keep this task focused on content management and lesson drafting.

## Definition of Done

- All required Admin APIs work.
- Database relationships and constraints are respected.
- Authorization is enforced.
- Existing APIs remain backward compatible.
- Backend verification passes.
- No critical functional, security, or data-integrity issues remain.

If runtime verification is blocked, report `NOT VERIFIED` accurately.

Do not automatically push or merge without permission.

**Final report in Vietnamese**, focusing on implemented functionality, actual test results, remaining product-impacting issues, and readiness for TASK-0009.

Start by inspecting the latest repository state and proceed through the established task workflow.
