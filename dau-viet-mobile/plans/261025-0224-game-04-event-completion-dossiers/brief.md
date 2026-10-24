# TASK GAME-04 — EVENT COMPLETION & HISTORICAL DOSSIER COLLECTION

## 1. Bối cảnh

Repository: https://github.com/longv0208/Dau_Viet.git

Dự án Dấu Việt:
- Flutter / Riverpod — Mobile
- Spring Boot — Backend
- PostgreSQL / Flyway — Database
- Next.js — Admin

GAME-01 đã chuẩn hóa nghiệp vụ.

GAME-02 đã triển khai Backend Thể lực.

GAME-03 đã triển khai giao diện Thể lực.

**GAME-04 triển khai hệ thống hoàn thành sự kiện lịch sử và mở khóa bộ sưu tập nhân vật, địa điểm, hiện vật có quan hệ chính xác với sự kiện đó.**

Không chỉ viết plan. Hãy trực tiếp triển khai database, backend, API, phần Flutter cần thiết, tests và cập nhật tài liệu.

Không chuyển sang GAME-05 khi chưa hoàn thành.

---

## 2. Tài liệu bắt buộc

Đọc kỹ:

- `docs/GAMIFICATION_BUSINESS_RULES.md`
- `docs/GAMIFICATION_TECHNICAL_CONTRACT.md`
- `docs/GAMIFICATION_GAP_REPORT.md`
- `docs/DATABASE_DESIGN.md`
- `docs/API_SPEC.md`
- `docs/LEARNING_ENGINE_DESIGN.md`
- `docs/CODING_RULES.md`
- `design/MOBILE_SCREEN_DESIGN.md`
- `design/UI_COMPONENT_SPEC.md`

Đặc biệt phải tuân thủ:

**Business Rules:**
- Mục 7 — Lesson, Mastery, Event Completion.
- Mục 8 — Historical Collection, Map và quyền xem tri thức.
- Mục 9 — Ranh giới vật phẩm và huy hiệu.
- EVT-01 đến EVT-07.

**Technical Contract:**
- Mục 2.4 — Event Milestone Data Model.
- Mục 3 — State Transitions.
- Mục 5 — Transaction & Idempotency.
- Mục 8 — Event Completion & Policy Versioning.
- Mục 9 — Historical Dossier.
- Mục 11 — API.

Nếu tài liệu xung đột với source hiện tại, phải xác minh và giải thích phương án tương thích, không tự sửa business baseline.

---

## 3. Mục tiêu nghiệp vụ

Xây dựng quan hệ chuẩn:

Historical Event
→ Required Lessons
→ Lesson Completed / Lesson Mastered
→ Event Completed / Event Mastered
→ Unlock Historical Dossiers.

Trong khi học, user vẫn có thể thu thập Evidence/Dấu như hiện tại.

Khi hoàn thành toàn bộ required lessons của sự kiện, người học được mở khóa các hồ sơ lịch sử liên quan đã được cấu hình.

Ví dụ sự kiện Bạch Đằng năm 938:

- Nhân vật: Ngô Quyền.
- Địa điểm: Sông Bạch Đằng.
- Hiện vật/khảo cổ: Hồ sơ về cọc gỗ Bạch Đằng, nếu đã có nội dung nguồn được kiểm duyệt.

Ví dụ sự kiện Hai Bà Trưng năm 40:

- Nhân vật: Trưng Trắc, Trưng Nhị.
- Địa điểm: Mê Linh, Luy Lâu, nếu được cấu hình.

Ví dụ sự kiện Lý Thái Tổ dời đô năm 1010:

- Nhân vật: Lý Thái Tổ.
- Địa điểm: Hoa Lư, Đại La/Thăng Long, nếu được cấu hình.

Đây chỉ là ví dụ quan hệ nghiệp vụ. Nội dung thực tế phải dựa vào dữ liệu lịch sử, nguồn và sự liên kết chính thức trong database.

**Không hard-code ba sự kiện này vào service.**

Mọi sự kiện mới phải sử dụng cùng domain và cùng quy tắc.

---

## 4. Audit code trước khi sửa

Kiểm tra:

### Backend

- `HistoricalEvent`
- `HistoricalEventRepository`
- `Lesson`
- `LessonRepository`
- `LessonVersion`
- `LessonVersionRepository`
- `LearnerAttemptService`
- `LearnerAttempt`
- `LearnerAttemptRepository`
- `LessonResult`
- `LessonResultRepository`
- `SnapshotModel`
- `GradedActivityClassifier`
- `RewardGrantService`
- `ItemUnlockService`
- `CollectionService`
- `EvidenceCollectionRecorder`
- `UserEvidence`
- `MapLocationUnlockQuery`
- `MapLocationService`

### Flutter

