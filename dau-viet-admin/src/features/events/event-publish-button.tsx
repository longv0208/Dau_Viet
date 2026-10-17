"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { AdminEventDetail } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";

/**
 * Publish a DRAFT event — POST /admin/events/{id}/publish (no request body).
 * Bài học chỉ xuất bản được khi sự kiện đã PUBLISHED, nên đây là điều kiện
 * tiên quyết của toàn bộ luồng publish bài học.
 */
export function EventPublishButton({ event }: { event: AdminEventDetail }) {
  const qc = useQueryClient();
  const [confirmOpen, setConfirmOpen] = useState(false);

  const publish = useMutation({
    mutationFn: () =>
      apiFetch<AdminEventDetail>(`/admin/events/${event.id}/publish`, { method: "POST" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.events.detail(event.id) });
      qc.invalidateQueries({ queryKey: ["events"] });
    },
  });

  if (event.status !== "DRAFT") return null;

  return (
    <div className="flex items-center gap-2">
      <Button variant="secondary" onClick={() => setConfirmOpen(true)} disabled={publish.isPending}>
        {publish.isPending ? "Đang xuất bản..." : "Xuất bản sự kiện"}
      </Button>
      {publish.isError && (
        <p role="alert" className="text-xs text-error">
          {toUserMessage(publish.error)}
        </p>
      )}
      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Xuất bản sự kiện này?"
        description="Sự kiện sẽ hiển thị với học viên và cho phép các bài học thuộc sự kiện được xuất bản. Không thể hoàn tác ngoài việc lưu trữ."
        confirmLabel="Xuất bản"
        onConfirm={() => publish.mutate()}
      />
    </div>
  );
}
