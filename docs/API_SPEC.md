# DẤU VIỆT — REST API Specification (MVP Draft)

> **Status:** Contract proposal — chưa baseline; target Spring Boot (Java 21) + Flutter/Next.js clients.  
> **Base path:** `/api/v1` · JSON UTF-8 · HTTPS ngoài local · IDs UUID trừ stable stage/activity IDs trong snapshot.

## 1. Chuẩn chung

- `Authorization: Bearer <access_token>` cho endpoint bảo vệ; Admin cần `CONTENT_ADMIN`.
- Response JSON; timestamps ISO 8601 UTC; pagination `page/size` ở query, xác định consistent paging policy khi implement.
- Response lỗi: HTTP status đúng ngữ nghĩa + `code`, `message`, `details`, `traceId`.
- `Idempotency-Key` là header bắt buộc cho mutate có hậu quả như submit/complete/publish khi contract chốt.
- Never return password hash, JWT signing secrets, unpublished lesson (learner), correct answers, hidden rubric hoặc `validation` nhạy cảm.
- Version công khai trong URL `/v1`; version lesson thuộc business data (`lessonVersionId`) và độc lập API version.

### Error envelope

```json
{
  "code": "ACTIVITY_NOT_AVAILABLE",
  "message": "Hoạt động hiện chưa thể thực hiện",
  "details": {"activityId": "act-04"},
  "traceId": "2b6b36d5"
}
```

| HTTP | Khi dùng |
|---|---|
| 400 | Validation input/syntax |
| 401 | Chưa xác thực / token không hợp lệ |
| 403 | Không được phép thao tác |
| 404 | Không tồn tại hoặc tài nguyên không được lộ |
| 409 | State conflict, idempotency key reuse khác payload, attempt đã completed |
| 422 | Answer hợp cú pháp nhưng vi phạm rule nghiệp vụ không thể tiếp nhận |
| 429 | Rate limited |
| 500 | Lỗi server ngoài dự kiến |

## 2. Learner API endpoints

| Method | Path | Mục đích |
|---|---|---|
| POST | `/auth/register` | Đăng ký |
| POST | `/auth/login` | Trả access + refresh token theo policy |
| POST | `/auth/refresh` | Rotate refresh token |
| POST | `/auth/logout` | Revoke refresh session |
| GET | `/me` | Profile / level / EXP khi hỗ trợ |
| GET | `/events` | Danh sách event/lesson published |
| GET | `/events/{eventId}` | Metadata event, available lessons |
| GET | `/lessons/{lessonId}` | Public lesson detail, latest publish info |
| POST | `/lessons/{lessonId}/attempts` | Start/resume theo policy |
| GET | `/attempts/{attemptId}` | Attempt progress/cursor |
| GET | `/attempts/{attemptId}/current` | Current activity (learner-safe payload) |
| POST | `/attempts/{attemptId}/activities/{activityId}/submissions` | Submit answer, nhận feedback + next state |
| POST | `/attempts/{attemptId}/complete` | Finalize nếu lesson đủ điều kiện |
| GET | `/attempts/{attemptId}/result` | Xem kết quả |
| GET | `/me/collection` | Evidence đã thu thập (scope phụ thuộc MVP) |
| GET | `/me/progress` | Lesson in progress/completed |

### Start/resume

```http
POST /api/v1/lessons/4e18d732-62d6-4c6f-b62d-9f746197322a/attempts
Authorization: Bearer <token>
Content-Type: application/json

{}
```

```json
{
  "attemptId": "7fb4141d-766d-4602-b811-2241b8e53ac0",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "status": "IN_PROGRESS",
  "resumed": false,
  "currentStageId": "stage-context",
  "currentActivityId": "act-intro"
}
```

### Current activity — output đã redact

```json
{
  "attemptId": "7fb4141d-766d-4602-b811-2241b8e53ac0",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "stage": {"id": "stage-evidence", "type": "EVIDENCE"},
  "activity": {
    "id": "act-mcq-01",
    "type": "MULTIPLE_CHOICE",
    "instruction": "Chọn phương án đúng",
    "config": {
      "question": "Trận Bạch Đằng năm 938 diễn ra trên sông nào?",
      "options": [
        {"id": "a", "text": "Sông Hồng"},
        {"id": "b", "text": "Sông Bạch Đằng"}
      ]
    }
  },
  "progress": {"completedRequiredActivities": 2, "totalRequiredActivities": 9}
}
```

### Submit activity

```http
POST /api/v1/attempts/7fb4141d-766d-4602-b811-2241b8e53ac0/activities/act-mcq-01/submissions
Authorization: Bearer <token>
Idempotency-Key: 11e36737-9f1e-469b-84d6-c232a76c5672
Content-Type: application/json

{"answer": {"selectedOptionIds": ["b"]}}
```

