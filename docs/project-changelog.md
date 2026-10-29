# DẤU VIỆT — Project Changelog

> Detailed record of significant changes, features và fixes. Newest first.

## 2026-10-29 — TASK-0021 / Issue #34: OTP đăng ký, quên mật khẩu và đăng nhập Google

**Scope:** Nâng cấp xác thực theo Issue #34 — đăng ký xác thực OTP qua email, quên/đặt lại mật khẩu bằng OTP với thu hồi phiên, đăng nhập Google (idToken) có account linking. Plan: `plans/261029-issue-34-auth-otp-google/plan.md`.

**Database**
- `V53__auth_otp_and_google_oauth.sql` — `users.password_hash` nullable (tài khoản Google-only); bảng `auth_otp_challenges` (mã OTP 6 số băm SHA-256 có salt, purpose `REGISTER_VERIFY`/`PASSWORD_RESET`, partial unique `ux_otp_active` đảm bảo một challenge active/(email,purpose)); bảng `user_oauth_accounts` (`UNIQUE (provider, provider_subject)`).

**Backend**
- `POST /api/v1/auth/register` đổi contract: tạo REGISTER_VERIFY challenge → `202 OtpChallengeResponse` (không tạo user). `POST /auth/register/verify` tạo user `email_verified_at=now()` + trả `TokenResponse`. `POST /auth/otp/resend` (cooldown 60s → `429 OTP_RESEND_COOLDOWN`). `POST /auth/password/forgot` luôn `200` (anti-enumeration); `POST /auth/password/reset` verify OTP + BCrypt mật khẩu mới + revoke toàn bộ `auth_refresh_tokens` của user. `POST /auth/google` verify idToken qua `GoogleIdTokenVerifier` (sig/iss/aud/exp/email_verified), link-or-create LEARNER, từ chối link vào email chưa verified (`403 GOOGLE_EMAIL_UNVERIFIED`).
- `OtpService` (issue/verify/resend, max 5 attempts, hết hạn 300s), `OtpSender` với `SmtpOtpSender` (`MAIL_ENABLED=true`) và `LoggingOtpSender` fallback chỉ log mã khi profile `local`. Error codes mới: `OTP_INVALID`, `OTP_EXPIRED`, `OTP_MAX_ATTEMPTS_EXCEEDED`, `OTP_RESEND_COOLDOWN`, `OTP_NO_CHALLENGE`, `GOOGLE_TOKEN_INVALID`, `GOOGLE_EMAIL_UNVERIFIED`.

**Mobile**
- `RegisterScreen` → luồng 2 bước qua `OtpVerificationScreen` mới (ô nhập 6 số, countdown resend 60s); `ForgotPasswordScreen` + `ResetPasswordScreen` cho luồng khôi phục; nút "Quên mật khẩu?" và "Tiếp tục với Google" trên `AuthScreen` (`google_sign_in` + gateway provider mockable). Routes mới: `/auth/forgot`, `/auth/otp`, `/auth/reset-password`.

**Tests/Docs** — `OtpServiceTest` (11), `AuthServiceTest` viết lại (15), `GoogleAuthServiceTest` (7), `AuthControllerIT` viết lại cho contract OTP (Docker-blocked locally), mobile auth tests 29/29 pass. Docs: `API_SPEC.md`, `DATABASE_DESIGN.md`, `backend-runbook.md` (`MAIL_*`/`GOOGLE_CLIENT_IDS` envs).


## 2026-10-28 — PATH-2.0 & HERITAGE-MAP-2.0 (Epics A–F, Issues #2–#26): Luồng Học Theo Thời Kỳ & Bản Đồ Di Sản

**Scope:** Nâng cấp toàn diện lộ trình học lịch sử phân cấp (`ERA -> PERIOD -> PHASE -> EVENT -> LESSON`), mở khóa tuần tự theo từng thời kỳ, tách địa điểm di tích thành thực thể độc lập liên kết N–N với sự kiện và bài học (`ANY`/`ALL`), tích hợp Admin CMS, Flutter Mobile, kiểm thử End-to-End và chốt lộ trình gỡ cột deprecated (ADR-009). Plan: `plans/261028-issue-26-e2e-integration-docs/plan.md`.

