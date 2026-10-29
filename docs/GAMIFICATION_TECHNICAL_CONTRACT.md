# DẤU VIỆT — GAMIFICATION TECHNICAL CONTRACT

**Mã tài liệu:** DV-GAME-TC-001
**Phiên bản:** 1.0 — contract kỹ thuật cho chuỗi task GAME-02..08
**Ngày:** 25/10/2026
**Nguồn nghiệp vụ:** `docs/GAMIFICATION_BUSINESS_RULES.md` (DV-GAME-BR-001 v1.0)
**Trạng thái:** Contract/foundation — KHÔNG triển khai. Tài liệu này chốt ranh giới kỹ thuật để các task sau không phải quyết định lại kiến trúc giữa chừng.

---

## 1. Phân ranh giới domain (domain boundaries)

Hệ thống gamification chia thành 7 bounded context. Mỗi context sở hữu một nguồn truth; không context nào được ghi vào bảng của context khác ngoài contract nêu dưới.

| Context | Module hiện tại | Sở hữu (source of truth) | Được đọc bởi |
|---|---|---|---|
| **Learning Runtime** | `com.dauviet.learning` | `learner_attempts`, `activity_attempts`, `lesson_results`, `idempotency_records` | Reward Engine, Progress Read, Energy Service, Streak Service |
| **Reward Ledger** | `com.dauviet.reward` | `reward_transactions` (EXP + HISTORY_POINTS credits, append-only) | Wallet Service (bridge), Profile Summary |
| **Wallet** | (mới, GAME-07/02) | `wallet_accounts`, `wallet_transactions` | Energy Refill, Shop tương lai, Profile |
| **Energy** | (mới, GAME-02) | `user_energy`, `energy_transactions` | Learning Runtime (gate), Mobile Energy UI |
| **Learning Streak** | `com.dauviet.streak` (mới, STREAK-01) | `user_learning_streaks`, `user_learning_streak_days` | Mobile Streak UI (dashboard pill, detail, result animation) |
| **Event/Milestone** | (mới, GAME-04) | `event_completion_policies`, `user_event_progress` | Dossier Unlock, Item Rules, Map |
| **Collection & Items** | `com.dauviet.collection`, `com.dauviet.reward` | `user_evidence`, `historical_dossiers` (mới), `event_dossiers` (mới), `user_dossier_unlocks` (mới), `item_catalog`, `item_unlock_rule`, `user_inventory` | Profile, Item Rule Engine |

Quy tắc xuyên context:

1. **Một chiều tác động:** Learning Runtime → (Reward, Energy, Event, Collection, Streak). Ngược lại chỉ đọc — ví dụ Energy Service được Learning Runtime gọi để gate submit, nhưng Energy không sửa attempt; Streak Service được `doComplete` gọi để ghi ngày học, nhưng Streak không sửa attempt và **không sinh reward** (STRK-05).
2. **Cùng một transaction vật lý** khi action gốc là `submit` hoặc `complete` (xem §5). Không outbox/event bus trong V1 — độ phức tạp không cần thiết ở quy mô một datasource.
3. **Đọc chéo hợp lệ:** Wallet đọc `reward_transactions` chỉ một lần qua migration bridge (POINT-09); Profile Summary đọc mọi ledger qua read model.
4. **Không tạo ledger song song cho cùng một khái niệm:** EXP chỉ sống ở `reward_transactions`; Điểm Sử Ký chi tiêu được chỉ sống ở `wallet_*`; energy chỉ sống ở `user_energy`.

## 2. Mô hình dữ liệu (ERD logic)

### 2.1 Đã có (giữ nguyên, không sửa ngược)

