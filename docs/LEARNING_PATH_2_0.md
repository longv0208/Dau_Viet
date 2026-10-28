# DẤU VIỆT — Kiến Trúc Bản Đồ Dấu Ấn 2.0 (Learning Path)

> Tài liệu kỹ thuật chuẩn hóa nguồn dữ liệu và lộ trình học tập lịch sử Việt Nam (TASK PATH-01).  
> Phiên bản baseline: `HISTORY_MAIN` v1 (Flyway V33).

---

## 1. Triết lý: Một Bản Đồ Dấu Ấn Duy Nhất

Trước PATH-01, ứng dụng tồn tại sự phân tách khái niệm giữa "Bản đồ Dấu Ấn" (Map) và "Dòng thời gian" (Timeline), dẫn đến nguy cơ lệch dữ liệu điều hướng và logic khóa bài phân mảnh.

**Nguyên tắc cốt lõi của Bản đồ Dấu Ấn 2.0:**
1. **Bản đồ Dấu Ấn chính là Timeline học tập**: Không duy trì hai hệ thống điều hướng lộ trình độc lập.
2. **Cấu trúc phả hệ 4 cấp nghiêm ngặt**:
   $$\text{Learning Path} \longrightarrow \text{Chapter (Thời kỳ/Chương)} \longrightarrow \text{Event Node (Sự kiện)} \longrightarrow \text{Lesson Node (Bài học)}$$
3. **Mã lộ trình chuẩn hóa**: `HISTORY_MAIN` là dòng chảy lịch sử dân tộc duy nhất xuyên suốt ứng dụng.
4. **Backend Authoritative**: Thứ tự sư phạm và tính sẵn sàng của nội dung được quản lý tập trung từ database, tuyệt đối không suy đoán qua chuỗi `era`, so khớp tiêu đề, timestamp tạo bản ghi hay pagination API.

---

## 2. Mô Hình Dữ Liệu & Khái Niệm

### 2.1. Cấu trúc thực thể

- **`learning_path_versions`**: Quản lý phiên bản của lộ trình (mã `path_code`, số phiên bản `version_no`).
  - Hỗ trợ vòng đời `DRAFT` $\rightarrow$ `PUBLISHED` $\rightarrow$ `ARCHIVED`.
  - Quy tắc bất biến: Tối đa duy nhất **1 phiên bản PUBLISHED** hiện hành cho mỗi `path_code` (enforced bởi partial unique index `ux_learning_path_active_published`).
  - Khi Admin cập nhật lộ trình (thêm chương, đổi thứ tự), hệ thống xuất bản một `version_no` mới thay vì sửa đổi phiên bản đang công bố.
  - Trigger `trg_learning_path_version_immutable` ngăn chặn cập nhật trực tiếp nội dung trên phiên bản `PUBLISHED`.

- **`learning_path_chapters`**: Lưu trữ các chương/thời kỳ lịch sử lớn.
  - Mang thông tin niên đại tổng quan (`start_year`, `end_year`, `period_label`).
  - Thứ tự chương được xác định bằng `sort_order` tường minh.
  - Trường `theme_key` (ví dụ `FOUNDING_ERA`, `NORTHERN_DOMINATION`, `LY_DYNASTY`) là khóa metadata ngữ nghĩa giúp client chọn artwork/theme phù hợp; không nhúng đường dẫn asset cục bộ vào database.

- **`learning_path_event_nodes`**: Nút sự kiện lịch sử trong chương.
  - Trỏ trực tiếp tới bản ghi canonical trong `historical_events(id)`.
  - Đảm bảo tính toàn vẹn: Unique `(path_version_id, event_id)` đảm bảo mỗi sự kiện lịch sử chỉ xuất hiện **tối đa một lần** trong cùng một phiên bản lộ trình.
  - Niên đại, tiêu đề, tóm tắt và ảnh bìa đọc từ `historical_events`, tránh sao chép dữ liệu gây phân mảnh.

- **`learning_path_lesson_nodes`**: Nút bài học thuộc sự kiện trong lộ trình.
  - Trỏ tới `lessons(id)`.
  - Composite Foreign Key `(event_id, lesson_id)` đảm bảo ở tầng cơ sở dữ liệu rằng bài học được gắn phải thuộc đúng sự kiện của event node, ngăn chặn triệt để bài học bị gán chéo sự kiện.
  - Sắp xếp theo `sort_order` sư phạm tăng dần.

