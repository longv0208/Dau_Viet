# Kế hoạch Khắc phục Triệt để các Bug Còn Gặp sau khi Merge `main` (`63befe1`) — Issue #45 Phase 4

> **Trạng thái:** Ready for Implementation (`/cook`)  
> **Base commit trên `main`:** `63befe1` (đã gộp Issue #43 `TASK-0035`, Issue #46 `TASK-0034`, Issue #47 `TASK-0036` và giải quyết toàn bộ xung đột với Issue #45 `TASK-0037`)  
> **Phạm vi:** `dau-viet-backend`, `dau-viet-admin`, `dau-viet-mobile`

---

## 1. Những gì đã được giải quyết sau khi cập nhật `main` (`63befe1`)

Khi hợp nhất `main` (`#43`, `#46`, `#47`) vào nhánh `feat/issue-45-e2e-flows-ux-audit`:
- **Đã giải quyết trên `main`:**
  1. Toàn bộ 9 cảnh báo `flutter analyze` ở `dau-viet-mobile/lib/features/island/` đã được sửa trong Issue #46 (`flutter analyze --no-pub` toàn bộ repo hiện đạt **`No issues found!`**).
  2. MSW handler cho `GET /api/proxy/admin/map-locations` trong `builder-page.test.tsx` và cơ chế mặc định `required: true` + `defaultFeedbackForActivity(type)` trong `use-builder.ts` đã được đồng bộ với Issue #47.
  3. Cơ chế phân tách `COLLECT` / `ASSESS` và hiển thị verdict từng thẻ bằng chứng trên `EvidenceSelectRenderer` (Issue #43) đã được tích hợp cùng `expectedCount` & `totalItems` của Issue #45.
  4. Mã task của Issue #45 đã được chuyển sang **`TASK-0037`** (`tasks/TASK-0037/`) để không trùng với `TASK-0034..0036` trên `main`.

---

## 2. Danh mục 5 Nhóm Bug Còn Tồn Đọng Cần Xử Lý

| Mã Bug | Phân hệ | Mức độ | Mô tả chi tiết & Vị trí file |
|---|---|---|---|
| **BUG-01** | `dau-viet-backend` + `dau-viet-mobile` | **High (P1)** | **Mất Banner Địa điểm Mở khóa (`UnlockedLocationBanner`) và Hồ sơ Lịch sử (`_DossierUnlockBanner`) khi reload / mở lại màn Kết quả (`/learning/result/:attemptId`):**<br>- `LearnerAttemptService.doComplete()` chỉ trả `newlyUnlockedLocations` & `newlyUnlockedDossiers` ở response của `POST /complete` mà không lưu vào `lesson_results.result_json`.<br>- Khi học viên F5/reload trình duyệt hoặc mở lại màn Kết quả từ lịch sử (`extra == null`), `GET /api/v1/attempts/{id}/result` (`LessonResultResponse`) không trả về 2 trường này nên cả 2 banner biến mất (như quan sát thấy ở ảnh chụp E2E `flow4_3` và `flow4_5`). |
| **BUG-02** | `dau-viet-admin` | **Medium (P2)** | **15 lỗi TypeScript (`npx tsc --noEmit` exit code 2) trên 5 file chặn build production:**<br>1. `src/lib/dto/map-location.ts` (6 lỗi `TS2322`): `HERITAGE_PRESET_MAPS[0..5]` có kiểu `HeritagePresetMap \| undefined` dưới cờ `noUncheckedIndexedAccess: true`.<br>2. `src/features/learning-path/learning-path.test.tsx` (3 lỗi `TS2322`, `TS2741` mới phát sinh từ Issue #47 trên `main`): fixture test thiếu `pathVersionId` trên chapter/event node và gán `null` cho `createdAt: string`.<br>3. `src/features/island-builder/island-builder-workspace.tsx` (2 lỗi `TS2345`, `TS2322`): truyền `DraftSnapshotState \| undefined` vào `setSnapshot` và truyền sai props `{ title, message }` vào `<ErrorState />`.<br>4. `src/features/island-builder/island-isometric-canvas.tsx` (2 lỗi `TS2532`): truy cập mảng thiếu non-null guard.<br>5. `src/features/island-builder/island-layout-list.tsx` (2 lỗi `TS2322`): truyền `{ message }` vào `<ErrorState />` và `variant="primary"` vào `<Button />`. |
| **BUG-03** | `dau-viet-admin` | **Medium (P2)** | **`UnlockedLocationsCard` trong Lesson Builder (`/lessons/[id]/builder`) hiển thị sai `"Địa điểm mở khóa (0) — Bài học này chưa gắn địa điểm mở khóa nào"` trong lúc đang tải API:**<br>- File: `src/features/lessons/builder/unlocked-locations-card.tsx` (dòng 35–55, 131–136).<br>- Khi `locationsQuery.isPending` là `true`, `linkedLocations` tạm thời là `[]` nhưng UI không hiển thị trạng thái đang tải (skeleton/spinner) mà kết luận ngay là `(0)` địa điểm (như xuất hiện ở góc phải dưới ảnh chụp E2E `part_3`). |
| **BUG-04** | `dau-viet-mobile` | **Medium (P2)** | **Tư liệu `UNLOCKED_ONLY` trong `LocationProfileSheet` (`/map?locationId=`) thiếu huy hiệu phân biệt phần thưởng mở khóa sau bài học:**<br>- File: `lib/features/map/presentation/widgets/location_profile_sheet.dart`.<br>- Khi học viên mở địa điểm vừa được mở khóa từ Bài học A, tư liệu `UNLOCKED_ONLY` hiển thị giống hệt tư liệu `PUBLIC_PREVIEW`, thiếu nhãn `"MỞ KHÓA TỪ BÀI HỌC"` để nhấn mạnh phần thưởng tư liệu độc quyền. |
| **BUG-05** | `dau-viet-admin` + `dau-viet-mobile` | **Low (P3)** | **Cảnh báo Kiểm toán Lộ trình thiếu nút nhảy nhanh & Lỗi console Google Sign-In (`GIS`) trên Flutter Web headless:**<br>- Trong `dau-viet-admin/src/features/learning-path/path-validation.tsx`: các dòng cảnh báo (`EVENT_OUTSIDE_CHAPTER`, `EVENT_CHRONOLOGY`, `NO_PUBLISHED_LESSON`) chỉ in mã lỗi mà chưa có nút điều hướng nhanh tới chương/sự kiện bị cảnh báo.<br>- Trên Flutter Web (`dau-viet-mobile`), khi chạy ở môi trường headless hoặc origin dev bất kỳ, `google_sign_in_web` bắn `page_errors` nếu không được bọc guard an toàn. |

---

## 3. Thiết kế Giải pháp theo từng Phase

### Phase 4.1 — Lưu & Trả `unlockedLocations` / `unlockedDossiers` trong `GET /attempts/{id}/result` (BUG-01)

1. **Backend (`LearnerAttemptService.java` & `LessonResultResponse.java`):**
   - Trong `LearnerAttemptService.doComplete(UUID userId, LearnerAttempt a)`:
     - Sau khi `eventMilestones.recordIfEarned(...)` và `completionHooks` (`LocationUnlockEvaluator.onLessonCompleted`) hoàn tất, cập nhật `lesson_results.result_json` để lưu thêm 2 trường:
       - `"unlockedDossiers"`: mảng UUID các hồ sơ lịch sử vừa được mở khóa bởi attempt này.
       - `"unlockedLocations"`: mảng `UnlockedLocationCue` các địa điểm di tích vừa được mở khóa bởi attempt này.
   - Trong `LessonResultResponse.java` và `LearnerAttemptService.getResult(UUID userId, UUID attemptId)`:
     - Bổ sung 2 trường additive `List<UUID> newlyUnlockedDossiers` và `List<CompleteAttemptResponse.UnlockedLocationCue> newlyUnlockedLocations` (đọc từ `result_json` của `LessonResult`), giữ constructor cũ tương thích ngược cho các test hiện hữu.
2. **Mobile (`attempt_dtos.dart` & `lesson_result_screen.dart`):**
   - Trong `LessonResultDto.fromJson`: đọc `newlyUnlockedDossiers` và `newlyUnlockedLocations` từ top-level response của `GET /attempts/{id}/result` (hoặc fallback từ `result['unlockedDossiers']` / `result['unlockedLocations']`).
   - Giữ nguyên invariant: **Popup ăn mừng (`UnlockCelebrationDialog` + pháo giấy) chỉ phát 1 lần khi `isFreshCompletion == true`**, nhưng **2 banner tĩnh `UnlockedLocationBanner` và `_DossierUnlockBanner` trên màn Kết quả luôn hiển thị** kể cả khi học viên F5/reload trang hoặc mở lại từ lịch sử.

---

### Phase 4.2 — Sửa triệt để 15 lỗi TypeScript trên `dau-viet-admin` (BUG-02)

1. **`src/lib/dto/map-location.ts` (6 lỗi `TS2322`):**
   - Khai báo `const FALLBACK_PRESET_MAP: HeritagePresetMap = HERITAGE_PRESET_MAPS[5]!;` và dùng `HERITAGE_PRESET_MAPS[i] ?? FALLBACK_PRESET_MAP` tại các dòng 413, 425, 435, 446, 458, 460.
2. **`src/features/learning-path/learning-path.test.tsx` (3 lỗi `TS2322`, `TS2741`):**
   - Bổ sung `pathVersionId: "v-1"` vào mock `chapter` và `event.node`, đổi `createdAt: null` thành `createdAt: "2026-10-30T00:00:00Z"` theo đúng kiểu `PathDetail` trong `src/lib/dto/learning-path.ts`.
3. **`src/features/island-builder/island-builder-workspace.tsx` (2 lỗi):**
   - Trong `handleUndo`: kiểm tra `const prevSnap = undoStack[undoStack.length - 1]; if (!prevSnap) return; setSnapshot(prevSnap);`.
   - Đổi `<ErrorState title=... message=... onRetry=... />` thành `<ErrorState error={versionQuery.error} onRetry={() => void versionQuery.refetch()} />`.
4. **`src/features/island-builder/island-isometric-canvas.tsx` (2 lỗi `TS2532`):**
   - Bổ sung non-null / fallback guard khi truy cập phần tử mảng theo chỉ số.
5. **`src/features/island-builder/island-layout-list.tsx` (2 lỗi `TS2322`):**
   - Đổi `<ErrorState message=... onRetry=... />` thành `<ErrorState error={layoutsQuery.error} onRetry={() => void layoutsQuery.refetch()} />`.
   - Đổi `variant="primary"` thành `variant="default"` trên `<Button />`.

---

### Phase 4.3 — Bổ sung Loading/Error State cho `UnlockedLocationsCard` trong Lesson Builder (BUG-03)

1. **Trong `dau-viet-admin/src/features/lessons/builder/unlocked-locations-card.tsx`:**
   - Trên tiêu đề: hiển thị `Địa điểm mở khóa ({locationsQuery.isPending ? "…" : linkedLocations.length})`.
   - Khi `locationsQuery.isPending` là `true`: hiển thị khung loading `<div className="h-14 animate-pulse rounded border border-border bg-surface" />` thay vì câu `"Bài học này chưa gắn địa điểm mở khóa nào"`.
   - Khi `locationsQuery.isError` là `true`: hiển thị thông báo lỗi kèm nút `"Thử lại"` (`locationsQuery.refetch()`).

---

### Phase 4.4 — Huy hiệu `"MỞ KHÓA TỪ BÀI HỌC"` cho Media `UNLOCKED_ONLY` trên `LocationProfileSheet` (BUG-04)

1. **Trong `dau-viet-mobile/lib/features/map/presentation/widgets/location_profile_sheet.dart`:**
   - Sắp xếp danh sách media trong mỗi tab sao cho các tư liệu vừa mở khóa (`visibility == 'UNLOCKED_ONLY'`) hiển thị nổi bật kèm huy hiệu **`"🔓 MỞ KHÓA TỪ BÀI HỌC"`** (nền vàng ngự `DauVietColors.imperialGold.withValues(alpha: 0.18)`, viền `DauVietColors.imperialGold`, chữ `DauVietColors.inkHeading`), giúp học viên nhận diện ngay phần thưởng tư liệu độc quyền sau khi hoàn thành Bài học A.

---

### Phase 4.5 — Nút điều hướng nhanh trong Kiểm toán Lộ trình & Guard Google Sign-In Web (BUG-05)

1. **Trong `dau-viet-admin/src/features/learning-path/path-validation.tsx` & `path-builder.tsx`:**
   - Truyền callback `onSelectTarget?: (targetId: string) => void` vào `PathValidation` để mỗi dòng lỗi/cảnh báo có `targetId` hiển thị nút `"Đi tới mục này →"`, tự động chọn đúng chương/sự kiện tương ứng trên `PathBuilder` và đóng hộp thoại.
2. **Trong `dau-viet-mobile/lib/features/auth/` (Google Sign-In Web):**
   - Bọc an toàn quá trình khởi tạo GSI button / plugin trên Web để không ném unhandled exception ra `window.onerror` khi chạy kiểm thử tự động trên cổng local bất kỳ.

---

## 4. Tiêu chí Nghiệm thu (Acceptance Gates)

1. **`npx tsc --noEmit` (`dau-viet-admin`):** **0 lỗi** trên toàn bộ dự án (giảm từ 15 lỗi xuống 0).
2. **`npx vitest run` (`dau-viet-admin`):** **100% test files pass**, 0 lỗi MSW.
3. **`.\mvnw.cmd test` (`dau-viet-backend`):** **100% unit + WebMvc tests pass**, kèm unit test mới xác nhận `GET /api/v1/attempts/{id}/result` trả về `newlyUnlockedLocations` & `newlyUnlockedDossiers` đã lưu trong `lesson_results`.
4. **`flutter analyze --no-pub` & `flutter test` (`dau-viet-mobile`):** **0 issues** analyze, **100% widget/integration tests pass**, kèm test xác nhận reload `LessonResultScreen` vẫn hiển thị `UnlockedLocationBanner` và `_DossierUnlockBanner`.
