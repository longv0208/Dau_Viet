# DẤU VIỆT — GAMIFICATION GAP REPORT

**Mã tài liệu:** DV-GAME-GAP-001
**Ngày rà soát:** 25/10/2026 (nhánh `main`, commit `230db76`)
**Baseline:** `docs/GAMIFICATION_BUSINESS_RULES.md` v1.0 · Contract: `docs/GAMIFICATION_TECHNICAL_CONTRACT.md` v1.0
**Phạm vi:** backend `dau-viet-backend`, mobile `dau-viet-mobile`, migrations V1–V20. Không audit admin web (ngoài phạm vi GAME-01).

**Thang phân loại:** `IMPLEMENTED` — code đáp ứng rule; `PARTIAL` — có nền nhưng thiếu/sai một phần; `MISSING` — chưa có; `CONFLICT` — code hiện hành vi phạm rule; `NEEDS_DECISION` — cần quyết định sản phẩm/kiến trúc trước khi code.

---

## 1. EXP & Level (§4)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| EXP-01 tích lũy, không tiêu | IMPLEMENTED | `reward_transactions` chỉ ghi credit dương (`CHECK amount>0`, V4); không đường debit nào | — | — | — | — |
| EXP-02 +100 first completion | IMPLEMENTED | `RewardPolicy` `${dauviet.rewards.first-completion.exp:100}`; `RewardGrantService.grantFirstCompletion` | — | — | — | — |
| EXP-03 grant một lần/user/lesson/type | IMPLEMENTED | `cause_key UNIQUE` + `insertIgnore` (V4); `isFirstCompletion` đếm attempt COMPLETED khác | Race hai complete trên 2 version khác nhau — `cause_key` chặn ở DB | Đã có backstop; IT concurrency nên cover | GAME-08 | Thấp |
| EXP-04 không thưởng theo knowledgeScore | IMPLEMENTED | `RewardPolicy` chỉ phát first-completion | — | — | — | — |
| EXP-05 Level tính server từ EXP | **MISSING** | Không có bảng/hàm level; `RewardSummaryResponse` chỉ trả `expTotal` | Client tự tính level → lệch nguồn truth | `level_thresholds` config (contract §2.6) + `level`/`levelProgress` trong summary | GAME-07 | Cao |

## 2. Điểm Sử Ký / Wallet (§5)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| POINT-01 +50 first completion | IMPLEMENTED | `RewardPolicy` history-points:50 | — | — | — | — |
| POINT-02 không thưởng lại | IMPLEMENTED | cause_key + ON CONFLICT DO NOTHING | — | — | — | — |
| POINT-03 nguồn cộng mới đăng ký policy/cause | IMPLEMENTED (khung) | `RewardPolicy.Grant` + causeKey pattern; chưa có nguồn mới nào | — | Mọi nguồn mới đi qua RewardPolicy/wallet service | GAME-07 | Trung bình |
| POINT-04 điểm là tiền tiêu được | **MISSING** | `historyPoints` trong summary = Σ credit lifetime; không có debit/balance | UI hiển thị "tổng kiếm được" như số dư → user đổi xong vẫn thấy số cũ | `wallet_accounts`/`wallet_transactions` (contract §2.3/§6) | GAME-07 | Cao |
| POINT-05 debit + tác dụng cùng tx | **MISSING** | Chưa có debit nào tồn tại | — | WalletService.debit trong tx của refill/purchase | GAME-07 | Cao |
| POINT-06 balance ≥ 0, lock | **MISSING** | — | Double-spend khi có shop/refill | `CHECK balance>=0` + `UPDATE … WHERE balance>=:amt` + unique cause | GAME-07 | Cao |
| POINT-07 purchaseId/key xử lý một lần | **PARTIAL** | `IdempotencyService` dùng được cho endpoint mới; chưa có endpoint mua | — | Refill/purchase endpoint bắt buộc Idempotency-Key + cause_key ledger | GAME-02/07 | Cao |
| POINT-08 ledger truy vết đầy đủ | PARTIAL | `reward_transactions` có user/attempt/type/amount/reason/cause/created_at — nhưng chỉ credit | — | `wallet_transactions` bổ sung direction/balance_after/source_ref | GAME-07 | Trung bình |
| POINT-09 không sửa ledger cũ, bridge credit | IMPLEMENTED (nguyên tắc) / MISSING (bridge) | `reward_transactions` append-only sẵn; chưa có bridge | Nhân đôi điểm nếu bridge thiết kế sai | Bridge `BRIDGE:{txId}` cause_key, chạy 1 lần, idempotent | GAME-08 | Cao |
| POINT-10 kiến trúc wallet | **NEEDS_DECISION** | Baseline khuyến nghị `wallet_accounts`+`wallet_transactions`; contract §6 đề xuất dual-write rồi cắt đứt | Chọn sai → migrate lại | Chốt: dual-write `reward_transactions`↔`wallet_transactions` trong GAME-07 hay wallet-only ngay? | GAME-07 | **Cao — quyết trước khi code** |

