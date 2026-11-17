# Dấu Việt

Ứng dụng học lịch sử Việt Nam theo hướng điều tra: người học đọc bối cảnh, chọn bằng chứng, lập giả thuyết, kiểm chứng và kết luận theo mô hình Claim–Evidence–Reasoning. Nội dung bài học là dữ liệu, không phải màn hình gắn cứng từng sự kiện.

## Bài toán

Sách giáo khoa và quiz trắc nghiệm cho người học một đáp án, nhưng không cho họ thực hành cách sử gia làm việc: phân biệt nguồn, nối bằng chứng với suy luận, và sửa giả thuyết khi nguồn mâu thuẫn. Mỗi sự kiện lịch sử nếu được code thành một luồng riêng sẽ không mở rộng được.

Dấu Việt tách **khung tư duy lịch sử** khỏi **nội dung sự kiện**. Một Learning Engine dùng chung render mọi bài học từ cấu hình đã xuất bản. Thêm sự kiện mới là việc biên tập, không phải việc sửa engine.

## Sản phẩm

Ba ứng dụng dùng chung một backend:

| Ứng dụng | Vai trò |
|---|---|
| `dau-viet-mobile` | App học viên (Flutter): hành trình, bài học, bản đồ di sản, bộ sưu tập, đảo di sản |
| `dau-viet-admin` | Web biên tập (Next.js): soạn bài, kiểm tra, xem trước, xuất bản phiên bản |
| `dau-viet-backend` | Nguồn sự thật cho chấm điểm, tiến độ, hoàn thành và phần thưởng |

### Học viên

- Đăng ký, đăng nhập, làm mới phiên (JWT access/refresh) và đăng nhập Google.
- Hành trình theo cây **Đại thời kỳ → Thời kỳ → Sự kiện → Bài học**, chọn thời kỳ tự do, theo dõi phần trăm hoàn thành.
- Sổ tay điều tra 9 chặng: bối cảnh, khám phá, bằng chứng, suy luận, giả thuyết, tái dựng, kiểm chứng, kết luận CER, suy ngẫm.
- Thư viện hoạt động dùng chung: đọc, ảnh, bản đồ/hotspot, trắc nghiệm, chọn bằng chứng, ghép nối, sắp xếp diễn biến, giả thuyết, kiểm chứng, CER.
- Lưu tiến độ và tiếp tục đúng phiên bản bài đang học. Nộp bài và hoàn thành bài được xử lý idempotent khi mạng lỗi hoặc gửi lại.
- Bản đồ di sản mở địa điểm sau khi hoàn thành bài (điều kiện ANY/ALL), kèm thư viện ảnh và sách đọc 3 chương có trích nguồn.
- Đảo di sản isometric: tham quan, bày vật phẩm, nâng cấp đảo.

### Biên tập viên

- Soạn sự kiện, bài học, chặng, hoạt động, bằng chứng, tư liệu và địa điểm trên một workspace.
- Kiểm tra schema trước khi xuất bản: hoạt động không được engine hỗ trợ bị chặn lúc publish.
- Xuất bản tạo **phiên bản bất biến**. Lượt học đang dở giữ nguyên phiên bản cũ khi có bản mới.
- Xem trước đúng projection mà học viên nhận — không lộ đáp án.

## Kiến trúc

```text
Flutter (học viên) ──┐
                     ├── HTTPS / REST / JSON ── Spring Boot ── PostgreSQL
Next.js (biên tập) ──┘                              │
                                                    └── Object storage (tư liệu)
```

- **Backend quyết định đúng/sai.** Client chỉ render cấu hình công khai và gửi câu trả lời. Đáp án, điểm và phần thưởng không nằm trên app.
- **Một handler cho mỗi loại hoạt động**, đăng ký theo `ActivityType`. Không có nhánh `if (eventId == "bach-dang-938")` trong engine hay renderer.
- **Stage là bước tư duy, activity là thao tác, screen là lớp vẽ.** Một chặng có thể gồm nhiều hoạt động.
- **Lesson version là snapshot.** Mọi lượt học ghim `lessonVersionId`. Sửa bài đã xuất bản là tạo version mới.
- **Schema qua Flyway.** Cấu hình riêng từng activity nằm trong JSONB đã validate; quan hệ cố định nằm ở bảng và ràng buộc.

## Công nghệ

| Tầng | Lựa chọn |
|---|---|
| Mobile | Flutter, Dart 3, Riverpod, go_router, Dio |
| Admin | Next.js 15, React 19, TypeScript |
| Backend | Java 21, Spring Boot 3.4, Spring Security, Spring Data JPA |
| Dữ liệu | PostgreSQL, Flyway, JSONB cho cấu hình hoạt động |
| Kiểm thử | JUnit 5, Spring Boot Test, Testcontainers, Vitest, widget test Flutter |
| Hạ tầng local | Docker Compose |

## Điểm kỹ thuật đáng ghi vào CV

- Thiết kế learning engine hướng dữ liệu: cùng một runtime chạy nhiều sự kiện lịch sử mà không nhánh theo mã sự kiện.
- Versioning bài học bất biến và ghim lượt học, để xuất bản lại không làm hỏng tiến độ đang học.
- Chấm điểm, chuyển chặng và hoàn thành bài nằm trên server, kèm khóa idempotency cho nộp bài và hoàn thành.
- Kiểm chứng có đường sửa giả thuyết; kết luận theo CER truy được về bằng chứng đã chọn ở các chặng trước.
- Tách hành trình học (`/journey`) và bản đồ di sản (`/map`): địa điểm di tích gắn sự kiện theo quan hệ nhiều-nhiều và luật mở khóa ANY/ALL.
- Bộ biên tập web xuất bản được bài mới mà không sửa client renderer.

### Gợi ý một dòng trên CV

**Dấu Việt** — Nền tảng học lịch sử Việt Nam theo mô hình điều tra bằng chứng. Flutter, Next.js, Spring Boot, PostgreSQL. Learning engine hướng dữ liệu, phiên bản bài học bất biến, chấm điểm phía server.

### English, for an international CV

- Built a Vietnamese-history learning platform where lessons are authored data, not per-event screens: a shared engine renders investigation activities (evidence selection, hypothesis, verification, claim–evidence–reasoning).
- Kept scoring, progress, and completion on a Spring Boot API. Published lesson versions are immutable snapshots; in-progress attempts stay pinned to the version they started.
- Made submissions and lesson completion idempotent, and blocked unsupported activity types at publish time instead of at runtime.
- Shipped a Flutter learner app (journey, lesson player, heritage map, collection) and a Next.js lesson builder (draft, validate, preview, publish) on PostgreSQL + Flyway.

## Cấu trúc repo

```text
dau-viet-backend/    API, learning engine, auth, Flyway
dau-viet-admin/      Web biên tập bài học
dau-viet-mobile/     App học viên
dau-viet-db/         Tài liệu và bản thiết kế dữ liệu
docs/                Đặc tả sản phẩm, API, schema, learning engine
```

Tài liệu kỹ thuật: [tổng quan sản phẩm](docs/PROJECT_OVERVIEW.md), [kiến trúc](docs/TECH_STACK.md), [API](docs/API_SPEC.md), [cơ sở dữ liệu](docs/DATABASE_DESIGN.md), [learning engine](docs/LEARNING_ENGINE_DESIGN.md). Chạy local: [backend](docs/backend-runbook.md), [admin](docs/admin-runbook.md).
