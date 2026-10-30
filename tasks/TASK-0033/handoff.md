# TASK-0033 — Handoff: Issue #44 (Cải tổ Giao diện & Luồng Quản trị Web Admin)

## Kết quả thực thi
Đã hoàn thành toàn bộ 5 Phase theo kế hoạch `plans/261030-issue-44-admin-web-ux-overhaul/plan.md`:

1. **Chuẩn hóa Typography tiếng Việt (`AC-1`)**:
   - Gỡ bỏ `Press_Start_2P` (`subsets: ["latin"]`) khỏi `src/app/layout.tsx` và toàn bộ các component trong `src/`.
   - Cấu hình `Be_Vietnam_Pro` (`--font-sans`), `Noto_Serif` (`--font-display`) và `JetBrains_Mono` (`--font-mono`, `subsets: ["vietnamese", "latin"]`) hỗ trợ đầy đủ dấu tiếng Việt.
   - Chuyển header bảng (`DataTable`, `IslandShopManager`) và `SectionEyebrow` sang `font-sans` sắc nét; chuyển `StampSeal`, `ChapterBadge` và các chỉ số thống kê (`AdminPingCard`, `EventOverviewTab`, `PathVersions`) sang `font-display font-bold tabular-nums`.
2. **Tái cấu trúc Tree Sidebar theo quan hệ Cha – Con & Hub Navigation (`AC-2`)**:
   - Tổ chức lại `src/components/admin-shell.tsx` thành 3 nhóm chức năng (`Bắt đầu & Biên tập chính`, `Kho dùng chung`, `Gamification & Đảo Di Sản`).
   - Giữ **`Sự kiện` (`/events`)** làm nhánh gốc trung tâm và đặt 7 màn hình thành phần làm **nhánh con thụt lề** ngay dưới `Sự kiện`: *Bài học (`/lessons`), Mẫu bài học (`/templates`), Bằng chứng (`/evidence`), Hoạt họa lịch sử (`/animations`), Hồ sơ lịch sử (`/dossiers`), Địa điểm di tích (`/map-locations`), Phiên bản (`/versions`)*.
   - Đặt *Cửa hàng Đảo Di Sản (`/island-shop`)* làm nhánh con của *Đảo Di Sản (`/island-builder`)*.
   - Hỗ trợ đóng/mở nhánh con linh hoạt (tự động mở khi điều hướng vào nhánh con và vẫn cho phép thu gọn thủ công).
   - Tạo `<WorkspaceHubTabs />` (`src/components/workspace-hub-tabs.tsx`) để chuyển đổi nhanh giữa các màn hình cùng cụm.
3. **Hướng dẫn Bắt đầu 4 Bước (Onboarding) trên `/dashboard` (`AC-3`)**:
   - Tạo `<OnboardingWorkflowCard />` (`src/features/dashboard/onboarding-workflow-card.tsx`) hướng dẫn 4 bước biên tập từ *Bước 1: Tạo Sự kiện & Địa điểm* → *Bước 2: Chuẩn bị Tư liệu, Bằng chứng & Hồ sơ* → *Bước 3: Soạn Bài học & Gắn phần thưởng* → *Bước 4: Đưa vào Bản đồ Dấu Ấn & Xuất bản*.
   - Bổ sung khung quy trình 4 bước tương ứng ngay trong tab Tổng quan của `EventWorkspace` (`event-overview-tab.tsx`).
4. **Chú thích Ngữ cảnh (`PageGuideBanner`) & Liên kết Cấu hình Trực tiếp (`AC-4`)**:
   - Tạo `<PageGuideBanner />` (`src/components/page-guide-banner.tsx`) có thể thu gọn/mở rộng (lưu `localStorage` an toàn với SSR) và tích hợp vào 14 trang quản trị chính.
   - Mở rộng `DataTable` hỗ trợ `headerTooltip` giải thích ý nghĩa nghiệp vụ từng cột trên `EventsTable` và `ItemsTable`.
   - Tại `ItemsTable` (`src/features/items/items-table.tsx`), bổ sung liên kết trực tiếp **`+ Gắn vào bài học / sự kiện →`** và **`Sửa điều kiện mở khóa →`** trỏ tới `/items/${id}#unlock-rule` (khớp với `<Card id="unlock-rule">` trong `item-detail.tsx`) cùng liên kết **`Cấu hình bán tại Shop →`** (`/island-shop`).

## Kiểm chứng & Review (`AC-5`)
| Kiểm tra | Kết quả |
|---|---|
| `npx vitest run` (`dau-viet-admin`) | **51/51 test files pass (300/300 tests)** |
| `npx tsc --noEmit` (`dau-viet-admin`) | **0 lỗi mới** trên toàn bộ file sửa/tạo mới (chỉ còn 12 lỗi pre-existing ở `map-location.ts` và `island-builder/*`) |
| `git diff --check` | **Sạch (0 lỗi whitespace/format)** |
| Independent Code Review (`Issue44CodeReviewer`) | **Pass** — phát hiện 1 lỗi P2 khi thu gọn nhánh cha lúc đang đứng ở route con; đã sửa bằng `useEffect([pathname])` và bổ sung test kiểm chứng trong `admin-shell.test.tsx`. |

## Hành động tiếp theo
- Chờ người dùng kiểm tra và ủy quyền commit/push trên nhánh `feat/issue-44-admin-web-ux-overhaul`.