## 3. Thể lực / Energy (§6)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| ENGY-01..04 khởi tạo/giới hạn/vào bài miễn phí | **MISSING** (backend) | Không có `user_energy`/service; `dau-viet-mobile` chỉ demo | — | `user_energy` 100/100 lazy-create | GAME-02 | Cao |
| ENGY-05 submit sai graded −10 | **MISSING** (backend) | `doSubmit` không settle energy; nhưng `isGradedActivity` + verdict `INCORRECT` đã sẵn đúng semantics (contract §4) | Trừ nhầm PARTIAL/exhausted-accept nếu implement hời | `penalizableIncorrect` = `isGradedActivity && outcome==INCORRECT`; debit trong doSubmit | GAME-02 | **Cao — core** |
| ENGY-06 partial/ungraded không phạt | IMPLEMENTED (mặc định) | Không trừ gì hiện nay; contract §4 đóng băng bảng loại trừ | — | Giữ verdict adapter đúng bảng §6.2 | GAME-02 | Cao |
| ENGY-07/08 hồi +5/15ph server, không vượt max | **MISSING** | — | Client tự cộng giờ máy → sai lệch | Lazy-recover theo `last_recovery_at` (contract §5/§7); trả `nextRecoveryAt`,`serverTime` | GAME-02 | Cao |
| ENGY-09 energy=0 chặn submit graded, vẫn học/ôn | **MISSING** | — | Chặn nhầm READ/optional → khóa học | Gate chỉ `isGradedActivity`, trả `ENERGY_DEPLETED`+mốc hồi | GAME-02 | Cao |
| ENGY-10 clamp `min(current,10)` | **MISSING** | — | — | Trong settle | GAME-02 | Cao |
| ENGY-11 refill +20/30đ, ≤80, 1/24h | **MISSING** | — | Nút mua chạy khi wallet chưa có → "mua giả" | Phụ thuộc wallet debit (GAME-07) — refill endpoint có thể dựng trước trả 503 FEATURE_DISABLED | GAME-02/07 | Cao |
| Mobile energy screens | **CONFLICT** | `energy_management_screen.dart` `_currentEnergy=80` + `setState` +20 (`:18,:72-77`); `energy_pill.dart` default `100/150` hard-code trên ≥8 màn; `profile-screen.dart` chú thích "EnergyPill vẫn hard-code" (`:79`) | §10.2, §14.1-#1: client tự quyết năng lượng/điểm → giả mạo backend | GAME-03 nối API thật; mock chỉ trong `mock/` rõ ràng | GAME-03 | Cao |

