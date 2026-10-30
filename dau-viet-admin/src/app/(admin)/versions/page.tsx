import { Suspense } from "react";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Skeleton } from "@/components/ui/skeleton";

import { VersionsBrowser } from "@/features/versions/versions-browser";

export const metadata = { title: "Phiên bản — Dấu Việt CMS" };

export default async function VersionsPage({
  searchParams,
}: {
  searchParams: Promise<{ lesson?: string }>;
}) {
  const { lesson } = await searchParams;
  return (
    <div className="flex flex-col gap-4">
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · PHIÊN BẢN"
        title="Lịch sử Phiên bản Bài học"
        description="Tra cứu các snapshot bất biến đã xuất bản của từng bài học."
      />
      <PageGuideBanner
        storageKey="versions"
        title="Phiên bản xuất bản"
        purpose="Mỗi lần xuất bản bài học sẽ tạo ra một phiên bản bất biến (immutable snapshot) để không làm hỏng lượt học đang diễn ra của học viên."
        appSurface="Học viên luôn học trên phiên bản đã xuất bản mới nhất tại thời điểm bắt đầu lượt học."
        nextStep="Chọn một bài học bên dưới để xem chi tiết nội dung từng phiên bản."
        links={[{ href: "/lessons", label: "Danh sách Bài học" }]}
      />
      <Suspense fallback={<Skeleton className="h-64 w-full" />}>
        <VersionsBrowser initialLessonId={lesson} />
      </Suspense>
    </div>
  );
}
