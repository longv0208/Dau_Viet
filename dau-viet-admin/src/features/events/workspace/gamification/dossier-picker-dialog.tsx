"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminDossierSummary, DossierType } from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { Dialog } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { StatusChip } from "@/components/status-chip";

const TYPE_LABELS: Record<DossierType, string> = {
  PERSON: "Nhân vật",
  LOCATION: "Địa điểm",
  ARTIFACT: "Hiện vật",
  CONTEXT: "Bối cảnh",
};

/** Dialog chọn dossier PUBLISHED để link vào event. */
export function DossierPickerDialog({
  open,
  onOpenChange,
  excludeIds,
  onPick,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  excludeIds: Set<string>;
  onPick: (dossier: AdminDossierSummary) => void;
}) {
  const [q, setQ] = useState("");
  const [type, setType] = useState("");

  const params = { status: "PUBLISHED", q: q || undefined, type: type || undefined, size: 50 };
  const list = useQuery({
    queryKey: qk.dossiers.list(params),
    queryFn: () =>
      apiFetch<PageResponse<AdminDossierSummary>>(
        `/admin/dossiers${toQuery(params)}`,
      ),
    enabled: open,
  });

  const rows = (list.data?.content ?? []).filter((d) => !excludeIds.has(d.id));

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Liên kết hồ sơ lịch sử"
      description="Chỉ hồ sơ đã PUBLISHED mới liên kết được — learner sẽ mở khi hoàn thành sự kiện."
      size="lg"
    >
      <div className="mb-3 flex gap-2">
        <Input
          placeholder="Tìm theo tên hoặc mã…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <Select value={type} onChange={(e) => setType(e.target.value)}>
          <option value="">Mọi loại</option>
          {Object.entries(TYPE_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </Select>
      </div>
      {list.isPending && <p className="text-sm text-ink-muted">Đang tải…</p>}
      {list.isError && (
        <p className="text-sm text-error">Không tải được danh sách.</p>
      )}
      {!list.isPending && rows.length === 0 && (
        <p className="text-sm text-ink-muted">
          Không có hồ sơ PUBLISHED phù hợp.
        </p>
      )}
      <ul className="flex flex-col divide-y divide-border rounded-md border border-border">
        {rows.map((d) => (
          <li
            key={d.id}
            className="flex items-center justify-between gap-3 px-3 py-2"
          >
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-ink">
                {d.title}
                <span className="ml-2 text-xs text-ink-muted">
                  {d.canonicalCode}
                </span>
              </p>
              <p className="text-xs text-ink-muted">
                {TYPE_LABELS[d.dossierType]} · v{d.dossierVersion}
              </p>
            </div>
            <div className="flex items-center gap-2">
              <StatusChip status={d.status} />
              <Button variant="secondary" onClick={() => onPick(d)}>
                Chọn
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </Dialog>
  );
}
