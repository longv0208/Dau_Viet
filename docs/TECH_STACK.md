# DẤU VIỆT — Tech Stack & Architecture

> **Architecture decision:** Flutter learner app + Spring Boot backend + PostgreSQL; Next.js Admin web.  
> **Style:** Modular Monolith cho MVP, REST/JSON giữa clients và backend.

## 1. Technology stack

| Layer | Lựa chọn | Ghi chú |
|---|---|---|
| Mobile | Flutter + Dart | Android/iOS cùng codebase |
| Mobile state | Riverpod | State async và dependency management |
| Routing | go_router | Navigation khai báo |
| Networking | Dio | Interceptors, auth và timeout |
| Backend | Java 21 + Spring Boot 3.x | REST API và nghiệp vụ; kiểm tra compatibility khi khởi tạo |
| Backend build | Maven | Build/test reproducible |
| Security | Spring Security + JWT | Access/refresh token; refresh rotation theo thiết kế xác thực |
| ORM | Spring Data JPA / Hibernate | Entity/repository |
| Database | PostgreSQL | Dữ liệu quan hệ; JSONB cho activity configuration |
| Migration | Flyway | Schema migration có version |
| API spec | springdoc-openapi | OpenAPI/Swagger |
| Validation | Jakarta Bean Validation | Request DTO; rule nghiệp vụ vẫn ở domain/service |
| Admin | Next.js + TypeScript | Lesson authoring/preview/publish |
| Media | S3-compatible storage (S3/R2) | Lưu file; DB lưu metadata và reference |
| Containers | Docker + Docker Compose | Local/dev environment |
| Test | JUnit 5, Spring Boot Test, Testcontainers | Unit/integration với PostgreSQL |
| Cache/queue | Redis (optional) | Chỉ thêm khi có use case rõ |

**Version policy:** Pin chính xác versions trong source lock/build files sau khi khởi tạo; các phiên bản trên là định hướng, không phải bảng tương thích đã được kiểm thử.

## 2. System boundaries

```text
Flutter App ─────┐
                 ├── HTTPS / REST / JSON ── Spring Boot API ── PostgreSQL
Next.js Admin ───┘                              │
                                               └── Object Storage
```

- Flutter render lesson/activities; **không chứa đáp án đúng, secret validation hay quyền cộng điểm**.
- Spring Boot là nguồn chân lý cho submission, progress, completion, reward và publish.
- Admin dùng cùng domain API nhưng tách endpoint và authorization.
- Không dùng microservices ở MVP; module boundaries vẫn phải rõ để có thể tách sau.

## 3. Backend modules

```text
src/main/java/com/dauviet/
├── DauVietApplication.java
├── common/                 # exceptions, API error, config, pagination
├── security/               # filter, token, permissions
├── auth/
├── user/
├── historicalevent/
├── lesson/                 # lesson, template, version, publish
├── evidence/               # source & evidence metadata
├── asset/                  # media metadata & storage
├── learningengine/         # handlers, rules, transitions
├── attempt/                # activity submissions, idempotency, resume
├── progress/
├── reward/                 # basic reward ledger
├── collection/             # phase/scope dependent
├── island/                 # later
├── inventory/              # later
└── shop/                   # later
```

Mỗi feature module tự quản lý `api/`, `application/`, `domain/`, `infrastructure/` khi đủ phức tạp. Tránh folder toàn cục chứa hàng trăm Controller/Service không có ranh giới nghiệp vụ.

## 4. Domain model nền tảng

```text
HistoricalEvent 1 -> N Lesson 1 -> N LessonVersion
LessonVersion -> ordered Stage[] -> ordered Activity[]
Activity -> Config + ValidationRule + FeedbackRule + EvidenceRef[]
User 1 -> N LearnerAttempt -> one immutable LessonVersion
LearnerAttempt -> ActivityAttempt[] / output state / progress
```

**Data policy:**