```
learner_attempts ──< activity_attempts
learner_attempts ──< lesson_results          (learner_attempt_id UNIQUE)
learner_attempts ──< reward_transactions     (cause_key UNIQUE, CHECK amount>0)
users ──< user_evidence                      (UNIQUE(user_id, evidence_id))
users ──< user_inventory                     (UNIQUE(user_id, item_id))
item_catalog ──< item_unlock_rule            (partial unique: 1 active rule/item)
map_locations (lesson_id -> lessons)
idempotency_records                          (UNIQUE(user_id, operation, key))
```

### 2.2 Mới — GAME-02 (energy)

```
user_energy
  user_id          PK/FK users
  current_energy   smallint  CHECK (0..100)
  last_recovery_at timestamptz NOT NULL   -- mốc neo chu kỳ hồi
  row_version      bigint    NOT NULL DEFAULT 0   -- optimistic lock

energy_transactions
  id               uuid PK
  user_id          FK users
  direction        text  'DEBIT' | 'CREDIT'
  amount           smallint CHECK (amount > 0)   -- luôn dương, chiều ở direction
  reason           text  'GRADED_INCORRECT' | 'NATURAL_RECOVERY' | 'REFILL_PURCHASE' | 'ADMIN_ADJUST'
  cause_key        text  UNIQUE NOT NULL        -- vd SUBMIT_PENALTY:{attemptId}:{activityId}:{attemptNo}
  balance_after    smallint NOT NULL            -- snapshot sau ghi, audit + QA
  reference_json   jsonb                         -- attemptId/activityId/purchaseId…
  created_at       timestamptz NOT NULL
```

### 2.3 Mới — GAME-07/02 (wallet, khuyến nghị POINT-10)

```
wallet_accounts
  user_id          PK/FK users
  currency         text  'HISTORY_POINTS'        -- một row/user/currency, mở rộng sau
  balance          bigint CHECK (balance >= 0)   -- điều kiện DB, không chỉ service
  row_version      bigint NOT NULL DEFAULT 0

wallet_transactions
  id               uuid PK
  user_id          FK users
  currency         text
  direction        text 'CREDIT' | 'DEBIT'
  amount           bigint CHECK (amount > 0)
  reason           text
  cause_key        text UNIQUE NOT NULL          -- PURCHASE:{purchaseId}, REFILL:{key}…
  source_ref       text                          -- vd reward_transactions.id khi bridge credit cũ
  balance_after    bigint NOT NULL
  created_at       timestamptz NOT NULL
```

`pointsEarned = Σ CREDIT`, `pointsSpent = Σ DEBIT`, `pointsBalance = wallet_accounts.balance ≡ earned − spent`. Bridge migration: insert CREDIT vào `wallet_transactions` cho từng row `reward_transactions(reward_type='HISTORY_POINTS')` với `source_ref = reward_transactions.id`, `cause_key = 'BRIDGE:' || reward_transactions.id` — idempotent nhờ UNIQUE cause_key; `reward_transactions` không bị sửa/xoá (POINT-09).

### 2.4 Mới — GAME-04 (event milestone)

```
event_completion_policies
  id                 uuid PK
  event_id           FK historical_events
  policy_version     int  NOT NULL
  status             text 'DRAFT' | 'PUBLISHED' | 'ARCHIVED'
  required_lesson_ids jsonb NOT NULL   -- snapshot thứ tự lesson required
  optional_lesson_ids jsonb NOT NULL DEFAULT '[]'
  mastery_threshold  smallint          -- default 70; null = event không xét mastered
  published_at       timestamptz
  UNIQUE(event_id, policy_version)
  -- invariant: chỉ 1 policy PUBLISHED/event (partial unique index)

user_event_progress
  user_id            FK users
  event_id           FK historical_events
  milestone          text 'EVENT_COMPLETED' | 'EVENT_MASTERED'
  policy_version     int  NOT NULL              -- version đã đạt, audit EVT-04
  required_snapshot  jsonb NOT NULL             -- lesson set tại thời điểm ghi
  granted_at         timestamptz
  PRIMARY KEY(user_id, event_id, milestone)     -- một lần mỗi milestone (EVT-06)

historical_dossiers
  id          uuid PK
  canonical_code text UNIQUE          -- 'ngo-quyen', 'song-bach-dang'…
  dossier_type   text 'PERSON' | 'LOCATION' | 'ARTIFACT' | 'CONTEXT'
  title, description, source_json, asset_id
  status         text 'DRAFT' | 'PUBLISHED' | 'ARCHIVED'

event_dossiers
  event_id   FK historical_events
  dossier_id FK historical_dossiers
  unlock_on  text 'EVENT_COMPLETED'           -- V1 chỉ một trigger
  PRIMARY KEY(event_id, dossier_id)

user_dossier_unlocks
  user_id    FK users
  dossier_id FK historical_dossiers
  event_id   FK                              -- event đã mở (provenance ITEM-03)
  granted_at timestamptz
  PRIMARY KEY(user_id, dossier_id)           -- unique theo canonical dossier (§8.3)
```

