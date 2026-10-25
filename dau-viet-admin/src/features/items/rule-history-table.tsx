"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { AdminRuleHistoryEntry } from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable, type Column } from "@/components/data-table";
import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

/**
 * Lịch sử revision rule của item (GAME-06) — mọi phiên bản đã publish,
 * revision mới nhất trước, kèm grantCount provenance (user_inventory
 * trỏ về unlock_rule_id) + dialog xem AST.
 */
export function RuleHistoryTable({ itemId }: { itemId: string }) {
  const [preview, setPreview] = useState<AdminRuleHistoryEntry | null>(null);

  const query = useQuery({
    queryKey: qk.ruleHistory(itemId),
    queryFn: () =>
      apiFetch<AdminRuleHistoryEntry[]>(`/admin/items/${itemId}/rule/history`),
  });

  const columns: Column<AdminRuleHistoryEntry>[] = [
    {
      key: "revision",
      header: "Revision",
      cell: (r) => (
        <span className="font-medium">
          #{r.revision}
          {r.active && (
            <span className="ml-2 rounded-full bg-success/20 px-2 py-0.5 text-xs">
              đang dùng
            </span>
          )}
        </span>
      ),
    },
    {
      key: "ruleType",
      header: "Loại",
      cell: (r) => (
        <span>
          <code className="text-xs">{r.ruleType}</code>{" "}
          <span className="text-xs text-ink-muted">(schema v{r.ruleVersion})</span>
        </span>
      ),
    },
    {
      key: "createdAt",
      header: "Thời điểm",
      cell: (r) => new Date(r.createdAt).toLocaleString("vi-VN"),
    },
    {
      key: "grantCount",
      header: "Đã cấp",
      cell: (r) => r.grantCount,
    },
    {
      key: "condition",
      header: "Điều kiện",
      cell: (r) =>
        r.ruleVersion === 2 && r.conditionJson ? (
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => setPreview(r)}
          >
            Xem AST
          </Button>
        ) : (
          <span className="text-xs text-ink-muted">
            {r.ruleType === "LESSON_COMPLETED"
              ? "Bài học chỉ định"
              : `Ngưỡng ≥ ${r.threshold ?? "?"}`}
          </span>
        ),
    },
  ];

  return (
    <Card>
      <CardHeader>
        <CardTitle>Lịch sử điều kiện</CardTitle>
      </CardHeader>
      <CardContent>
        <DataTable
          columns={columns}
          rows={query.data ?? []}
          rowKey={(r) => r.id}
          loading={query.isPending}
          error={query.error ?? undefined}
          onRetry={() => query.refetch()}
          emptyTitle="Chưa có phiên bản nào"
          emptyDescription="Điều kiện đầu tiên sẽ xuất hiện sau khi lưu."
        />
      </CardContent>

      <Dialog
        open={preview !== null}
        onOpenChange={(open) => !open && setPreview(null)}
        title={`Điều kiện revision #${preview?.revision ?? ""}`}
        description="AST đã lưu trong database — đọc-only."
      >
        <pre className="overflow-x-auto rounded-md bg-surface-subtle p-3 text-xs text-ink">
          {preview ? JSON.stringify(preview.conditionJson, null, 2) : ""}
        </pre>
      </Dialog>
    </Card>
  );
}
