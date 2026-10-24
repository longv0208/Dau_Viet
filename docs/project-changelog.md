# DẤU VIỆT — Project Changelog

> Detailed record of significant changes, features và fixes. Newest first.

## 2026-10-25 — GAME-04: Event Completion & Historical Dossier Collection

**Scope:** versioned event completion policies, event progress milestones, canonical historical dossiers với unlock fan-out, learner APIs, Flutter collection tabs.

**Database**
- `V22__event_completion_dossiers.sql` — 5 bảng mới:
  - `event_completion_policies` — versioned per event; partial unique index `ux_event_policy_published` (tối đa 1 PUBLISHED/event); `required_lesson_ids`/`optional_lesson_ids` JSONB; `mastery_threshold` SMALLINT nullable (CHECK 0..100); `status ∈ DRAFT/PUBLISHED/ARCHIVED`.
  - `user_event_progress` — PK `(user_id, event_id, milestone)`; milestone `EVENT_COMPLETED|EVENT_MASTERED`; `policy_version` + `required_snapshot` audit.
  - `historical_dossiers` — `canonical_code` UNIQUE; `dossier_type ∈ PERSON/LOCATION/ARTIFACT/CONTEXT`; `source_json` JSONB; `status ∈ DRAFT/PUBLISHED/ARCHIVED`; `dossier_version`.
  - `event_dossiers` — PK `(event_id, dossier_id)`; `unlock_on='EVENT_COMPLETED'`; `sort_order`.
  - `user_dossier_unlocks` — PK `(user_id, dossier_id)`; `event_id` provenance lần mở đầu; `dossier_version`; `granted_at`.
- Seed idempotent: 3 events resolve theo slug (`bach-dang-938`, `hai-ba-trung-40`, `ly-thai-to-1010`), 1 PUBLISHED policy v1 mỗi event, 8 dossiers (4 PERSON, 3 LOCATION, 1 ARTIFACT) với citation thật (ĐVSKTT, Bảo tàng LSQG, Ban quản lý di tích Mê Linh, Viện Hàn lâm KHXH&NV).

**Backend** (`com.dauviet.collection`)
- `EventCompletionPolicyService`, `EventProgressEvaluator`, `EventMilestoneRecorder` (`pg_advisory_xact_lock(hashtextextended(userId|eventId))` serialize per (user,event)), `EventProgressQueryService` (reconcile-on-read idempotent), `DossierService` (visibility: DRAFT hidden / ARCHIVED hidden trừ khi đã unlock / locked PUBLISHED → preview).
- `EventProgressController` — `GET /api/v1/me/events/{eventId}/progress`.
- `DossierController` — `GET /api/v1/me/collection/dossiers` (filters: `type`, `eventId`, `unlocked`, page, size≤50, sort `title,id`), `GET /api/v1/me/collection/dossiers/{dossierId}`.
- `LearnerAttemptService.doComplete()` — gọi `eventMilestones.recordIfEarned` trong cùng transaction sau rewards + item unlocks; exceptions rollback completion.
- `CompleteAttemptResponse.newlyUnlockedDossiers` — additive `UUID[]`, rỗng trên replay/`alreadyCompleted`/`NOT_CONFIGURED`.

**Mobile** (`dau-viet-mobile`)
- Collection screen 4-tab: Dấu (existing evidence) + Nhân vật + Địa điểm + Hiện vật (dossiers qua API).
- Dossier detail screen + route `/collection/dossiers/:dossierId`.
- `EventProgressSection` trên campaign detail.
- Once-only unlock banner trên lesson result screen (đọc `newlyUnlockedDossiers`).

