"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { Evidence } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { EvidenceForm } from "./evidence-form";

/** Loads GET /admin/evidences/{id}, renders the form + lifecycle actions. */
export function EvidenceEditorPage({ evidenceId }: { evidenceId: string }) {
  const qc = useQueryClient();
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const query = useQuery({
    queryKey: qk.evidences.detail(evidenceId),
    queryFn: () => apiFetch<Evidence>(`/admin/evidences/${evidenceId}`),
  });

  const approveMut = useMutation({
    mutationFn: () =>
      apiFetch<Evidence>(`/admin/evidences/${evidenceId}/approve`, { method: "POST" }),
    onSuccess: () => {
      setActionError(null);
      qc.invalidateQueries({ queryKey: qk.evidences.detail(evidenceId) });
      qc.invalidateQueries({ queryKey: ["evidences"] });
    },
    onError: (err) => setActionError(toUserMessage(err)),
  });

  const archiveMut = useMutation({
    mutationFn: () =>
      apiFetch<Evidence>(`/admin/evidences/${evidenceId}/archive`, {
        method: "POST",
        body: JSON.stringify({ expectedRowVersion: query.data?.rowVersion }),
      }),
    onSuccess: () => {
      setActionError(null);
      qc.invalidateQueries({ queryKey: qk.evidences.detail(evidenceId) });
      qc.invalidateQueries({ queryKey: ["evidences"] });
    },
    onError: (err) => {
      setActionError(
        err instanceof ApiClientError && err.isConflict
          ? "Không thể lưu trữ — bằng chứng đang được tham chiếu bởi phiên bản bài học đã xuất bản."
          : toUserMessage(err),
      );
    },
  });

  if (query.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }
  if (query.isError) return <ErrorState error={query.error} onRetry={() => query.refetch()} />;

  const ev = query.data;
  const archived = ev.status === "ARCHIVED";

  return (
    <div className="flex flex-col gap-4">
      <PaperCard className="flex flex-wrap items-center gap-3 p-3.5">
        <StatusChip status={ev.status} />
        {ev.status === "APPROVED" && (
          <StampSeal variant="success" label="CHỨNG THỰC" className="scale-90" />
        )}
        <span className="text-xs text-ink-muted">
          Cập nhật {new Date(ev.updatedAt).toLocaleString("vi-VN")}
        </span>
        <div className="ml-auto flex gap-2">
          {ev.status === "DRAFT" && (
            <Button
              variant="secondary"
              onClick={() => approveMut.mutate()}
              disabled={approveMut.isPending || archiveMut.isPending}
            >
              {approveMut.isPending ? "Đang phê duyệt..." : "Phê duyệt"}
            </Button>
          )}
          {!archived && (
            <Button
              variant="secondary"
              onClick={() => setArchiveOpen(true)}
              disabled={approveMut.isPending || archiveMut.isPending}
            >
              Lưu trữ
            </Button>
          )}
        </div>
      </PaperCard>

      {actionError && (
        <p role="alert" className="rounded-md bg-error/10 px-3 py-2 text-sm text-error">
          {actionError}
        </p>
      )}

      {archived ? (
        <p className="rounded-md bg-surface-alt px-3 py-2 text-sm text-ink">
          Bằng chứng đã lưu trữ — chỉ xem, không chỉnh sửa.
        </p>
      ) : null}

      <EvidenceForm initial={ev} />

      <ConfirmDialog
        open={archiveOpen}
        onOpenChange={setArchiveOpen}
        title="Lưu trữ bằng chứng?"
        description="Bằng chứng sẽ chuyển sang trạng thái lưu trữ. Không thể lưu trữ nếu đang được phiên bản bài học đã xuất bản tham chiếu."
        confirmLabel="Lưu trữ"
        destructive
        onConfirm={() => archiveMut.mutate()}
      />
    </div>
  );
}