---

## 3. Quy Ước Niên Đại Lịch Sử (BCE & CE)

Hệ thống phân biệt rạch ròi giữa **dữ liệu lịch sử khách quan** (`start_year` trong `historical_events`) và **trình tự chương trình học** (`sort_order` trong lộ trình).

### 3.1. Lưu trữ và hiển thị năm

| Mốc lịch sử | Giá trị DB (`start_year`) | Định dạng hiển thị (`yearLabel`) | Ghi chú quy chuẩn |
|---|---|---|---|
| Hùng Vương dựng nước | `-700` | `Khoảng thế kỷ VII TCN` | Số âm tròn thế kỷ $\rightarrow$ chuyển đổi La Mã + "TCN" |
| Thục Phán An Dương Vương | `-257` | `Năm 257 TCN` | Số âm không tròn thế kỷ $\rightarrow$ `Năm <abs> TCN` |
| Triệu Đà sáp nhập Âu Lạc | `-179` | `Năm 179 TCN` | Số âm không tròn thế kỷ |
| Khởi nghĩa Hai Bà Trưng | `40` | `Năm 40` | Số nguyên dương Công nguyên |
| Đại chiến Bạch Đằng | `938` | `Năm 938` | Số nguyên dương Công nguyên |
| Lý Thái Tổ dời đô | `1010` | `Năm 1010` | Số nguyên dương Công nguyên |
| Chiến thắng Như Nguyệt | `1077` | `Năm 1077` | Số nguyên dương Công nguyên |
| Chiến dịch Điện Biên Phủ | `1954` | `Năm 1954` | Số nguyên dương Công nguyên |

- **Không có năm 0**: Trong quy ước biên niên sử thông thường (từ năm 1 TCN sang năm 1 SCN), không tồn tại năm 0. `YearLabelFormatter` ném `IllegalArgumentException` nếu nhận giá trị 0.
- **Niên đại truyền thuyết & ước lượng**: Không coi năm 2879 TCN trong truyền thuyết là niên đại khảo cổ xác nhận. Thời đại dựng nước Văn Lang lấy mốc khảo cổ học đồ đồng Đông Sơn (khoảng thế kỷ VII TCN) với ghi chú ước lượng.

---

## 4. Trạng Thái Biên Tập Nội Dung (`contentStatus`)

Mỗi sự kiện trong lộ trình được server đánh giá tự động dựa trên mức độ sẵn sàng của nội dung và chính sách hoàn thành:

```
                  ┌───────────────────────────────┐
                  │ Event Node in Learning Path  │
                  └──────────────┬────────────────┘
                                 │
                   Có bài học PUBLISHED không?
                                 │
                   ┌─────────────┴─────────────┐
                  Không                       Có
                   │                           │
                   ▼                           ▼
        NO_PUBLISHED_LESSON         Có PUBLISHED Policy không?
                                               │
                                 ┌─────────────┴─────────────┐
                                Không                       Có
                                 │                           │
                                 ▼                           ▼
                       NO_COMPLETION_POLICY         Policy hợp lệ và các
                                                    required lessons đủ?
                                                             │
                                               ┌─────────────┴─────────────┐
                                              Không                       Có
                                               │                           │
                                               ▼                           ▼
                                    CONTENT_REVIEW_REQUIRED            PLAYABLE
```

1. **`PLAYABLE`**: Sự kiện có ít nhất một bài học đã xuất bản và có `event_completion_policies` ở trạng thái `PUBLISHED` mà toàn bộ `required_lesson_ids` đều tồn tại và hợp lệ trong sự kiện.
2. **`NO_PUBLISHED_LESSON`**: Sự kiện chưa có bài học nào được công bố (ví dụ: Chương I `hung-vuong-van-lang`).
3. **`NO_COMPLETION_POLICY`**: Đã có bài học công bố nhưng chưa thiết lập chính sách hoàn thành sự kiện (ví dụ: `chien-thang-nhu-nguyet-1077`, `chien-dich-dien-bien-phu-1954`).
4. **`CONTENT_REVIEW_REQUIRED`**: Chính sách hoàn thành tham chiếu tới lesson không tồn tại hoặc bài học bị gỡ khỏi trạng thái công bố.

