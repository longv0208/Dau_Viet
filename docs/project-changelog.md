# DẤU VIỆT — Project Changelog

> Detailed record of significant changes, features và fixes. Newest first.

## 2026-10-25 — GAME-05 FIX: Rule Engine Integrity & CI

**Scope:** 8 fix trên commit `da4e9cf` — đồng bộ trạng thái UNCONFIGURED, grammar chặt cho condition JSON, trigger item evaluation sau event reconcile, `rule_version` thành revision per-item, chặn ruleType lệch, kiểm chứng evidence collectible, reconcile theo batch, sửa countdown test mobile CI.

**Database**
- `V26__item_rule_revision_check.sql` — `chk_rule_version` nới `rule_version >= 1` (thay `IN (1,2)`); `chk_unlock_rule_shape` nhánh v2 đòi `rule_version >= 2` (revision per-item, mỗi publish = max+1); `chk_rule_v2_condition` giữ nguyên semantics. Không đụng V24/V25 đã áp dụng, không retro-update.

**Backend**
- FIX-1 (P1): `ItemUnlockRule.isNeedsMapping(metadata)` static dùng chung — grant path (`ItemUnlockService.blockedByAudit`) và catalog read path (`RewardService.requirement` → `UNCONFIGURED`, `satisfied=false`, children rỗng, description "Điều kiện mở khóa đang được cập nhật"). Không fake satisfied của rule legacy, không progress bar giả, owned giữ Owned, status biến mất khi publish rule v2 hợp lệ.
- FIX-2 (P1): `ItemConditionParser` rewrite — `ALLOWED_LEAF_FIELDS` per `LeafType`; leaf từ chối field ngoài tập cho phép (bug `eventId` thừa trên `LESSON_COUNT` bị bỏ qua âm thầm); operator node phải đúng 1 key; không all+any đồng thời, không all/any+type; ALL/ANY non-empty depth ≤2. Lỗi → HTTP 400.
- FIX-3 (P1): `EventMilestoneRecorder` inject `@Lazy ItemUnlockService` — khi reconcile-on-read ghi MỚI milestone `EVENT_COMPLETED`/`EVENT_MASTERED` thì gọi `evaluateAfterEventMilestone` cùng tx. Chỉ trigger trên milestone mới, không vòng lặp, không re-eval thừa.
- FIX-4 (P2): `rule_version` = revision per-item — `AdminItemService.setRule` tính `findMaxRuleVersion(itemId)+1` (min 2). Provenance `user_inventory.unlock_rule_version` trace đúng lần publish; rule cũ → inactive.
- FIX-5 (P2): `buildRule` validate `ruleType` trước DB write — condition non-null thì chỉ chấp nhận null/blank/`RULE_V2`, ngược lại 400 "contradicts a v2 condition"; normalize về `RULE_V2`.
- FIX-6 (P2): `ItemConditionValidator.isCollectible` — `SPECIFIC_EVIDENCE_SET` đòi evidence xuất hiện trong `snapshot.evidence[]` của một lesson PUBLISHED (current version) hoặc đã có `user_evidence` row; không đoán theo title/tag.
- FIX-7 (P2): `ItemUnlockService.reconcileBatched(batchSize)` — keyset pagination `user_id > cursor` (CAST uuid), mỗi trang `REQUIRES_NEW` qua self-injection `ObjectProvider`; trả `{itemsGranted, usersScanned, batches}`; endpoint `?batchSize=` (default 200, 0 = legacy single-shot). Cùng evaluator + grant path realtime.
- FIX-8 (P1): `EnergyStateDto.debugOverrideEnergyNow(DateTime)` test hook + `_deviceNowUtc()` helper — countdown test định `fakeNowUtc` cố định, `nextRecoveryAt` dẫn xuất từ fake now → expect đúng `Duration(seconds: 30)`; không đổi gameplay energy.

**Mobile** (`dau-viet-mobile`)
- `reward_dtos.dart`: `ItemRequirementDto.isUnconfigured` (`status == 'UNCONFIGURED'`) + doc cập nhật enum status.
- `inventory_screen.dart`: `_RequirementTree` early-return node UNCONFIGURED → row icon tune + text nghiêng muted "Điều kiện mở khóa đang được cập nhật" (hoặc description server).
- `energy_dto.dart` + `energy_dto_test.dart`: hook override now + test countdown dùng fake now cố định.

