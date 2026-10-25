"use client";

import { useMutation } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import { toUserMessage } from "@/lib/api-error";
import type { ReconcileResult } from "@/lib/dto/gamification";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

/**
 * Panel đối soát + bảo trì phần thưởng (GAME-06) — nâng cấp từ
 * RewardBackfillButton: thêm batchSize + confirm dialog + result card
 * hiển thị itemsGranted/usersScanned/batches thật từ backend.
 * Cả hai thao tác chỉ chạy khi admin bấm — KHÔNG tự động.
 */
export function ReconcilePanel() {
  const [batchSize, setBatchSize] = useState("200");
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [backfillMsg, setBackfillMsg] = useState<string | null>(null);
  const [result, setResult] = useState<ReconcileResult | null>(null);
  const [reconcileErr, setReconcileErr] = useState<string | null>(null);

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
    mutationFn: (size: number) =>
      apiFetch<ReconcileResult>(
        `/admin/rewards/reconcile-unlocks${toQuery({ batchSize: size })}`,
        { method: "POST" },
      ),
    onSuccess: (res) => {
      setResult(res);
      setReconcileErr(null);
    },
    onError: (err) => {
      setResult(null);
      setReconcileErr(toUserMessage(err));
    },
  });

  const parsedSize = Number(batchSize);
  const sizeValid =
    Number.isInteger(parsedSize) && parsedSize >= 1 && parsedSize <= 5000;

  const runReconcile = () => {
    if (!sizeValid) return;
    setConfirmOpen(true);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Bảo trì phần thưởng</CardTitle>
        <CardDescription>
          Hai thao tác server-side chạy thủ công, idempotent — an toàn chạy
          lại nhiều lần.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <Button
            type="button"
            variant="secondary"
            onClick={() => backfill.mutate()}
            disabled={backfill.isPending}
            className="w-fit"
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

        <div className="flex flex-col gap-2 border-t border-border pt-4">
          <div className="flex items-end gap-3">
            <div className="flex w-36 flex-col gap-1">
              <Label htmlFor="batchSize">Kích thước batch</Label>
              <Input
                id="batchSize"
                type="number"
                min={1}
                max={5000}
                value={batchSize}
                onChange={(e) => setBatchSize(e.target.value)}
              />
            </div>
            <Button
              type="button"
              variant="secondary"
              onClick={runReconcile}
              disabled={reconcile.isPending || !sizeValid}
            >
              {reconcile.isPending
                ? "Đang đối soát..."
                : "Đối soát vật phẩm chưa nhận"}
            </Button>
          </div>
          {!sizeValid && (
            <p role="alert" className="text-xs text-error">
              Batch size phải là số nguyên từ 1 đến 5000.
            </p>
          )}
          <p className="text-xs text-ink-muted">
            Cấp vật phẩm cho học viên đã đủ điều kiện mở khóa nhưng chưa nhận
            (do rule được tạo hoặc đổi sau khi họ hoàn thành). Chỉ cấp phần
            thiếu — không thu hồi vật phẩm đã có, không cấp lại EXP/điểm.
          </p>
          {reconcileErr && (
            <p role="alert" className="text-sm text-error">{reconcileErr}</p>
          )}
          {result && (
            <div className="grid grid-cols-3 gap-3 rounded-md border border-border bg-surface-subtle p-3">
              <div>
                <p className="text-2xl font-semibold text-ink">
                  {result.itemsGranted}
                </p>
                <p className="text-xs text-ink-muted">Vật phẩm đã cấp</p>
              </div>
              <div>
                <p className="text-2xl font-semibold text-ink">
                  {result.usersScanned ?? "—"}
                </p>
                <p className="text-xs text-ink-muted">Học viên đã quét</p>
              </div>
              <div>
                <p className="text-2xl font-semibold text-ink">
                  {result.batches ?? "—"}
                </p>
                <p className="text-xs text-ink-muted">Số batch</p>
              </div>
            </div>
          )}
        </div>
      </CardContent>

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title="Chạy đối soát vật phẩm?"
        description={`Hệ thống sẽ quét học viên theo từng batch ${parsedSize} người và cấp vật phẩm còn thiếu theo rule đang bật. Thao tác idempotent nhưng có thể mất vài phút trên dữ liệu lớn.`}
        confirmLabel="Chạy đối soát"
        onConfirm={() => reconcile.mutate(parsedSize)}
      />
    </Card>
  );
}
