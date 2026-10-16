"use client";

import { ArrowDown, ArrowUp, Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { genItemId } from "../draft-id";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Item extends Record<string, unknown> {
  id: string;
  label: string;
}

/** Reads items preserving unknown item-level keys. */
function readItems(config: Record<string, unknown> | undefined): Item[] {
  const raw = config?.items;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((x) => x && typeof x === "object")
    .map((x) => {
      const r = x as Record<string, unknown>;
      return { ...r, id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") } as Item;
    })
    .filter((x) => x.id);
}

/**
 * DRAG_ORDER — config.items[{id,label}] ≥2; expectedOrder auto-mirrors the
 * authored order (the order the admin lists IS the correct order).
 */
export function DragOrderEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const items = readItems(activity.config);

  function write(next: Item[]) {
    onChange({
      config: {
        ...activity.config,
        items: next.map((x) => ({ ...x, id: x.id, label: x.label })),
        expectedOrder: next.map((x) => x.id),
      },
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-2">
        <Label>Các bước/sự kiện — theo đúng thứ tự (thứ tự này là đáp án đúng)</Label>
        {items.map((it, i) => (
          <div key={it.id} className="flex items-center gap-2">
            <span className="w-6 text-center text-xs text-ink-muted">{i + 1}</span>
            <Input
              value={it.label}
              disabled={readOnly}
              placeholder={`Bước ${i + 1}`}
              onChange={(e) =>
                write(items.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)))
              }
            />
            {!readOnly && (
              <>
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  disabled={i === 0}
                  aria-label={`Chuyển bước ${i + 1} lên`}
                  onClick={() => {
                    const next = [...items];
                    [next[i - 1], next[i]] = [next[i]!, next[i - 1]!];
                    write(next);
                  }}
                >
                  <ArrowUp className="size-3.5" />
                </Button>
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  disabled={i === items.length - 1}
                  aria-label={`Chuyển bước ${i + 1} xuống`}
                  onClick={() => {
                    const next = [...items];
                    [next[i], next[i + 1]] = [next[i + 1]!, next[i]!];
                    write(next);
                  }}
                >
                  <ArrowDown className="size-3.5" />
                </Button>
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  disabled={items.length <= 2}
                  aria-label={`Xoá bước ${i + 1}`}
                  onClick={() => write(items.filter((_, j) => j !== i))}
                >
                  <Trash2 className="size-3.5" />
                </Button>
              </>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            className="self-start"
            size="sm"
            onClick={() =>
              write([...items, { id: genItemId(items.map((x) => x.id)), label: "" }])
            }
          >
            <Plus className="size-4" /> Thêm bước
          </Button>
        )}
        {items.length < 2 && (
          <p role="alert" className="text-xs text-error">Cần ít nhất 2 bước/sự kiện.</p>
        )}
      </div>
    </div>
  );
}