### 2.5 Mới — GAME-05 (item rule v2)

`item_unlock_rule` mở rộng: giữ 3 cột hiện có, thêm `rule_version int NOT NULL DEFAULT 1`, `condition_json jsonb` chứa AST `{all|any:[{type, params…}]}`. Các `type` hợp lệ (§9.3): `EVENT_COMPLETED`, `EVENT_MASTERED`, `LESSON_MASTERED`, `LESSON_COMPLETED`, `EVENT_EVIDENCE_COUNT`, `SPECIFIC_EVIDENCE_SET`, `COLLECTION_COUNT`, `LESSON_COUNT`, `TOTAL_EVENTS_COMPLETED`, `TOTAL_EVENTS_MASTERED`, `LEVEL_AT_LEAST`. Độ sâu AST ≤ 2 (một lớp all/any bọc leaf) — đủ cho mọi policy V1 và review được bằng mắt.

### 2.6 Mới — level config

`level_thresholds` là config có version, không bảng riêng nếu không cần admin UI: lưu ở `application.yml` (`dauviet.gamification.levels: [0,500,1200,2100,3200]`) là đủ cho V1; nếu GAME-06 yêu cầu admin chỉnh, promote thành bảng `level_thresholds(level PK, min_exp, config_version)`. Quyết định: **config file V1** — YAGNI, chưa có yêu cầu admin đổi ngưỡng lúc runtime.

## 3. State transitions chuẩn

```
attempt:    IN_PROGRESS ──complete()──> COMPLETED        (terminal, không mở lại)
lesson:     LESSON_IN_PROGRESS → LESSON_COMPLETED → LESSON_MASTERED (đánh giá từ lesson_results)
event:      NOT_CONFIGURED → (policy PUBLISHED) → AVAILABLE
            AVAILABLE → EVENT_COMPLETED → EVENT_MASTERED   (một chiều, không thu hồi)
energy:     0..100, monotonic trong một tx; không có state ẩn ngoài (current, last_recovery_at)
dossier:    LOCKED → UNLOCKED (permanent entitlement, §2.1)
item:       LOCKED → OWNED   (append-only, không revoke)
```

Bất biến: `LESSON_COMPLETED` chỉ phát sinh qua `complete()` trên attempt COMPLETED; `LESSON_MASTERED` là **trạng thái dẫn xuất** đọc từ `lesson_results.result_json.knowledgeScore` + threshold — không lưu cờ riêng trong V1 (tránh hai nguồn truth); `EVENT_*` chỉ phát sinh qua `user_event_progress` insert.

## 4. Grading verdict contract (cho energy penalty)

Đây là phần GAME-02 phụ thuộc trực tiếp. `ActivityResult` hiện trả `(outcome, completed, output, feedbackCode)` — `completed=true` KHÔNG đồng nghĩa đúng (exhausted vẫn completed). Contract chuẩn hoá:

**Định nghĩa `penalizableIncorrect(result, activityType, config)`** — adapter thuần, GAME-02 đặt ở `learning/application/` hoặc `energy/application/`:

```
penalizableIncorrect = outcome == INCORRECT
                   AND activityType ∈ {MULTIPLE_CHOICE, MATCHING, DRAG_ORDER, CER_CHOICE}
                   OR (config.graded == true AND activityType ∈ {EVIDENCE_SELECT, REASONING_CONNECT})
```

Tương đương: tái dùng `LearnerAttemptService.isGradedActivity(act)` + `outcome == INCORRECT`.

| Loại | Có trừ? | Căn cứ |
|---|---|---|
| `MULTIPLE_CHOICE`, `MATCHING`, `DRAG_ORDER`, `CER_CHOICE` → `INCORRECT` | Có (−10) | ENGY-05; kể cả `exhausted=true` vẫn trừ 1 lần nếu submit khi energy>0 |
| `EVIDENCE_SELECT`, `REASONING_CONNECT` `graded:true` → `INCORRECT` | Có | ENGY-05/§6.2 |
| Mọi type → `PARTIAL` | Không | ENGY-06 — partial là tư duy một phần đúng |
| `VERIFICATION` → `PARTIAL`/`CONTRADICTED`/`SUPPORTED` | Không | §6.2 — verdict hỗ trợ giả thuyết, không phải chấm đúng/sai |
| `HYPOTHESIS_CHOICE`, `CER`, `READ`, `VIEW_IMAGE`, `REFLECTION_PROMPT`, `EXPLORE_MAP` | Không | Không có khái niệm đúng/sai |
| `EVIDENCE_SELECT`/`REASONING_CONNECT` `graded:false` → `IN_PROGRESS`/`COMPLETED` | Không | Không chấm |
| Handler ném `IllegalArgumentException` (payload sai, id ngoài snapshot) | Không | Không phải "submit sai hợp lệ" — request bị reject trước evaluate |
| Idempotency replay (cùng key + cùng payload) | Không | `IdempotencyService` trả stored response, `doSubmit` không chạy → không debit lần 2 |

Chốt thiết kế: penalty ghi **trong `doSubmit`, sau `handler.evaluate` và `state.recordOutput`, trước `activityAttempts.save`** — cùng transaction; `cause_key = 'SUBMIT_PENALTY:' + attemptId + ':' + activityId + ':' + attemptNo` (attemptNo đã bump → mỗi submit mới key mới; replay cùng Idempotency-Key không vào được đây). Zero-energy gate ở **đầu `doSubmit`**: nếu `isGradedActivity` và `energy == 0` → ném `EnergyDepletedException` (409 `ENERGY_DEPLETED` + `nextRecoveryAt`), không chạm attempt state (QA-06).

## 5. Transaction & idempotency

| Luồng | Phạm vi atomic | Khoá/đảm bảo |
|---|---|---|
| `submit()` | pessimistic `findForUpdate(attempt)` → `idempotency.execute` → evaluate → **energy settle** → evidence collect → item eval → `activity_attempts` → cursor → save | Lock attempt trước mọi ghi; `UNIQUE(user,op,key)` + `cause_key` chặn double-debit |
| `complete()` | lock attempt → idempotency → `markCompleted` → `lesson_results` → **streak record** (STREAK-01) → `rewardGrants` → `itemUnlocks` → **event eval** (GAME-04) → save | Một tx; reward fail → rollback cả complete + streak |
| `refill()` (GAME-02/07) | lock `user_energy` → lazy-recover → check ≤80 & rate-limit 24h → lock `wallet_accounts` → debit 30 → credit +min(20, 100−cur) → 2 ledger rows | Thứ tự lock cố định: `user_energy` → `wallet_accounts` (mọi nơi khác phải theo thứ tự này nếu chạm cả hai); `cause_key` từ Idempotency-Key request |
| `startOrResume` | advisory `pg_advisory_xact_lock(user|lesson)` → check → insert | Partial unique index backstop |
| Reconcile/backfill | per-rule set-based `INSERT … ON CONFLICT DO NOTHING` | Không lock; idempotent theo UNIQUE |

