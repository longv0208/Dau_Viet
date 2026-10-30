# DẤU VIỆT — Project Overview

> **Status:** MVP planning / implementation baseline  
> **Product:** Ứng dụng học lịch sử Việt Nam theo hướng khám phá và tư duy dựa trên bằng chứng.  
> **Clients:** Flutter learner app và web Admin Lesson Builder (`dau-viet-admin` — Next.js 15, bootstrapped in TASK-0013).  
> **Backend:** Spring Boot.

## 1. Giới thiệu

**Dấu Việt** là ứng dụng học lịch sử Việt Nam, trong đó người học không chỉ đọc thông tin hoặc làm quiz mà tham gia một hành trình **điều tra câu hỏi lịch sử**: tìm hiểu bối cảnh, khám phá tư liệu, chọn bằng chứng, suy luận, đặt giả thuyết, tái dựng, kiểm chứng và kết luận.

Ví dụ nội dung đầu tiên: **Trận Bạch Đằng năm 938**. Câu hỏi trung tâm mẫu: *Vì sao Ngô Quyền có thể đánh bại lực lượng thủy quân Nam Hán trên sông Bạch Đằng?*

**Nguyên tắc sản phẩm:** Không xây từng sự kiện lịch sử thành một bộ màn hình và logic độc lập. Một **Learning Engine** chung phải render các lesson theo dữ liệu và cấu hình.

## 2. Mục tiêu MVP

1. Người học xem các sự kiện đã xuất bản, bắt đầu/tiếp tục bài học và tương tác qua các hoạt động học tập.
2. Hệ thống lưu câu trả lời, bằng chứng, trạng thái activity/stage và cho phép resume đúng vị trí.
3. Người học xây dựng giải thích có bằng chứng, kiểm chứng và tạo kết luận trước màn Story/Result.
4. Admin tạo lesson theo template, cấu hình stage/activity/evidence/rule, preview, validate và publish version.
5. Chứng minh có thể thêm lesson thứ hai mà **không sửa Learning Engine hoặc hard-code eventId**.

## 3. Người sử dụng

| Actor | Nhiệm vụ |
|---|---|
| Learner | Khám phá sự kiện, tương tác, hoàn thành lesson, xem progress/result/collection cơ bản |
| Content Admin | Quản lý event, lesson, evidence/assets, rule, preview và publish |
| System | Render lesson, validate, quản lý attempt/progress, versioning và reward cơ bản |

## 4. Các khái niệm nghiệp vụ

| Khái niệm | Ý nghĩa |
|---|---|
| HistoricalEvent | Đối tượng tri thức lịch sử, ví dụ Bạch Đằng 938 |
| Lesson | Trải nghiệm học cụ thể xoay quanh một câu hỏi lịch sử; một event có thể có nhiều lesson |
| LessonTemplate | Khung stage/activity/rule mặc định cho một loại bài |
| LessonVersion | Snapshot bất biến sau publish; learner attempt gắn với một version |
| Stage | Bước tư duy lịch sử, **không đồng nghĩa một screen** |
| Activity | Thao tác học như đọc, chọn bằng chứng, matching, drag-order, CER |
| Evidence | Tư liệu/bằng chứng có định danh, nguồn và metadata |
| Rule | Quy tắc hoàn thành, kiểm tra, feedback và chuyển bước |
| LearnerAttempt | Lần học cụ thể, tiến độ và các activity submissions |

Mối quan hệ chính:

```text
HistoricalEvent 1 ── N Lesson 1 ── N LessonVersion
                                       └─ Stages (ordered)
                                           └─ Activities (ordered)
                                                 ├─ Content / Evidence refs
                                                 └─ Rules / Feedback
Learner 1 ── N LearnerAttempt ── 1 LessonVersion
                   └─ ActivityAttempt / Outputs / Progress
```

## 5. Framework tư duy lịch sử

Framework stage tham chiếu từ BA:

1. **Context (Bối cảnh):** Đặt câu hỏi lịch sử và cung cấp nền tảng.
2. **Discovery (Khám phá):** Mở map/hotspot/timeline/thông tin.
3. **Evidence (Bằng chứng):** Thu thập và đánh giá thông tin liên quan.
4. **Reasoning (Suy luận):** Kết nối bằng chứng thành inference.
5. **Hypothesis (Giả thuyết):** Tạo giải thích tạm thời có dẫn chứng.
6. **Reconstruction (Tái dựng):** Sắp xếp diễn biến/quan hệ/chiến thuật.
7. **Verification (Kiểm chứng):** Kiểm tra với nguồn; có thể quay lại sửa giả thuyết.
8. **Conclusion (Kết luận):** Trả lời câu hỏi theo Claim–Evidence–Reasoning (CER).
9. **Reflection (Suy ngẫm):** Nhìn lại bằng chứng, thay đổi nhận định và ý nghĩa.

Đây là **khung dùng chung**, không bắt buộc mọi lesson dùng tất cả stage theo một thứ tự cứng. Template xác định flow phù hợp.

**Luồng learner điển hình:** Explore → Event Detail → Start/Resume → Context → Discovery → Evidence → Reasoning → Hypothesis → Reconstruction → Verification (có thể revise) → Conclusion → Reflection → Story/Result.

## 6. Phạm vi tính năng

### Core MVP (Must)

- Authentication tối thiểu; khám phá event/lesson đã publish.
- Lesson rendering theo cấu hình, các hoạt động tương tác và validation.
- Learner attempt, save progress, resume và xử lý lỗi mạng/retry.
- Evidence/inference/hypothesis/conclusion outputs có thể truy vết.
- Admin Lesson Builder mức tối thiểu: draft, preview, validate, publish/version.
- Story/Result và reward đơn giản sau hoàn thành.

### Sau khi Core ổn định (Should/Phase sau)

- Bản đồ lịch sử, collection mở rộng; EXP/badge nâng cao.
- Đảo cá nhân, trang trí, inventory, shop và energy (thể hiện trong mockup nhưng **chưa chốt thuộc Core MVP**).
- AI hint/phản biện, AR, thông báo, cá nhân hóa và thương mại hóa.

**Lưu ý scope:** Tài liệu Functional Requirements cũ xem Map là Must và Admin CMS là Phase 2; tài liệu BA framework mới ưu tiên Admin Lesson Builder là Must, Map là Should. Cho implementation baseline này, ưu tiên **framework BA mới**; Product Owner cần xác nhận trước khi khóa backlog.

### Trạng thái đã code (ảnh chụp `main` @ `0744ae8`, 2026-10)

Phân biệt **mục tiêu MVP** ở trên với **đã implement trong source** dưới đây — "đã code" chưa đồng nghĩa "đã nghiệm thu E2E". Chi tiết truy vết: `docs/BA_IMPLEMENTATION_TRACEABILITY.md`.

