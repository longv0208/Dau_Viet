import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { Skeleton } from "@/components/ui/skeleton";

import { VersionsBrowser } from "@/features/versions/versions-browser";

export const metadata = { title: "Phiên bản — Dấu Việt CMS" };

/**
 * /versions — lịch sử phiên bản theo bài học. Backend exposes versions
 * per-lesson only (/admin/lessons/{id}/versions) so the page is a
 * lesson picker + list; `?lesson=<id>` deep-links one lesson's history.
 */
export default async function VersionsPage({
  searchParams,
}: {
  searchParams: Promise<{ lesson?: string }>;
}) {
  const { lesson } = await searchParams;
  return (
    <div className="flex flex-col gap-4">
      <PageHeader eyebrow="QUẢN TRỊ · PHIÊN BẢN" title="Phiên bản" />
      <Suspense fallback={<Skeleton className="h-64 w-full" />}>
        <VersionsBrowser initialLessonId={lesson} />
      </Suspense>
    </div>
  );
}