**Tests & verification**
- Backend: `EventCompletionIT` 20 tests, `EventProgressEvaluatorTest` 10 tests, `FlywayMigrationIT` updated (18 tables). `mvnw verify` **PASS 293/293**.
- Mobile: `flutter analyze` clean (0 issues), `flutter test` **PASS 424/424**.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/LEARNING_ENGINE_DESIGN.md`, `docs/development-roadmap.md`, `docs/project-changelog.md`.

## 2026-10-25 — GAME-04 FIX: Event completion, dossier integrity & mobile CI

9 sửa theo task fix trên commit GAME-04 (`00815dc`). Không viết lại feature; không đụng V22.

- **FIX 1 (P1)** — `V23__policy_v2_seed_audit.sql`: audit policy v1 seed của V22 (trước chọn required lesson bằng `ORDER BY created_at LIMIT 1` — arbitrary). Mỗi event có ≥1 lesson PUBLISHED: policy PUBLISHED thiếu lesson → ARCHIVE + publish v2 đủ bộ; event chưa có policy → v1 đủ bộ; không có lesson PUBLISHED → bỏ qua. Không đụng milestone/unlock đã cấp.
- **FIX 2 (P1)** — `UserEventProgressRepository.countUnlockedDossiersForEvent`: count đổi từ "unlocks có provenance event_id=này" sang join `event_dossiers` + `user_dossier_unlocks` với `COUNT(DISTINCT dossier_id)` — dossier shared giữa hai event được đếm ở cả hai, ownership vẫn 1 row.
- **FIX 3 (P1)** — `EventReconcileService` mới: điểm hội tụ duy nhất cho reconcile (`reconcileEvent`, `reconcileEvents`, `reconcileOwnedEvents`, `eventsWithPublishedPolicy`). `DossierService.list/detail` gọi reconcile lazy trước khi đọc (REQUIRED, không readOnly) — learner pre-GAME-04 mở Collection trực tiếp vẫn được grant; không quét toàn bộ, chỉ `visibleEventIdsOf(userId)`.
- **FIX 4 (P2)** — `EventMilestoneRecorder.evaluateAndRecord`: fan-out dossier chạy khi `completed || completedAlready` (không chỉ `completed`) — dossier admin publish/link sau khi learner completed được grant ở reconcile kế; `EventProgressQueryService.progressOf` gọi `recordIfEarned` không điều kiện.
- **FIX 5 (P2)** — `DossierQueryRepository` + `DossierService` + `DossierDtos`: `DossierSummaryResponse.dossierVersion` = pinned entitlement version (`user_dossier_unlocks.dossier_version`); `DossierDetailResponse` thêm `catalogVersion` = catalog hiện tại. Archive không thu hồi quyền — learner đã unlock vẫn đọc được.
- **FIX 6 (P2)** — `LessonResultRepository.lessonsWithGradedActivity`: SQL sync với `GradedActivityClassifier` — bắt buộc stage `required:true` + activity `required:true` + (contract-graded types | EVIDENCE_SELECT graded+acceptedEvidenceIds | REASONING_CONNECT graded+(expectedRelations|acceptedRelationSets hợp lệ)). Không sửa Learning Engine.
- **FIX 7 (P2)** — `EventProgressResponse.earnedPolicyVersion` (additive): policy_version đã cấp `EVENT_COMPLETED`. Flutter DTO + `EventProgressSection` hiển thị banner "đã hoàn thành phiên bản trước — chính sách mới bổ sung bài học" khi `earnedPolicyVersion < policyVersion`.
- **FIX 8 (P2)** — `event_progress_section.dart` rewrite states: loading → placeholder spinner + text (không shrink); error → message + THỬ LẠI qua `ref.invalidate`; NOT_CONFIGURED giữ info trung lập.
- **FIX 9 (P2, mandatory)** — CI `flutter analyze` fail do 5 file kebab-case (`file_names` lint): `git mv` → `main_bottom_nav.dart`, `register_screen.dart`, `stage_guidance.dart`, `onboarding_screen.dart`, `profile_screen.dart`; cập nhật 10 import. Không disable rule.

**Verification**
- Backend `./mvnw -B -ntp verify`: **305/305 PASS** (EventCompletionIT 32 tests: +multi-required 1/3-2/3-3/3, optional không block, created_at order không ảnh hưởng, shared dossier 2 events, lazy reconcile list+detail, late-linked dossier fan-out, pinned dossierVersion, archived-still-accessible, REASONING_CONNECT valid/invalid, optional-stage NOT_ASSESSED, earnedPolicyVersion).
- Mobile `dart format --set-exit-if-changed`: clean. `flutter analyze`: 0 issues. `flutter test`: **430/430 PASS** (thêm `test/campaign/event_progress_section_test.dart` 6 widget tests).

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/project-changelog.md`.
