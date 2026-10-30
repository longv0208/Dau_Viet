import { Suspense } from "react";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { MapLocationsWorkspace } from "@/features/map-locations/map-locations-page";

export const metadata = { title: "Địa điểm di tích — Dấu Việt CMS" };

export default function MapLocationsRoutePage() {
  return (
    <div className="space-y-4">
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · ĐỊA ĐIỂM DI TÍCH"
        title="Địa điểm di tích & Bản đồ Lịch sử"
        description="Quản lý các địa điểm di tích lịch sử, liên kết đa sự kiện (PRIMARY / RELATED), quy tắc mở khóa bài học (NONE / ANY / ALL) và tư liệu Media."
      />
      <PageGuideBanner
        storageKey="map-locations"
        title="Địa điểm di tích"
        purpose="Định nghĩa tọa độ di tích, liên kết với Sự kiện và cấu hình điều kiện mở khóa địa điểm sau khi học viên hoàn thành bài học (ANY / ALL)."
        appSurface="Hiển thị thành các ghim di tích trên tab 'Bản đồ' (/map) và mở Hồ sơ Di tích (LocationProfileSheet) khi học viên khám phá."
        nextStep="Bạn cũng có thể gắn nhanh địa điểm ngay trong tab 'Thông tin & địa điểm' của từng Sự kiện."
        links={[
          { href: "/events", label: "Không gian Sự kiện" },
          { href: "/learning-path", label: "Bản đồ Dấu Ấn" },
        ]}
      />
      <Suspense fallback={<Skeleton className="h-96 w-full rounded-xl" />}>
        <MapLocationsWorkspace />
      </Suspense>
    </div>
  );
}