- `collection_screen.dart`
- `collection_detail_screen.dart`
- `collection_providers.dart`
- `collection_dto.dart`
- Collection repository/API client
- `campaign_detail_screen.dart`
- `lesson_player_screen.dart`
- `lesson_result_screen.dart`
- Các route hiện có

Kiểm tra migration V20, V21 và version mới nhất.

Đặc biệt lưu ý:

- `lesson_results.score` đang biểu diễn tỷ lệ required activities đã hoàn thành.
- `result_json.knowledgeScore` mới phản ánh kiến thức.
- `completed=true` không đồng nghĩa trả lời đúng vì hoạt động có thể completed do exhausted.
- Một lesson có thể được republish nhiều lần.
- Một event có thể có nhiều lesson.
- `user_evidence` đã có event ID và uniqueness.
- Map location hiện được unlock theo lesson liên kết.

Không được phá những quy tắc đã có.

---

## 5. DATABASE — EVENT PROGRESSION

Tạo migration Flyway tiếp theo chưa sử dụng.

Không sửa migration cũ.

Đồng bộ migration theo cấu trúc backend/database mirror hiện có.

### 5.1. event_completion_policies

Thiết kế bảng policy có version:

- id UUID primary key.
- event_id FK historical_events.
- policy_version integer.
- status: DRAFT / PUBLISHED / ARCHIVED.
- required_lesson_ids JSONB.
- optional_lesson_ids JSONB.
- mastery_threshold nullable, mặc định đề xuất 70.
- published_at.
- created_at.
- updated_at.

Constraints:

- UNIQUE(event_id, policy_version).
- Chỉ tối đa một PUBLISHED policy trên một event.
- required_lesson_ids không được rỗng khi PUBLISHED.
- Mỗi required lesson phải thuộc event đó.
- Required lessons phải hợp lệ và đã publish tại thời điểm policy được publish.
- Không có ID trùng trong required/optional.
- Required và optional không giao nhau.
- mastery_threshold nằm trong khoảng 0–100 hoặc null.
- Không cho thay đổi cấu hình của phiên bản đã publish.

Quan trọng:

**Không được tự động coi tất cả bài học hiện tại hoặc bài học mới sau này là required.**

Published policy phải giữ snapshot danh sách required lesson IDs.

Admin thêm bài mới không được làm thay đổi nội dung policy cũ.

### 5.2. user_event_progress

Lưu milestone đã đạt:

- user_id FK users.
- event_id FK historical_events.
- milestone: EVENT_COMPLETED / EVENT_MASTERED.
- policy_version.
- required_snapshot JSONB.
- granted_at.

Unique:

(user_id, event_id, milestone).

Yêu cầu:

- Mỗi milestone chỉ cấp một lần.
- Ghi lại policy version và required lesson snapshot khi cấp.
- Không tự xóa/thu hồi khi Admin republish.
- Không ghi COMPLETED nếu chưa có published policy hợp lệ.
- Không ghi MASTERED trước COMPLETED.
- Không dùng trực tiếp completedCount toàn tài khoản để kết luận event đã hoàn thành.

---

## 6. EVENT COMPLETION ENGINE

Tạo module/event progress service phù hợp với kiến trúc modular monolith hiện có.

Tên class được quyền điều chỉnh, nhưng trách nhiệm nên tương đương:

- EventCompletionPolicyService
- EventProgressEvaluator
- EventMilestoneRecorder
- EventProgressQueryService

Tránh một class quá lớn làm hết tất cả nghiệp vụ.

### 6.1. LESSON_COMPLETED

Một lesson được hoàn thành khi learner có ít nhất một attempt COMPLETED hợp lệ cho lesson logic đó.

Xác định bằng join:

learner_attempts
→ lesson_versions
→ lessons

Dùng lesson ID logic, không chỉ lessonVersionId.

Không đếm số activity đã trả lời như số bài đã hoàn thành.

Không đếm các lần học lại cùng lesson thành nhiều bài.

### 6.2. EVENT_COMPLETED

Event Completed khi:

1. Có policy PUBLISHED hợp lệ.
2. Policy có ít nhất một required lesson.
3. Tất cả required lessons thuộc policy đều đã có completed attempt hợp lệ của user.
4. User chưa được cấp EVENT_COMPLETED trước đó.

Khi thỏa mãn:

- Insert milestone EVENT_COMPLETED.
- Lưu policyVersion.
- Lưu requiredSnapshot.
- Kích hoạt mở khóa dossier liên quan.
- Không cộng EXP/Điểm Sử Ký sự kiện nếu business rules chưa quy định khoản thưởng này.
- Không cấp item/huy hiệu tự động trong GAME-04.

Ví dụ:

Event có 3 required lessons:

Lesson A: Completed.
Lesson B: Completed.
Lesson C: In Progress.

Event vẫn chưa Completed.

Chỉ khi C Completed mới cấp EVENT_COMPLETED.

Nếu event có thêm optional lesson D thì D không được ngăn completion.

### 6.3. EVENT_MASTERED

Mastered khác Completed.

Mặc định yêu cầu:

- Đã đạt EVENT_COMPLETED.
- Có ít nhất một required lesson có hoạt động chấm kiến thức thực sự.
- Mọi required lesson có chấm điểm phải có một completed attempt hợp lệ đạt knowledgeScore ≥ mastery_threshold.
- Required lesson không có hoạt động chấm điểm phải Completed, nhưng được đánh dấu NOT_ASSESSED, không tự tính thành mastered.

Phải xác định graded activity từ pinned lesson snapshot, tái sử dụng classifier/contract hiện có khi phù hợp.

Không dùng `lesson_results.score` làm knowledge score.

Không lấy `knowledgeScore=0` của lesson không có bài chấm làm bằng chứng user không hiểu bài.

Không coi `COMPLETED do exhausted` là đạt mastery.

Nếu result cũ thiếu dữ liệu đủ tin cậy để xét mastery, phải báo NOT_ASSESSED/UNKNOWN theo contract, không tự suy thành mastered.

### 6.4. Best valid result

Nếu user làm lại một lesson và đạt kết quả tốt hơn:

- Không cộng lại EXP/Điểm Sử Ký first completion.
- Không cấp lại EVENT_COMPLETED.
- Có thể nâng EVENT_MASTERED từ chưa đạt lên đạt.
- Không giảm mastery milestone đã nhận.
- Không thay đổi lesson_results cũ.

Cần đối chiếu với cách Learning Engine tạo attempt mới sau khi lesson đã completed.

Không giả định mọi attempt completed đều là attempt hiện tại.

### 6.5. Event không có policy

Nếu event chưa có policy PUBLISHED:

- Trả trạng thái NOT_CONFIGURED.
- Không cấp EVENT_COMPLETED.
- Không cấp dossier.
- Không fallback "xong một lesson là xong event".
- Không hiển thị hoàn thành giả trên Flutter.

---

## 7. HOÀN THÀNH ATOMIC CÙNG LEARNING ENGINE

Tích hợp vào `LearnerAttemptService.doComplete()` ở vị trí phù hợp.

Luồng mong muốn:

1. Validate attempt.
2. Kiểm tra lesson completion.
3. Mark attempt Completed.
4. Ghi lesson_result.
5. Grant first-completion rewards như hiện tại.
6. Giữ nguyên item unlock V1 đang hoạt động.
7. Evaluate Event Completed/Mastered.
8. Nếu có milestone mới, ghi user_event_progress.
9. Mở các dossier đủ điều kiện.
10. Commit cùng transaction.

**Không được để lesson marked completed nhưng event milestone/dossier đáng ra cần ghi lại mất do lỗi ở giữa transaction.**

Có thể thiết kế transaction/service tương đương nếu bảo toàn atomicity.

Yêu cầu:

- Retry cùng Idempotency-Key không cấp hai lần.
- Replay complete không tạo lịch sử milestone mới sai.
- Hai attempt khác nhau của cùng user hoàn tất gần đồng thời không bỏ sót event completion.
- Hai request đồng thời không tạo duplicate.
- Không làm hỏng lock order hiện có của Learning/Rewards/Energy.
- User A không thể hoàn tất sự kiện của user B.
- Không có một phần transaction commit trong khi các phần khác rollback.

Đặc biệt kiểm thử tình huống hai required lessons cuối hoàn thành đồng thời.

Nếu dùng unique constraint + locking + re-evaluation, phải chứng minh không bị trường hợp cả hai transaction đều thấy bài còn lại chưa hoàn thành rồi cùng bỏ qua milestone.

Không chỉ thêm `ON CONFLICT DO NOTHING` rồi cho rằng đã giải quyết được mọi race condition.

---

## 8. DATABASE — HISTORICAL DOSSIERS

**Dossier là hồ sơ tri thức lịch sử, KHÔNG phải item trong inventory.**

### 8.1. historical_dossiers

Tạo bảng catalog hồ sơ lịch sử, tối thiểu:

- id UUID.
- canonical_code UNIQUE.
- dossier_type: PERSON / LOCATION / ARTIFACT / CONTEXT.
- title.
- short_description / preview_description.
- detail_description.
- source_json JSONB.
- asset_id nullable.
- status: DRAFT / PUBLISHED / ARCHIVED.
- created_at / updated_at.

Cần kiểm tra schema/assets có sẵn rồi thiết kế FK tương thích.

Nội dung yêu cầu:

- Có định danh canonical.
- Có loại rõ ràng.
- Có nguồn tham khảo.
- Phân biệt dữ kiện lịch sử với mô hình tái dựng.
- Không lưu thông tin lịch sử quan trọng chỉ trong Flutter.
- Không tạo fake asset hoặc URL ảnh không tồn tại.

Bổ sung version/snapshot hoặc chiến lược lưu thông tin tại thời điểm unlock để quyền đã mở có thể truy vết khi dossier được sửa/archive.

### 8.2. event_dossiers

Bảng liên kết nhiều-nhiều:

- event_id.
- dossier_id.
- unlock_on = EVENT_COMPLETED.
- created_at (nếu phù hợp).

Unique(event_id, dossier_id).

Yêu cầu:

- Một event có nhiều dossiers.
- Một dossier được liên kết nhiều events.
- Không tạo hai dossier Ngô Quyền chỉ vì nhân vật xuất hiện ở hai sự kiện.
- Không gán dossier bằng so khớp title/tag.
- Chỉ dossier PUBLISHED hợp lệ mới được unlock.
- Một dossier liên kết ở nhiều event không được nhân đôi số lượng owned.

### 8.3. user_dossier_unlocks

Lưu:

- user_id.
- dossier_id.
- event_id — sự kiện dẫn đến unlock đầu tiên.
- granted_at.
- snapshot/version provenance nếu cần.

Unique(user_id, dossier_id).

Yêu cầu:

- Chỉ cấp khi event milestone phù hợp.
- Không cấp khi learner mới hoàn thành một lesson chưa đủ.
- Không thu hồi khi event policy thay đổi.
- Không cấp hai lần khi retry.
- Nếu dossier đã mở từ event A, event B không tạo thêm quyền sở hữu trùng.

Nếu muốn lưu lịch sử đầy đủ nhiều nguồn mở khóa, tách provenance event thành quan hệ audit phụ thay vì vi phạm unique của quyền sở hữu.

---

## 9. SEED VÀ CẤU HÌNH TRƯỚC GAME-06

GAME-06 mới làm CMS Admin.

Nhưng GAME-04 cần một luồng end-to-end kiểm chứng được bằng dữ liệu thật.

Kiểm tra `V20__seed_events_lessons.sql` và các event/lesson đã seed.

Trong V20 hiện có ví dụ:
- Bạch Đằng 938.
- Hai Bà Trưng năm 40.
- Lý Thái Tổ dời đô năm 1010.

Các lesson mẫu liên kết event trong database.

Yêu cầu:

1. Chỉ seed completion policy cho event mẫu khi xác định chính xác published lesson liên quan.
2. Với dữ liệu mẫu hiện có chỉ một published required lesson/event, có thể cấu hình policy một lesson để demo, nhưng KHÔNG biến thành quy tắc mặc định cho mọi event.
3. Việc thêm lesson mới về sau phải cần policy version mới; không tự thêm vào required list cũ.
4. Seed một số hồ sơ canonical để kiểm chứng mở khóa nhân vật/địa điểm/hiện vật.
5. Mỗi dossier cần nguồn và nội dung đủ chất lượng, không bịa trích dẫn.
6. Tái sử dụng thông tin lịch sử đã được phê duyệt trong repo nếu phù hợp.
7. Không seed vật phẩm sở hữu cho user.
8. Không tự cấp milestone cho mọi tài khoản.
9. Không dựa vào UUID cố định nếu migration V20 đã có logic resolve row theo slug.
10. Migration phải idempotent và an toàn với DB đã có dữ liệu.

Ví dụ dữ liệu tối thiểu cho Bạch Đằng:

- PERSON: Ngô Quyền.
- LOCATION: Sông Bạch Đằng.
- ARTIFACT: Hồ sơ cọc gỗ Bạch Đằng, chỉ khi có nguồn đủ tin cậy.

Tương tự với hai event mẫu còn lại.

Nếu không có nguồn hợp lệ cho một dossier, để DRAFT/không seed thay vì tạo nội dung giả.

Không hard-code nội dung này trong Java service.

### Vấn đề dữ liệu cũ

GAME-04 phải xem xét các lesson đã hoàn thành trước khi migration/policy được triển khai.

Không được bắt người học hoàn thành lại chỉ vì hệ thống event progression mới được bổ sung.

Thiết kế một cơ chế đối soát idempotent cho completed attempts cũ, có thể là:
- Backfill có kiểm soát qua migration/service; hoặc
- Reconciliation transaction riêng có trigger rõ ràng.

Phải tránh việc endpoint đọc báo mãi IN_PROGRESS dù người học đã đủ required lesson từ trước.

Không tự gán mastery khi dữ liệu cũ thiếu bằng chứng đáng tin cậy.

