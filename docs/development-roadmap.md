# DẤU VIỆT — Development Roadmap

> Living document tracking project phases, milestones và progress. Update sau mỗi feature/milestone lớn.

## Phase: Gamification (GAME series)

| Task | Scope | Status | Notes |
|---|---|---|---|
| GAME-01 | Business rules baseline | Complete | `docs/GAMIFICATION_BUSINESS_RULES.md` |
| GAME-02 | Backend Thể lực (energy) | Complete | V21 `user_energy` + `energy_transactions`; `GET /me/energy`; penalty submit graded |
| GAME-03 | Flutter Thể lực UI | Complete | Energy display, ENERGY_DEPLETED handling, countdown |
| GAME-04 | Event Completion & Historical Dossier Collection | **Complete (2026-10-25)** | Xem bên dưới |
| GAME-05 | Item Unlock Rule Engine | Pending | Depends on GAME-04 milestones/dossiers |
| GAME-06 | Admin CMS quản lý policy/dossier | Pending | |
| GAME-07 | Wallet/Level/chi tiêu | Pending | |
| GAME-08 | Regression tổng thể | Pending | |

### GAME-04 — delivered (2026-10-25)

- **Schema** — `V22__event_completion_dossiers.sql`: 5 bảng mới (`event_completion_policies`, `user_event_progress`, `historical_dossiers`, `event_dossiers`, `user_dossier_unlocks`), idempotent seed theo event slug, 1 PUBLISHED policy/event, 8 dossiers canonical với citation thật.
- **Backend** — module `com.dauviet.collection`: `EventCompletionPolicyService`, `EventProgressEvaluator`, `EventMilestoneRecorder` (pg advisory lock per user+event), `EventProgressQueryService` (reconcile-on-read), `DossierService`, `DossierController`, `EventProgressController`. `CompleteAttemptResponse.newlyUnlockedDossiers` additive field.
- **Mobile** — collection screen 4-tab dossier UI (Dấu / Nhân vật / Địa điểm / Hiện vật), dossier detail screen, `EventProgressSection` trên campaign detail, once-only unlock banner trên lesson result.
- **Tests** — `EventCompletionIT` 20/20, `EventProgressEvaluatorTest` 10/10, `FlywayMigrationIT` updated to 18 tables. Backend `mvnw verify` **green 293/293** (2026-10-25). Flutter `flutter analyze` clean, `flutter test` **424/424**.

## Phase: Learning core (đã hoàn thành các task trước)

TASK-0005, 0007–0012, 0020–0023 — xem `docs/PROJECT_OVERVIEW.md` + `docs/PROGRESS.md` cho trạng thái generated từ task JSON.

## Next up

- GAME-05: Item unlock rules build on event milestones (`user_event_progress`) + dossier unlocks.
- GAME-06: Admin CMS cần expose `event_completion_policies` (publish/versioning), `historical_dossiers` CRUD, `event_dossiers` link management.
