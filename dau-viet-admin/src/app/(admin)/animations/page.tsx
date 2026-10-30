import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { AnimationLibrary } from "@/features/animations/animation-library";

export const metadata = { title: "Hoạt họa lịch sử — Dấu Việt CMS" };

export default function AnimationsPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · HOẠT HỌA"
        title="Thư viện hoạt họa lịch sử"
        description="Tải lên và quản lý hoạt họa tương tác HTML — một tệp .html tự chứa cho mỗi cảnh."
      />
      <PageGuideBanner
        storageKey="animations"
        title="Hoạt họa lịch sử HTML"
        purpose="Quản lý các sa bàn và cảnh diễn biến tương tác (.html) gắn với Sự kiện để nhúng vào hoạt động Đọc bối cảnh (READ)."
        appSurface="Hiển thị trực tiếp dưới dạng khung tương tác WebView trong Sổ tay Thám tử Lịch sử trên ứng dụng."
        nextStep="Tải tệp .html lên, kiểm tra xem trước và nhấn Xuất bản để cảnh xuất hiện trong trình chọn của Bài học."
        links={[{ href: "/events", label: "Không gian Sự kiện" }]}
      />
      <AnimationLibrary />
    </div>
  );
}