> [!NOTE]
> `contentStatus` thuộc tầng biên tập nội dung hệ thống. Trạng thái cá nhân của người học (`LOCKED`, `CURRENT`, `COMPLETED`, `MASTERED`) sẽ được tích hợp ở **PATH-03** qua endpoint `/api/v1/me/learning-path`.

---

## 5. Dữ Liệu Seed V1 (`HISTORY_MAIN`)

| Chương | Tiêu đề chương | Niên đại | Sự kiện gắn kết | Content Status | Bài học gắn kết |
|---|---|---|---|---|---|
| I | Buổi đầu dựng nước | -700 đến -179 | `hung-vuong-van-lang` | `NO_PUBLISHED_LESSON` | (0 bài học) |
| II | Bắc thuộc và đấu tranh giành độc lập | -179 đến 938 | `khoi-nghia-hai-ba-trung-40` / `hai-ba-trung-40` | `PLAYABLE` / `NO_COMPLETION_POLICY` | 1 bài học |
| III | Buổi đầu độc lập tự chủ | 938 đến 1009 | `bach-dang-938` | `PLAYABLE` | Trận Bạch Đằng năm 938 |
| IV | Thời nhà Lý | 1009 đến 1225 | `ly-thai-to-1010` / `history-thang-long-1010`<br>`chien-thang-nhu-nguyet-1077` | `PLAYABLE`<br>`NO_COMPLETION_POLICY` | 1. Vì sao dời đô?<br>2. Dấu tích đô thành<br>3. Chiến Tuyến Sông Cầu |
| V | Kháng chiến chống thực dân Pháp | 1945 đến 1954 | `chien-dich-dien-bien-phu-1954` | `NO_COMPLETION_POLICY` | Quyết Định Lịch Sử |

### Xử lý sự kiện trùng Hai Bà Trưng:
- Hai slug `hai-ba-trung-40` (từ V20) và `khoi-nghia-hai-ba-trung-40` (từ V29) cùng đại diện cho một sự kiện lịch sử.
- Cơ chế giải quyết trong PATH-01: Bộ phân giải ưu tiên slug canonical `hai-ba-trung-40`, fallback sang `khoi-nghia-hai-ba-trung-40` nếu môi trường chỉ có slug V29.
- Ràng buộc DB `ux_path_event_node_unique_event` bảo đảm chỉ có **duy nhất 1 nút sự kiện** cho cuộc khởi nghĩa Hai Bà Trưng trong `HISTORY_MAIN`.

---

## 6. Hợp Đồng API (`API Contract`)

### `GET /api/v1/learning-path`
- **Quyền truy cập**: Public / Authenticated.
- **Tham số**:
  - `code` (optional, mặc định `HISTORY_MAIN`).
- **Mã lỗi**:
  - `200 OK`: Trả về cây lộ trình hoàn chỉnh.
  - `404 NOT_FOUND`: Không tìm thấy phiên bản `PUBLISHED` cho `path_code`.

#### Cấu trúc phản hồi:
```json
{
  "pathCode": "HISTORY_MAIN",
  "pathVersion": 1,
  "title": "Hành trình Lịch sử Việt Nam",
  "description": "Lộ trình học tập lịch sử Việt Nam chuẩn hóa: từ buổi đầu dựng nước tới thời đại Hồ Chí Minh",
  "chapters": [
    {
      "chapterId": "d7e10000-0000-4000-8000-000000000001",
      "code": "FOUNDING_ERA",
      "title": "Buổi đầu dựng nước",
      "description": "Thời đại Hùng Vương mở nước, văn hóa Đông Sơn và nền văn minh sông Hồng.",
      "startYear": -700,
      "endYear": -179,
      "periodLabel": "Khoảng thế kỷ VII TCN – năm 179 TCN",
      "sortOrder": 1,
      "themeKey": "FOUNDING_ERA",
      "events": [
        {
          "nodeId": "UUID",
          "eventId": "00000000-0000-0000-0000-000000000005",
          "slug": "hung-vuong-van-lang",
          "title": "Thời Đại Hùng Vương - Dựng Nước Văn Lang",
          "startYear": -700,
          "yearLabel": "Khoảng thế kỷ VII TCN",
          "period": "Khoảng thế kỷ VII TCN",
          "coverAssetKey": "events/hung-vuong/hero.jpg",
          "sortOrder": 1,
          "contentStatus": "NO_PUBLISHED_LESSON",
          "lessons": []
        }
      ]
    }
  ]
}
```

