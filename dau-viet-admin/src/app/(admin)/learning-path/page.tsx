import { PageGuideBanner } from "@/components/page-guide-banner";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { PathVersions } from "@/features/learning-path/path-versions";

export const metadata = { title: "Bản đồ Dấu Ấn — Dấu Việt CMS" };
export default function LearningPathPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="map-and-path" />
      <PageGuideBanner
        storageKey="learning-path"
        title="Bản đồ Dấu Ấn (Lộ trình học chính)"
        purpose="Sắp xếp thứ tự các Đại thời kỳ → Thời kỳ → Sự kiện (Bắt buộc / Tham khảo) để định hình lộ trình học tập tuần tự."
        appSurface="Hiển thị trực tiếp tại tab 'Hành trình' (/journey) — luồng học tập chính của học viên trên ứng dụng."
        nextStep="Tạo bản nháp từ phiên bản hiện tại, thêm Sự kiện đã xuất bản vào chương phù hợp rồi nhấn Xuất bản lộ trình."
        links={[
          { href: "/events", label: "Danh sách Sự kiện" },
          { href: "/map-locations", label: "Địa điểm di tích (/map)" },
        ]}
      />
      <PathVersions />
    </div>
  );
}
