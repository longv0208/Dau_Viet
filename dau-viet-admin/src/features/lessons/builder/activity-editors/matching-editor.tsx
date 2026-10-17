"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { genItemId } from "../draft-id";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Side extends Record<string, unknown> {
  id: string;
  label: string;
}
interface Pair {
  left: Side;
  right: Side;
}

/** Reads pairs preserving unknown keys inside left/right items. */
function readPairs(config: Record<string, unknown> | undefined): Pair[] {
  const raw = config?.pairs;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((p) => p && typeof p === "object")
    .map((p) => {
      const r = p as { left?: Record<string, unknown>; right?: Record<string, unknown> };
      return {
        left: {
          ...(r.left ?? {}),
          id: String(r.left?.id ?? ""),
          label: String(r.left?.label ?? r.left?.text ?? ""),
        } as Side,
        right: {
          ...(r.right ?? {}),
          id: String(r.right?.id ?? ""),
          label: String(r.right?.label ?? r.right?.text ?? ""),
        } as Side,
      };
    })
    .filter((p) => p.left.id && p.right.id);
}

/**
 * MATCHING — config.pairs[{left,right}] ≥2 with unique ids; correctPairs
 * auto-mirrors the declared pairs (left↔right is already the correct match).
 */
export function MatchingEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const pairs = readPairs(activity.config);
  const allIds = pairs.flatMap((p) => [p.left.id, p.right.id]);

  function write(next: Pair[]) {
    onChange({
      config: {
        ...activity.config,
        pairs: next.map((p) => ({
          left: { ...p.left, id: p.left.id, label: p.left.label },
          right: { ...p.right, id: p.right.id, label: p.right.label },
        })),
        correctPairs: next.map((p) => ({ left: p.left.id, right: p.right.id })),
      },
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-2">
        <Label>Các cặp ghép (trái ↔ phải là cặp đúng)</Label>
        {pairs.map((p, i) => (
          <div key={`${p.left.id}-${p.right.id}`} className="flex items-center gap-2">
            <Input
              value={p.left.label}
              disabled={readOnly}
              placeholder={`Vế trái ${i + 1}`}
              onChange={(e) =>
                write(
                  pairs.map((x, j) =>
                    j === i ? { ...x, left: { ...x.left, label: e.target.value } } : x,
                  ),
                )
              }
            />
            <span className="text-ink-muted">↔</span>
            <Input
              value={p.right.label}
              disabled={readOnly}
              placeholder={`Vế phải ${i + 1}`}
              onChange={(e) =>
                write(
                  pairs.map((x, j) =>
                    j === i ? { ...x, right: { ...x.right, label: e.target.value } } : x,
                  ),
                )
              }
            />
            {!readOnly && (
              <Button
                variant="secondary"
                className="h-9 px-2"
                disabled={pairs.length <= 2}
                aria-label={`Xoá cặp ${i + 1}`}
                onClick={() => write(pairs.filter((_, j) => j !== i))}
              >
                <Trash2 className="size-3.5" />
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            className="self-start"
            size="sm"
            onClick={() =>
              write([
                ...pairs,
                {
                  left: { id: genItemId(allIds), label: "" },
                  right: { id: genItemId([...allIds, "x"]), label: "" },
                },
              ])
            }
          >
            <Plus className="size-4" /> Thêm cặp
          </Button>
        )}
        {pairs.length < 2 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 2 cặp ghép để tạo hoạt động nối.
          </p>
        )}
        {pairs.some((p) => !p.left.label.trim() || !p.right.label.trim()) && (
          <p role="alert" className="text-xs text-error">
            Có cặp chưa nhập đủ hai vế — điền đủ hoặc xoá bớt.
          </p>
        )}
      </div>
    </div>
  );
}
