# Phase 04 — Khắc phục `LessonResultScreen` & Làm sạch `flutter analyze` toàn Repo

## 1. Bối cảnh & Danh mục Vấn đề Phát hiện
Qua kiểm tra trực quan ảnh chụp màn hình E2E Chặng 7 (`stage7_lesson_result_360x800.png`, `stage7_lesson_result_390x844.png`) và kết quả chạy `flutter analyze` toàn dự án `dau-viet-mobile`:

| Mã | Màn hình / File | Vấn đề cụ thể (Root Cause) | Ảnh hưởng UI/UX & TC |
|---|---|---|---|
| **P4-01** | `LessonResultScreen`<br>(`lesson_result_screen.dart:190-203`) | Ảnh tĩnh `assets/images/kabi_celebration_victory.png` có chứa dòng chữ *"Bạn thật tuyệt vời!"* bị **cắt mất chữ ở mép phải** ngay bên trong file ảnh gốc, đồng thời bị **lặp lại 2 lần** với dòng tiêu đề `'Bạn thật tuyệt vời!'` phía trên (quan sát rõ trên `stage7_lesson_result_360x800.png`). | Lỗi thị giác rõ rệt trên màn Kết quả (`UX-01`, `UX-02`, `TC-RES-01`). |
| **P4-02** | `LessonResultScreen`<br>(`lesson_result_screen.dart:31-44, 143-145`) | Tên bài học trong khung trắng trung tâm đang hiển thị chuỗi chung chung `'Hoàn thành bài học'` thay vì tên thật của bài học vừa học (ví dụ: `'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa'`). Nguyên nhân: `_recapContentProvider` lấy `LessonContentDto` từ `/attempts/{id}/content`, nhưng `content` JSON của snapshot chỉ chứa `stages`, `evidence`, `assets` chứ không chứa trường `title` (trường `title` nằm ở `LessonMetadataDto` qua `getLessonMetadata(content.lessonId)`). | Mất ngữ cảnh tên bài học vừa hoàn thành trên màn Kết quả (`TC-RES-01`). |
| **P4-03** | `LessonResultScreen`<br>(`lesson_result_screen.dart:435-445`) | Nút hành động chính ở cuối màn Kết quả hiện chỉ có `'VỀ TRANG CHỦ'` (`context.go('/dashboard')`), thiếu nút điều hướng `'TIẾP TỤC HÀNH TRÌNH'` đưa người học quay về màn Sự kiện / Hành trình thời kỳ (`/campaign/:eventId` hoặc `/journey`) để thấy ngay bài học kế tiếp vừa được mở khóa (`TC-RES-07`). | Gián đoạn mạch học tập liên hoàn giữa các bài trong cùng sự kiện (`TC-RES-07`). |
| **P4-04** | Toàn bộ `dau-viet-mobile`<br>(`auth_screen.dart`, `profile_screen.dart`, `island_screen.dart`, `island_heritage_building.dart`, `island_scene.dart`, `island_tile_sheet.dart`) | Khi chạy `flutter analyze --no-pub` không giới hạn thư mục trên toàn bộ `dau-viet-mobile`, trình phân tích báo **10 cảnh báo/info** (`unused_import`, `unnecessary_underscores`, `deprecated_member_use`) ở các module `auth`, `profile`, `island`. | Vi phạm `AC-4` (*"`flutter analyze` đạt `0 issues`"*). |

---

## 2. Thiết kế Giải pháp Kỹ thuật

### 2.1. Xử lý ảnh linh vật ăn mừng bị cắt chữ trên `LessonResultScreen` (`lesson_result_screen.dart`)
- Sử dụng `KabiMascotWidget(mood: KabiMood.victory, width: 140, height: 140, headOnly: false)` hoặc cắt/ẩn vùng chữ thừa ở góc trên bên phải của `kabi_celebration_victory.png` để không còn chữ *"Bạn thật tuyệt vời!"* bị cắt cụt và trùng lặp với tiêu đề phía trên.

### 2.2. Hiển thị đúng Tên Bài học & Sự kiện trên `LessonResultScreen`
- Mở rộng `_recapDataProvider(attemptId)` để sau khi lấy `LessonContentDto` (có `content.lessonId`), gọi tiếp `repo.getLessonMetadata(content.lessonId)` (bọc `try/catch` an toàn) nhằm lấy đúng `meta.title`, `meta.centralQuestion`, và `meta.eventId`.
- Nhờ có `meta.title` và `meta.eventId`:
  1. Khung trắng trung tâm và khối `ÔN LẠI BÀI HỌC` hiển thị chính xác tên bài học lịch sử vừa hoàn thành (`Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa`, `Trận Bạch Đằng năm 938`, v.v.).
  2. Nút CTA chính hiển thị **`TIẾP TỤC HÀNH TRÌNH`** và điều hướng về `/campaign/${meta.eventId}` (hoặc `/journey` / `/dashboard` nếu không có `eventId`), giúp người học thấy ngay trạng thái `Đã hoàn thành` và bài học tiếp theo vừa mở khóa (`TC-RES-07`).

### 2.3. Làm sạch 100% `flutter analyze` trên toàn bộ `dau-viet-mobile` (`0 issues`)
- Xóa 3 unused imports trong:
  - `lib/features/island/presentation/island_screen.dart:18`
  - `lib/features/island/presentation/widgets/island_heritage_building.dart:1`
  - `lib/features/island/presentation/widgets/island_tile_sheet.dart:3`
- Thay `(_, __, ___)` / `(_, __)` bằng `(_, _, _)` / `(_, _)` trong:
  - `lib/features/auth/presentation/auth_screen.dart:122`
  - `lib/features/profile/presentation/profile_screen.dart:337`
  - `lib/features/island/presentation/widgets/island_heritage_building.dart:142, 155`
- Xử lý cảnh báo `deprecated_member_use` tại `lib/features/island/presentation/widgets/island_scene.dart:216-217`.

---

## 3. Tiêu chí Nghiệm thu Phase 04
- [ ] Ảnh chụp `stage7_lesson_result_360x800.png` và `stage7_lesson_result_390x844.png` không còn dòng chữ bị cắt góc trong ảnh minh họa và hiển thị đúng tên bài học lịch sử vừa hoàn thành.
- [ ] Nút `'TIẾP TỤC HÀNH TRÌNH'` hoạt động chính xác.
- [ ] Chạy `flutter analyze --no-pub` ở thư mục gốc `dau-viet-mobile` đạt tuyệt đối **`No issues found! (0 issues)`**.
