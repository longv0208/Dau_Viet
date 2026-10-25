"use client";

import { ArrowDown, ArrowUp, X } from "lucide-react";

import type { AdminEventDossierLink } from "@/lib/dto/gamification";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";

const TYPE_LABELS: Record<string, string> = {
  PERSON: "Nhân vật",
  LOCATION: "Địa điểm",
  ARTIFACT: "Hiện vật",
  CONTEXT: "Bối cảnh",
};

/** Bảng dossier đang link — reorder up/down + remove (dirty state o parent). */
export function DossierLinkTable({
  rows,
  onMove,
  onRemove,
}: {
  rows: AdminEventDossierLink[];
  onMove: (index: number, dir: -1 | 1) => void;
  onRemove: (dossierId: string) => void;
}) {
  const columns: Column<AdminEventDossierLink>[] = [
    {
      key: "order",
      header: "Thứ tự",
      cell: (d) => (
        <div className="flex items-center gap-1">
          <span className="w-6 text-ink-muted">{d.displayOrder}</span>
          <button
            type="button"
            aria-label="Lên"
            className="rounded p-1 hover:bg-surface-alt"
            onClick={() => onMove(rows.indexOf(d), -1)}
          >
            <ArrowUp className="size-4" />
          </button>
          <button
            type="button"
            aria-label="Xuống"
            className="rounded p-1 hover:bg-surface-alt"
            onClick={() => onMove(rows.indexOf(d), 1)}
          >
            <ArrowDown className="size-4" />
          </button>
        </div>
      ),
    },
    {
      key: "title",
      header: "Hồ sơ",
      cell: (d) => (
        <div>
          <p className="font-medium">{d.title}</p>
          <p className="text-xs text-ink-muted">{d.canonicalCode}</p>
        </div>
      ),
    },
    {
      key: "type",
      header: "Loại",
      cell: (d) => TYPE_LABELS[d.dossierType] ?? d.dossierType,
    },
    {
      key: "status",
      header: "Trạng thái",
      cell: (d) => <StatusChip status={d.status} />,
    },
    {
      key: "rm",
      header: "",
      cell: (d) => (
        <button
          type="button"
          aria-label={`Gỡ ${d.title}`}
          className="rounded p-1.5 text-ink-muted hover:bg-error/10 hover:text-error"
          onClick={() => onRemove(d.dossierId)}
        >
          <X className="size-4" />
        </button>
      ),
    },
  ];

  return (
    <DataTable
      columns={columns}
      rows={rows}
      rowKey={(d) => d.dossierId}
      emptyTitle="Chưa liên kết hồ sơ"
      emptyDescription="Liên kết hồ sơ để learner mở khoá khi hoàn thành sự kiện."
    />
  );
}
