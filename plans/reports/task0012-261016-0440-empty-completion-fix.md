# P1 Review — Empty `completion:{}` Early-Complete Fix + `stage.required` vs `activity.required` Open Question

Ngày: 2026-10-16 · Branch: `main` (local, chưa push)

## 1. Finding 1 — `completion:{}` complete sớm: ĐÃ SỬA (P1)

**Phát hiện (verified, đúng như report):** `LessonCompletionEvaluator.evaluate` phân nhánh `completion == null || !isObject()` → `DEFAULT_ALL_REQUIRED`. Nhưng `{"completion":{}}` LÀ object → qua nhánh config, không clause nào kích hoạt (`requireAllRequiredStages` falsy, `requiredStageIds` rỗng, `minScore` null) → rơi xuống `verdict(true, ...)` ở cuối và trả `complete=true` dù `doneRequired=0`. Lesson với `completion:{}` (publish được vì `DraftValidator.validateCompletion` chỉ check type + `requiredStageIds` refs) có thể được đánh dấu hoàn thành **ngay sau Start**.

**Fix — nhất quán 2 lớp (authoring validation + runtime evaluator):**

- **Runtime `LessonCompletionEvaluator.java`**: object `completion` không chứa clause nào được kích hoạt (bao gồm `{}`, `requireAllRequiredStages:false` + `requiredStageIds:[]` + `minScore:null`, hoặc bất kỳ tổ hợp inert nào) → rơi về `DEFAULT_ALL_REQUIRED` giống vắng mặt. Trước fix code đã chọn reason `DEFAULT_ALL_REQUIRED` cho trường hợp này nhưng vẫn trả `complete=true` — bug nằm ở `verdict(true,...)` cuối không kiểm tra counts. Không thay đổi gì cho config có clause thật.
- **Authoring `DraftValidator.validateCompletion`**: reject `completion:{}` ở `PUBLISH` (`EMPTY_COMPLETION` → `422 DRAFT_SCHEMA_INVALID`) — config rỗng là no-op runtime nên publish nó hoặc là lỗi authoring hoặc là field thừa; reject giữ intent tường minh. `SAVE` vẫn tolerant (author có thể đang soạn dở). Snapshot legacy đã publish trước siết vẫn an toàn nhờ fallback runtime — không cần data migration.

**Test chứng minh:**
- `LessonCompletionEvaluatorTest` +2: `emptyCompletionObject_fallsBackToDefaultAllRequired` (`{}` → NOT_COMPLETE khi 0 done, DEFAULT_ALL_REQUIRED khi done hết), `completionObjectWithoutActiveClause_fallsBackToDefault` (clauses inert → cùng fallback).
- `DraftValidatorTest` +1: `completion_emptyObject_rejectedAtPublish_toleratedAtSave` (SAVE sạch, PUBLISH → `EMPTY_COMPLETION`).
- `AttemptCompletionIT` +1: `emptyCompletionConfig_cannotCompleteRightAfterStart` — insert trực tiếp `lesson_versions` có `completion:{}` (mô phỏng snapshot legacy, bypass authoring validation), `POST /complete` ngay sau start → `409 ATTEMPT_NOT_COMPLETE` + không flip status + không `lesson_results`; sau khi làm xong required work → `200 COMPLETED` `reason=DEFAULT_ALL_REQUIRED` (không lock-out vĩnh viễn).

## 2. Finding 2 — `stage.required` vs `activity.required`: OPEN BA QUESTION (chưa sửa)

**Phát hiện (verified, có cơ sở source):** default rule `DEFAULT_ALL_REQUIRED` đếm `activity.required=true` trên **mọi stage**, kể cả stage `required:false`. Một REFLECTION optional chứa activity `required:true` sẽ bị đếm vào `totalRequired` — nếu stage transition bỏ qua stage đó, learner không bao giờ submit được activity → lesson **có thể không complete được**.

**Tại sao chưa sửa:** hành vi này CÓ CHỦ ĐÍCH theo test hiện tại — `LessonCompletionEvaluatorTest.absentCompletion_defaultAllRequiredRule` comment rõ "c1 lives in optional stage but is still a required activity → counts in the default rule". Đây là quyết định nghiệp vụ (required activity = bắt buộc toàn lesson, bất kể stage), không phải bug implementation rõ ràng. Đổi semantics (ví dụ chỉ đếm required activities trong required stages) có thể phá lesson thật và cần BA xác nhận hai cờ nghĩa gì. Đã ghi vào `LEARNING_ENGINE_DESIGN.md §14 Open decisions`.

**Câu hỏi cho BA:** khi `stage.required=false`, các `activity.required=true` trong stage đó có còn gate completion không? Nếu "Reflection optional" nghĩa là cả stage + activities của nó đều tùy chọn, default rule cần sửa đếm chỉ required stages; nếu "required activity" nghĩa là bắt buộc toàn lesson, publish validation nên cảnh báo/từ chối required-in-optional-stage.

## 3. Full Maven verify

`mvnw verify` (Docker Testcontainers, postgres:16-alpine): **151 unit + 151 IT, 0 failures, BUILD SUCCESS** (+3 unit, +1 IT so với đợt review trước; trước: 148/150).

## 4. Files thay đổi

- `dau-viet-backend/.../resolver/LessonCompletionEvaluator.java` — no-clause config → DEFAULT_ALL_REQUIRED
- `dau-viet-backend/.../lesson/draft/DraftValidator.java` — PUBLISH reject `completion:{}` (`EMPTY_COMPLETION`)
- `LessonCompletionEvaluatorTest.java` +2, `DraftValidatorTest.java` +1, `AttemptCompletionIT.java` +1
- `docs/LEARNING_ENGINE_DESIGN.md` (§ completion evaluator + §14 open decision), `docs/API_SPEC.md` (completion contract)

## 5. Rủi ro còn lại / unresolved

- Finding 2 là rủi ro nghiệp vụ THẬT (lesson không completable) nhưng semantics hiện tại có chủ đích — **chờ BA chốt** trước khi thay đổi; nếu BA xác nhận "optional stage = optional activities", cần thêm publish-validation rule + sửa default rule + migration check cho snapshot đã publish.
- `EMPTY_COMPLETION` là error code mới ở PUBLISH — `AdminLessonValidateIT`/authoring frontend nên biết để hiển thị lỗi đúng (đã document trong API_SPEC).
- Snapshot legacy `completion:{}` đã publish trước siết vẫn tồn tại trong DB → runtime fallback xử lý an toàn; nếu muốn làm sạch dữ liệu, có thể chạy migration xóa field `completion` rỗng (không bắt buộc — runtime đã đúng).