### `GET /api/v1/admin/learning-path/audit`

- Quyền truy cập: Yêu cầu quyền `CONTENT_ADMIN`. Không cấp quyền truy cập tự do cho learner.
- **Mục đích**: Báo cáo kiểm toán chất lượng lộ trình và tính sẵn sàng của nội dung.
- **Tham số**: `code` (mặc định `HISTORY_MAIN`), `version` (optional).
- **Phản hồi**: Tổng số chương, số sự kiện, số bài học, phân bổ `contentStatusCounts`, danh sách cảnh báo biên tập (`emptyChapters`, `issues`).

---

## 7. Kế Hoạch Cho Các Task Tiếp Theo

1. **PATH-02 (Data Reconciliation & Unification)**:
   - Hợp nhất dữ liệu alias trùng lặp: di chuyển các bài học, địa điểm bản đồ (`map_locations`), và chính sách hoàn thành của `khoi-nghia-hai-ba-trung-40` và `history-thang-long-1010` về bản ghi canonical.
   - Bổ sung `event_completion_policies` cho `chien-thang-nhu-nguyet-1077` và `chien-dich-dien-bien-phu-1954` để nâng hạng thành `PLAYABLE`.
   - Soạn thảo nội dung bài học mở đầu cho Chương I (`hung-vuong-van-lang`).

2. **PATH-03 (Learner Progression & Unlocking Engine)**:
   - Xây dựng endpoint cá nhân: `GET /api/v1/me/learning-path`.
   - Tính toán trạng thái cá nhân: `LOCKED`, `AVAILABLE`, `CURRENT`, `COMPLETED`, `MASTERED`.
   - Áp dụng luật mở khóa theo sự kiện (`EVENT_COMPLETED` của sự kiện trước là điều kiện tiên quyết để mở khóa sự kiện sau).

3. **PATH-04 (Admin Learning Path CMS)**:
   - Giao diện Admin soạn thảo lộ trình: tạo draft version mới, sắp xếp kéo thả (drag-and-drop) chương và sự kiện, publish version mới.

4. **PATH-05 (Mobile Flutter Integration)**:
   - Đồng bộ màn hình Timeline và Sa Bàn di sản tiêu thụ API `GET /api/v1/learning-path` và `GET /api/v1/me/learning-path`.


---

## 8. Nâng Cấp Kiến Trúc Luồng Học Lịch Sử & Địa Điểm Di Tích (V39–V43, Epics A–F)

### 8.1. Phân cấp cây học tập (Hierarchy: `ERA -> PERIOD -> PHASE -> EVENT -> LESSON`)
- Tái sử dụng bảng `learning_path_chapters` làm cây phân cấp (`parent_id UUID`, `node_type VARCHAR(16) NOT NULL DEFAULT 'PERIOD'` trong `{ERA, PERIOD, PHASE}`).
- Quy tắc phân cấp nghiêm ngặt (`PATH_NODE_INVALID_PARENT` 422):
  - `ERA`: `parent_id IS NULL` (nút gốc Thời đại).
  - `PERIOD`: `parent_id` có thể `NULL` (backward-compatible) hoặc trỏ tới `ERA` cùng `path_version_id`.
  - `PHASE`: `parent_id` bắt buộc trỏ tới `PERIOD` cùng `path_version_id`.
  - `learning_path_event_nodes.chapter_id`: chỉ được gắn vào `PERIOD` hoặc `PHASE` (không gắn trực tiếp vào `ERA`).
- Niên đại sự kiện (`historical_events`): bổ sung `end_year INTEGER` và `date_precision VARCHAR(16) NOT NULL DEFAULT 'EXACT'` (`EXACT`, `CIRCA`, `CENTURY`, `PERIOD`).

### 8.2. Khóa bài học tuần tự theo từng Thời kỳ (`PERIOD`) & Tự động nâng cấp phiên bản
- **Phạm vi khóa (`Per-Period Sequential Locking`)**:
  - Mỗi `PERIOD` là một luồng học độc lập — bài/sự kiện đầu tiên của **mọi** `PERIOD` luôn ở trạng thái `AVAILABLE`.
  - Bên trong một `PERIOD`, thứ tự các sự kiện `REQUIRED` được mở tuần tự theo cây (`PERIOD` events + `PHASE` child events theo `sort_order`).
  - Các bài học `PUBLISHED` nằm ngoài lộ trình (`status == null` trong projection) được phép học tự do, không tính vào tiến độ thời kỳ.