Energy recovery là **lazy**: không scheduler. Mọi đọc/ghi `user_energy` tính `cycles = floor((now − last_recovery_at)/15min)`, `current = min(100, current + 5*cycles)`, `last_recovery_at += cycles*15min` (phần lẻ bảo tồn); khi current chạm 100 → neo `last_recovery_at = now` (ENGY-08). Wallet/energy debit không bao giờ lớn hơn balance hiện hữu — CHECK ở DB + update có điều kiện `WHERE balance >= :amount` làm backstop (QA-10).

### 5.1 Thiết kế Streak (STREAK-01)

- `user_learning_streaks`: 1 row/user (`current_streak`, `longest_streak`, `last_qualified_date`, `row_version`) — lazy-create lần complete đầu tiên, KHÔNG lazy-create khi đọc.
- `user_learning_streak_days`: append-only ledger PK `(user_id, study_date)` — ground truth; `study_date = (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date` tính server-side từ `learner_attempts.completed_at` UTC.
- **Lock-order:** `learner_attempts` (doComplete) → `user_learning_streak_days` (insertIgnore) → `user_learning_streaks` (PESSIMISTIC_WRITE). Ledger insert trước để UNIQUE quyết race; chỉ tx thắng (inserted=1) mới đụng aggregate — thua race trả `null` StreakInfo.
- `UserLearningStreak.advanceTo(newDate)` trả `AdvanceResult{dayRecorded, shieldConsumed, protectedDate}` — 4 nhánh (issue-38): `== last` → no-op (`dayRecorded=false`); `== last+1` → `current+1`; `== last+2 && shield>0` → trừ 1 khiên + `current+1` + `protectedDate=last+1`; còn lại → `current=1`. `longest = max(longest, current)`.
- Đọc `GET /me/streak` + `/calendar` `readOnly=true`: không reset `current_streak` âm thầm, không lazy-create — `streakAlive` cho UI phân biệt trạng thái.
- **Streak rewards (issue-38):** `StreakRewardPolicy` — daily +5 EXP/+5 pts khi `current ≥ 2`; milestone {3,7,14,30} → {+15/+10, +30/+25, +60/+50, +120/+100}. Grant trong cùng tx `doComplete` qua `RewardTransactionRepository.insertIgnore`, `cause_key = STREAK:{user}:{studyDate}:{DAILY|MILESTONE_N}:{EXP|POINTS}` → idempotent; `milestone_day` ghi lên ledger row. Điểm Sử Ký đổ vào ví qua lazy-bridge (không `WalletService.credit`).
- **Khiên (issue-38):** `shield_count` ∈ [0,3] trên `user_learning_streaks`. `buyShield` trong `IdempotencyService.execute` op `STREAK_SHIELD_PURCHASE`: lock `user_learning_streaks` (PESSIMISTIC_WRITE) → cap check 422 → `wallet.debit(20, REASON_STREAK_SHIELD_PURCHASE, STREAK_SHIELD:{key})` → `addShield()`. Lock-order khác `doComplete` (attempt→days→streaks): không chia sẻ cặp đảo → deadlock-safe.
- **SHIELD_PROTECTED rows:** ngày được cứu ghi `day_type='SHIELD_PROTECTED'` (FK reuse lesson/attempt của complete hiện tại — FK NOT NULL), `reward_exp=reward_points=0`, `insertIgnore` → STUDY row thắng nếu race. `day_type` check `('STUDY','SHIELD_PROTECTED')`.

## 6. Thiết kế Wallet