```json
{
  "submissionId": "69272410-945e-40b1-88ac-537ea71bb7f0",
  "status": "ACCEPTED",
  "evaluation": {"outcome": "SUPPORTED", "feedback": "Chính xác."},
  "activityCompleted": true,
  "progress": {"completedRequiredActivities": 3, "totalRequiredActivities": 9},
  "next": {"stageId": "stage-reasoning", "activityId": "act-match-01"}
}
```

**Không** cho Flutter gửi `correct`, `earnedExp`, `isCompleted`, `nextStageId` với quyền quyết định. Backend tính các dữ liệu đó từ snapshot/rule và state server.

## 3. Admin / CMS API endpoints

| Method | Path | Mục đích |
|---|---|---|
| POST | `/admin/events` | Tạo event |
| PATCH | `/admin/events/{eventId}` | Sửa event metadata |
| GET | `/admin/templates` | Danh sách template supported |
| POST | `/admin/lessons` | Tạo lesson/draft từ template |
| GET | `/admin/lessons/{lessonId}` | Lấy draft + metadata |
| PUT | `/admin/lessons/{lessonId}/draft` | Lưu toàn bộ draft, optimistic version |
| POST | `/admin/lessons/{lessonId}/validate` | Validate đầy đủ trước publish |
| POST | `/admin/lessons/{lessonId}/preview` | Trả learner-safe preview payload từ draft |
| POST | `/admin/lessons/{lessonId}/publish` | Transactional publish snapshot version mới |
| POST | `/admin/lessons/{lessonId}/archive` | Archive, giữ version cũ |
| POST | `/admin/assets/upload-intent` | Tạo upload URL tạm thời (implementation proposal) |
| POST | `/admin/assets/confirm` | Verify file sau upload |

### Publish request/response

```http
POST /api/v1/admin/lessons/{lessonId}/publish
Authorization: Bearer <admin_token>
Idempotency-Key: 7c76c47c-b31f-46fb-9d47-bab36d75af61
Content-Type: application/json

{"expectedDraftRevision": 12}
```

```json
{
  "lessonId": "4e18d732-62d6-4c6f-b62d-9f746197322a",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "versionNo": 2,
  "status": "PUBLISHED"
}
```

Nếu thiếu question/objective, required activity, evidence reference, validation rule hoặc renderer phù hợp, trả `422` cùng mảng lỗi có `fieldPath` để Admin highlight.

## 4. Security và cạnh tranh trạng thái

1. Authorize user ownership mọi attempt/result, role Admin trên CMS endpoints.
2. Không để user thay đổi `lessonVersionId` của attempt.
3. Signature/expiry/revocation cho access/refresh; hash refresh token nếu persist.
4. Rate limit login/submit; validate payload size và upload file type/size.
5. Idempotency key theo `user + operation + key`; lưu request hash/result; cùng key + payload khác → 409.
6. Concurrent requests submit cùng activity phải được serialize hoặc dùng optimistic lock; không được nhảy state 2 lần.
7. Không expose thông tin mật bằng `GET current`; validate/feedback luôn tính server side.

## 5. Truy vết requirement

| API nhóm | BA requirement |
|---|---|
| Events/Lessons | LRN-01, ADM-01…03 |
| Start/Resume/Current | LRN-02…04, LRN-13, ENG-01…03, ENG-07 |
| Submissions | LRN-05…10, ENG-05…09 |
| Complete/Result | LRN-11…14, ENG-09 |
| Admin validate/preview/publish | ADM-08…13, ENG-10 |

## 6. Các điểm cần BA/PO duyệt

- Allow multiple attempts? Repeated reward? Retry limits và hint penalties?
- Với lesson archived, learner cũ còn resume đến khi nào?
- Có hỗ trợ offline answer queue không? MVP đề xuất online-first, retry-safe.
- Có cần phân trang/cursor cho event catalog lớn từ MVP không?
- Ai được publish: một Content Admin hay cần reviewer?
- API `PUT draft` lưu full document hay patch theo stage? Đề xuất MVP full document + `expectedDraftRevision`.

## 7. Nguồn

- `Dau_Viet_BA_MVP_Learning_Framework.docx`: functional requirements LRN/ADM/ENG và use cases.
- `Functional_Requirements_Dau_Viet_MVP.docx`: FR-01…46 và luồng chức năng.
- Endpoint names, HTTP errors và payloads ở đây là **đề xuất kỹ thuật**, chưa phải API đã có hoặc được kiểm thử.