**Tests & verification**
- Backend: `ItemRuleEngineIT` 17/17 (+6 test mới: needs-mapping catalog, event reconcile trigger, rule revision provenance, contradictory ruleType 400, evidence-not-collectible 400, extraneous/ambiguous fields 400), `ItemConditionParserTest` 14/14 (+6 strict-shape), `ItemRuleEvaluatorTest` 13/13. `mvnw verify` **PASS 322/322** (trước đó 316).
- Mobile: `dart format --set-exit-if-changed` clean, `flutter analyze` 0 issues, `flutter test` **PASS 430/430**.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/project-changelog.md`.

## 2026-10-25 — GAME-05: Item Unlock Rule Engine V2 & Achievement Rules

**Scope:** vật phẩm/huy hiệu chỉ mở khóa khi learner thoả điều kiện cấu hình — AST `condition_json` thay cho 3 rule phẳng V1, event-scoped conditions đọc ledger GAME-04, rule append-only có provenance, API requirement tree cho Flutter.

**Database**
- `V24__item_rule_engine_v2.sql` — `item_unlock_rule` +`rule_version`/`condition_json` JSONB/`rule_metadata` JSONB; `user_inventory` +provenance (`unlock_rule_id`, `unlock_rule_version`, `source_event_id`, `cause_key` + partial unique); `acquisition_source` +`RULE_UNLOCK`/`RECONCILE_GRANT` (giữ `ADMIN_GRANT`); normalize rule v1 sang `condition_json` tương đương (giữ `rule_version=1`); seed audit 7 item event-themed → `needs-mapping`, `HUY_HIEU_DIEN_BIEN_PHU` → `valid-global`.
- `V25__item_rule_v2_check_extension.sql` — mở rộng `chk_unlock_rule_type` (+`RULE_V2`) và `chk_unlock_rule_shape` (v2 đòi `condition_json` NOT NULL, cột phẳng NULL) — fix gap V24 thiếu CHECK cho `rule_type='RULE_V2'`.

**Backend** (`com.dauviet.reward`)
- Mới: `ItemCondition` (sealed `Leaf|All|Any`, `LeafType` 11 loại), `ItemConditionParser` (depth ≤2, ≤20 children/operator, grammar nghiêm → `ItemRuleException`), `ItemConditionValidator` (tham chiếu event/lesson PUBLISHED, `EVENT_*` đòi policy configured, `SPECIFIC_EVIDENCE_SET` evidence APPROVED thuộc `eventId` + không trùng, `LEVEL_AT_LEAST` → 400 "not evaluable yet"), `ItemRuleEvaluator` (`Evaluation(satisfied, root ConditionStatus)` — per-branch `status ∈ SATISFIED|PENDING|UNSUPPORTED`, `current`/`required`, `description` tiếng Việt), `ItemRuleEvaluationContext` (lazy per-request cache, không N+1).
- `ItemUnlockService` rewrite: `evaluate(userId, lessonId?, attemptId?, eventId?)` — per-user advisory lock `pg_advisory_xact_lock(hashtextextended('item-unlock|'||userId))`; `conditionOf()` + `legacyConditionJson()` fallback cho rule v1 (row JDBC thiếu `condition_json`); `blockedByAudit()` đọc `rule_metadata.audit='needs-mapping'` chặn grant mới; grant qua `insertIgnoreV2` với `acquisition_source='RULE_UNLOCK'`, `cause_key = item-rule|{ruleId}|{userId}`.
- `LearnerAttemptService.doComplete` ordering fix: `eventMilestones.recordIfEarned` **trước** `itemUnlocks.evaluateAfterLessonCompletion` (leaf `EVENT_*` thấy milestone vừa ghi trong cùng tx).
- `RewardService` — catalog() dùng chung một `ItemRuleEvaluationContext`; `requirement()` parse `condition_json` (fallback legacy) → evaluator → `toRequirement()` map cây `ConditionStatus` sang `Requirement` tree; `inventoryList`/`itemsUnlockedByAttempt` trả provenance.
- `AdminItemService.setRule` — `req.condition` non-null → parse+validate → `ItemUnlockRule.v2` (`ruleVersion=2`, `ruleType='RULE_V2'` default); không `condition` → validateV1 + legacy factory. `AdminItemResponse.Rule` +`ruleVersion`/`conditionJson`/`ruleMetadata`.
- `GlobalExceptionHandler` — `ItemRuleException` → `400 VALIDATION_ERROR` "Invalid unlock rule" (không 500).
- `reconcileUnlocks` — cùng evaluator realtime trên tập user ứng viên (UNION `user_evidence`/`learner_attempts COMPLETED`/`user_event_progress`, không quét toàn bảng); `acquisition_source='ADMIN_GRANT'`; rule `LESSON_COMPLETED` backfill `source_lesson_id` + earliest COMPLETED attempt.

**Mobile** (`dau-viet-mobile`)
- `reward_dtos.dart`: `ItemRequirementDto` → tree model (`operator`, `eventId`, `lessonId`, `lessonTitle`, `evidenceIds`, `threshold`, `current`, `required`, `satisfied`, `status`, `description`, `conditions`); `isOperator`/`isUnsupported`/`operatorHeading()`/`describe()`/`progressFraction`; `InventoryItemDto` +provenance fields.
- `inventory_screen.dart`: locked branch render `_RequirementTree` — operator heading (`Hoàn thành tất cả/một trong các điều kiện sau`) + indented leaf rows theo status; progress bar chỉ dưới leaf đếm PENDING; UNSUPPORTED muted.

**Tests & verification**
- Backend: `ItemRuleEngineIT` 11 tests (event-scope QA-16, SPECIFIC_EVIDENCE_SET, EVENT_COMPLETED ledger+ordering, ALL/ANY, LEVEL_AT_LEAST reject+no-grant, validation 400 matrix, v1→v2 provenance, needs-mapping block, catalog tree, v1 compat), `ItemConditionParserTest` 8, `ItemRuleEvaluatorTest` 13, `ItemUnlockIT` 22 (2 assert đổi `RULE_UNLOCK`). `mvnw verify` **PASS 316/316**.
- Mobile: `dart format --set-exit-if-changed` clean, `flutter analyze` 0 issues, `flutter test` **PASS 430/430**.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/project-changelog.md`.

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
