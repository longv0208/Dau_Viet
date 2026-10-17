"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { genItemId } from "../draft-id";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Node extends Record<string, unknown> {
  id: string;
  label: string;
}

/** Preset quan hệ phổ biến — người dùng vẫn có thể nhập quan hệ tuỳ ý. */
const RELATION_PRESETS = ["nguyen-nhan", "ket-qua", "dong-thoi", "mau-thuan"] as const;
const RELATION_LABELS: Record<string, string> = {
  "nguyen-nhan": "nguyên nhân",
  "ket-qua": "kết quả",
  "dong-thoi": "đồng thời",
  "mau-thuan": "mâu thuẫn",
};

/** Reads nodes preserving unknown item-level keys. */
function readNodes(config: Record<string, unknown> | undefined): Node[] {
  const raw = config?.nodes;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((n) => n && typeof n === "object")
    .map((n) => {
      const r = n as Record<string, unknown>;
      return { ...r, id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") } as Node;
    })
    .filter((n) => n.id);
}

function readRelations(config: Record<string, unknown> | undefined): string[] {
  const raw = config?.allowedRelations;
  return Array.isArray(raw) ? raw.map((r) => String(r ?? "")).filter(Boolean) : [];
}

/**
 * REASONING_CONNECT — config.nodes[{id,label}] ≥2 + config.allowedRelations[]
 * ≥1 (chuỗi tuỳ ý; backend không ép schema chặt hơn). Học viên nối các khái
 * niệm bằng quan hệ được phép — không định nghĩa đáp án đúng ở builder.
 */
export function ReasoningConnectEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const nodes = readNodes(activity.config);
  const relations = readRelations(activity.config);

  function write(next: { nodes?: Node[]; relations?: string[] }) {
    const cfg: Record<string, unknown> = { ...activity.config };
    if (next.nodes) cfg.nodes = next.nodes.map((n) => ({ ...n, id: n.id, label: n.label }));
    if (next.relations) cfg.allowedRelations = next.relations;
    onChange({ config: cfg });
  }

  function toggleRelation(r: string) {
    const s = new Set(relations);
    if (s.has(r)) s.delete(r);
    else s.add(r);
    write({ relations: Array.from(s) });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <div className="flex flex-col gap-2">
        <Label>Khái niệm / sự kiện (nút) *</Label>
        {nodes.map((n, i) => (
          <div key={n.id} className="flex items-center gap-2">
            <span className="w-6 text-center text-xs text-ink-muted">{i + 1}</span>
            <Input
              value={n.label}
              disabled={readOnly}
              placeholder={`Khái niệm ${i + 1} — ví dụ: Thuỷ triều lên`}
              aria-label={`Khái niệm ${i + 1}`}
              onChange={(e) =>
                write({ nodes: nodes.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)) })
              }
            />
            {!readOnly && (
              <Button
                variant="secondary"
                className="h-9 px-2"
                disabled={nodes.length <= 2}
                aria-label={`Xoá khái niệm ${i + 1}`}
                onClick={() => write({ nodes: nodes.filter((_, j) => j !== i) })}
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
              write({ nodes: [...nodes, { id: genItemId(nodes.map((x) => x.id)), label: "" }] })
            }
          >
            <Plus className="size-4" /> Thêm khái niệm
          </Button>
        )}
        {nodes.length < 2 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 2 khái niệm để học viên nối.
          </p>
        )}
        {nodes.some((n) => !n.label.trim()) && (
          <p role="alert" className="text-xs text-error">
            Có khái niệm chưa nhập nội dung — điền đủ hoặc xoá bớt.
          </p>
        )}
      </div>

      <div className="flex flex-col gap-2">
        <Label>Quan hệ được phép *</Label>
        <p className="text-xs text-ink-muted">
          Học viên gắn nhãn quan hệ giữa các nút từ danh sách này.
        </p>
        <div className="flex flex-wrap gap-2">
          {RELATION_PRESETS.map((r) => (
            <label
              key={r}
              className={
                "flex cursor-pointer items-center gap-1.5 rounded-md border px-2.5 py-1 text-xs " +
                (relations.includes(r) ? "border-brand bg-brand/10 text-ink" : "border-border text-ink-muted")
              }
            >
              <input
                type="checkbox"
                className="size-3.5 accent-brand"
                checked={relations.includes(r)}
                disabled={readOnly}
                onChange={() => toggleRelation(r)}
              />
              {RELATION_LABELS[r] ?? r}
            </label>
          ))}
        </div>
        {relations
          .filter((r) => !(RELATION_PRESETS as readonly string[]).includes(r))
          .map((r) => (
            <div key={r} className="flex items-center gap-2">
              <Input value={RELATION_LABELS[r] ?? r} disabled className="w-52" />
              {!readOnly && (
                <Button
                  variant="secondary"
                  className="h-9 px-2"
                  aria-label={`Xoá quan hệ ${r}`}
                  onClick={() => write({ relations: relations.filter((x) => x !== r) })}
                >
                  <Trash2 className="size-3.5" />
                </Button>
              )}
            </div>
          ))}
        <CustomRelationInput
          disabled={readOnly || false}
          onAdd={(r) => {
            if (!relations.includes(r)) write({ relations: [...relations, r] });
          }}
        />
        {relations.length === 0 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 1 quan hệ được phép.
          </p>
        )}
      </div>
    </div>
  );
}

/** Ô nhập quan hệ tuỳ ý (ví dụ "dan-den"). */
function CustomRelationInput({ disabled, onAdd }: { disabled: boolean; onAdd: (r: string) => void }) {
  return (
    <div className="flex items-center gap-2">
      <Input
        placeholder="Quan hệ khác (ví dụ: dẫn đến)…"
        className="w-52"
        disabled={disabled}
        onKeyDown={(e) => {
          if (e.key !== "Enter") return;
          const v = (e.target as HTMLInputElement).value.trim();
          if (v) {
            onAdd(v);
            (e.target as HTMLInputElement).value = "";
          }
          e.preventDefault();
        }}
        aria-label="Thêm quan hệ tuỳ ý"
      />
      <Button
        variant="secondary"
        size="sm"
        disabled={disabled}
        onClick={(e) => {
          const input = (e.currentTarget.previousSibling as HTMLInputElement);
          const v = input.value.trim();
          if (v) {
            onAdd(v);
            input.value = "";
          }
        }}
      >
        <Plus className="size-4" /> Thêm
      </Button>
    </div>
  );
}