GAME-08 vẫn chịu trách nhiệm backfill/regression toàn cục, nhưng GAME-04 phải hoạt động đúng với dữ liệu hợp lệ đã tồn tại.

---

## 10. API — EVENT PROGRESS

Triển khai:

`GET /api/v1/me/events/{eventId}/progress`

Response tham khảo:

```json
{
  "eventId": "uuid",
  "status": "IN_PROGRESS",
  "policyVersion": 1,
  "requiredLessonsTotal": 3,
  "requiredLessonsCompleted": 2,
  "eventCompleted": false,
  "eventMastered": false,
  "masteryThreshold": 70,
  "requiredLessons": [
    {
      "lessonId": "uuid",
      "title": "Bài học A",
      "required": true,
      "completed": true,
      "masteryStatus": "MASTERED",
      "bestKnowledgeScore": 85
    }
  ],
  "unlockedDossiersCount": 0
}
```

Ví dụ chỉ mô tả shape. Không hard-code dữ liệu.

Yêu cầu:

- Trả các required lessons và trạng thái thực.
- Có phân biệt NOT_CONFIGURED, IN_PROGRESS, EVENT_COMPLETED và EVENT_MASTERED.
- PolicyVersion null khi chưa cấu hình.
- Có giá trị tiến độ đủ cho Flutter.
- Dữ liệu lọc theo JWT.
- Không dùng dữ liệu tiến độ user khác.
- Không trả score giả cho NOT_ASSESSED.
- Cần phân biệt event đã được ghi nhận hoàn thành ở policy cũ với tiến độ hiển thị theo policy mới; không làm biến mất milestone đã đạt.
- Không phá API event hiện có.

Nếu cần API danh sách event progress dạng batch để tránh N+1 khi render nhiều sự kiện, có thể bổ sung read endpoint phù hợp, nhưng không tạo nhiều nguồn trạng thái trùng lặp.

---

## 11. API — HISTORICAL DOSSIERS

Triển khai các endpoint:

`GET /api/v1/me/collection/dossiers`

`GET /api/v1/me/collection/dossiers/{dossierId}`

Danh sách hỗ trợ:
- Filter dossier type.
- Filter eventId.
- Filter unlocked/locked khi phù hợp.
- Pagination.
- Sort ổn định.
- Canonical ID.
- Event liên quan.
- Preview metadata.
- Trạng thái quyền mở khóa.

Đảm bảo không đụng route:

`GET /api/v1/me/collection/{evidenceId}`

### 11.1. Dossier đã mở

Response chứa:
- ID.
- Canonical code.
- Type.
- Title.
- Description.
- Asset nếu có.
- Source/citation.
- Event mở khóa.
- Granted at.
- Unlocked=true.

### 11.2. Dossier chưa mở

Nếu PUBLISHED:
- Có thể hiển thị title/preview được phép.
- Unlocked=false.
- Không đánh dấu Collected.
- Không trả nội dung chi tiết bị khóa.

### 11.3. Dossier chưa publish

- Không xuất hiện trong danh sách public.
- Không để lộ nội dung DRAFT.
- Không cho user truy cập detail bằng ID đoán được.

### 11.4. Archived dossier

- Không tự thu hồi quyền đã cấp.
- Phải có chiến lược snapshot/version để quyền lợi hợp lệ còn đọc được khi nội dung bị archive, trừ trường hợp thu hồi nội dung vì pháp lý/bản quyền.
- Không mở mới dossier bị archive.

Không trả danh sách user sở hữu của người khác.

---

## 12. QUY TẮC EVIDENCE COLLECTION

**Giữ nguyên hệ thống Dấu hiện có.**

Evidence được collect từ accepted submission trong lúc học.

Dossier được unlock khi hoàn thành event.

Hai loại không được nhập thành một bảng sở hữu chung.

Yêu cầu:

- Evidence vẫn nằm trong user_evidence.
- Dossier nằm trong user_dossier_unlocks.
- Không sửa ý nghĩa evidence_type.
- Không đổi evidence thành item_catalog.
- Không ép mọi evidence phải thuộc loại PERSON/LOCATION/ARTIFACT.
- Không làm hỏng collection API và filter cũ.
- Không ghi thêm Dấu khi sự kiện hoàn thành trừ khi người học thực sự collect evidence qua activity.
- Không dùng evidence count global để xác định Event Completed.

---

## 13. MAP — GIỮ ĐÚNG QUYỀN MỞ KHÓA

Hiện bản đồ có `MapLocationUnlockQuery` mở khóa theo lesson.

Trong GAME-04:

- Không thay đổi đột ngột rule unlock map location sang EVENT_COMPLETED.
- Không gộp dossier LOCATION với map location.
- Nếu dossier LOCATION mô tả sông Bạch Đằng, đó là một hồ sơ tri thức.
- Nếu map có marker sông Bạch Đằng, đó là một vị trí trong hành trình bản đồ.
- Hai đối tượng có thể liên kết bằng ID khi thiết kế hỗ trợ, nhưng quyền mở khóa khác nhau.
- Không tự tạo marker địa lý từ tên dossier.
- Không tự suy tọa độ hoặc sửa lịch sử/map seed.

Tài liệu phải giải thích rõ sự khác biệt này.

---

## 14. FLUTTER — BỘ SƯU TẬP

Cập nhật màn Bộ sưu tập hiện tại.

Không viết lại từ đầu.

### 14.1. Tổ chức nội dung

Thiết kế nhóm/tab cấp cao:

- Dấu / Bằng chứng.
- Nhân vật.
- Địa điểm.
- Hiện vật.

Có thể bổ sung Bối cảnh sau nếu dữ liệu có `CONTEXT`.

Yêu cầu:
- Tab Dấu giữ nguyên luồng API và chức năng lọc/pagination đang hoạt động.
- Các tab mới dùng dossier API.
- Không hiển thị inventory item như một dossier.
- Người học dễ hiểu sự khác nhau giữa bằng chứng đã tìm được và hồ sơ mở khóa sau sự kiện.

### 14.2. Dossier cards

Mỗi card hiển thị:
- Tên hồ sơ.
- Loại.
- Sự kiện liên quan.
- Ảnh/illustration nếu có.
- Trạng thái đã mở/chưa mở.
- Yêu cầu mở khóa ngắn gọn.

Nếu chưa mở:
- Hiển thị khóa hoặc preview.
- Không hiển thị giả rằng đã nhận.
- Cho biết cần hoàn thành sự kiện nào khi có thông tin policy.
- Không làm lộ toàn bộ dossier detail.

Nếu đã mở:
- Có thể mở trang chi tiết.
- Hiển thị mô tả lịch sử.
- Nguồn/citation.
- Ảnh nếu có.
- Ngày mở khóa.
- Sự kiện dẫn đến unlock.

Giữ phong cách UI Dấu Việt: giấy cổ, màu Đông Sơn, phù hợp mobile.

### 14.3. Empty state

Phải phân biệt:
- Chưa có dossier nào trong catalog.
- Event chưa cấu hình bộ sưu tập.
- Chưa hoàn thành sự kiện.
- Không có item khớp filter.
- API lỗi.
- Loading.

Không hiển thị danh sách mock như thể dữ liệu thật.

### 14.4. Navigation

Giữ route collection hiện tại.

Bổ sung route detail dossier có định danh rõ ràng, chẳng hạn:

`/collection/dossiers/:dossierId`

Không phá route evidence detail:

`/collection/:evidenceId`

Điều hướng quay lại phải giữ tab/filter khi phù hợp.

---

## 15. FLUTTER — TIẾN ĐỘ SỰ KIỆN

Trong màn chi tiết sự kiện hoặc màn phù hợp hiện có:

Hiển thị:
- Số bài bắt buộc đã hoàn thành/tổng.
- Thanh tiến độ.
- Trạng thái chưa hoàn thành / đã hoàn thành.
- Trạng thái thông thạo nếu đủ dữ liệu.
- Số hồ sơ mở khóa liên quan.
- Nút xem bộ sưu tập.

Ví dụ:

`Bạch Đằng 938 — Hoàn thành 2/3 bài bắt buộc`

Sau khi hoàn thành toàn bộ:

`Đã hoàn thành sự kiện`

`Đã mở khóa 3 hồ sơ lịch sử`

Số lượng phải lấy từ backend.

Không dùng số hard-code cho ba sự kiện mẫu.

Không hiển thị EVENT_COMPLETED khi chỉ có một bài completed mà policy yêu cầu nhiều bài.

Nếu NOT_CONFIGURED:
- Có thể hiển thị tiến độ lesson cá nhân nếu API khác cung cấp.
- Không giả định event hoàn thành.
- Không đưa ra lỗi khó hiểu cho người học.

---

## 16. LUỒNG LESSON COMPLETION → COLLECTION

Sau khi learner hoàn thành bài:

1. Backend ghi completion/reward như hiện tại.
2. Backend đánh giá Event Completed/Mastered.
3. Backend ghi dossier unlock nếu có.
4. Flutter lấy tiến độ event mới.
5. Flutter làm mới collection dossier provider.
6. Nếu có hồ sơ mới mở, có thông báo nhẹ nhàng dẫn đến Bộ sưu tập.

Lưu ý:

- Không POST thêm endpoint để "nhận" dossier.
- Không dùng client tự cấp unlock.
- Không tự cộng Điểm Sử Ký hoặc EXP theo số dossier.
- Không hiện "Vừa mở khóa" mỗi lần người học vào lại kết quả cũ.