## 4. Lesson/Mastery (§7.1–7.2)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| `score` = % required, không phải điểm kiến thức | IMPLEMENTED | `scoreOf` chú thích rõ (LearnerAttemptService:537-547) | — | — | — | — |
| `knowledgeScore` từ graded activities | IMPLEMENTED | `knowledgeScoreOf` (:561-580) — mean `score`/`correct` trên required graded | — | — | — | — |
| `NOT_ASSESSED` khi zero graded | **CONFLICT** | `knowledgeScoreOf` trả `BigDecimal.ZERO` khi `total==0` (:577) — lesson không chấm bị ghi điểm 0 | Lesson thuần READ hiển thị "0 điểm kiến thức"; event mastery tính sai; vi phạm §7.2 | `result_json` ghi `gradableRequiredCount` + `masteryStatus: NOT_ASSESSED` thay vì số 0 | GAME-04 | Cao |
| `masteryThreshold` 70 mặc định, metadata result | **MISSING** | `resultJsonOf` chỉ ghi score/knowledgeScore (:610-623) | — | Thêm `gradableRequiredCount`, `masteryThreshold`, `masteryStatus` vào result_json (additive) | GAME-04 | Cao |
| `LESSON_MASTERED` | **MISSING** | Không trạng thái/verdict mastery | — | Dẫn xuất từ knowledgeScore+threshold (contract §3) | GAME-04 | Cao |
| Best-valid-result khi ôn/retry | **NEEDS_DECISION** | Attempt COMPLETED là terminal; không cơ chế attempt ôn không thưởng | Mastery không thể cải thiện sau complete | Quyết: attempt ôn (free-review mode §6.4) có ghi knowledgeScore cải thiện không? | GAME-04 | Trung bình |

## 5. Event completion (§7.3)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| EVT-01 requiredLessonIds admin cấu hình | **MISSING** | Không bảng policy; `historical_events` không có liên kết required | — | `event_completion_policies` (contract §2.4) | GAME-04 | Cao |
| EVT-02 completed = mọi required COMPLETED (bất kỳ version) | **MISSING** (phần đếm) — nhưng primitive `completedLessonIds` đã có đúng semantics | `MapLocationUnlockQuery` (:35-39) join version→lesson, status COMPLETED | — | Tái dùng query pattern trong event evaluator | GAME-04 | Cao |
| EVT-03 republish không reset | IMPLEMENTED (nền) | Attempt pin version; map unlock đếm theo lesson không theo version | — | Áp dụng cùng cho event progress | GAME-04 | Trung bình |
| EVT-04 ledger một lần + policyVersion + snapshot | **MISSING** | — | Thêm lesson sau → mất/trục trặc entitlement | `user_event_progress` PK(user,event,milestone) + `required_snapshot` | GAME-04 | Cao |
| EVT-05 không thu hồi entitlement | IMPLEMENTED (nguyên tắc) | `user_inventory`/`user_evidence` append-only; chưa có event entitlement để thu hồi | — | Progress/dossier unlock insert-only | GAME-04 | Trung bình |
| EVT-06 không cấp trùng | **MISSING** | — | — | PK composite + ON CONFLICT DO NOTHING | GAME-04 | Cao |
| EVT-07 NOT_CONFIGURED | **MISSING** | — | Suy sai "1 bài = xong sự kiện" | API trả NOT_CONFIGURED khi không có policy PUBLISHED | GAME-04 | Cao |

## 6. Collection / Dossier / Map (§8)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| Lớp A — `user_evidence` collect khi submit hợp lệ, snapshot pin | IMPLEMENTED | `EvidenceCollectionRecorder` + `UNIQUE(user_id,evidence_id)` (V10/V11); `event_id` đã lưu | — | — | — | — |
| Thu evidence không cần trả lời đúng | IMPLEMENTED | Collect sau `result.completed()` của EVIDENCE_SELECT, kể cả graded-exhausted (đã "khám phá") | — | — | — | — |
| Lớp B — `historical_dossiers` PERSON/LOCATION/ARTIFACT | **MISSING** | Không bảng/service dossier | — | Contract §2.4/§9 | GAME-04 | Cao |
| `event_dossiers` link + unlock-on-completed | **MISSING** | — | — | GAME-04 | Cao |
| `user_dossier_unlocks` unique canonical | **MISSING** | — | — | GAME-04 | Cao |
| Preview công khai ≠ unlocked | **MISSING** | — | — | `preview` flag trong dossier API | GAME-04 | Trung bình |
| MAP_LOCATION_UNLOCKED theo lesson (FR-37) | IMPLEMENTED | `MapLocationUnlockQuery` + `MapLocationService` | — | Giữ; không đánh đồng dossier | — | — |
| §8.3 không suy theo tên; quan hệ chính thức | PARTIAL | `user_evidence.event_id`/`lesson_id` chính thức OK; nhưng item rule COLLECTION_COUNT đếm **global** (xem §7) | — | Dossier/rule v2 bắt buộc canonical ids | GAME-04/05 | Cao |

