# TASK-0039: Issue #48 — Thiết kế lại Hành trình Lịch sử dạng Đường đi Phong cảnh 2.5D & Nâng cấp Bản đồ Di sản thành Thư viện Đa ảnh và Sách Đọc Lịch sử

## Mục tiêu
Nâng cấp và thiết kế lại đồng bộ hai trục khám phá lịch sử chính trên ứng dụng **Dấu Việt (`dau-viet-mobile` + `dau-viet-admin` + `dau-viet-backend`)** theo [Issue #48](https://github.com/longv0208/Dau_Viet/issues/48):
1. **Hành trình Lịch sử (`/journey` & `/journey/:periodCode`)**:
   - Thiết kế lại giao diện theo phong cách **Bản đồ Đường đi Phong cảnh 2.5D (Winding Landscape Journey)** giống mẫu thiết kế (`journey-mockup.png`), đi từ **Đại thời kỳ (`ERA`) -> Thời kỳ con (`PERIOD`) -> Sự kiện (`EVENT`)**, hiển thị rõ **`% hoàn thành`** và **`X/Y sự kiện đã hoàn thành`**, kèm **Thẻ Tổng quan Nổi ở Chân màn hình (`BottomFloatingSummaryCard`)**.
   - **Tự do chọn Thời kỳ (Không khóa cứng giữa các Thời kỳ)**: Người học có thể tự do bấm chọn và vào học bất kỳ Đại thời kỳ / Thời kỳ con nào mà không bị chặn tuần tự giữa các thời kỳ.
2. **Bản đồ Di sản (`/map` & `LocationProfileSheet` / `LocationProfileScreen`)**:
   - Nâng cấp khu vực hình ảnh thành **Thư viện Đa ảnh & Tư liệu (`LocationMediaGalleryCarousel`)**: hỗ trợ nhiều ảnh/tư liệu với Carousel `PageView`, bộ đếm `1/N`, chú thích + nguồn sử liệu (`sourceCitation`), thanh ảnh thu nhỏ (`Thumbnail Strip`) và chế độ **xem toàn màn hình (`LocationFullscreenLightbox`)** có pinch-to-zoom.
   - Thiết kế khu vực nội dung theo phong cách **Cuốn Sách Lịch Sử (`HistoricalStorybookReader`)** gồm 3 phần: *Phần 1 — Tóm tắt Sự kiện Lịch sử*, *Phần 2 — Câu chuyện & Diễn biến (trang sách đọc hiểu có Drop-cap & trích dẫn sử liệu)*, *Phần 3 — Tư liệu & Liên kết Hành trình*.
   - Mở rộng trang quản lý Địa điểm di tích trên **Web Admin (`/map-locations`)** hỗ trợ tải ảnh trực tiếp, sắp xếp thứ tự Lên/Xuống, nhập nguồn sử liệu và biên tập nội dung Sách Lịch sử.

## Kế hoạch chi tiết
Xem [`plans/261030-issue-48-journey-map/plan.md`](../../plans/261030-issue-48-journey-map/plan.md).