- **Một tài khoản/currency/user** — V1 chỉ `HISTORY_POINTS`. `wallet_accounts` tạo lazy lần đầu chạm (hoặc backfill từ bridge).
- **Credit nguồn:** (a) bridge từ `reward_transactions` HISTORY_POINTS (một lần, migration/backfill); (b) các nguồn mới phải qua `RewardGrantService`-tương-đương ghi **đồng thời** `reward_transactions` (tương thích đọc cũ, POINT-09) + `wallet_transactions` — hoặc quyết định GAME-07 cắt đứt: chỉ wallet, summary đọc wallet. Khuyến nghị: **dual-write có cause_key chung** rồi GAME-08 cắt đứt khi client cũ hết dùng — nhưng đây là NEEDS_DECISION ghi trong gap report.
- **Debit:** chỉ qua `wallet_transactions(direction='DEBIT')` trong cùng tx với tác dụng (refill/purchase). `balance_after` ghi snapshot — truy vết QA-19.
- **Không sửa `reward_transactions`** — CHECK amount>0 ở đó là cố ý: không insert amount âm vào bảng cũ (§5.4 note).

## 7. Thiết kế Energy

- `user_energy`: 1 row/user, `current_energy` ∈ [0,100], `last_recovery_at` UTC server. Tạo lazy = 100/100 với `last_recovery_at = now()` (ENGY-01).
- `energy_transactions` ghi mọi biến động (DEBIT graded-incorrect, CREDIT recovery thực sự áp dụng khi settle, CREDIT refill, CREDIT/DEBIT admin). Recovery lazy cũng ghi một row `NATURAL_RECOVERY` khi settle thực sự đổi số — audit đầy đủ, không cần cron.
- Gate chỉ áp cho **submit vào activity có chấm** (`isGradedActivity`): energy 0 → reject trước evaluate; ungraded submit đi qua bình thường (ENGY-09). Debit `min(current, 10)` (ENGY-10).
- Refill: một SKU V1 `+20/30 điểm`, điều kiện `current ≤ 80` sau lazy-recover, `pointsBalance ≥ 30`, rate-limit 1 lần/24h trượt (đếm từ `energy_transactions`/`wallet_transactions` gần nhất có `reason='REFILL_PURCHASE'` — một nguồn truth, không bảng riêng).
- Response `GET /me/energy`: `{current, max:100, recoveryAmount:5, recoveryIntervalSeconds:900, nextRecoveryAt, serverTime, canSubmitGraded: current>0, refillEligibility:{eligible, reasons[]}}` — client chỉ hiển thị + countdown; không tự tính (§10.2).

## 8. Event completion & policy versioning

- `event_completion_policies` immutable khi PUBLISHED — thay đổi = `policy_version+1` (policy mới PUBLISHED, cũ ARCHIVED), giống mô hình lesson_versions.
- Đánh giá tại **cuối `doComplete()`** (GAME-04): lesson vừa complete → resolve `lesson.event_id` → nếu event có policy PUBLISHED → tất cả `required_lesson_ids` đều có ≥1 attempt COMPLETED (bất kỳ version, dùng join giống `MapLocationUnlockQuery`) → insert `user_event_progress(EVENT_COMPLETED, policy_version, required_snapshot)` `ON CONFLICT DO NOTHING` → fan-out dossier unlock `INSERT … ON CONFLICT DO NOTHING` theo `event_dossiers`.
- `EVENT_MASTERED` (V1): event completed + mọi required lesson **có graded activity** đạt `knowledgeScore ≥ mastery_threshold`, và event có ≥1 graded lesson; lesson `NOT_ASSESSED` vẫn phải completed nhưng không tính vào điều kiện mastered (§7.2). Đánh giá ngay sau EVENT_COMPLETED và sau mỗi complete sau đó (best-valid-result improvement).
- `NOT_CONFIGURED`: event không có policy PUBLISHED → API trả `NOT_CONFIGURED`, không suy "1 lesson = event done" (EVT-07).
- Entitlement không bị thu hồi: admin republish/đổi policy không xoá `user_event_progress`/`user_dossier_unlocks`/`user_inventory` đã ghi (EVT-05, §2.1). Retry toàn bộ chain an toàn vì mọi insert đều `ON CONFLICT DO NOTHING` trên PK/UNIQUE.

