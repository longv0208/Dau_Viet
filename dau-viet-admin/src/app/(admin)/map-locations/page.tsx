import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { Skeleton } from "@/components/ui/skeleton";
import { MapLocationsWorkspace } from "@/features/map-locations/map-locations-page";

export const metadata = { title: "Địa điểm di tích — Dấu Việt CMS" };

export default function MapLocationsRoutePage() {
  return (
    <div className="space-y-4">
      <PageHeader
        eyebrow="QUẢN TRỊ · ĐỊA ĐIỂM DI TÍCH"
        title="Địa điểm di tích & Bản đồ Lịch sử"
        description="Quản lý độc lập các địa điểm di tích, liên kết đa sự kiện (PRIMARY / RELATED), quy tắc mở khóa đa bài học (NONE / ANY / ALL) và thư viện tư liệu Media."
      />
      <Suspense fallback={<Skeleton className="h-96 w-full rounded-xl" />}>
        <MapLocationsWorkspace />
      </Suspense>
    </div>
  );
}
