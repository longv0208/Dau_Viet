# DẤU VIỆT — Development Roadmap

> Living document tracking project phases, milestones và progress. Update sau mỗi feature/milestone lớn.

## Phase: Gamification (GAME series)

| Task | Scope | Status | Notes |
|---|---|---|---|
| GAME-01 | Business rules baseline | Complete | `docs/GAMIFICATION_BUSINESS_RULES.md` |
| GAME-02 | Backend Thể lực (energy) | Complete | V21 `user_energy` + `energy_transactions`; `GET /me/energy`; penalty submit graded |
| GAME-03 | Flutter Thể lực UI | Complete | Energy display, ENERGY_DEPLETED handling, countdown |
| GAME-04 | Event Completion & Historical Dossier Collection | **Complete (2026-10-25)** | Xem bên dưới |
| GAME-05 | Item Unlock Rule Engine | **Complete (2026-10-25)** | V24–V27 AST `condition_json`, scope guard, provenance |
| GAME-06 | Admin CMS quản lý policy/dossier/rule | **Complete (2026-10-25)** | V28 + 3 admin modules + Gamification tab, `/dossiers`, Rule Builder |
| GAME-07 | Wallet/Level/chi tiêu | Pending | |
| GAME-08 | Regression tổng thể | Pending | |

### GAME-04 — delivered (2026-10-25)

- **Schema** — `V22__event_completion_dossiers.sql`: 5 bảng mới (`event_completion_policies`, `user_event_progress`, `historical_dossiers`, `event_dossiers`, `user_dossier_unlocks`), idempotent seed theo event slug, 1 PUBLISHED policy/event, 8 dossiers canonical với citation thật.
- **Backend** — module `com.dauviet.collection`: `EventCompletionPolicyService`, `EventProgressEvaluator`, `EventMilestoneRecorder` (pg advisory lock per user+event), `EventProgressQueryService` (reconcile-on-read), `DossierService`, `DossierController`, `EventProgressController`. `CompleteAttemptResponse.newlyUnlockedDossiers` additive field.
- **Mobile** — collection screen 4-tab dossier UI (Dấu / Nhân vật / Địa điểm / Hiện vật), dossier detail screen, `EventProgressSection` trên campaign detail, once-only unlock banner trên lesson result.
- **Tests** — `EventCompletionIT` 20/20, `EventProgressEvaluatorTest` 10/10, `FlywayMigrationIT` updated to 18 tables. Backend `mvnw verify` **green 293/293** (2026-10-25). Flutter `flutter analyze` clean, `flutter test` **424/424**.

### GAME-06 — delivered (2026-10-25)

- **Schema** — `V28__historical_dossier_versions.sql`: bảng snapshot append-only `historical_dossier_versions` (UNIQUE `(dossier_id, dossier_version)`), `historical_dossiers` +`row_version` optimistic lock; backfill dossier PUBLISHED có sẵn. Không sửa V22–V27.
- **Backend** — Module A `AdminCompletionPolicyController` (list/detail/create DRAFT/`PUT` in-place DRAFT/`validate`/`publish` atomic với archive `saveAndFlush` + `expectedPolicyVersion` 409); Module B `AdminDossierController` (CRUD structured source — không raw JSON, publish → snapshot V28 + `pendingChanges`, `PUT /events/{id}/dossiers` replace-list); Module C `AdminItemRuleController` (`rule/validate` dry-run đúng pipeline scope-check, `rule/history` + grantCount). `GlobalExceptionHandler` bắt superclass `OptimisticLockingFailureException` → 409.
- **Admin UI** — tab `gamification` trong Event Workspace (PolicyEditor + DossierLinkTable), trang `/dossiers` (list/filter/editor + publish/archive), Rule Builder V2 + scope banner + history + `ReconcilePanel` trong `/items/[id]`.
- **Tests** — Backend `mvnw verify` **green 363 IT + 486 unit** (AdminCompletionPolicyIT, AdminDossierIT, AdminItemRuleIT); admin `typecheck` PASS, `vitest` **288/288**, `build` PASS (2026-10-25).

## Phase: Learning core (đã hoàn thành các task trước)

TASK-0005, 0007–0012, 0020–0023 — xem `docs/PROJECT_OVERVIEW.md` + `docs/PROGRESS.md` cho trạng thái generated từ task JSON.

## Next up

- GAME-07: Wallet/Level/chi tiêu — `LEVEL_AT_LEAST` leaf của rule engine hiện UNSUPPORTED chờ wallet/level model.
- GAME-08: Regression tổng thể sau khi game loop hoàn chỉnh.