Nếu cần trả danh sách `newlyUnlockedDossiers`, hãy chọn read/response contract có audit thực tế, additive và không nhầm với toàn bộ hồ sơ đã sở hữu.

Không triển khai màn huy hiệu/vật phẩm GAME-05 trong task này.

---

## 17. TRANSACTION, IDEMPOTENCY & CONCURRENCY

Bắt buộc kiểm tra:

### Scenario A — Hai required lessons

- A completed.
- B chưa completed.
- Event chưa completed.
- Hoàn thành B.
- Event completed đúng một lần.
- Dossier liên quan được mở.

### Scenario B — Replay Complete

- POST complete cùng idempotency key.
- Không ghi milestone trùng.
- Không ghi dossier unlock trùng.
- Không nhân EXP/points.

### Scenario C — Hai required lessons hoàn thành đồng thời

- A và B completed gần cùng thời điểm.
- Không mất EVENT_COMPLETED do race.
- Không có duplicate milestone.
- Không deadlock kéo dài.

### Scenario D — Republish Lesson

- User hoàn thành lesson version 1.
- Admin publish version 2.
- Completed cũ vẫn tính.
- Không reset Event Completed.

### Scenario E — Policy version mới

- Policy v1 required [A,B].
- User đạt EVENT_COMPLETED.
- Admin publish policy v2 required [A,B,C].
- Quyền completed/dossier đã cấp không bị thu hồi.
- User mới chịu yêu cầu v2.

### Scenario F — Nhiều events chia sẻ dossier

- Một nhân vật ở event A và event B.
- User completed cả hai.
- Dossier chỉ sở hữu một lần.
- Provenance unlock rõ ràng.

### Scenario G — Không có policy

- Event NOT_CONFIGURED.
- Không cấp milestone.
- Không mở dossier giả.

### Scenario H — Mastery

- Required graded lesson đạt knowledgeScore dưới ngưỡng.
- Event vẫn completed nhưng chưa mastered.
- User học lại đạt ngưỡng.
- Event mastered.
- Không cấp EXP first completion lần nữa.

### Scenario I — Không có graded activity

- Lesson không chấm kiến thức.
- Lesson có thể completed.
- Lesson là NOT_ASSESSED.
- Event không tự mastered nếu không có graded lesson nào.

### Scenario J — Failure rollback

Nếu dossier grant fail sau khi milestone được chuẩn bị:

- Không để event completion chain commit một nửa.
- Không tạo trạng thái milestone thành công nhưng dossier đáng ra được mở lại bị thiếu mà không có reconciliation.

---

## 18. TESTS BẮT BUỘC

Không sử dụng Playwright.

### Backend Unit Tests

Kiểm tra:
- Policy validation.
- Required vs optional lesson.
- Mastery threshold.
- NOT_ASSESSED.
- Best valid result.
- One-way milestone transition.
- Dossier relationship.

### Backend Integration Tests

Kiểm tra:
- Migration Flyway + Hibernate validate.
- Event Completed đúng lúc.
- Event Mastered đúng điều kiện.
- Reward không bị nhân đôi.
- Dossier unlock atomic.
- Completed lesson khác version.
- Concurrent completion.
- Idempotent replay.
- Existing completed attempts.
- Policy republish không revoke.
- Security/ownership.
- Dossier preview và detail access.
- Evidence/Map regression.

Dùng PostgreSQL/Testcontainers như convention hiện tại.

### Flutter Tests

Kiểm tra:
- Parse event progress DTO.
- Parse dossier DTO.
- Collection tabs.
- Evidence tab vẫn hoạt động.
- Locked/unlocked dossier.
- Dossier detail.
- Loading/error/empty.
- Refresh sau completion.
- Logout/login khác user không rò collection.
- Navigation.
- NOT_CONFIGURED state.

### Build/Verify

Backend:
`./mvnw -B -ntp verify`

