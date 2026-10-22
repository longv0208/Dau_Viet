"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { ApiClientError, toUserMessage } from "@/lib/api-error";
import type { AdminEventDetail } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";

/**
 * Archive (ẩn) an event — POST /admin/events/{id}/archive.
 * Ẩn khỏi học viên (learner APIs 404 cho mọi status ≠ PUBLISHED), đồng thời
 * khóa sửa/publish phía admin. Backend từ chối (409 EVENT_IN_USE) khi sự
 * kiện còn bài học chưa lưu trữ — UI hiển thị message thân thiện cho case đó.
 */
export function EventArchiveButton({ event }: { event: AdminEventDetail }) {
  const qc = useQueryClient();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [inUse, setInUse] = useState(false);

  const archive = useMutation({
    mutationFn: () =>
      apiFetch<AdminEventDetail>(`/admin/events/${event.id}/archive`, { method: "POST" }),
    onSuccess: () => {
      setInUse(false);
      qc.invalidateQueries({ queryKey: qk.events.detail(event.id) });
      qc.invalidateQueries({ queryKey: ["events"] });
    },
    onError: (err) => {
      if (err instanceof ApiClientError && err.status === 409) setInUse(true);
    },
  });

  if (event.status === "ARCHIVED") return null;

  return (
    <div className="flex items-center gap-2">
      <Button
        variant="secondary"
        className="text-error hover:bg-error/10"
        onClick={() => setConfirmOpen(true)}
        disabled={archive.isPending}
      >
        {archive.isPending ? "Đang lưu trữ..." : "Lưu trữ sự kiện"}
      </Button>
      {archive.isError && !inUse && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(archive.error)}
        </p>
      )}
      {inUse && (
        <p role="alert" className="max-w-xs text-xs text-error">
          Sự kiện còn bài học chưa lưu trữ — hãy lưu trữ các bài học trước rồi thử lại.
        </p>
      )}
      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Lưu trữ sự kiện này?"
        description="Sự kiện sẽ bị ẩn khỏi học viên và không thể chỉnh sửa hay xuất bản lại. Toàn bộ bài học thuộc sự kiện cần được lưu trữ trước."
        confirmLabel="Lưu trữ"
        destructive
        onConfirm={() => archive.mutate()}
      />
    </div>
  );
}
