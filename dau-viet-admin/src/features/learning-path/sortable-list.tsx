"use client";

import { ArrowDown, ArrowUp, GripVertical } from "lucide-react";
import { useState, type ReactNode } from "react";
import { Button } from "@/components/ui/button";

const MIME = "application/x-dauviet-path-order";

/** Only the handle starts a drag; scope prevents dropping a lesson into a chapter list. */
export function SortableList<T>({ items, scope, getId, disabled, onReorder, children }: {
  items: T[];
  scope: string;
  getId: (item: T) => string;
  disabled: boolean;
  onReorder: (ids: string[]) => Promise<unknown>;
  children: (item: T, index: number) => ReactNode;
}) {
  const [announcement, setAnnouncement] = useState("");
  const move = async (from: number, to: number) => {
    if (disabled || from === to || from < 0 || to < 0 || to >= items.length) return;
    const ids = items.map(getId);
    const [id] = ids.splice(from, 1);
    ids.splice(to, 0, id);
    const result = await onReorder(ids);
    if (result != null) setAnnouncement(`Đã lưu thứ tự mới, vị trí ${to + 1}.`);
  };
  return (
    <>
      <ol className="space-y-2">
        {items.map((item, index) => (
          <li key={getId(item)} className="rounded-lg border border-border bg-white"
            onDragOver={(event) => { if (!disabled && event.dataTransfer.types.includes(MIME)) event.preventDefault(); }}
            onDrop={(event) => {
              event.preventDefault(); event.stopPropagation();
              if (disabled) return;
              try {
                const drag = JSON.parse(event.dataTransfer.getData(MIME)) as { scope: string; id: string };
                if (drag.scope === scope) void move(items.findIndex((row) => getId(row) === drag.id), index);
              } catch { /* Ignore external drags and malformed payloads. */ }
            }}>
            <div className="flex min-w-0 items-start gap-1 p-2">
              {!disabled && <button type="button" draggable aria-label={`Kéo mục ${index + 1} để sắp xếp`}
                className="flex size-11 shrink-0 cursor-grab items-center justify-center rounded text-ink-muted active:cursor-grabbing"
                onDragStart={(event) => { event.stopPropagation(); event.dataTransfer.effectAllowed = "move"; event.dataTransfer.setData(MIME, JSON.stringify({ scope, id: getId(item) })); }}>
                <GripVertical className="size-4" aria-hidden />
              </button>}
              <div className="min-w-0 flex-1">{children(item, index)}</div>
            </div>
            {!disabled && <div className="flex justify-end gap-1 border-t border-border px-2 py-1">
              <Button type="button" variant="ghost" size="icon" disabled={index === 0} aria-label={`Đưa mục ${index + 1} lên`} onClick={() => void move(index, index - 1)}><ArrowUp aria-hidden /></Button>
              <Button type="button" variant="ghost" size="icon" disabled={index === items.length - 1} aria-label={`Đưa mục ${index + 1} xuống`} onClick={() => void move(index, index + 1)}><ArrowDown aria-hidden /></Button>
            </div>}
          </li>
        ))}
      </ol>
      <p className="sr-only" aria-live="polite">{announcement}</p>
    </>
  );
}