Flutter:
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`

Không sử dụng Playwright.

Không được báo test pass nếu không thực sự chạy.

Nếu môi trường thiếu Flutter/Docker thì báo cụ thể và tận dụng GitHub CI sau khi push để xác minh.

---

## 19. DATABASE MIGRATION AN TOÀN

Các yêu cầu bổ sung:

- Không sửa Flyway version đã áp dụng.
- Không DELETE/TRUNCATE dữ liệu cũ.
- Không ghi ownership giả cho user.
- Không làm hỏng user_inventory.
- Không reset user_evidence.
- Không reset lesson_results.
- Không sửa reward_transactions.
- Không thay đổi reward grants.
- Có FK/UNIQUE/CHECK/index phù hợp.
- JSONB policy phải được validate ở service trước publish.
- Có unique partial index đảm bảo một published policy/event.
- Quy tắc version immutable.
- Tách DRAFT/PUBLISHED/ARCHIVED.
- Nếu seed dùng historical event slugs thì phải resolve ID thực tế.

Không sửa database bằng SQL thủ công ngoài migration cho production.

---

## 20. GIỚI HẠN PHẠM VI

**Chỉ làm GAME-04.**

Không thực hiện:

- GAME-05 — Item Unlock Rule Engine.
- GAME-06 — Admin UI quản lý policy/dossier.
- GAME-07 — Wallet/Level/chi tiêu.
- GAME-08 — Regression tổng thể.
- ISLAND-01 đến ISLAND-08.

Trong GAME-04 có thể xây service/hợp đồng publish policy để hỗ trợ cấu hình và test, nhưng không triển khai toàn bộ CMS, form Admin, phân quyền quản lý phức tạp hoặc rule editor thuộc GAME-06.

Không thay đổi cơ chế trừ/hồi Thể lực.

Không xây lại Map.

Không thêm loại tiền mới.

Không cấp huy hiệu mặc định cho Event Completed.

Không tạo Item vào inventory thay cho dossier.

Không hard-code logic Bạch Đằng 938.

Không sửa trực tiếp published lesson snapshots.

Không thay đổi BA baseline.

Không tự động commit/push.

---

## 21. BÁO CÁO SAU KHI HOÀN THÀNH

Báo cáo bằng tiếng Việt.

### A. Tổng kết
- Những tính năng đã triển khai.
- Những tính năng chưa triển khai.
- Mức độ hoàn thành GAME-04.

### B. Database
- Migration mới.
- Bảng mới.
- Constraints/indexes.
- Data seed.
- Cách bảo vệ chính sách version.
- Cách xử lý completed attempts cũ.

### C. Backend
- Domain.
- Repository.
- Service.
- Event Progress Evaluator.
- Dossier Unlock.
- API mới.
- Tích hợp LearnerAttemptService.

### D. Flutter
- Collection tabs.
- Dossier cards.
- Dossier detail.
- Event progress.
- Refresh sau completion.
- Navigation.

### E. Nghiệp vụ
- Khi nào Event Completed?
- Khi nào Event Mastered?
- Khi nào dossier được mở?
- Khi nào chưa được mở?
- Hoàn thành lại có cấp trùng không?
- Republish có làm mất quyền không?
- Map khác dossier LOCATION thế nào?

### F. Testing
- Tests tạo mới.
- Build/test đã chạy.
- PASS/FAIL thực tế.
- Các blocker nếu có.
- CI cần theo dõi.

### G. Chuẩn bị GAME-05
- Event milestone API/data có thể tái sử dụng.
- Dossier và Inventory phân biệt thế nào.
- Những trigger nào cần cho rule engine.
- Không thực hiện GAME-05 ngay.

---

## 22. DEFINITION OF DONE

GAME-04 chỉ đạt yêu cầu khi:

- [ ] Có event_completion_policies versioned.
- [ ] Có user_event_progress.
- [ ] Có EVENT_COMPLETED thực sự.
- [ ] Có EVENT_MASTERED dựa trên kiến thức.
- [ ] Có NOT_CONFIGURED.
- [ ] Required vs optional rõ ràng.
- [ ] Hoàn thành lesson cũ sau republish vẫn tính.
- [ ] Không revoke milestone đã cấp.
- [ ] Có historical_dossiers.
- [ ] Có event_dossiers.
- [ ] Có user_dossier_unlocks.
- [ ] Một dossier canonical không cấp trùng.
- [ ] Có nguồn/citation và preview phù hợp.
- [ ] Có API event progress.
- [ ] Có API dossier list/detail.
- [ ] Backend grant dossier trong transaction đúng.
- [ ] Không phá evidence collection hiện có.
- [ ] Không thay đổi Map unlock vô ý.
- [ ] Flutter có tab nhân vật, địa điểm, hiện vật.
- [ ] Flutter phân biệt locked/unlocked.
- [ ] Sau khi hoàn thành event, bộ sưu tập cập nhật.
- [ ] Dữ liệu demo được cấu hình đúng, không hard-code trong business service.
- [ ] Không tăng EXP/Điểm Sử Ký sai.
- [ ] Có unit/integration/widget tests phù hợp.
- [ ] Build/CI không có lỗi phát sinh từ GAME-04.
- [ ] Không chạy Playwright.

**Bắt đầu thực hiện GAME-04 trực tiếp trên repo hiện tại.**

Không chỉ trình bày phương án.

Triển khai xong database, backend, API, Flutter, tests và báo cáo.

Sau khi hoàn thành, dừng lại để tôi review. Không tự làm GAME-05.
