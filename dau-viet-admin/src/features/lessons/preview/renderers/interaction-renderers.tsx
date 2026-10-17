"use client";

import { ArrowDown, ArrowUp } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";

import type { PreviewActivityProps } from "./types";

interface Item {
  id: string;
  label: string;
}

function readItems(raw: unknown): Item[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((o) => o && typeof o === "object")
    .map((o) => {
      const r = o as Record<string, unknown>;
      return { id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") };
    })
    .filter((o) => o.id);
}

function readStrings(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.map((x) => String(x ?? "")).filter(Boolean) : [];
}

/**
 * EVIDENCE_SELECT — visibleEvidenceIds list (multi-pick demo).
 * requiredEvidenceIds / evidenceRefs are hidden keys the projection stripped.
 */
export function EvidenceSelectActivityView({ activity }: PreviewActivityProps) {
  const ids = readStrings(activity.config?.visibleEvidenceIds);
  const minRequired =
    typeof activity.config?.minRequired === "number" ? activity.config.minRequired : null;
  const [picked, setPicked] = useState<string[]>([]);
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">
        Chọn bằng chứng{minRequired ? ` (tối thiểu ${minRequired})` : ""}:
      </p>
      <div className="flex flex-col gap-2">
        {ids.map((id, i) => (
          <label
            key={id}
            className={
              "flex items-center gap-2.5 rounded-md border px-3 py-2 text-sm " +
              (picked.includes(id) ? "border-brand bg-brand/5" : "border-border")
            }
          >
            <input
              type="checkbox"
              checked={picked.includes(id)}
              onChange={() =>
                setPicked((p) =>
                  p.includes(id) ? p.filter((x) => x !== id) : [...p, id],
                )
              }
              className="size-4 accent-brand"
            />
            Bằng chứng {i + 1}
            <span className="ml-auto font-mono text-[10px] text-ink-muted">{id.slice(0, 8)}…</span>
          </label>
        ))}
        {ids.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa khai báo bằng chứng nào.</p>
        )}
      </div>
    </div>
  );
}

/** MATCHING — pairs[{left,right}] rendered as two columns to connect. */
export function MatchingActivityView({ activity }: PreviewActivityProps) {
  const raw = activity.config?.pairs;
  const pairs = (Array.isArray(raw) ? raw : [])
    .filter((p) => p && typeof p === "object")
    .map((p) => {
      const r = p as { left?: Record<string, unknown>; right?: Record<string, unknown> };
      return {
        left: String(r.left?.label ?? r.left?.text ?? ""),
        right: String(r.right?.label ?? r.right?.text ?? ""),
      };
    });
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Nối các cặp tương ứng:</p>
      {pairs.length > 0 ? (
        <div className="flex flex-col gap-2">
          {pairs.map((p, i) => (
            <div key={i} className="flex items-center gap-3 text-sm">
              <span className="flex-1 rounded-md border border-border px-3 py-2">{p.left}</span>
              <span className="text-ink-muted">↔</span>
              <span className="flex-1 rounded-md border border-dashed border-border px-3 py-2 text-ink-muted">
                {p.right}
              </span>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-sm italic text-ink-muted">Chưa có cặp nối nào.</p>
      )}
      <p className="text-[11px] text-ink-muted">
        Xem trước — thứ tự đúng không được hiển thị.
      </p>
    </div>
  );
}

/** REASONING_CONNECT — nodes + allowedRelations, schema-level display. */
export function ReasoningConnectActivityView({ activity }: PreviewActivityProps) {
  const nodes = readItems(activity.config?.nodes);
  const relations = readStrings(activity.config?.allowedRelations);
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Nối các khái niệm bằng quan hệ hợp lý:</p>
      <div className="flex flex-wrap gap-1.5">
        {nodes.map((n) => (
          <span
            key={n.id}
            className="rounded-full border border-border bg-surface px-2.5 py-1 text-xs text-ink"
          >
            {n.label}
          </span>
        ))}
        {nodes.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa có khái niệm nào.</p>
        )}
      </div>
      {relations.length > 0 && (
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-xs text-ink-muted">Quan hệ cho phép:</span>
          {relations.map((r) => (
            <span
              key={r}
              className="rounded-full bg-brand/10 px-2 py-0.5 text-[11px] font-medium text-brand"
            >
              {r}
            </span>
          ))}
        </div>
      )}
      <p className="text-[11px] text-ink-muted">
        Hoạt động tương tác — xem trước chỉ hiển thị cấu trúc.
      </p>
    </div>
  );
}

/** DRAG_ORDER — items list with up/down buttons (local reorder only). */
export function DragOrderActivityView({ activity }: PreviewActivityProps) {
  const [items, setItems] = useState<Item[]>(() => readItems(activity.config?.items));

  function move(i: number, dir: -1 | 1) {
    setItems((prev) => {
      const j = i + dir;
      if (j < 0 || j >= prev.length) return prev;
      const next = [...prev];
      [next[i], next[j]] = [next[j]!, next[i]!];
      return next;
    });
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Sắp xếp theo đúng thứ tự:</p>
      {items.length > 0 ? (
        <div className="flex flex-col gap-1.5">
          {items.map((it, i) => (
            <div
              key={it.id}
              className="flex items-center gap-2 rounded-md border border-border bg-white px-2 py-1.5"
            >
              <span className="w-6 text-center text-xs font-medium text-ink-muted">{i + 1}</span>
              <span className="flex-1 text-sm text-ink">{it.label}</span>
              <Button
                variant="secondary"
                className="h-6 w-6 p-0"
                aria-label={`Đưa "${it.label}" lên`}
                disabled={i === 0}
                onClick={() => move(i, -1)}
              >
                <ArrowUp className="size-3" />
              </Button>
              <Button
                variant="secondary"
                className="h-6 w-6 p-0"
                aria-label={`Đưa "${it.label}" xuống`}
                disabled={i === items.length - 1}
                onClick={() => move(i, 1)}
              >
                <ArrowDown className="size-3" />
              </Button>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-sm italic text-ink-muted">Chưa có mục nào để sắp xếp.</p>
      )}
      <p className="text-[11px] text-ink-muted">
        Xem trước — thứ tự đúng (expectedOrder) không được hiển thị.
      </p>
    </div>
  );
}
