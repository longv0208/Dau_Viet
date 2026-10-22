"use client";

import { useMutation } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import { Button } from "@/components/ui/button";

/**
 * POST /admin/rewards/backfill — bổ sung thưởng first-completion cho các
 * attempt đã COMPLETED trước khi tính năng ra mắt. Idempotent: server
 * chỉ ghi bút toán còn thiếu (cause_key chặn trùng), chạy lại an toàn.
 */
export function RewardBackfillButton() {
  const [message, setMessage] = useState<string | null>(null);

  const backfill = useMutation({
    mutationFn: () =>
      apiFetch<{ attemptsGranted: number }>("/admin/rewards/backfill", {
        method: "POST",
      }),
    onSuccess: (res) =>
      setMessage(
        res.attemptsGranted > 0
          ? `Đã bổ sung thưởng cho ${res.attemptsGranted} lượt hoàn thành.`
          : "Không còn lượt hoàn thành nào thiếu thưởng.",
      ),
    onError: (err) => setMessage(toUserMessage(err)),
  });

  return (
    <div className="flex flex-col gap-2">
      <Button
        type="button"
        variant="secondary"
        onClick={() => backfill.mutate()}
        disabled={backfill.isPending}
      >
        {backfill.isPending ? "Đang xử lý..." : "Bổ sung thưởng lượt hoàn thành cũ"}
      </Button>
      {message && <p className="text-sm text-ink-muted">{message}</p>}
    </div>
  );
}
