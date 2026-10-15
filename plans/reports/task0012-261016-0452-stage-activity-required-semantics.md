# Final Learning Completion Semantics Review — `stage.required` × `activity.required` ĐÃ CHỐT

Ngày: 2026-10-16 · Branch: `main` (local, chưa push)

## 1. Intended semantics theo BA — ĐÃ XÁC ĐỊNH

BA docs (`LEARNING_ENGINE_DESIGN.md` §10 Bạch Đằng 938 master, §7 state machine):
- Reflection stage = **"Một điều học được (optional)"**; Result = "System screen (không bắt buộc là stage)"
- Completion = "required outputs satisfied + conclusion" — conclusion sống trong stage bắt buộc
- §13 chốt trước: cursor chỉ dừng ở required activity; optional activity submit không đổi cursor/không tính progress

**Semantics nhất quán: `stage.required=false` nghĩa là TOÀN BỘ stage + activities của nó là optional.** Không gating completion, không đếm progress bắt buộc, cursor không bị kéo vào. `activity.required=true` bên trong optional stage là shape mâu thuẫn — flag vô nghĩa ngoại trừ khi `completion.requiredStageIds` explicit chỉ định stage đó.

## 2. Thay đổi — áp dụng nhất quán 4 layer + publish readiness

| Layer | Trước | Sau |
|---|---|---|
| `SnapshotModel.requiredActivities` | Đếm `required:true` mọi stage | Chỉ đếm khi stage `required:true`; thêm `requiredFlaggedActivities` (ignore stage flag) cho explicit clause + publish check |
| `LessonCompletionEvaluator` (default + minScore + requireAllRequiredStages) | Optional-stage required đếm `totalRequired` | Không đếm — `requiredActivities` giờ stage-gated; `requiredStageIds` explicit vẫn đếm qua `requiredFlaggedActivities` (author override) |
| `StageTransitionResolver` (c)+(d) | Cursor kéo vào optional stage còn required chưa xong | Optional stage luôn "complete" → traverse xuyên như transparent stage — cursor không bao giờ vào |
| `progressOf` (progress + score) | `totalRequired` đếm optional-stage required | Chỉ đếm required-stage required → score đúng |
| `DraftValidator.validatePublishGuardrails` | Cho qua shape mâu thuẫn | PUBLISH reject `REQUIRED_IN_OPTIONAL_STAGE` (422); SAVE tolerant |

Không đổi: submit guard optional-in-current-stage vẫn `409 ACTIVITY_NOT_AVAILABLE` cho optional ở stage khác (đúng — optional stage vẫn là stage khác). `requireAllRequiredStages` vốn đã chỉ check required stages → không đổi. `minScore` vẫn % trên `totalRequired` (giờ stage-gated đúng).

## 3. Tests (task 4)

- `LessonCompletionEvaluatorTest` (11): fixture sửa — c1 drop flag mâu thuẫn; **+2 mới**: `optionalStage_requiredFlaggedActivity_ignoredByDefaultRule` (legacy snapshot vẫn an toàn), `requiredStageIds_explicitClause_overridesStageFlag` (explicit clause đếm required trong optional stage — task 3 preserved).
- `StageTransitionResolverTest` (16): fixtures đánh `required:true` cho gating stages (trước đây thiếu flag → semantics mới bỏ qua chúng); `requiredFreeStageTraversed` giữ `mid` optional → transparent traversal vẫn đúng.
- `DraftValidatorTest` (+2): `requiredActivityInOptionalStage_rejectedAtPublish` (SAVE sạch, PUBLISH → `REQUIRED_IN_OPTIONAL_STAGE`), `optionalStage_fullyOptional_publishesFine`.
- `AttemptCompletionIT` (+1): `optionalStage_neverGatesCompletionOrCursor` end-to-end — lesson ctx(required,r1)→ev(required,mc)→ref(optional,note): `totalRequired=2`, cursor ctx→ev không vào ref, complete 200 sau 2 submits (không soft-lock, không bypass required work).

## 4. Verify (task 5-6)

`mvnw verify` (Docker Testcontainers postgres:16-alpine): **155 unit + 152 IT, 0 failures, BUILD SUCCESS**. Không IT hiện có nào gãy — fixtures đều đã `required:true` ở gating stages. Required work không thể bypass: `AttemptCompletionIT.complete_beforeRequirements_409_noFlip` vẫn xanh; optional stage không thể soft-lock vì `requiredFlaggedActivities` trong optional stage không còn đường vào (publish reject + runtime ignore).

## 5. Files thay đổi

- `SnapshotModel.java` — `requiredActivities` stage-gated + `requiredFlaggedActivities` mới
- `LessonCompletionEvaluator.java` — `missingRequiredStages` explicit-filter dùng `requiredFlaggedActivities`
- `DraftValidator.java` — `REQUIRED_IN_OPTIONAL_STAGE` publish guard
- 4 test files sửa/extended; `docs/LEARNING_ENGINE_DESIGN.md` (§13 optional-stage semantics + §14 open-decision đã chốt), `docs/API_SPEC.md` (completion contract)

## 6. Rủi ro / unresolved

- Snapshot **legacy đã publish** có `required:true` activity trong optional stage: runtime giờ bỏ qua flag → lesson có thể complete "dễ hơn" intent cũ. Publish reject chỉ chặn snapshot MỚI. Nếu production đã có snapshot như vậy, cần audit + quyết định migrate draft (PO). Không có data nào hiện tại vi phạm (ITs xanh).
- `requiredStageIds` trỏ vào stage không có `required:true` activities → clause inert (auto-pass) — authoring nên tránh; validator chưa warn (minor, có thể thêm sau nếu BA muốn).
- RESOLVED — `stage.required` vs `activity.required` semantics đã chốt theo BA; không còn open question.
