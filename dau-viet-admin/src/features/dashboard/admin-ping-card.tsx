"use client";

import { useQuery } from "@tanstack/react-query";
import { CheckCircle2, XCircle } from "lucide-react";

import { ApiClientError } from "@/lib/api-error";
import { apiFetch } from "@/lib/api-client";
import { qk } from "@/lib/query-keys";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Kết nối backend</CardTitle>
      </CardHeader>
      <CardContent>
        {query.isPending ? (
          <Skeleton className="h-5 w-40" />
        ) : query.isError ? (
          <div className="flex flex-col gap-1">
            <p className="flex items-center gap-2 text-sm font-medium text-error">
              <XCircle className="size-4" aria-hidden /> Backend: Lỗi
            </p>
            {traceId && <p className="text-xs text-ink-muted">Mã lỗi: {traceId}</p>}
          </div>
        ) : (
          <p
            className={
              ok
                ? "flex items-center gap-2 text-sm font-medium text-success"
                : "flex items-center gap-2 text-sm font-medium text-error"
            }
          >
            {ok ? (
              <>
                <CheckCircle2 className="size-4" aria-hidden /> Backend: Hoạt động
              </>
            ) : (
              <>
                <XCircle className="size-4" aria-hidden /> Backend: Phản hồi bất thường
              </>
            )}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
