# TASK-0033: Issue #44 — Cải tổ Giao diện & Luồng Quản trị Web Admin (`dau-viet-admin`)

## Mục tiêu
Giải quyết triệt để 3 vấn đề UX/UI trên `dau-viet-admin` theo [Issue #44](https://github.com/longv0208/Dau_Viet/issues/44):
1. **Sửa lỗi font chữ tiếng Việt:** Thay thế `Press_Start_2P` (`subsets: ["latin"]`, gây lỗi nhảy font/lệch dấu tiếng Việt ở tiêu đề bảng, `StampSeal`, `ChapterBadge`) và chuẩn hóa `SectionEyebrow` sang `Be Vietnam Pro` / `Noto Serif`, bổ sung `JetBrains Mono` (`vietnamese`) cho mã kỹ thuật.
2. **Thu gọn Sidebar theo cấu trúc Cây Cha – Con rõ ràng:** Giữ `Sự kiện` (`/events`) làm mục cha trung tâm và gom toàn bộ thành phần thuộc về Sự kiện (*Bài học, Mẫu bài học, Bằng chứng, Hoạt họa lịch sử, Hồ sơ lịch sử, Địa điểm di tích, Phiên bản*) thành **nhánh con thụt lề** ngay dưới `Sự kiện` (có đóng/mở); đưa *Cửa hàng Đảo Di Sản* làm nhánh con của *Đảo Di Sản*; kết hợp `<WorkspaceHubTabs />` và checklist tiến độ trong Event Workspace.
3. **Bổ sung Hướng dẫn từng bước (Onboarding) & Chú thích ngữ cảnh:**
   - Thêm **Sơ đồ Quy trình Biên tập 4 Bước (`OnboardingWorkflowCard`)** trên `/dashboard`.
   - Thêm khung chỉ dẫn `<PageGuideBanner />` ở đầu các trang quản trị chính.
   - Bổ sung `headerTooltip` cho `DataTable` và các liên kết hành động trực tiếp (`+ Gắn vào bài học / sự kiện →` tới `/items/[id]#unlock-rule`, `Cấu hình trên Shop →` tới `/island-shop`).

## Kế hoạch chi tiết
Xem [`plans/261030-issue-44-admin-web-ux-overhaul/plan.md`](../../plans/261030-issue-44-admin-web-ux-overhaul/plan.md).

## Ánh xạ Kiểm chứng (AC → Check)
| AC | Kiểm tra | Kỳ vọng |
|---|---|---|
| AC-1 | Kiểm tra `layout.tsx`, `data-table.tsx`, `atoms/*` + `atoms.test.tsx` + trình duyệt | Không còn `Press_Start_2P` trên văn bản tiếng Việt; chữ có dấu hiển thị đồng nhất, sắc nét |
| AC-2 | `admin-shell.test.tsx` + kiểm tra điều hướng Tree Sidebar & `WorkspaceHubTabs` | Sidebar hiển thị rõ nhánh cha `Sự kiện` + 7 nhánh con và `Đảo Di Sản` + nhánh con `Cửa hàng`; đóng/mở mượt, không gãy route |
| AC-3 | `dashboard-page.test.tsx` + kiểm tra `/dashboard` | Hiển thị Sơ đồ Quy trình Biên tập 4 Bước kèm nút CTA tới từng màn hình |
| AC-4 | `items-table.test.tsx` + kiểm tra các trang chính | Có `PageGuideBanner`, tooltip giải thích cột bảng và link trực tiếp tới nơi cấu hình mở khóa |
| AC-5 | `npx tsc --noEmit` + `npx vitest run` + smoke trình duyệt | 0 lỗi TypeScript mới, 100% test suite pass, giao diện không vỡ bố cục |