**Database**
- `V39__learning_path_hierarchy.sql` — Mở rộng `learning_path_chapters` (`parent_id`, `node_type ∈ ERA|PERIOD|PHASE`) và `historical_events` (`end_year`, `date_precision ∈ EXACT|CIRCA|CENTURY|PERIOD`).
- `V40__heritage_locations.sql` — Nới `map_locations.event_id` thành nullable, gỡ FK bắt buộc cùng sự kiện, bổ sung metadata di sản (`slug`, `kind`, `coordinate_precision`, `visibility`, `unlock_rule_mode`, `cover_asset_id`, `short_summary`) và 4 bảng mới: `map_location_events`, `map_location_unlock_lessons`, `map_location_media`, `user_location_unlocks`.
- `V41__user_path_period_state.sql` — Bảng `user_path_period_state` lưu dấu thời kỳ người học tương tác gần nhất (`last_touched_at`).
- `V42__seed_history_main_v2.sql` — Phát hành `HISTORY_MAIN` v2 (`PUBLISHED`) với 4 đại thời kỳ (`ERA`) và 5 thời kỳ (`PERIOD`), tự động nâng cấp enrollment của người học.
- `V43__seed_heritage_location_assets_and_media.sql` — Đồng bộ 6 tranh minh họa di sản vào `assets`, backfill 12 địa điểm di tích canonical và tư liệu `map_location_media`.
- **Quyết định gỡ cột deprecated (`ADR-009` / Issue #26)**: Hai cột `map_locations.event_id` và `map_locations.unlock_lesson_id` được đánh dấu deprecated (nguồn chuẩn là `map_location_events` và `map_location_unlock_lessons`); giữ tương thích ngược trong Phase 1 và chỉ thực thi `DROP COLUMN` ở Milestone M4 Cleanup khi thỏa mãn đủ 4 cổng kiểm toán trong `docs/DATABASE_DESIGN.md`.

**Backend**
- `com.dauviet.path`: `PathHierarchyValidator` kiểm tra nghiêm ngặt phân cấp `ERA -> PERIOD -> PHASE` (`422 PATH_NODE_INVALID_PARENT`); `LearnerPathProgressionService` mở khóa tuần tự trong phạm vi từng `PERIOD`, cho phép học tự do bài `PUBLISHED` ngoài lộ trình (`#8`), tự động nâng cấp lên phiên bản `PUBLISHED` mới nhất của `HISTORY_MAIN`, trả `periodProgress[]`, `currentByPeriod`, `lastPeriodCode` và cung cấp `POST /api/v1/me/learning-path/periods/{periodCode}/touch`.
- `com.dauviet.map`: `LocationUnlockEvaluator` (`LessonCompletionHook`) đánh giá luật mở khóa `ANY`/`ALL` trong cùng transaction `LearnerAttemptService.doComplete()` và trả `newlyUnlockedLocations[]`; `MapLocationService` lọc ẩn tư liệu `UNLOCKED_ONLY` khi địa điểm đang khóa; `AdminStandaloneMapLocationController` cung cấp CRUD địa điểm, liên kết sự kiện, bài học mở khóa và media.

**Admin & Mobile**
- Admin (`#18`–`#20`): Learning Path Builder dạng cây phân cấp, trang quản lý Địa điểm Di sản và Media độc lập (`/map-locations`), và thẻ Địa điểm mở khóa trong Lesson Builder.
- Mobile (`#21`–`#26`): Tầng dữ liệu `lib/features/learning_path/data/`, màn Chọn thời kỳ (`/journey`) và Hành trình thời kỳ (`/journey/:periodCode`) ẩn tầng 1 mục và hiển thị badge có đủ icon + nhãn, Trang chủ tiếp tục hành trình theo `currentByPeriod[lastPeriodCode]`, danh sách bài học trong Chiến dịch hiển thị trạng thái từ lộ trình, chuyển hướng `/heritage/:locationId`, sửa lỗi tràn khung ngang (`RenderFlex` overflow) trên màn hình hẹp 412px tại `PeriodSelectionScreen`/`PeriodJourneyScreen`, và sửa lỗi điều hướng sự kiện từ Sa Bàn (`BattleSabanScreen`).

**Tests & verification**
- Backend: `LearningFlowHeritageEndToEndIT` **3/3**, `LearningPathHierarchyAndPeriodIT` **2/2**, `LearningPathApiIT` **6/6**, `HeritageLocationV2IT` **1/1** pass trên PostgreSQL 16 Testcontainers; sửa `LearningPathItFixture` upsert theo `slug` và đồng bộ template/policy với V42.
- Mobile: `flutter test --no-pub test/learning_path/ test/dashboard/ test/campaign/ test/campaign_detail_test.dart` **35/35 pass** (bao gồm `learning_flow_e2e_integration_test.dart`).

**Docs updated:** `docs/DECISIONS.md`, `docs/DATABASE_DESIGN.md`, `docs/LEARNING_PATH_2_0.md`, `docs/API_SPEC.md`, `docs/PROJECT_OVERVIEW.md`, `docs/development-roadmap.md`, `docs/project-changelog.md`.

## 2026-10-26 — LEARN-STREAK: Chuỗi Ngày Học — Ngọn Lửa Hào Khí

**Scope:** Daily learning streak end-to-end — PostgreSQL → Spring Boot → Flutter. Streak = số ngày VN liên tiếp có ≥1 attempt COMPLETED, timezone `Asia/Ho_Chi_Minh` tính server-side từ `learner_attempts.completed_at`; streak KHÔNG sinh reward transaction (POINT-03); không đụng GAME-07/GAME-08, không sửa migration đã apply. Plan: `plans/261026-1315-learning-streak/`.

**Database**
- `V31__learning_streak.sql` — `user_learning_streaks` (current_streak, longest_streak, last_qualified_date — aggregate optimistic row) + `user_learning_streak_days` (ledger `UNIQUE(user_id, study_date)`, `first_attempt_id` provenance). Idempotency 3 lớp: ledger insert `ON CONFLICT`, `advanceTo` no-op same-day, retry-safe. Mirror sang `dau-viet-db/db/migration`; backfill `dau-viet-db/scripts/` replay ngày học từ `learner_attempts` theo VN day.

**Backend**
- `com.dauviet.streak`: entities + repositories; `LearningStreakService` pessimistic lock (thứ tự lock `learner_attempts` → `days` → `streaks` — no deadlock với completion flow), `recordStudyDay` trả flag "ngày mới được ghi", `advanceTo` — ngày liên tiếp `current+1`, bỏ lỡ reset 1, `longestStreak = max(...)` không giảm, `streakAlive` = last là hôm nay HOẶC hôm qua VN; read path `readOnly` không lazy-create.
- `LearningStreakController`: `GET /api/v1/me/streak` (currentStreak, longestStreak, completedToday, streakAlive, lastQualifiedDate, today, timezone, serverTime), `GET /api/v1/me/streak/calendar?from&to` (cap 92 ngày, 400 range ngược).
- Hook `LearnerAttemptService.doComplete` sau reward/event milestone cùng tx; `CompleteAttemptResponse.streak` additive — non-null CHỈ khi ledger ghi ngày mới (null trên replay/bài thứ hai cùng ngày → client không re-animate, không cần gọi thêm API).

**Mobile**
- `lib/features/streak/data/`: `streak_dto` (`LearningStreakDto`, `LearningStreakCalendarDto`, `StreakInfoDto.tryParse` → null khi `!dayRecorded`), `streak_api_client`, repository interface + api impl (ApiException thẳng lên UI, không fallback mock) + mock (5 ngày demo), `streak_providers` — `StreakController` AsyncNotifier mirror energy (sessionKey, `applyStreakInfo` freshness `serverTime`, `_noRetry`), `streakCalendarProvider` family theo (year, month).
- UI: route `/streak` + `LearningStreakScreen` (flame hero dim khi chưa cháy, today message 4 trạng thái, stat cards, month calendar chấm đỏ ngày học + viền vàng hôm nay); dashboard thay `'⚡12'`/`'❤️3'` bằng `_EnergyMiniPill`/`_StreakMiniPill` đọc provider thật (placeholder `'—'` khi loading/error) → `/energy`, `/streak`; profile `_StreakCard` + menu tile; lesson player header `_StreakBadge` số thật; result screen `_StreakFlameBanner` animate một-lần (flame elastic + count N-1→N, "Kỷ lục mới!") qua `LessonResultDto.newlyRecordedStreak` — client-only, server GET /result không trả → deep-link không replay animation.

**Tests & verification**
- Backend: `LearningStreakServiceTest` **14/14**, `LearnerAttemptServiceTest` **19/19**; `mvnw verify` — toàn bộ IT fail do Testcontainers cần Docker (Docker off — pre-existing blocker, không liên quan streak).
- Mobile: `dart format` clean, `flutter analyze` 0 errors, `flutter test` **438 pass**; dashboard test cập nhật assertion (không còn số hard-code); 2 fail `lesson_player_energy_test` xác nhận pre-existing trên HEAD qua stash/pop.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/GAMIFICATION_BUSINESS_RULES.md` (STRK-01..08), `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` (context thứ 7 + §5.1), `docs/development-roadmap.md`, `docs/project-changelog.md`.

## 2026-10-25 — GAME-06: Admin Gamification CMS

**Scope:** Admin CMS (Spring Boot + Next.js admin) quản trị gamification — event completion policies, historical dossiers + event links, item rule builder V2 + history, reconcile/backfill panel. Backend authoritative, mọi route `/api/v1/admin/**` gate `CONTENT_ADMIN`; không đụng Flutter, không đụng learning engine internals, không sửa V22–V27. Plan: `plans/261025-0553-game06-admin-gamification-cms/`.

**Database**
- `V28__historical_dossier_versions.sql` — `historical_dossiers` +`row_version` (optimistic lock admin PUT); bảng `historical_dossier_versions` append-only snapshot mỗi publish (`UNIQUE(dossier_id, dossier_version)`, status CHECK `PUBLISHED|ARCHIVED`, `published_by`), backfill dossier PUBLISHED có sẵn — pin `user_dossier_unlocks.dossier_version` truy vết được nội dung đã duyệt.

**Backend**
- Module A — `AdminCompletionPolicyController` + `AdminCompletionPolicyService`: `GET/POST/PUT /admin/events/{eventId}/completion-policies[/{policyId}]`, `POST .../validate` (dry-run `{valid,errors,warnings,diff}`), `POST .../publish` atomic (lock event `FOR UPDATE` → revalidate → archive PUBLISHED cũ `saveAndFlush` trước insert mới tránh va `ux_event_policy_published` → publish). `PUT` sửa **in-place trên DRAFT** (policyId ổn định — user override thay copy-on-write; PUBLISHED immutable). `expectedPolicyVersion` lệch → 409 `OPTIMISTIC_LOCK_CONFLICT`; validate fail → 422.
- Module B — `AdminDossierController` + `AdminDossierService`: dossier CRUD (`GET/POST /admin/dossiers`, `GET/PUT /admin/dossiers/{id}` — `canonicalCode` kebab-case set một lần, `source` structured `DossierSourceInput` **không raw JSON**, `expectedRowVersion` guard), `POST .../publish` (`dossier_version=max+1` + snapshot V28), `POST .../archive` (entitlement đã unlock giữ nguyên), `GET/PUT /admin/events/{eventId}/dossiers` (replace-list nguyên tử — mọi dossier phải PUBLISHED, `displayOrder≥0` không trùng → 422). Sửa nội dung trên PUBLISHED → `pendingChanges` chờ publish version mới.
- Module C — `AdminItemRuleController`: `POST /admin/items/{itemId}/rule/validate` (đúng pipeline parse+validate+scope-check của `PUT /rule`, không ghi DB → `{valid,errors,warnings,normalizedCondition,scope,acceptsRule}`), `GET .../rule/history` (revision append-only + `grantCount` từ `user_inventory.unlock_rule_id`).
- `GlobalExceptionHandler` mở rộng bắt `org.springframework.dao.OptimisticLockingFailureException` (superclass — service throw thủ công cho stale guard, trước chỉ bắt `ObjectOptimisticLockingFailureException` → 500 thay vì 409).

**Admin UI**
- Tab `gamification` trong Event Workspace: `PolicyEditor` (checkbox required/optional lesson, threshold mastered, validate + publish với stale-409 handling), `DossierLinkTable` (reorder + remove + link picker).
- Trang `/dossiers`: list + filter type/status/q + dossier editor (source form structured, pending-changes banner, publish/archive).
- `/items/[id]`: Rule Builder V2 (AST builder không raw JSON, scope banner GLOBAL/EVENT_SCOPED/UNRESOLVED, validate trước Save), rule history table, `ReconcilePanel` (confirm dialog → POST reconcile-unlocks/backfill → counter thật).

**Tests & verification**
- Backend: `AdminCompletionPolicyIT`, `AdminDossierIT`, `AdminItemRuleIT` mới; `AbstractPostgresIT` thêm cleanup `historical_dossier_versions`; `mvnw verify` **PASS 363 IT + 486 unit**, Flyway V28 clean.
- Admin: `npm run typecheck` PASS; `vitest run` **288/288** (+13 test: policy-editor, dossier-link-table, dossiers-table, reconcile-panel, scope-banner; MSW handlers cho toàn bộ endpoint mới); `npm run build` PASS.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/development-roadmap.md`, `docs/project-changelog.md`.

## 2026-10-25 — GAME-05 FINAL FIX: Grant Provenance & Rule Safety

**Scope:** 4 fix trên commit `32f6428` — grant event-milestone giữ provenance attempt, chặn bypass bảo vệ event-specific bằng rule V1 global, tách schema `rule_version` khỏi `revision` publish monotonic, siết kiểm chứng evidence collectible theo EVIDENCE_SELECT. Không refactor rộng, không tính năng mới — chuẩn bị cho GAME-06.

**Database**
- `V27__item_rule_revision_schema.sql` — `item_unlock_rule` +`revision INTEGER`; backfill `revision = rule_version` (provenance cũ giữ nguyên); `SET NOT NULL` + `DEFAULT 1` (chỉ bảo vệ insert thủ công) + `chk_rule_revision CHECK (revision >= 1)`. Không sửa V24/V25/V26.

**Backend**
- FINAL FIX-1 (P1): `EventMilestoneRecorder.recordIfEarned` overload 4-tham-số `(userId, eventId, lessonId, attemptId)`; `doComplete` truyền attempt đang hoàn thành → `ItemUnlockService.evaluateAfterEventMilestone` grant với `source_attempt_id`/`source_lesson_id` đúng → `itemsUnlocked` (lọc `source_attempt_id` + `acquisition_source<>'ADMIN_GRANT'`) hiển thị badge `EVENT_COMPLETED` ngay trên result screen. Overload 2-tham-số cho reconcile giữ null — không gán attempt giả; không vòng gọi; grant cùng tx completion; `cause_key` chặn double-grant khi `evaluateAfterLessonCompletion` chạy sau.
- FINAL FIX-2 (P1): `ItemRuleScopeResolver` (mới) suy `ItemScope ∈ UNRESOLVED|EVENT_SCOPED|GLOBAL` từ toàn bộ lịch sử rule của item — từng có AST chứa leaf event-scoped → `EVENT_SCOPED`; chỉ có flag `needs-mapping` → `UNRESOLVED`; còn lại `GLOBAL`. `AdminItemService.buildRule` từ chối 400 publish rule global lên item `UNRESOLVED`/`EVENT_SCOPED`; `ItemUnlockService.blockedByAudit` chặn grant `UNRESOLVED` kể cả khi active rule mất flag; `RewardService.requirement` → `UNCONFIGURED`. Không hard-code mã item/tên Bạch Đằng; item `GLOBAL` vẫn nhận rule global.
- FINAL FIX-3 (P2): `rule_version` giờ chỉ là schema payload (1=V1, 2=V2 — CHECK cũ giữ); `revision` mới là thứ tự publish per-item — cả nhánh V1 lẫn V2 của `setRule` đều ghi `findMaxRevision(itemId)+1` (V2 floor 2). Sửa lỗi publish V1 sau nhiều publish V2 ghi `rule_version=1` → revision trùng/giảm. `user_inventory.unlock_rule_version` ghi `revision`; `AdminItemResponse.Rule.ruleVersion` trả `revision`.
- FINAL FIX-4 (P2): `ItemConditionValidator.isCollectible` siết lại — evidence chỉ "collect được" khi một activity `EVIDENCE_SELECT` trong snapshot PUBLISHED hiện tại tham chiếu nó (`@> jsonb_build_array(to_jsonb(:eid))` trên `visibleEvidenceIds`/`acceptedEvidenceIds`/`requiredEvidenceIds` hoặc `evidenceOptions[{id}]`); chỉ nằm trong `snapshot.evidence[]` metadata là chưa đủ (recorder chỉ ghi từ submission EVIDENCE_SELECT được chấp nhận). Fallback `user_evidence` row — entitlement collect từ version cũ giữ nguyên. Native query fix: bỏ `::text` cast làm param fail.

**Tests & verification**
- `ItemRuleEngineIT` 23/23 (+6: eventMilestoneGrant giữ provenance hiển thị trên result, eventScopedItem từ chối rule global tới khi có rule event, globalItem vẫn cho COLLECTION_COUNT, revision monotonic V1→V2→V1 (schema 1,2,2,1 / revision 1,2,3,4), SPECIFIC_EVIDENCE_SET từ chối evidence chỉ có trong READ, chấp nhận evidence collect từ version cũ). `ItemUnlockIT`/`EventCompletionIT`/`RewardGrantIT`/`AttemptCompletionIT` + parser/evaluator unit tests.
- `mvnw verify` **PASS 328/328** (trước 322). Mobile: `dart format` clean, `flutter analyze` 0 issues, `flutter test` **PASS 430/430** — không đổi code mobile.

**Docs updated:** `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/project-changelog.md`.

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
