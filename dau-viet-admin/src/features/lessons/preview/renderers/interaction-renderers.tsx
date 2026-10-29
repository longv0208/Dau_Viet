"use client";

import { ArrowDown, ArrowUp } from "lucide-react";
import { useMemo, useState } from "react";

import { Button } from "@/components/ui/button";

import { evidenceLabel, findEvidence } from "./resolve-evidence";
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
 * Build the two independent MATCHING columns. Prefers the projected
 * leftItems/rightItems; falls back to deriving them from raw pairs[] on an
 * admin (un-projected) snapshot so version detail still renders.
 */
function deriveColumns(config: PreviewActivityProps["activity"]["config"]) {
  const left = readItems(config?.leftItems);
  const right = readItems(config?.rightItems);
  if (left.length > 0 || right.length > 0) return { left, right };
  const pairs = Array.isArray(config?.pairs) ? config.pairs : [];
  const l: Item[] = [];
  const r: Item[] = [];
  for (const p of pairs) {
    if (!p || typeof p !== "object") continue;
    const lp = "left" in p ? p.left : undefined;
    const rp = "right" in p ? p.right : undefined;
    const li = lp && typeof lp === "object" && "id" in lp
      ? { id: String(lp.id), label: String("label" in lp ? lp.label ?? "" : "") }
      : null;
    const ri = rp && typeof rp === "object" && "id" in rp
      ? { id: String(rp.id), label: String("label" in rp ? rp.label ?? "" : "") }
      : null;
    if (li?.id) l.push(li);
    if (ri?.id) r.push(ri);
  }
  return { left: l, right: r };
}

/**
 * EVIDENCE_SELECT — visibleEvidenceIds list (multi-pick demo).
 * requiredEvidenceIds / evidenceRefs are hidden keys the projection stripped.
 */
export function EvidenceSelectActivityView({ activity, evidence }: PreviewActivityProps) {
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
        {ids.map((id, i) => {
          const doc = findEvidence(evidence, id);
          const source = doc?.source;
          const sourceLine = [source?.title, source?.author]
            .filter(Boolean)
            .join(" — ");
          return (
            <label
              key={id}
              className={
                "flex items-start gap-2.5 rounded-md border px-3 py-2 text-sm " +
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
                className="mt-0.5 size-4 accent-brand"
              />
              <span className="flex flex-col gap-0.5">
                <span className="font-medium text-ink">
                  {evidenceLabel(evidence, id, `Bằng chứng ${i + 1}`)}
                </span>
                {doc?.description && (
                  <span className="line-clamp-2 text-xs text-ink-muted">
                    {doc.description}
                  </span>
                )}
                {sourceLine && (
                  <span className="text-[11px] italic text-ink-muted">
                    Nguồn: {sourceLine}
                  </span>
                )}
              </span>
            </label>
          );
        })}
        {ids.length === 0 && (
          <p className="text-sm italic text-ink-muted">Chưa khai báo bằng chứng nào.</p>
        )}
      </div>
    </div>
  );
}

/**
 * MATCHING — two INDEPENDENT columns (leftItems/rightItems). The projection
 * removed `pairs`/`correctPairs` so row position can never encode the answer;
 * learners connect a left id to a right id, preview only shows the columns.
 */
export function MatchingActivityView({ activity }: PreviewActivityProps) {
  // Learner projection supplies leftItems/rightItems with `pairs` removed.
  // A raw admin snapshot only carries pairs[] — derive the two columns from
  // it so the version-detail view renders instead of a blank column.
  const derived = useMemo(() => deriveColumns(activity.config), [activity.config]);
  const left = derived.left;
  const right = derived.right;
  const [selectedLeft, setSelectedLeft] = useState<string | null>(null);
  const [links, setLinks] = useState<Record<string, string>>({});

  function pickRight(rightId: string) {
    if (!selectedLeft) return;
    setLinks((prev) => {
      const next = { ...prev };
      for (const k of Object.keys(next)) {
        if (next[k] === rightId) delete next[k];
      }
      next[selectedLeft] = rightId;
      return next;
    });
    setSelectedLeft(null);
  }

  const linkedRight = new Set(Object.values(links));
  const hasColumns = left.length > 0 || right.length > 0;

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-ink">Nối các cặp tương ứng:</p>
      {hasColumns ? (
        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1.5">
            {left.map((item) => {
              const linked = links[item.id];
              const active = selectedLeft === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setSelectedLeft(active ? null : item.id)}
                  className={
                    "rounded-md border px-3 py-2 text-left text-sm " +
                    (active
                      ? "border-brand bg-brand/10 text-ink"
                      : linked
                        ? "border-brand/50 bg-brand/5 text-ink"
                        : "border-border bg-white text-ink")
                  }
                >
                  {item.label || "(mục trống)"}
                </button>
              );
            })}
          </div>
          <div className="flex flex-col gap-1.5">
            {right.map((item) => {
              const used = linkedRight.has(item.id);
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => pickRight(item.id)}
                  disabled={!selectedLeft && !used}
                  className={
                    "rounded-md border px-3 py-2 text-left text-sm " +
                    (used
                      ? "border-brand/50 bg-brand/5 text-ink"
                      : "border-dashed border-border bg-white text-ink")
                  }
                >
                  {item.label || "(mục trống)"}
                </button>
              );
            })}
          </div>
        </div>
      ) : (
        <p className="text-sm italic text-ink-muted">Chưa có cặp nối nào.</p>
      )}
      {selectedLeft && (
        <p className="text-[11px] text-brand">Chọn mục bên phải để nối.</p>
      )}
      <p className="text-[11px] text-ink-muted">
        Xem trước — hai cột hiển thị độc lập, cặp đúng không được tiết lộ.
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
        Xem trước — thứ tự đúng không được hiển thị.
      </p>
    </div>
  );
}
