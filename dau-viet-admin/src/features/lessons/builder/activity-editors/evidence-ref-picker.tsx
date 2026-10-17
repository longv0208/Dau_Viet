"use client";

import { useQuery } from "@tanstack/react-query";
import { Plus, Search, X } from "lucide-react";
import { useMemo, useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { Evidence } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import { EVIDENCE_TYPE_LABELS, evidenceTypeLabel } from "@/features/evidence/evidence-labels";

interface Props {
  /** Currently selected evidence ids (config order = display order). */
  selectedIds: string[];
  /** Prefer evidence of the lesson's event; other events still selectable. */
  eventId?: string;
  readOnly?: boolean;
  /** Field label + helper shown above the chip list. */
  label: string;
  hint?: string;
  required?: boolean;
  onChange: (ids: string[]) => void;
}

/**
 * Reusable evidence multi-select with search + event filter. Replaces raw
 * UUID textareas — emits the same string[] id list the backend expects.
 */
export function EvidenceRefPicker({
  selectedIds,
  eventId,
  readOnly,
  label,
  hint,
  required,
  onChange,
}: Props) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [filterEventId, setFilterEventId] = useState<string>(eventId ?? "");

  const query = useQuery({
    queryKey: qk.evidences.list({ q: q || undefined, eventId: filterEventId || undefined, size: 50 }),
    queryFn: () =>
      apiFetch<PageResponse<Evidence>>(
        `/admin/evidences${toQuery({ q: q || undefined, eventId: filterEventId || undefined, size: 50, status: "APPROVED" })}`,
      ),
    enabled: open,
  });
  // Also load DRAFT evidence (authors still need to pick unapproved work).
  const draftQuery = useQuery({
    queryKey: qk.evidences.list({ q: q || undefined, eventId: filterEventId || undefined, size: 50, status: "DRAFT" }),
    queryFn: () =>
      apiFetch<PageResponse<Evidence>>(
        `/admin/evidences${toQuery({ q: q || undefined, eventId: filterEventId || undefined, size: 50, status: "DRAFT" })}`,
      ),
    enabled: open,
  });
  // Resolve already-selected ids (they may be on another page/status).
  const selectedQuery = useQuery({
    queryKey: ["evidences", "byIds", selectedIds],
    queryFn: () => Promise.all(selectedIds.map((id) => apiFetch<Evidence>(`/admin/evidences/${id}`).catch(() => null))),
    enabled: selectedIds.length > 0,
  });
  const byId = useMemo(() => {
    const m = new Map<string, Evidence>();
    for (const e of selectedQuery.data ?? []) if (e) m.set(e.id, e);
    return m;
  }, [selectedQuery.data]);

  const items = useMemo(() => {
    const seen = new Set<string>();
    const out: Evidence[] = [];
    for (const e of [...(query.data?.content ?? []), ...(draftQuery.data?.content ?? [])]) {
      if (!seen.has(e.id)) {
        seen.add(e.id);
        out.push(e);
      }
    }
    return out;
  }, [query.data, draftQuery.data]);

  function toggle(id: string) {
    if (selectedIds.includes(id)) onChange(selectedIds.filter((x) => x !== id));
    else onChange([...selectedIds, id]);
  }

  return (
    <div className="flex flex-col gap-1.5">
      <Label>{label}{required ? " *" : ""}</Label>
      {hint && <p className="text-xs text-ink-muted">{hint}</p>}

      {/* Selected chips */}
      <div className="flex flex-wrap gap-1.5">
        {selectedIds.map((id) => {
          const e = byId.get(id);
          return (
            <span
              key={id}
              className="inline-flex items-center gap-1 rounded-md border border-border bg-white px-2 py-1 text-xs text-ink"
              title={e ? `${e.title} — ${e.sourceTitle ?? "chưa có nguồn"}` : "Bằng chứng không còn tồn tại"}
            >
              {e ? e.title.slice(0, 40) : "Đã xoá"}
              {!readOnly && (
                <button
                  type="button"
                  aria-label={`Gỡ ${e?.title ?? "bằng chứng"}`}
                  className="text-ink-muted hover:text-error"
                  onClick={() => onChange(selectedIds.filter((x) => x !== id))}
                >
                  <X className="size-3" />
                </button>
              )}
            </span>
          );
        })}
        {selectedIds.length === 0 && (
          <span className="text-xs text-ink-muted">Chưa chọn bằng chứng nào.</span>
        )}
      </div>

      {!readOnly && (
        <Button
          variant="secondary"
          size="sm"
          className="self-start"
          onClick={() => setOpen((o) => !o)}
          aria-expanded={open}
        >
          <Plus className="size-4" /> Chọn bằng chứng
        </Button>
      )}

      {open && !readOnly && (
        <div className="rounded-md border border-brand/40 bg-brand/5 p-3">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <div className="relative min-w-56 flex-1">
              <Search className="absolute left-2.5 top-2.5 size-4 text-ink-muted" aria-hidden />
              <Input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="Tìm bằng chứng theo tiêu đề…"
                className="pl-8"
              />
            </div>
            <Select
              value={filterEventId}
              onChange={(e) => setFilterEventId(e.target.value)}
              className="w-auto"
              aria-label="Lọc theo sự kiện"
            >
              {eventId ? <option value={eventId}>Sự kiện của bài học</option> : null}
              <option value="">Tất cả sự kiện</option>
            </Select>
          </div>

          <div className="max-h-56 overflow-y-auto rounded-md border border-border bg-white">
            {(query.isPending && draftQuery.isPending) && (
              <p className="p-3 text-xs text-ink-muted">Đang tải bằng chứng…</p>
            )}
            {items.length === 0 && !(query.isPending || draftQuery.isPending) && (
              <p className="p-3 text-xs text-ink-muted">
                Không tìm thấy bằng chứng — tạo mới ở trang Bằng chứng lịch sử.
              </p>
            )}
            {items.map((e) => {
              const checked = selectedIds.includes(e.id);
              const Icon = EVIDENCE_TYPE_LABELS[e.evidenceType]?.icon;
              return (
                <label
                  key={e.id}
                  className={
                    "flex cursor-pointer items-start gap-2 border-b border-border/60 px-3 py-2 text-sm last:border-0 " +
                    (checked ? "bg-brand/10" : "hover:bg-surface")
                  }
                >
                  <input
                    type="checkbox"
                    className="mt-1 size-3.5 shrink-0 accent-brand"
                    checked={checked}
                    onChange={() => toggle(e.id)}
                  />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-1.5 font-medium text-ink">
                      {Icon && <Icon className="size-3.5 shrink-0 text-ink-muted" aria-hidden />}
                      <span className="truncate">{e.title}</span>
                    </span>
                    <span className="block text-xs text-ink-muted">
                      {evidenceTypeLabel(e.evidenceType)} ·{" "}
                      {e.sourceTitle ? e.sourceTitle.slice(0, 50) : "Chưa có nguồn"}
                      {e.status === "DRAFT" ? " · nháp" : ""}
                    </span>
                  </span>
                </label>
              );
            })}
          </div>
        </div>
      )}

      {required && selectedIds.length === 0 && (
        <p role="alert" className="text-xs text-error">
          Cần chọn ít nhất 1 bằng chứng để xuất bản.
        </p>
      )}
    </div>
  );
}
