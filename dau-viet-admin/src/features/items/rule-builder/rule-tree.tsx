"use client";

import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import { LeafRow } from "./leaf-row";
import type { BuilderState, LeafForm } from "./rule-ast";

/**
 * Panel phải của Rule Builder: root ALL/ANY + danh sách leaf rows.
 * Depth ≤ 2 — chỉ một lớp operator bọc các leaf (contract backend).
 */
export function RuleTree({
  state,
  onChange,
}: {
  state: BuilderState;
  onChange: (next: BuilderState) => void;
}) {
  const updateLeaf = (localId: string, next: LeafForm) =>
    onChange({
      ...state,
      children: state.children.map((c) => (c.localId === localId ? next : c)),
    });

  const removeLeaf = (localId: string) =>
    onChange({
      ...state,
      children: state.children.filter((c) => c.localId !== localId),
    });

  const moveLeaf = (index: number, delta: -1 | 1) => {
    const j = index + delta;
    if (j < 0 || j >= state.children.length) return;
    const next = [...state.children];
    const a = next[index];
    const b = next[j];
    if (!a || !b) return;
    next[index] = b;
    next[j] = a;
    onChange({ ...state, children: next });
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-3">
        <Label htmlFor="rule-root" className="shrink-0">
          Học viên phải đạt
        </Label>
        <Select
          id="rule-root"
          value={state.root}
          onChange={(e) =>
            onChange({ ...state, root: e.target.value as "all" | "any" })
          }
          disabled={state.children.length <= 1}
          className="w-56"
        >
          <option value="all">TẤT CẢ điều kiện (AND)</option>
          <option value="any">MỘT TRONG các điều kiện (OR)</option>
        </Select>
      </div>

      {state.children.length === 0 ? (
        <p className="rounded-md border border-dashed border-border px-3 py-6 text-center text-sm text-ink-muted">
          Chưa có điều kiện nào — thêm từ thư viện bên trái.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {state.children.map((leaf, i) => (
            <LeafRow
              key={leaf.localId}
              leaf={leaf}
              index={i}
              count={state.children.length}
              onChange={(next) => updateLeaf(leaf.localId, next)}
              onRemove={() => removeLeaf(leaf.localId)}
              onMove={moveLeaf}
            />
          ))}
        </ul>
      )}
    </div>
  );
}