## 7. Item & Rule Engine (§9)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| ITEM-04 unique (user,item), không cấp trùng | IMPLEMENTED | `UNIQUE(user_id,item_id)` + `insertIgnore` (V12) | — | — | — | — |
| ITEM-05 đổi rule không revoke; backfill idempotent | IMPLEMENTED | `setRule` deactivate+insert; `reconcileUnlocks` ON CONFLICT DO NOTHING | — | — | — | — |
| ITEM-02 đánh giá đúng trigger | PARTIAL | Chỉ sau complete + sau evidence-collect; không có trigger event/mastery/level | Rule event-scoped không bao giờ cháy | Thêm trigger tại event-evaluator | GAME-05 | Cao |
| §9.3 rule event-scoped AND/OR (`EVENT_COMPLETED`, `EVENT_MASTERED`, `LESSON_MASTERED`, `EVENT_EVIDENCE_COUNT`, `SPECIFIC_EVIDENCE_SET`, `TOTAL_EVENTS_*`, `LEVEL_AT_LEAST`, `ALL`/`ANY`) | **MISSING** | `ItemUnlockRule` chỉ 3 `ruleType` phẳng, `lessonId`+`threshold` (:22-24) | Không biểu diễn được policy baseline | `condition_json` AST ≤2 lớp (contract §2.5/§10) | GAME-05 | Cao |
| `COLLECTION_COUNT` phạm vi | **CONFLICT** | `satisfied()` đếm `countDistinctEvidence(userId)` **toàn cục** (ItemUnlockService:236) — evidence event B có thể mở item "event A" | QA-16 fail: cross-event unlock (§8.3, §14.1-#8) | Rule mới `EVENT_EVIDENCE_COUNT(eventId)`; **quyết định**: rule global cũ giữ ngữ nghĩa hay diễn giải lại? (đã cấp không revoke — chỉ rule mới đúng) | GAME-05 | **Cao** |
| ITEM-01 rule version/provenance | **MISSING** | `user_inventory` có `acquisition_source`,`source_lesson_id`,`source_attempt_id`; không `rule_id`/`rule_version` | Audit không truy được "cấp theo rule nào/bản nào" | Thêm cột `rule_version` (và `rule_id` nếu chốt) — migration nhỏ | GAME-05 | Trung bình |
| ITEM-06 validation rule trước publish | PARTIAL | `validateRule` check lesson tồn tại+PUBLISHED, threshold non-null | AST v2 cần validation refs/depth/circular | GAME-06 validator | Trung bình |
| ITEM-07 mua = debit+ownership cùng tx | **MISSING** | Chưa có purchase | — | GAME-07 (shop sau) | Thấp |
| ITEM-08 không mua huy hiệu/kết quả | IMPLEMENTED (khung) | Chỉ có `ITEM_UNLOCK`/`ADMIN_GRANT` acquisition | — | Giữ nguyên tắc khi thêm purchase | — | — |
| `user_inventory` non-stackable | IMPLEMENTED | UNIQUE(user_id,item_id) | — | — | — | — |

## 8. API & Mobile (§10–11)

| Rule | Trạng thái | Bằng chứng | Rủi ro | Hướng xử lý | Task | Ưu tiên |
|---|---|---|---|---|---|---|
| `/me/rewards/summary` 4 chỉ số | IMPLEMENTED | `RewardService.summary` (exp, historyPoints, lessonsCompleted, itemsOwned) | `historyPoints` hiện = lifetime earned, chưa phải **balance** — §10.1 yêu cầu số dư | GAME-07 summary v2; cũ giữ tương thích | GAME-07 | Cao |
| Mobile profile đọc API thật | IMPLEMENTED | `reward_api_client.dart` → `/api/v1/me/rewards/summary`; `profile-screen.dart` dùng AsyncValue<RewardSummaryDto> | — | — | — | — |
| `GET /me/energy`, `/me/wallet*`, `/me/gamification/summary`, `/me/events/{id}/progress`, `/me/collection/dossiers`, admin policy/dossier/rule v2 | **MISSING** | — | — | Contract §11.2 | GAME-02/04/06/07 | Cao |
| Idempotency-Key trên write endpoints | IMPLEMENTED (pattern sẵn) | `IdempotencyService` + `idempotency_records` UNIQUE | — | Áp dụng cho refill/purchase | GAME-02/07 | — |
| Flutter không tự quyết thưởng/điểm/năng lượng | **CONFLICT** | EnergyPill hard-code trên dashboard/campaign/traces/inventory/heritage/context_reader/reward_claim/warship (8+ chỗ); `reward_claim_screen`/`warship_artifact_detail` dùng mock repo | §14.1-#1 | GAME-03 thay nguồn dữ liệu | GAME-03 | Cao |

## 9. Chất lượng nền đã đạt (giữ, không phá)

- Idempotency records persistent + fingerprint canonical (attemptId|activityId|canonical(answer)) — đúng baseline §11.2.
- Pessimistic attempt lock → idempotency → evaluate: thứ tự lock nhất quán sẵn để chèn energy settle (contract §5).
- `learner_attempts` pin version + advisory lock start; partial unique index active-attempt.
- `activity_attempts` lưu mọi submit với attemptNo — đủ dữ liệu để `cause_key` penalty theo attemptNo mà không cần schema mới.
- `lesson_results` UNIQUE(learner_attempt_id) — một result/attempt.
- Answer keys không lộ: handlers chỉ emit `correct`+counts; `HiddenKeyLeakIT` đã cover.
- `user_evidence.event_id` đã lưu sẵn → `EVENT_EVIDENCE_COUNT` cần **không** migration data.

## 10. Quyết định cần user chốt trước GAME-02

| # | Quyết định | Lựa chọn | Khuyến nghị |
|---|---|---|---|
| D1 | Wallet: dual-write `reward_transactions`↔`wallet_transactions` rồi cắt đứt, hay wallet-only + bridge đọc ngay? | Dual-write tương thích client cũ nhưng hai chỗ ghi / wallet-only đơn giản nhưng phải sửa summary ngay | **Dual-write một chu kỳ** (GAME-07), GAME-08 cắt — client cũ không gãy |
| D2 | `COLLECTION_COUNT` cũ: giữ ngữ nghĩa global và chỉ rule mới event-scoped, hay diễn giải lại rule cũ thành event-scoped? | Giữ global (đã cấp không revoke) / diễn giải lại (đúng baseline hơn nhưng đổi ý nghĩa rule đã publish) | **Giữ global + rule mới** — không âm thầm đổi hành vi rule đang active |
| D3 | `user_inventory` thêm `rule_version`/`rule_id`? | Thêm cột (audit ITEM-01/03 đủ) / nhét vào `acquisition_source` string (xấu) | **Thêm cột** — migration nhỏ, không phá |
| D4 | Ôn tập miễn phí (§6.4) có cho cải thiện `knowledgeScore`/mastery? | Có (best-valid-result) / Không (mastery cố định lần complete đầu) | Cần Product chốt — ảnh hưởng scope GAME-04 |
| D5 | Level thresholds: config file `application.yml` hay bảng admin? | Config file (đủ V1) / bảng (admin đổi runtime) | **Config file** — YAGNI; promote bảng nếu GAME-06 yêu cầu |

## 11. Tóm tắt số lượng

| Trạng thái | Số rule |
|---|---|
| IMPLEMENTED | 22 |
| PARTIAL | 6 |
| MISSING | 28 |
| CONFLICT | 3 (`knowledgeScore=0` khi NOT_ASSESSED; `COLLECTION_COUNT` global; mobile energy/points hard-code) |
| NEEDS_DECISION | 3 (D1 wallet, D4 mastery-ôn-tập, + D2/D3/D5 gom ở §10) |

Ba `CONFLICT` là lỗi hành vi thật — không phải "chưa làm" mà là "đang làm sai": ưu tiên sửa trong GAME-03/04/05 tương ứng, kèm regression test cho QA-16 và NOT_ASSESSED.