| Đã code | Chưa code / chưa hoàn thiện |
|---|---|
| Auth (register/login/refresh/logout), `/users/me` | `/me` (profile + level/EXP) |
| Events catalogue + detail (public) | — |
| Admin: events, lesson-templates, lessons draft CRUD, stages/activities sub-resource, evidences, assets upload/list/stream, validate/preview/publish/versions | `/admin/templates` alias; `upload-intent`/`confirm` 2-step asset flow |
| Learner: `lessons/{id}` + `/content`, attempts start/resume/current/content, submissions, complete → `lesson_results`, `/me/attempts`, `/me/progress` | `/me/collection` (chưa có endpoint), reward/EXP grant |
| Snapshot immutable, learner-safe projection, idempotency persist (`SUBMIT_ACTIVITY`, `COMPLETE_ATTEMPT`) | Story tổng quát sau mọi lesson; UX Submit→Feedback→Continue chưa hoàn thiện phía Flutter |
| **Learning Path 2.0 & Historical Map v2** (V33–V43, Epics A–F): cây `ERA -> PERIOD -> PHASE -> EVENT -> LESSON`, mở khóa tuần tự theo từng thời kỳ (`GET /me/learning-path`, `POST .../periods/{code}/touch`), địa điểm di tích độc lập N–N sự kiện/bài học (`ANY`/`ALL`), lọc media `UNLOCKED_ONLY`, Admin CMS & Mobile E2E | Gỡ vật lý 2 cột deprecated `map_locations.event_id`, `unlock_lesson_id` ở Milestone M4 Cleanup (ADR-009) |
| **Hai trục `/journey` + `/map` tách biệt** (Issue #42, hoàn tác Issue #36): `/journey` (`PeriodSelectionScreen`/`PeriodJourneyScreen`) = luồng học chính — cây `ERA→PERIOD→Sự kiện→Bài học`, chọn bài học trực tiếp; `/map` (Bản Đồ Dấu Ấn) chỉ hiển thị địa điểm di tích `map_locations` mở khóa sau bài học (`ANY`/`ALL`) → `LocationProfileSheet`; bottom nav có tab "Hành trình" + "Bản đồ" riêng | — |
| — | **Collection Dấu** (FR-39–41): `user_evidence` chỉ là schema, chưa có API/UI backend-connected |
| — | **EXP/reward thật** (FR-34): `reward_transactions` chỉ là schema, `complete()` chưa grant |
| — | **Heritage Island / Shop / Energy** (design M-22–M-28): UI demo hard-coded, chưa có catalog/ownership/placement backend |
| **UI/UX Design System v3** (Issue #40): đại tu mobile + admin theo Landing Page (giấy dó `#F8F0E0`, mực nho `#30251F`, chu sa `#B93430`, vàng ngự `#E0AE45`, jade `#247D78`, pixel shadow `4px 4px 0 #402C29`, Noto Serif + Be Vietnam Pro + Press Start 2P); 12 atoms mới mobile + 8 atoms admin; Lesson Player → "Sổ tay Thám tử Lịch sử" (StepProgressBar 6 chặng, clue cards, sa bàn, C-E-R board); 11 renderer thiết kế lại | — |
| **Cải tổ Giao diện & Luồng Quản trị Web Admin** (Issue #44, TASK-0033): gỡ `Press_Start_2P` khỏi chữ tiếng Việt, chuẩn hóa `Be Vietnam Pro` + `Noto Serif` + `JetBrains Mono` (`vietnamese`); Tree Sidebar 3 nhóm với `Sự kiện` chứa 7 nhánh con (*Bài học, Mẫu bài học, Bằng chứng, Hoạt họa, Hồ sơ, Địa điểm di tích, Phiên bản*) và `Đảo Di Sản` chứa nhánh con *Cửa hàng*; Sơ đồ Quy trình Biên tập 4 Bước (`OnboardingWorkflowCard`) trên `/dashboard`; `PageGuideBanner` & `WorkspaceHubTabs` trên 14 màn quản trị chính + tooltip/link cấu hình trực tiếp `#unlock-rule` | — |
| **Thiết kế lại Đảo Di Sản Isometric 2.5D** (Issue #46, TASK-0035, V59): 3 cấp đảo đồng tâm **Đảo An Lạc** (`4×4 = 16 ô`) · **Đảo Phồn Thịnh** (`6×6 = 36 ô`) · **Đảo Trường Tồn** (`8×8 = 64 ô`); tách 2 chế độ **Tham quan** (ẩn lưới ô, nền vịnh Hạ Long & đảo phụ phía xa, nút `<` `>`, trợ lý Rùa Kabi đội nón lá) và **Bài trí** (hiện lưới ô sáng rõ, 3 nút nổi *Lưu đảo / Xoay / Xóa*, Khay vật phẩm phân loại 5 tab *Tất cả / Công trình / Cây cối / Trang trí / Khác* dạng lưới 4 cột kèm badge số lượng); phân cấp tỷ lệ hiển thị công trình lớn vs vật phẩm nhỏ | — |
| **Mặc định Bắt buộc & Phản hồi học viên tự động trên Web Admin** (Issue #47, TASK-0036): mặc định `required: true` cho mọi Stage/Activity, `config.graded = true` cho `EVIDENCE_SELECT`, `requireAllRequiredStages: true` cho Lesson Completion, `optionalLessonIds: []` (tự chọn sẵn toàn bộ bài học `PUBLISHED`) cho Event Policy và `participationType = "REQUIRED"` cho Sự kiện trên Bản đồ Dấu Ấn; gỡ bỏ toàn bộ checkbox/dropdown Bắt buộc/Tuỳ chọn/Tham khảo; tự động điền sẵn bộ câu Phản hồi học viên mặc định (`DEFAULT_FEEDBACK_BY_TYPE`) cho cả 13 loại Activity kèm nút *Khôi phục mặc định* và tự khôi phục khi blur ô trống | — |

## 7. Hoạt động tương tác dự kiến

| Activity | Mục đích |
|---|---|
| READ / VIEW_IMAGE | Trình bày bối cảnh/tư liệu |
| EXPLORE_MAP / HOTSPOT | Khám phá marker, dấu vết |
| MULTIPLE_CHOICE | Chọn đáp án |
| EVIDENCE_SELECT | Chọn bằng chứng phù hợp |
| MATCHING / REASONING_CONNECT | Ghép và giải thích quan hệ |
| HYPOTHESIS_CHOICE | Chọn giả thuyết và bằng chứng hỗ trợ |
| DRAG_ORDER | Sắp xếp chuỗi diễn biến |
| VERIFICATION | Đối chiếu, phản hồi Supported/Partial/Contradicted |
| CER | Tạo kết luận gồm Claim, Evidence, Reasoning |

Danh sách là **đề xuất activity library ban đầu**, còn cần chốt schema chi tiết theo từng type.

## 8. Hướng phát triển

- **M0 — Domain contract:** ERD, templates MVP, activity schemas, completion/transition rules, versioning, OpenAPI contract.
- **M1 — Core backend:** Event/Lesson/Version, Learning Engine, attempts, validation.
- **M2 — Vertical slice:** Chạy trọn một lesson Bạch Đằng 938 trên Flutter.
- **M3 — Admin authoring:** Tạo và publish lesson mới không sửa code engine.
- **M4 — Progression:** Reward, map, collection, island và economy theo scope được duyệt.

## 9. Definition of Done cho vertical slice

- Lesson được publish thành **version bất biến** và đọc được từ API.
- Flutter render activity theo `type` + config mà không có điều kiện riêng cho `bach-dang-938`.
- Submit/validate trên server; save và resume được sau khi tắt app.
- Verification có feedback và revise path theo rule.
- Learner tạo conclusion; hoàn thành lesson; reward không cấp trùng khi retry.
- Admin có thể chỉnh draft/publish version tiếp theo; attempt đang học version cũ không hỏng.
- Có ít nhất một lesson khác được cấu hình để xác nhận engine tái sử dụng.

## 10. Tài liệu nền

- `Dau_Viet_BA_MVP_Learning_Framework.docx` — Product requirements, Historical Thinking Framework, Lesson Builder, versioning.
- `Functional_Requirements_Dau_Viet_MVP.docx` — Functional requirements ban đầu và các luồng người học.
- 8 mockup UI — timeline/map, 4 Dấu Vết, interactions, rewards, island, shop, energy và user journey.

> **Quy ước:** Những quyết định stack, module và thứ tự triển khai trong bộ Markdown này là **technical recommendation**, không phải tính năng đã được xác nhận trong tài liệu BA.
