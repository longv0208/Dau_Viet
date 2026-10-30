"use client";

import { useQuery } from "@tanstack/react-query";
import { Activity, CheckCircle2, XCircle } from "lucide-react";

import { ApiClientError } from "@/lib/api-error";
import { apiFetch } from "@/lib/api-client";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Skeleton } from "@/components/ui/skeleton";

/** Backend health probe — GET /admin/ping. Honest: no fabricated metrics. */
export function AdminPingCard() {
  const query = useQuery({
    queryKey: qk.admin.ping(),
    queryFn: () => apiFetch<{ status: string }>("/admin/ping"),
  });

  const ok = query.data?.status === "ok";
  const traceId =
    query.error instanceof ApiClientError ? query.error.traceId : null;

  return (
    <PaperCard className="flex flex-col justify-between p-5">
      <SectionDivider
        eyebrow="HỆ THỐNG"
        eyebrowColor="brand"
        title="Kết nối máy chủ"
        className="mb-4"
      />
      <div>
        {query.isPending ? (
          <Skeleton className="h-10 w-40" />
        ) : query.isError ? (
          <div className="flex items-center justify-between gap-3">
            <div className="flex flex-col gap-1">
              <p className="font-display text-2xl font-bold text-chapter">OFFLINE</p>
              <p className="flex items-center gap-2 text-sm font-medium text-error">
                <XCircle className="size-4 text-brand" aria-hidden /> Máy chủ: Lỗi
              </p>
              {traceId && <p className="text-xs text-ink-muted">Mã tra cứu lỗi: {traceId}</p>}
            </div>
            <Activity className="size-8 text-brand" aria-hidden />
          </div>
        ) : (
          <div className="flex items-center justify-between gap-3">
            <div className="flex flex-col gap-1">
              <p className="font-display text-2xl font-bold text-chapter">{ok ? "ONLINE" : "WARN"}</p>
              <p
                className={
                  ok
                    ? "flex items-center gap-2 text-sm font-medium text-jade"
                    : "flex items-center gap-2 text-sm font-medium text-error"
                }
              >
                {ok ? (
                  <>
                    <CheckCircle2 className="size-4 text-jade" aria-hidden /> Máy chủ: Hoạt động
                  </>
                ) : (
                  <>
                    <XCircle className="size-4 text-brand" aria-hidden /> Máy chủ: Phản hồi bất thường
                  </>
                )}
              </p>
            </div>
            <Activity className={ok ? "size-8 text-jade" : "size-8 text-brand"} aria-hidden />
          </div>
        )}
      </div>
    </PaperCard>
  );
}
