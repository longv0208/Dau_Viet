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

interface ExpectedRelation {
  from: string;
  to: string;
  relation: string;
}

function readExpectedRelations(config: Record<string, unknown> | undefined): ExpectedRelation[] {
  const raw = config?.expectedRelations;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((r) => r && typeof r === "object")
    .map((r) => {
      const x = r as Record<string, unknown>;
      return {
        from: String(x.from ?? ""),
        to: String(x.to ?? ""),
        relation: String(x.relation ?? ""),
      };
    })
    .filter((r) => r.from && r.to && r.relation);
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
  const graded = (activity.config?.graded as boolean | undefined) ?? false;
  const expected = readExpectedRelations(activity.config);

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

      <label className="flex items-center gap-2 text-sm text-ink">
        <input
          type="checkbox"
          className="size-4 accent-brand"
          checked={graded}
          disabled={readOnly}
          onChange={(e) =>
            onChange({ config: { ...activity.config, graded: e.target.checked || undefined } })
          }
        />
        Chấm điểm theo đáp án (graded)
      </label>
      {graded && (
        <ExpectedRelationsEditor
          nodes={nodes}
          relations={relations}
          expected={expected}
          readOnly={readOnly}
          onChange={(next) => onChange({ config: { ...activity.config, expectedRelations: next } })}
        />
      )}
    </div>
  );
}

/** Graded-mode: canonical expectedRelations[] — pick from/to/relation. */
function ExpectedRelationsEditor({
  nodes, relations, expected, readOnly, onChange,
}: {
  nodes: Node[];
  relations: string[];
  expected: ExpectedRelation[];
  readOnly?: boolean;
  onChange: (next: ExpectedRelation[]) => void;
}) {
  function add() {
    const from = nodes[0]?.id;
    const to = nodes[1]?.id;
    const rel = relations[0];
    if (from === undefined || to === undefined || rel === undefined) return;
    onChange([...expected, { from, to, relation: rel }]);
  }
  function set(i: number, patch: Partial<ExpectedRelation>) {
    onChange(expected.map((r, j) => (j === i ? { ...r, ...patch } : r)));
  }
  return (
    <div className="flex flex-col gap-2 rounded-md border border-brand/30 bg-brand/5 p-3">
      <Label>Quan hệ đúng (đáp án) *</Label>
      <p className="text-xs text-ink-muted">
        Backend chấm đúng khi học viên nối đúng TẤT CẢ các quan hệ này — không hiển thị cho học viên.
      </p>
      {expected.map((r, i) => (
        <div key={i} className="flex items-center gap-2">
          <select
            className="h-9 rounded-md border border-border bg-white px-2 text-sm"
            value={r.from}
            disabled={readOnly}
            aria-label={`Quan hệ ${i + 1} — từ`}
            onChange={(e) => set(i, { from: e.target.value })}
          >
            {nodes.map((n) => (
              <option key={n.id} value={n.id}>{n.label || n.id}</option>
            ))}
          </select>
          <select
            className="h-9 rounded-md border border-border bg-white px-2 text-sm"
            value={r.relation}
            disabled={readOnly}
            aria-label={`Quan hệ ${i + 1} — loại`}
            onChange={(e) => set(i, { relation: e.target.value })}
          >
            {relations.map((x) => (
              <option key={x} value={x}>{x}</option>
            ))}
          </select>
          <select
            className="h-9 rounded-md border border-border bg-white px-2 text-sm"
            value={r.to}
            disabled={readOnly}
            aria-label={`Quan hệ ${i + 1} — đến`}
            onChange={(e) => set(i, { to: e.target.value })}
          >
            {nodes.map((n) => (
              <option key={n.id} value={n.id}>{n.label || n.id}</option>
            ))}
          </select>
          {!readOnly && (
            <Button
              variant="secondary"
              className="h-9 px-2"
              aria-label={`Xoá quan hệ đúng ${i + 1}`}
              onClick={() => onChange(expected.filter((_, j) => j !== i))}
            >
              <Trash2 className="size-3.5" />
            </Button>
          )}
        </div>
      ))}
      {!readOnly && (
        <Button
          variant="secondary"
          size="sm"
          className="self-start"
          disabled={nodes.length < 2 || relations.length === 0}
          onClick={add}
        >
          <Plus className="size-4" /> Thêm quan hệ đúng
        </Button>
      )}
      {expected.length === 0 && (
        <p role="alert" className="text-xs text-error">
          Cần ít nhất 1 quan hệ đúng để xuất bản khi chấm điểm.
        </p>
      )}
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