- Dùng UUID cho IDs; indexes/foreign keys/constraints cho quan hệ.
- Trường có cấu trúc cố định sử dụng columns/tables rõ ràng.
- `JSONB` phù hợp cho config chuyên biệt từng activity và published snapshot; phải validate bằng schema/version tương ứng.
- Published lesson version là snapshot **immutable**. Attempt pin vào `lessonVersionId`.
- Không xóa asset còn được published snapshot tham chiếu.
- Lưu timestamps UTC (`Instant`) và convert timezone ở UI.
- Secrets nằm trong environment/secrets manager; không commit.

## 5. API groups (draft contract)

| Group | Endpoint ví dụ |
|---|---|
| Auth | `POST /api/v1/auth/login`, `/refresh`, `/logout` |
| Events | `GET /api/v1/events`, `GET /api/v1/events/{id}` |
| Lessons | `GET /api/v1/lessons/{id}` |
| Attempts | `POST /api/v1/lessons/{id}/attempts` |
| Runtime | `GET /api/v1/attempts/{id}/current` |
| Submit | `POST /api/v1/attempts/{id}/activities/{activityId}/submissions` |
| Progress | `GET /api/v1/me/progress` |
| Admin | `/api/v1/admin/events`, `/lessons`, `/lessons/{id}/preview`, `/lessons/{id}/publish` |

API paths này là **đề xuất**, cần sinh/duy trì OpenAPI contract khi code.

### Submit flow

1. Authenticate và kiểm tra ownership của attempt.
2. Resolve published `LessonVersion` mà attempt đang sử dụng.
3. Validate request + activity input theo type/config trên server.
4. Ghi `ActivityAttempt` và output bằng transaction.
5. Kiểm tra completion rule và quyết định `next`/`fallback`.
6. Ghi progress, result/reward với **idempotency key hoặc unique business constraint**.
7. Trả state/feedback vừa đủ để Flutter render bước tiếp theo.

## 6. Activity handler architecture

```java
public interface ActivityHandler {
    ActivityType supportedType();
    ActivityResult evaluate(
        ActivityDefinition definition,
        ActivitySubmission submission,
        AttemptContext context
    );
}
```

`ActivityDefinition`, `ActivitySubmission`, `AttemptContext`, `ActivityResult` là domain contracts cần hiện thực. Spring DI inject một `List<ActivityHandler>` rồi registry theo `ActivityType`. Không dùng `if (eventId == ...)` trong logic.

## 7. Mobile structure

```text
lib/
├── app/                   # bootstrap, router, theme
├── core/                  # API client, errors, storage, widgets
├── features/
│   ├── auth/
│   ├── home/
│   ├── explore/
│   ├── lesson/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── activities/    # registry per activity type
│   ├── progress/
│   └── profile/
└── main.dart
```

Flutter renderer đọc activity `type`/public `config` từ API; câu trả lời được gửi về backend để validate. Hỗ trợ thao tác `tap/select` thay thế cho drag-drop khi cần.

## 8. Testing / release

- Unit test: rule handlers, validation, stage transitions, reward eligibility.
- Integration test: auth, version pinning, concurrency/idempotent submit, progress resume, publish validation.
- Contract test: OpenAPI DTO compatibility với Flutter/Admin.
- Widget test: từng activity renderer và loading/error/empty states.
- CI: format/lint → unit tests → integration tests → build Docker/Flutter artifact.
- Logging: structured logs + correlation/request ID; tuyệt đối không log access token/password.

## 9. Các quyết định cần PO/BA xác nhận

- Template MVP bắt buộc (đề xuất: Event Investigation, Decision Analysis).
- Activity types và cấu trúc validation riêng từng type.
- Scoring/pass-fail, giới hạn retry, behavior của Verification loop.
- Collection/Historical Map thuộc MVP hay sau MVP.
- Energy, shop, premium items có thực sự nằm trong release đầu hay chỉ là concept mockup.
- Auth policy, có guest mode hay không, có yêu cầu moderation/content review không.