## 9. Thiết kế Dossier (Hồ sơ lịch sử)

- `historical_dossiers` là catalog canonical (PERSON/LOCATION/ARTIFACT/CONTEXT), admin tạo, publish kiểm duyệt nguồn; `source_json` chứa citation + asset pin tương tự `user_evidence.snapshot_json` (§8.3 — archive asset không mất nội dung đã mở).
- `event_dossiers` là quan hệ chính thức duy nhất sinh unlock — không so khớp tên/tag (§8.3, QA-16).
- `user_dossier_unlocks` chỉ ghi qua fan-out EVENT_COMPLETED (V1); mở rộng trigger khác (mastery, admin grant) qua cột `unlock_on`/`acquisition_source` nếu GAME-05 cần.
- Xem trước công khai: dossier PUBLISHED chưa unlock trả `preview=true`, không `collected/unlocked` (§8.1 Lớp B).

## 10. Thiết kế rule mở khóa item (v2)

- `condition_json` AST: `{"all":[leaf…]} | {"any":[leaf…]} | leaf`. Leaf: `{type, eventId?, lessonId?, evidenceIds?, threshold?, level?}`.
- Đánh giá server-side tại các trigger: submit-collect (chỉ leaf evidence-scoped có thể đổi), lesson-complete (mọi leaf), event-milestone (EVENT_*/TOTAL_EVENTS_*), level-change (sau này — V1 không có trigger này nên `LEVEL_AT_LEAST` đánh giá tại lesson-complete).
- `EVENT_EVIDENCE_COUNT(eventId, n)`: `COUNT(DISTINCT evidence_id) FROM user_evidence WHERE user_id=? AND event_id=?` — **bắt buộc scope event**; `user_evidence.event_id` đã có sẵn (V10) nên không cần migration data. Rule cũ `COLLECTION_COUNT` giữ ngữ nghĩa global (không sửa ngược — item đã cấp theo nó), rule mới dùng `EVENT_EVIDENCE_COUNT`.
- Validation trước publish (GAME-06, ITEM-06): event/lesson/evidence tồn tại và đúng trạng thái PUBLISHED; AST depth ≤2; không leaf `EVENT_COMPLETED` trỏ event `NOT_CONFIGURED`; `SPECIFIC_EVIDENCE_SET` ids phải thuộc snapshot published của lesson thuộc event liên quan.
- Grant: `user_inventory.insertIgnore` giữ nguyên; thêm `rule_id`/`rule_version` vào provenance nếu ITEM-01 yêu cầu audit — `source_metadata` của `user_inventory` chưa có cột này → NEEDS_DECISION: thêm cột `rule_version int` vào `user_inventory` (migration nhỏ, không phá tương thích) trong GAME-05.

## 11. Danh sách API

### 11.1 Hiện có (giữ tương thích)

| Endpoint | Trạng thái |
|---|---|
| `POST /api/v1/attempts` startOrResume; `GET /api/v1/attempts/{id}` progress; `GET …/current`; `POST …/activities/{aId}/submit`; `POST …/complete`; `GET …/result` | Giữ — GAME-02 thêm field `energy` vào submit/result response (additive, không đổi shape) |
| `GET /api/v1/me/rewards/summary` | Giữ; `historyPoints` tiếp tục = tổng credit cũ cho tới khi GAME-07 chuyển sang balance (đánh dấu rõ trong gap) |
| `GET /api/v1/me/rewards/transactions`; `GET /api/v1/me/inventory`; `GET /api/v1/me/inventory/catalog` | Giữ |
| `GET /api/v1/me/collection*`; `GET /api/v1/map/locations*` | Giữ |
| `POST /api/v1/admin/rewards/backfill`; `…/reconcile-unlocks` | Giữ |

