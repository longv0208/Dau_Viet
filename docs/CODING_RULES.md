# DẤU VIỆT — Coding Rules

> Áp dụng cho **Flutter/Dart**, **Spring Boot/Java**, **Next.js/TypeScript**, database và các tài liệu hợp đồng API.  
> Mục tiêu: code dễ đọc, kiểm thử được, an toàn, **tái sử dụng giữa các sự kiện lịch sử**.

## 1. Non-negotiable rules

1. **No event-specific logic:** Cấm `if (eventId == "bach-dang-938")` trong Learning Engine/renderer. Lesson khác nhau ở cấu hình, nội dung và rules.
2. **Stage ≠ Screen:** Stage là bước tư duy; Activity là hành vi; Widget/Screen là renderer. Một stage có thể gồm nhiều activity.
3. **Backend authoritative:** Client không tự xác nhận correct/complete/EXP/reward và không nhận private answer keys.
4. **Version safety:** Published LessonVersion là immutable; LearnerAttempt luôn gắn một version đã publish.
5. **Evidence traceability:** Claim, inference và conclusion phải có cách tham chiếu evidence/source phù hợp.
6. **Idempotency:** Retry request không được tạo duplicate submission/completion/reward; kiểm tra cả transaction và unique constraints.
7. **Security by default:** Phân quyền trên server, validate input/upload, không commit secrets; logs tránh dữ liệu nhạy cảm.
8. **Schema first:** Mỗi activity type cần public config schema, submission schema, server validation và renderer tương ứng.
9. **No silent rule changes:** Khi thay đổi business rule, cập nhật tài liệu, tests, schema/version và migration nếu cần.
10. **Scope discipline:** Island/shop/energy không can thiệp sâu vào Learning Engine. Tích hợp qua completion/reward boundaries.

## 2. Naming & code style

| Area | Rule | Example |
|---|---|---|
| Java classes | PascalCase | `LessonPublishService` |
| Java methods/fields | camelCase | `submitActivity()` |
| Java constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Dart types | PascalCase | `EvidenceSelectWidget` |
| Dart members | lowerCamelCase | `lessonVersionId` |
| DB tables/columns | snake_case | `activity_attempts`, `created_at` |
| REST paths | lowercase nouns, versioned | `/api/v1/attempts/{id}` |
| JSON fields | camelCase | `lessonVersionId` |
| Activity type enums | UPPER_SNAKE_CASE | `DRAG_ORDER` |

- Code, API field names, class names dùng tiếng Anh; learner-facing content có thể là tiếng Việt, UTF-8.
- Không dùng magic strings/numbers cho states, types, reward policies.
- Mỗi function nên có một nhiệm vụ rõ ràng; đặt tên theo ý nghĩa nghiệp vụ.
- Comment giải thích **why** và invariant, không lặp lại **what** rõ ràng từ code.

## 3. Spring Boot / Java rules

- Controller: nhận request, validate DTO, gọi application service, trả response. Không chứa business rules hoặc truy vấn phức tạp.
- Service/Domain: xử lý lifecycle, transaction, authorization, rule evaluation.
- Repository: truy cập dữ liệu; tránh expose Entity JPA trực tiếp qua API.
- DTO request và DTO response riêng; không bind entity trực tiếp từ request JSON.
- Constructor injection; tránh field injection và circular dependency.
- `@Transactional` ở application service có ranh giới write rõ ràng; read-only khi phù hợp.
- Bean Validation cho format và constraints; business validation ở service/handler.
- Dùng exception/error contract nhất quán (`code`, `message`, `details`, `traceId`) và HTTP status phù hợp.
- Tránh query N+1; quan sát SQL và chỉ optimize có đo lường.
- Không log JWT, password, private answer keys hoặc PII không cần thiết.

### Activity handler contract

- Mỗi `ActivityType` có đúng một handler (fail startup hoặc validation nếu trùng/missing).
- Handler nhận validated definition + submission + attempt context; trả structured result, không tự cộng reward.
- Rule chuyển stage nằm ở transition/completion service, không nằm rải rác trong controllers.
- Output có kiểu rõ: selectedEvidence, inference, hypothesis, reconstruction, verification, conclusion.
- Unsupported activity type phải bị block lúc publish, không đợi learner mở mới lỗi.

## 4. Database rules

- Mọi thay đổi schema thông qua **Flyway migration**, không sửa schema thủ công giữa môi trường.
- Thêm PK, FK, unique constraints và index theo query path; đặt tên constraint có nghĩa.
- Published snapshot bất biến; thay đổi nội dung tạo version mới.
- Attempt/progress gắn với `lesson_version_id` và `activity_id` đúng version.
- Có cơ chế idempotency/unique key ở submit/reward ledger.
- `JSONB` là config/data có schema, không phải nơi đổ mọi quan hệ.
- Không xóa cứng evidence/assets khi còn version đã publish tham chiếu; dùng policy archive/retention.
- UTC timestamps; phân biệt created/updated/published/completed.

## 5. Flutter rules

