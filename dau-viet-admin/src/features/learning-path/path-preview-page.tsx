"use client";

import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionEyebrow } from "@/components/atoms/section-eyebrow";
import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/error-state";
import { StatusChip } from "@/components/status-chip";
import { PathPreview } from "./path-preview";
import { usePathVersion } from "./use-learning-path";

export function PathPreviewPage({ versionId }: { versionId: string }) {
  const query = usePathVersion(versionId);
  if (query.isPending) return <p role="status">Đang tải bản xem trước…</p>;
  if (!query.data) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />;
  return <div className="flex h-[calc(100dvh-104px)] min-h-[420px] flex-col overflow-hidden">
    <header className="flex shrink-0 flex-wrap items-center justify-between gap-3 pb-4">
      <div><div className="mb-1.5"><SectionEyebrow color="brand">QUẢN TRỊ · XEM TRƯỚC LỘ TRÌNH</SectionEyebrow></div><h1 className="font-display text-2xl font-semibold text-ink">Xem trước hành trình</h1><p className="mt-1 text-sm text-ink-muted">Dữ liệu từ phiên bản quản trị đã chọn.</p></div>
      <div className="flex items-center gap-2"><StatusChip status={query.data.version.status} /><Button asChild variant="secondary"><Link href={`/learning-path/${versionId}/edit`}><ArrowLeft aria-hidden />{query.data.version.status === "DRAFT" ? "Tiếp tục thiết kế" : "Chi tiết phiên bản"}</Link></Button></div>
    </header>
    <PaperCard className="min-h-0 flex-1 overflow-y-auto overscroll-contain p-3"><div className="mx-auto max-w-md rounded-3xl border-2 border-heading bg-surface-alt p-2 shadow-pixel"><PathPreview detail={query.data} /></div></PaperCard>
  </div>;
}