### 11.2 Đề xuất (baseline §11 — GAME-02..07 triển khai)

| Endpoint | Task | Nội dung |
|---|---|---|
| `GET /api/v1/me/energy` | GAME-02 | current/max/nextRecoveryAt/serverTime/canSubmitGraded/refillEligibility |
| `POST /api/v1/me/energy/refills` | GAME-02 (gate) / GAME-07 (wallet live) | Idempotency-Key bắt buộc; 200 {energy, wallet} | 409/422 kèm lý do |
| `GET /api/v1/me/wallet` + `…/wallet/transactions` | GAME-07 | balance/earned/spent + ledger credit/debit |
| `GET /api/v1/me/gamification/summary` | GAME-07 | expTotal, level, levelProgress, points{Balance,Earned,Spent}, energy, lessonsCompleted, eventsCompleted, itemsOwned, dossiersUnlocked — một nguồn truth; `rewards/summary` trở thành adapter |
| `GET /api/v1/me/events/{eventId}/progress` | GAME-04 | required lessons + status, eventCompleted/Mastered, policyVersion, NOT_CONFIGURED |
| `GET /api/v1/me/collection/dossiers` (+ `/{id}`) | GAME-04 | unlocked/preview theo loại/event, canonical id, nguồn |
| `GET /api/v1/admin/events/{id}/completion-policy` + `PUT …/publish` | GAME-06 | CRUD policy versioned, validate trước publish |
| `GET/POST/PUT /api/v1/admin/dossiers*` + `PUT …/events/{id}/dossiers` | GAME-06 | Dossier CMS + link event |
| `PUT /api/v1/admin/items/{id}/rule` (v2) | GAME-06 | condition_json AST + validation |

Quy ước: mọi response biến động tiền/năng lượng trả `serverTime` (UTC ISO8601) để client hiển thị countdown không lệch giờ; lỗi dùng code ổn định `ENERGY_DEPLETED`, `INSUFFICIENT_FUNDS`, `REFILL_RATE_LIMITED`, `POLICY_INVALID`, `IDEMPOTENCY_CONFLICT`.

## 12. Ánh xạ GAME-02..08

| Task | Phụ thuộc contract | Bảng chạm | API chạm |
|---|---|---|---|
| GAME-02 Energy | §2.2, §4, §5, §7 | `user_energy`, `energy_transactions` | `/me/energy`, `/refills` (wallet stub nếu GAME-07 chưa xong — refill trả 503 FEATURE_DISABLED thay vì fake) |
| GAME-03 Flutter Energy | §7, §11 | — | đọc `/me/energy`, gọi submit bình thường (server trả energyDelta) |
| GAME-04 Event + Dossier | §2.4, §3, §8, §9 | `event_completion_policies`, `user_event_progress`, `historical_dossiers`, `event_dossiers`, `user_dossier_unlocks` | `/me/events/{id}/progress`, `/me/collection/dossiers` |
| GAME-05 Item rules v2 | §2.5, §10 | `item_unlock_rule` (+cols), `user_inventory` (+rule_version?) | admin rule v2 (GAME-06 UI sau) |
| GAME-06 Admin CMS | §8–10 | các bảng trên (admin write) | admin endpoints §11.2 |
| GAME-07 Wallet + Profile | §2.3, §5, §6 | `wallet_*`, bridge migration | `/me/wallet*`, `/me/gamification/summary`, refill live |
| GAME-08 Migration/QA | §5, QA-01..20 | bridge credit, backfill mastery (nếu đủ bằng chứng) | — |

Thứ tự khuyến nghị điều chỉnh theo §15 baseline: wallet **core** (bảng + bridge + debit) đi trước hoặc song song GAME-02; refill không mở trên mobile cho tới khi debit thật chạy được — không tồn tại trạng thái "nút mua giả".
