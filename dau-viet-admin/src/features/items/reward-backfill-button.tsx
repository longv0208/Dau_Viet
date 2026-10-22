"use client";

import { useMutation } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import { Button } from "@/components/ui/button";

/**
 * Hai thao tác bảo trì server-side (chỉ chạy khi admin bấm, KHÔNG tự động):
 * - Bổ sung thưởng: POST /admin/rewards/backfill — ghi bút toán EXP /
 *   History Points còn thiếu cho attempt COMPLETED cũ (idempotent theo
 *   cause_key, không tạo thêm lần hai).
 * - Đối soát vật phẩm: POST /admin/rewards/reconcile-unlocks — đánh giá
 *   mọi rule ACTIVE trên tiến độ hiện có và cấp item learner đã đủ điều
 *   kiện nhưng chưa nhận (vì rule được tạo/sửa SAU khi họ hoàn thành).
 *   Idempotent qua UNIQUE(user_id, item_id) — không nhân đôi, không
 *   thu hồi vật phẩm đã cấp, không cấp EXP/điểm.
 */
export function RewardBackfillButton() {
  const [backfillMsg, setBackfillMsg] = useState<string | null>(null);
  const [reconcileMsg, setReconcileMsg] = useState<string | null>(null);

  const backfill = useMutation({
    mutationFn: () =>
      apiFetch<{ attemptsGranted: number }>("/admin/rewards/backfill", {
        method: "POST",
      }),
    onSuccess: (res) =>
      setBackfillMsg(
        res.attemptsGranted > 0
          ? `Đã bổ sung thưởng cho ${res.attemptsGranted} lượt hoàn thành.`
          : "Không còn lượt hoàn thành nào thiếu thưởng.",
      ),
    onError: (err) => setBackfillMsg(toUserMessage(err)),
  });

  const reconcile = useMutation({
    mutationFn: () =>
      apiFetch<{ itemsGranted: number }>(
        "/admin/rewards/reconcile-unlocks",
        { method: "POST" },
      ),
    onSuccess: (res) =>
      setReconcileMsg(
        res.itemsGranted > 0
          ? `Đã cấp ${res.itemsGranted} vật phẩm cho học viên đủ điều kiện.`
          : "Không có vật phẩm nào thiếu cần cấp.",
      ),
    onError: (err) => setReconcileMsg(toUserMessage(err)),
  });

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <Button
          type="button"
          variant="secondary"
          onClick={() => backfill.mutate()}
          disabled={backfill.isPending}
        >
          {backfill.isPending
            ? "Đang xử lý..."
            : "Bổ sung thưởng lượt hoàn thành cũ"}
        </Button>
        <p className="text-xs text-ink-muted">
          Ghi bù EXP và History Points cho attempt đã hoàn thành trước khi
          tính năng ra mắt. Không ảnh hưởng vật phẩm.
        </p>
        {backfillMsg && (
          <p className="text-sm text-ink-muted">{backfillMsg}</p>
        )}
      </div>

      <div className="flex flex-col gap-2">
        <Button
          type="button"
          variant="secondary"
          onClick={() => reconcile.mutate()}
          disabled={reconcile.isPending}
        >
          {reconcile.isPending
            ? "Đang xử lý..."
            : "Đối soát vật phẩm chưa nhận"}
        </Button>
        <p className="text-xs text-ink-muted">
          Cấp vật phẩm cho học viên đã đủ điều kiện mở khóa nhưng chưa nhận
          (do rule được tạo hoặc đổi sau khi họ hoàn thành). Chỉ cấp phần
          thiếu — không thu hồi vật phẩm đã có, không cấp lại EXP/điểm.
        </p>
        {reconcileMsg && (
          <p className="text-sm text-ink-muted">{reconcileMsg}</p>
        )}
      </div>
    </div>
  );
}
