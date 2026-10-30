# Handoff — TASK-0039 (Issue #48)

## 1. Kết quả thực hiện
Đã hoàn thành toàn bộ 5 Phase của [Issue #48](https://github.com/longv0208/Dau_Viet/issues/48) (`plans/261030-issue-48-journey-map/plan.md`):
1. **Phase 1 — Backend (`V62` Migration & Mở rộng API `/api/v1/map/locations` + `/api/v1/admin/map-locations`)**:
   - Tạo `V62__enrich_heritage_storybook_and_multi_media_gallery.sql` bổ sung `key_figures`, `story_narrative`, `historical_significance` vào `map_locations` và `source_citation` vào `map_location_media`; đăng ký bổ sung 10 seed assets hình ảnh/bản đồ và seed **3–4 mục `IMAGE_2D` kèm `caption` + `source_citation` cùng nội dung Sách Lịch sử 3 phần** cho toàn bộ 12 địa điểm di sản chuẩn.
   - Mở rộng `MapLocationDto`, `MapLocationService`, `AdminStandaloneMapLocationDtos`, `AdminMapLocationService` trả đầy đủ `keyFigures`, `storyNarrative`, `historicalSignificance`, `media[].sourceCitation` và `events[].(slug, summary, description, periodCode, periodTitle)` bằng batch query (không N+1), đồng thời nạp sẵn `media` trên `listForLearner`.
2. **Phase 2 — Mobile Hành trình Đường đi Phong cảnh 2.5D & Tự do chọn Thời kỳ (`AC-1`, `AC-2`)**:
   - Chuẩn hóa `derivePeriodStatus` trong `path_status_badge.dart`: Thời kỳ (`PERIOD`) có nội dung học không bao giờ trả về `LearnerPathStatus.locked` (hiển thị `AVAILABLE` khi chưa học `0%`), cho phép học viên tự do chọn và vào học bất kỳ Đại thời kỳ / Thời kỳ con nào.
   - Tạo `WindingLandscapeJourneyCanvas` + `WindingStonePathPainter` (đường đá vàng 2.5D uốn lượn `cubicTo` đi qua tâm các mốc tròn trên nền tranh phong cảnh `journey_coastal_landscape_bg.jpg`) và `BottomFloatingSummaryCard` (ảnh tròn `56×56`, tên thời kỳ + niên đại, thanh tiến độ xanh `#2E7D47`, `X/Y sự kiện` + `Z%`, nút `>`).
   - Thiết kế lại `PeriodSelectionScreen` (`/journey`) và `PeriodJourneyScreen` (`/journey/:periodCode`) khớp mẫu thiết kế `journey-mockup.png`.
3. **Phase 3 — Mobile Thư viện Đa ảnh Carousel, Lightbox & Cuốn Sách Lịch Sử (`AC-3`, `AC-4`)**:
   - Tạo `LocationMediaGalleryCarousel` (`PageView` + bộ đếm `1/N` + nút phóng to + chú thích/nguồn sử liệu + dải `Thumbnail Strip`) và `LocationFullscreenLightbox` (`InteractiveViewer` zoom `1.0x–4.0x` kèm khóa cuộn ngang `PageView` khi đang zoom).
   - Tạo `HistoricalStorybookReader` theo phong cách **Cuốn Sách Lịch Sử Mở Ra** trên nền giấy dó `#F8F0E0`, viền đôi vàng kim, chữ cái đầu *Drop-cap*, cỡ chữ `A-/A+` và 3 phần: *Phần 1 — Tóm tắt Sự kiện & Di tích*, *Phần 2 — Câu chuyện & Diễn biến (kèm trích dẫn sử liệu)*, *Phần 3 — Tư liệu & Liên kết Hành trình* (mở Sự kiện, Thời kỳ hoặc Bài học).
4. **Phase 4 — Admin Web (`/map-locations`) (`AC-3`, `AC-4`)**:
   - Bổ sung vùng biên tập **Nội dung Cuốn Sách Lịch Sử** (`keyFigures`, `storyNarrative`, `historicalSignificance`) ở Tab 1.
   - Nâng cấp Tab 4 (`Media`): xem trước ảnh thu nhỏ (`MediaItemThumbnail` qua `useAssetObjectUrl`), nút tải ảnh trực tiếp từ máy (`uploadAsset`), nút sắp xếp thứ tự Lên/Xuống/Đưa lên đầu (`↑`/`↓`/`★`) và ô nhập nguồn sử liệu (`sourceCitation`).

## 2. Kiểm chứng (Verification)
- **Backend**: `mvnw.cmd test -Dtest=AdminMapLocationServiceTest` → **3/3 passed (`BUILD SUCCESS`)**.
- **Mobile**:
  - `flutter analyze --no-pub` → **No issues found! (0 errors, 0 warnings)**.
  - `flutter test test/learning_path/ test/map/` → **52/52 tests passed (100%)**.
- **Admin Web**:
  - `npx tsc --noEmit` → **0 errors**.
  - `npx vitest run --testTimeout=15000` → **54/54 test files passed (314/314 tests)**.
- **Independent Code Review (`Issue48CodeReviewer`)**: Toàn bộ P1/P2 findings đã được khắc phục và tái xác minh.

## 3. Hành động tiếp theo
- Chờ người dùng review và ủy quyền commit/push.