- Phân chia feature rõ (`data/domain/presentation` khi cần); business logic không đặt trong Widget build.
- Riverpod quản lý async state và dependency; widget chỉ render và phát sinh user intent.
- Dùng models typed, JSON parsing có lỗi rõ ràng; không truyền `dynamic` khắp ứng dụng.
- API client tập trung, timeout/retry có kiểm soát; không retry mù lệnh có side effects.
- `ActivityRenderer` dispatch theo enum/type và public config; không theo `eventId`/lesson title.
- Đủ `loading`, `empty`, `error`, retry và submit pending/double-tap guards.
- Drag/drop phải có tương tác tap/select thay thế trên thiết bị nhỏ hoặc accessibility mode.
- UI không hiển thị/giữ correct answer nếu API không cần; server kiểm tra đáp án.
- Không đặt asset lớn vào widget tree hoặc tải toàn bộ ảnh/video trước khi cần.

## 6. API & authentication

- REST `/api/v1`; mô tả endpoints, DTO và response codes trong OpenAPI.
- Kiểm tra ownership/authorization **cho từng attempt**, không chỉ kiểm tra token hợp lệ.
- Admin endpoints yêu cầu vai trò riêng; publish cần kiểm tra completeness và references.
- Access token ngắn hạn, refresh token được bảo vệ và có khả năng thu hồi/rotation theo implementation.
- Không tin vào `userId`, `score`, `isCorrect`, `completed` hoặc `reward` do client gửi.
- Submit API phải idempotent (header key hoặc transaction/unique key đủ mạnh).
- Validation errors mang `code` ổn định cho Flutter hiển thị và xử lý.

## 7. Lesson authoring & publish rules

Không publish nếu:

- Thiếu central historical question hoặc objective.
- Stage required không có activity enabled.
- Activity required thiếu instruction/config/completion rule.
- Evidence reference bị gãy hoặc asset bắt buộc không tồn tại.
- Có Hypothesis nhưng không có feedback/verification path hợp lệ.
- Không có cách tạo Conclusion hoặc template-specific equivalent.
- Activity type không có Flutter renderer/schema phù hợp.

Publish phải tạo version snapshot; attempt đã tạo tiếp tục với version cũ. Preview dùng cùng schema và mapping gần với learner app.

## 8. Testing requirements

**Mọi tính năng mới phải có tests phù hợp.** Tối thiểu:

- Handler: correct/incorrect/partial/invalid inputs; retry limits.
- Stage engine: normal transition, revise loop, required/optional activity.
- Attempt: start, resume, save, complete, attempt-version pinning.
- Concurrency: submit hai lần cùng key, complete hai lần, reward một lần.
- Publish: missing fields, broken evidence refs, invalid config, unsupported renderer.
- API: unauthorized/forbidden/not-found/validation/error response.
- Flutter: activity render, pending/empty/error state, tap fallback.

Có bug regression thì **viết test tái hiện bug trước hoặc cùng lúc sửa**.

## 9. Git / PR convention

- Branches: `feat/<scope>`, `fix/<scope>`, `chore/<scope>`, `docs/<scope>`.
- Commit examples: `feat(learning): add drag order handler`, `fix(attempt): prevent duplicate completion`.
- Một PR tập trung một mục tiêu; mô tả nghiệp vụ, thay đổi schema/API, tests, screenshots nếu UI.
- Không merge nếu build/test đỏ hoặc có secret trong diff.
- Migration đã deploy không được sửa nội dung; tạo migration kế tiếp.

## 10. Definition of Done

Một task được coi là Done khi:

- Thỏa acceptance criteria và không hard-code sự kiện.
- Có validation phía server, authorization và error states phù hợp.
- Có tests tự động cho happy path và edge case liên quan.
- OpenAPI/schema/migration được cập nhật nếu hợp đồng hoặc DB thay đổi.
- User attempt không bị hỏng nếu lesson version đổi.
- Không cộng trùng reward khi retry/submit lặp.
- Code đã format/lint, reviewed và có tài liệu ngắn nếu thêm cơ chế mới.

## 11. Quy trình khi code bằng AI assistant

1. Trước khi code, đọc `PROJECT_OVERVIEW.md`, `TECH_STACK.md`, `CODING_RULES.md` và các requirement liên quan.
2. Nêu module bị tác động, business invariants, dữ liệu, API, edge cases và kế hoạch tests.
3. Chỉ triển khai phạm vi được yêu cầu; **không tự mở rộng sang shop/island/energy** nếu không liên quan.
4. Không invent requirement. Nếu chưa được chốt, ghi `ASSUMPTION` hoặc `OPEN QUESTION` và hỏi trước khi thay đổi thiết kế lớn.
5. Giữ compatibility với published lesson versions và contract Flutter ↔ API.
6. Khi hoàn tất, báo file đã thay đổi, migrations, cách chạy, kết quả tests và các điểm chưa giải quyết.

---

**Baseline:** Bộ coding rules này được đề xuất để team thống nhất triển khai, có thể sửa bằng ADR/PR khi kiến trúc thay đổi.