- **Tự động nâng cấp phiên bản lộ trình**:
  - Vì tiến độ hoàn thành (`learner_attempts`, `user_event_progress`) lưu độc lập với `path_version_id`, khi có phiên bản `PUBLISHED` mới của `HISTORY_MAIN`, `enrolledVersion()` tự động chuyển `user_learning_path_enrollments.path_version_id` sang bản `PUBLISHED` mới nhất ngay ở lần đọc tiếp theo.
- **Ghi nhận thời kỳ đang học (`user_path_period_state`)**:
  - Endpoint `POST /api/v1/me/learning-path/periods/{periodCode}/touch` cập nhật `last_touched_at` để phản hồi `GET /api/v1/me/learning-path` trả về `lastPeriodCode` và `current` của thời kỳ gần nhất.

### 8.3. Địa điểm Di tích độc lập (`map_locations` v2 — V40 & V43)
- Địa điểm di tích là thực thể độc lập (`map_locations.event_id` nullable), liên kết N–N với sự kiện qua `map_location_events(location_id, event_id, role, sort_order)`.
- Thuộc tính phân loại địa điểm:
  - `slug VARCHAR(120) UNIQUE`
  - `kind VARCHAR(32)` (`HERITAGE_SITE`, `BATTLEFIELD`, `ANCIENT_CAPITAL`, `ARCHAEOLOGICAL_SITE`, `MEMORIAL`, `SCHEMATIC_REGION`)
  - `coordinate_precision VARCHAR(24)` (`EXACT`, `APPROXIMATE`, `SCHEMATIC_ONLY`)
  - `visibility VARCHAR(24)` (`ALWAYS_VISIBLE`, `HIDDEN_UNTIL_UNLOCKED`)
  - `unlock_rule_mode VARCHAR(16)` (`NONE`, `ANY`, `ALL`) kết hợp bảng `map_location_unlock_lessons(location_id, lesson_id)` (bỏ giới hạn cùng event).
- Media sau mở khóa (`map_location_media` + `assets`):
  - Lưu trữ `asset_id` (`IMAGE_2D`, `PANORAMA_360`, `AUDIO_GUIDE`, `DOCUMENTARY_CLIP`) với `visibility ∈ {PUBLIC_PREVIEW, UNLOCKED_ONLY}`.
  - Khi địa điểm đang `LOCKED`, Learner API ẩn toàn bộ bản ghi `UNLOCKED_ONLY` (không trả `assetId`/`assetUrl`).
- Sổ cái mở khóa địa điểm (`user_location_unlocks`):
  - Đánh giá ngay trong cùng transaction `LearnerAttemptService.doComplete()` thông qua `LessonCompletionHook`, đồng thời trả về `newlyUnlockedLocations[]` trong `CompleteAttemptResponse`.

### 8.4. Quyết định gỡ cột deprecated `map_locations.event_id` và `unlock_lesson_id` (Issue #26 / ADR-009)
- Hai cột `map_locations.event_id` và `map_locations.unlock_lesson_id` đã chuyển sang trạng thái **DEPRECATED** từ `V40__heritage_locations.sql`.
- Trong giai đoạn chuyển tiếp (Phase 1), `AdminMapLocationService` tự động đồng bộ xuống `map_location_events` và `map_location_unlock_lessons` khi gọi qua endpoint legacy `/api/v1/admin/events/{eventId}/map-locations`, còn `MapLocationService` và `LocationUnlockEvaluator` đọc từ hai bảng nối làm nguồn chuẩn.
- Việc xóa vật lý hai cột (`ALTER TABLE map_locations DROP COLUMN event_id, DROP COLUMN unlock_lesson_id`) được ấn định vào **Milestone M4 Cleanup** ngay sau khi hoàn tất 4 điều kiện: (1) Mobile E4/E5 và Admin D2/D3 hợp nhất hoàn toàn trên `main`, (2) chuyển/ngừng endpoint `/api/v1/admin/events/{eventId}/map-locations`, (3) cập nhật fixture trong `MapLocationIT`, và (4) truy vấn kiểm toán không còn bản ghi mồ côi giữa cột cũ và bảng nối.
