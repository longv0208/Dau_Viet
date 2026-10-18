import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { Skeleton } from "@/components/ui/skeleton";

import { VersionDetailView } from "@/features/versions/version-detail-view";

export const metadata = { title: "Chi tiết phiên bản — Dấu Việt CMS" };

/**
 * /versions/{lessonId}/{versionId} — read-only view of one immutable
 * published snapshot (GET /admin/lessons/{id}/versions/{versionId}).
 */
export default async function VersionDetailPage({
  params,
}: {
  params: Promise<{ lessonId: string; versionId: string }>;
}) {
  const { lessonId, versionId } = await params;
  return (
    <div className="flex flex-col gap-4">
      <PageHeader title="Chi tiết phiên bản" />
      <Suspense fallback={<Skeleton className="h-[30rem] w-full max-w-[390px]" />}>
        <VersionDetailView lessonId={lessonId} versionId={versionId} />
      </Suspense>
    </div>
  );
}
